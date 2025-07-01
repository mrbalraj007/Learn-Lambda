#!/bin/bash

#==============================================================================
# Script Name: export_route53_records_detailed.sh
# Description: Export all Route 53 hosted zones and their detailed records information to CSV file
# Author: Professional AWS DevOps Engineer
# Date: $(date +"%Y-%m-%d")
# Version: 2.0
# 
# This script exports comprehensive Route 53 information including:
# - Hosted Zone Name and details
# - All DNS records within each hosted zone
# - Record Name, Type, Routing Policy, Alias, Value/Route Traffic to, TTL, Evaluate Target Health
#==============================================================================

# Set default AWS region
export AWS_DEFAULT_REGION="ap-southeast-2"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_processing() {
    echo -e "${CYAN}[PROCESSING]${NC} $1"
}

# Function to display script banner
display_banner() {
    echo -e "${CYAN}"
    echo "=============================================================================="
    echo "  AWS Route 53 Comprehensive Records Export Tool"
    echo "  Professional AWS DevOps Engineer Script"
    echo "  Region: $AWS_DEFAULT_REGION"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================================================="
    echo -e "${NC}"
}

# Function to check if AWS CLI is installed and configured
check_aws_cli() {
    print_status "Checking AWS CLI installation and configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        print_error "Installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        print_error "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    # Display current AWS identity
    local identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    print_success "AWS CLI configured - Identity: $identity"
}

# Function to validate Route 53 permissions
validate_permissions() {
    print_status "Validating Route 53 permissions..."
    
    if ! aws route53 list-hosted-zones --max-items 1 &> /dev/null; then
        print_error "Insufficient permissions to access Route 53."
        print_error "Required permissions: route53:ListHostedZones, route53:GetHostedZone, route53:ListResourceRecordSets"
        exit 1
    fi
    
    print_success "Route 53 permissions validated"
}

# Function to create output directory if it doesn't exist
create_output_dir() {
    OUTPUT_DIR="route53_exports"
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        print_status "Created output directory: $OUTPUT_DIR"
    fi
}

# Function to generate CSV filename with timestamp
generate_filename() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    CSV_FILENAME="route53_exports/route53_detailed_records_${TIMESTAMP}.csv"
    echo "$CSV_FILENAME"
}

# Function to write CSV header
write_csv_header() {
    local filename=$1
    {
        echo "Hosted Zone Name,Hosted Zone ID,Zone Type,Record Name,Record Type,Routing Policy,Alias Target,Alias Hosted Zone ID,Value/Route Traffic To,TTL,Evaluate Target Health,Set Identifier,Weight,Region,Failover,Health Check ID,Export Timestamp"
    } > "$filename"
    print_status "CSV header written to $filename"
}

# Function to get hosted zone type
get_zone_type() {
    local zone_id=$1
    local vpc_info
    
    vpc_info=$(aws route53 get-hosted-zone --id "$zone_id" --query 'VPCs' --output text 2>/dev/null)
    
    if [ "$vpc_info" == "None" ] || [ -z "$vpc_info" ] || [ "$vpc_info" == "null" ]; then
        echo "Public"
    else
        echo "Private"
    fi
}

# Function to safely extract JSON values with null handling
safe_extract() {
    local value="$1"
    if [ "$value" == "null" ] || [ -z "$value" ]; then
        echo ""
    else
        echo "$value"
    fi
}

# Function to extract routing policy information
get_routing_policy() {
    local record_json="$1"
    local set_identifier=$(echo "$record_json" | jq -r '.SetIdentifier // empty')
    local weight=$(echo "$record_json" | jq -r '.Weight // empty')
    local region=$(echo "$record_json" | jq -r '.Region // empty')
    local failover=$(echo "$record_json" | jq -r '.Failover // empty')
    
    if [ -n "$weight" ]; then
        echo "Weighted"
    elif [ -n "$region" ]; then
        echo "Latency-based"
    elif [ -n "$failover" ]; then
        echo "Failover"
    elif [ -n "$set_identifier" ]; then
        echo "Geolocation/Geoproximity"
    else
        echo "Simple"
    fi
}

