#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\25.Bash_Script_AWS_S3\Working_For_Hosted_Zones\export_route53_info.sh

# AWS Route 53 Hosted Zones Information Export Script
# Description: Exports all Route 53 hosted zone details to CSV format

set -e  # Exit on any error

# Configuration
AWS_REGION="ap-southeast-2"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$(dirname "$0")"
CSV_FILE="${OUTPUT_DIR}/route53_hosted_zones_${TIMESTAMP}.csv"
LOG_FILE="${OUTPUT_DIR}/export_log_${TIMESTAMP}.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check AWS CLI availability
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_message "ERROR: AWS CLI is not installed or not in PATH"
        exit 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log_message "ERROR: AWS credentials not configured or invalid"
        exit 1
    fi
}

# Function to get hosted zone details
get_hosted_zone_details() {
    local zone_id="$1"
    local zone_name="$2"
    
    # Get hosted zone details
    local zone_details=$(aws route53 get-hosted-zone --id "$zone_id" --region "$AWS_REGION" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Extract information from the response
        local created_date=$(echo "$zone_details" | jq -r '.HostedZone.Config.Comment // "N/A"')
        local description=$(echo "$zone_details" | jq -r '.HostedZone.Config.Comment // "N/A"')
        local private_zone=$(echo "$zone_details" | jq -r '.HostedZone.Config.PrivateZone')
        local zone_type="Public"
        
        if [ "$private_zone" = "true" ]; then
            zone_type="Private"
        fi
        
        # Get record count
        local record_count=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --region "$AWS_REGION" --query 'length(ResourceRecordSets)' --output text 2>/dev/null || echo "0")
        
        # Get creation date from hosted zone details
        local creation_date=$(echo "$zone_details" | jq -r '.HostedZone.CreatedDate // "N/A"')
        
        # Try to get creator information (this might not be available)
        local created_by="N/A"
        
        # Clean zone name (remove trailing dot)
        zone_name=$(echo "$zone_name" | sed 's/\.$//')
        
        # Output CSV row
        echo "\"$zone_name\",\"$zone_type\",\"$created_by\",\"$record_count\",\"$description\",\"$zone_id\",\"$creation_date\""
    else
        log_message "WARNING: Failed to get details for hosted zone: $zone_id"
        echo "\"$zone_name\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$zone_id\",\"N/A\""
    fi
}

# Main function
main() {
    log_message "Starting Route 53 hosted zones export..."
    
    # Check prerequisites
    check_aws_cli
    check_aws_credentials
    
    log_message "Using AWS Region: $AWS_REGION"
    log_message "Output file: $CSV_FILE"
    
    # Create CSV header
    echo "Hosted Zone Name,Type,Created By,Record Count,Description,Hosted Zone ID,Creation Date" > "$CSV_FILE"
    
    # Get all hosted zones
    log_message "Retrieving hosted zones list..."
    local hosted_zones=$(aws route53 list-hosted-zones --region "$AWS_REGION" --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to retrieve hosted zones"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_message "ERROR: jq is required but not installed"
        exit 1
    fi
    
    # Extract hosted zones and process each one
    local zone_count=$(echo "$hosted_zones" | jq '.HostedZones | length')
    log_message "Found $zone_count hosted zones"
    
    if [ "$zone_count" -eq 0 ]; then
        log_message "No hosted zones found in the account for region $AWS_REGION"
        exit 0
    fi
    
    # Process each hosted zone
    for i in $(seq 0 $((zone_count - 1))); do
        local zone_id=$(echo "$hosted_zones" | jq -r ".HostedZones[$i].Id" | sed 's|/hostedzone/||')
        local zone_name=$(echo "$hosted_zones" | jq -r ".HostedZones[$i].Name")
        
        log_message "Processing hosted zone: $zone_name ($zone_id)"
        
        # Get detailed information and append to CSV
        get_hosted_zone_details "$zone_id" "$zone_name" >> "$CSV_FILE"
    done
    
    log_message "Export completed successfully!"
    log_message "CSV file saved as: $CSV_FILE"
    log_message "Total hosted zones processed: $zone_count"
    
    # Display summary
    echo ""
    echo "========================================="
    echo "Route 53 Export Summary"
    echo "========================================="
    echo "Region: $AWS_REGION"
    echo "Total Hosted Zones: $zone_count"
    echo "Output File: $CSV_FILE"
    echo "Log File: $LOG_FILE"
    echo "========================================="
}

# Execute main function
main "$@"
