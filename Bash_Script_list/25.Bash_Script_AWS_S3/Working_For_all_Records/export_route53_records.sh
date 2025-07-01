#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\25.Bash_Script_AWS_S3\export_route53_records.sh

# AWS Route 53 DNS Records Export Script
# Author: AWS DevOps Engineer
# Description: Exports all Route 53 hosted zones and DNS records to CSV

set -euo pipefail

# Configuration
AWS_REGION="ap-southeast-2"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="route53_export_${TIMESTAMP}.csv"
TEMP_DIR="/tmp/route53_export_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid."
        exit 1
    fi
    
    # Check jq installation
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it first."
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create CSV header
create_csv_header() {
    log "Creating CSV header..."
    echo "Export_Date,Hosted_Zone_ID,Hosted_Zone_Name,Record_Name,Record_Type,Routing_Policy,Alias,Value_Route_Traffic_To,TTL,Evaluate_Target_Health" > "$OUTPUT_FILE"
    success "CSV header created"
}

# Get all hosted zones
get_hosted_zones() {
    log "Fetching all hosted zones..."
    aws route53 list-hosted-zones --region "$AWS_REGION" --output json > "$TEMP_DIR/hosted_zones.json"
    
    local zone_count
    zone_count=$(jq '.HostedZones | length' "$TEMP_DIR/hosted_zones.json")
    success "Found $zone_count hosted zones"
}

# Process each hosted zone
process_hosted_zones() {
    local zone_count
    zone_count=$(jq '.HostedZones | length' "$TEMP_DIR/hosted_zones.json")
    
    for ((i=0; i<zone_count; i++)); do
        local hosted_zone_id zone_name
        hosted_zone_id=$(jq -r ".HostedZones[$i].Id" "$TEMP_DIR/hosted_zones.json" | sed 's|/hostedzone/||')
        zone_name=$(jq -r ".HostedZones[$i].Name" "$TEMP_DIR/hosted_zones.json")
        
        log "Processing hosted zone: $zone_name (ID: $hosted_zone_id)"
        
        # Get all records for this hosted zone
        aws route53 list-resource-record-sets \
            --hosted-zone-id "$hosted_zone_id" \
            --region "$AWS_REGION" \
            --output json > "$TEMP_DIR/records_${hosted_zone_id}.json"
        
        process_dns_records "$hosted_zone_id" "$zone_name"
    done
}

# Process DNS records for a hosted zone
process_dns_records() {
    local hosted_zone_id="$1"
    local zone_name="$2"
    local export_date
    export_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Process each record set
    jq -c '.ResourceRecordSets[]' "$TEMP_DIR/records_${hosted_zone_id}.json" | while read -r record; do
        local record_name record_type routing_policy alias_target ttl health_check
        local value_route_traffic_to evaluate_target_health
        
        # Extract basic fields
        record_name=$(echo "$record" | jq -r '.Name // "N/A"')
        record_type=$(echo "$record" | jq -r '.Type // "N/A"')
        ttl=$(echo "$record" | jq -r '.TTL // "N/A"')
        
        # Check if it's an alias record
        if echo "$record" | jq -e '.AliasTarget' > /dev/null 2>&1; then
            alias_target="Yes"
            value_route_traffic_to=$(echo "$record" | jq -r '.AliasTarget.DNSName // "N/A"')
            evaluate_target_health=$(echo "$record" | jq -r '.AliasTarget.EvaluateTargetHealth // "N/A"')
            ttl="N/A" # Alias records don't have TTL
        else
            alias_target="No"
            evaluate_target_health="N/A"
            # Get resource records
            if echo "$record" | jq -e '.ResourceRecords' > /dev/null 2>&1; then
                value_route_traffic_to=$(echo "$record" | jq -r '.ResourceRecords[].Value' | tr '\n' ';' | sed 's/;$//')
            else
                value_route_traffic_to="N/A"
            fi
        fi
        
        # Determine routing policy
        if echo "$record" | jq -e '.Weight' > /dev/null 2>&1; then
            routing_policy="Weighted"
        elif echo "$record" | jq -e '.Region' > /dev/null 2>&1; then
            routing_policy="Latency-based"
        elif echo "$record" | jq -e '.Failover' > /dev/null 2>&1; then
            routing_policy="Failover"
        elif echo "$record" | jq -e '.GeoLocation' > /dev/null 2>&1; then
            routing_policy="Geolocation"
        elif echo "$record" | jq -e '.MultiValueAnswer' > /dev/null 2>&1; then
            routing_policy="Multivalue Answer"
        else
            routing_policy="Simple"
        fi
        
        # Clean up fields for CSV (escape quotes and commas)
        record_name=$(echo "$record_name" | sed 's/"/""/g')
        zone_name=$(echo "$zone_name" | sed 's/"/""/g')
        value_route_traffic_to=$(echo "$value_route_traffic_to" | sed 's/"/""/g')
        
        # Write to CSV
        echo "\"$export_date\",\"$hosted_zone_id\",\"$zone_name\",\"$record_name\",\"$record_type\",\"$routing_policy\",\"$alias_target\",\"$value_route_traffic_to\",\"$ttl\",\"$evaluate_target_health\"" >> "$OUTPUT_FILE"
    done
    
    local record_count
    record_count=$(jq '.ResourceRecordSets | length' "$TEMP_DIR/records_${hosted_zone_id}.json")
    success "Processed $record_count records for zone: $zone_name"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Main execution
main() {
    log "Starting Route 53 DNS Records Export"
    log "AWS Region: $AWS_REGION"
    log "Output file: $OUTPUT_FILE"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Set up cleanup on exit
    trap cleanup EXIT
    
    # Execute workflow
    check_prerequisites
    create_csv_header
    get_hosted_zones
    process_hosted_zones
    
    # Final summary
    local total_records
    total_records=$(($(wc -l < "$OUTPUT_FILE") - 1)) # Subtract header
    
    success "Export completed successfully!"
    success "Total DNS records exported: $total_records"
    success "Output file: $OUTPUT_FILE"
    success "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    
    log "Sample of exported data:"
    head -n 5 "$OUTPUT_FILE" | column -t -s ','
}

# Script usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -r, --region   AWS region (default: ap-southeast-2)"
    echo ""
    echo "Example:"
    echo "  $0"
    echo "  $0 --region us-east-1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Execute main function
main "$@"