# Function to process records for a hosted zone
process_zone_records() {
    local zone_name="$1"
    local zone_id="$2"
    local zone_type="$3"
    local filename="$4"
    local export_time="$5"
    
    print_processing "Processing records for hosted zone: $zone_name"
    
    # Get all resource record sets for this hosted zone
    local records_json
    records_json=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_warning "Failed to retrieve records for hosted zone: $zone_name"
        return
    fi
    
    # Count total records
    local record_count
    record_count=$(echo "$records_json" | jq '.ResourceRecordSets | length')
    print_status "Found $record_count records in hosted zone: $zone_name"
    
    # Process each record
    echo "$records_json" | jq -c '.ResourceRecordSets[]' | while read -r record; do
        # Extract basic record information
        local record_name=$(echo "$record" | jq -r '.Name')
        local record_type=$(echo "$record" | jq -r '.Type')
        local ttl=$(echo "$record" | jq -r '.TTL // empty')
        
        # Extract alias information
        local alias_target=""
        local alias_zone_id=""
        local evaluate_target_health=""
        
        if echo "$record" | jq -e '.AliasTarget' >/dev/null 2>&1; then
            alias_target=$(echo "$record" | jq -r '.AliasTarget.DNSName // empty')
            alias_zone_id=$(echo "$record" | jq -r '.AliasTarget.HostedZoneId // empty')
            evaluate_target_health=$(echo "$record" | jq -r '.AliasTarget.EvaluateTargetHealth // empty')
        fi
        
        # Extract resource records (values)
        local values=""
        if echo "$record" | jq -e '.ResourceRecords' >/dev/null 2>&1; then
            values=$(echo "$record" | jq -r '.ResourceRecords[].Value' | tr '\n' '; ' | sed 's/; $//')
        fi
        
        # Determine the main value/route traffic to field
        local route_traffic_to=""
        if [ -n "$alias_target" ]; then
            route_traffic_to="$alias_target"
        elif [ -n "$values" ]; then
            route_traffic_to="$values"
        fi
        
        # Extract routing policy information
        local routing_policy=$(get_routing_policy "$record")
        local set_identifier=$(echo "$record" | jq -r '.SetIdentifier // empty')
        local weight=$(echo "$record" | jq -r '.Weight // empty')
        local region=$(echo "$record" | jq -r '.Region // empty')
        local failover=$(echo "$record" | jq -r '.Failover // empty')
        local health_check_id=$(echo "$record" | jq -r '.HealthCheckId // empty')
        
        # Clean up record name (remove trailing dot if present)
        record_name=$(echo "$record_name" | sed 's/\.$//g')
        
        # Write record to CSV
        {
            printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
                "$zone_name" \
                "$zone_id" \
                "$zone_type" \
                "$record_name" \
                "$record_type" \
                "$routing_policy" \
                "$alias_target" \
                "$alias_zone_id" \
                "$route_traffic_to" \
                "$ttl" \
                "$evaluate_target_health" \
                "$set_identifier" \
                "$weight" \
                "$region" \
                "$failover" \
                "$health_check_id" \
                "$export_time"
        } >> "$filename"
    done
    
    print_success "Completed processing hosted zone: $zone_name"
}

# Function to export all Route 53 information
export_route53_info() {
    local filename=$1
    local export_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    print_status "Starting Route 53 export process..."
    
    # Get all hosted zones
    print_status "Retrieving list of hosted zones..."
    local zones_json
    zones_json=$(aws route53 list-hosted-zones --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to retrieve hosted zones list"
        exit 1
    fi
    
    # Count total hosted zones
    local zone_count
    zone_count=$(echo "$zones_json" | jq '.HostedZones | length')
    print_success "Found $zone_count hosted zones to process"
    
    if [ "$zone_count" -eq 0 ]; then
        print_warning "No hosted zones found in the current AWS account"
        return
    fi
    
    # Process each hosted zone
    local current_zone=1
    echo "$zones_json" | jq -c '.HostedZones[]' | while read -r zone; do
        local zone_name=$(echo "$zone" | jq -r '.Name' | sed 's/\.$//g')
        local zone_id=$(echo "$zone" | jq -r '.Id' | sed 's|/hostedzone/||g')
        local zone_type=$(get_zone_type "$zone_id")
        
        echo ""
        print_status "Processing hosted zone $current_zone of $zone_count: $zone_name"
        
        # Process all records in this hosted zone
        process_zone_records "$zone_name" "$zone_id" "$zone_type" "$filename" "$export_time"
        
        ((current_zone++))
    done
}

# Function to display export summary
display_summary() {
    local filename=$1
    
    if [ -f "$filename" ]; then
        local total_records=$(($(wc -l < "$filename") - 1))  # Subtract header line
        local file_size=$(ls -lh "$filename" | awk '{print $5}')
        
        echo ""
        print_success "Export completed successfully!"
        echo -e "${GREEN}=================================="
        echo -e "Export Summary:"
        echo -e "=================================="
        echo -e "Output file: $filename"
        echo -e "Total records exported: $total_records"
        echo -e "File size: $file_size"
        echo -e "Export completed at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "==================================${NC}"
        echo ""
        print_status "You can open the CSV file in Excel, Google Sheets, or any CSV viewer"
    else
        print_error "Export file not found: $filename"
    fi
}

# Main execution function
main() {
    # Display banner
    display_banner
    
    # Pre-flight checks
    check_aws_cli
    validate_permissions
    create_output_dir
    
    # Generate filename and create CSV
    local csv_file
    csv_file=$(generate_filename)
    
    print_status "Export will be saved to: $csv_file"
    
    # Write CSV header
    write_csv_header "$csv_file"
    
    # Export Route 53 information
    export_route53_info "$csv_file"
    
    # Display summary
    display_summary "$csv_file"
    
    print_success "Route 53 detailed export process completed!"
}

# Script execution starts here
main "$@"
