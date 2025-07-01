#!/bin/bash

#==============================================================================
# Script Name: export_route53_info.sh
# Description: Export all Route 53 hosted zones information to CSV file
# Author: AWS DevOps Engineer
# Date: $(date +"%Y-%m-%d")
# Version: 1.0
# 
# This script exports the following Route 53 information:
# - Hosted Zone Name
# - Type (Public/Private)
# - Created By (Caller Reference)
# - Record Count
# - Description
# - Hosted Zone ID
#==============================================================================

# Set default AWS region
export AWS_DEFAULT_REGION="ap-southeast-2"

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to check if AWS CLI is installed and configured
check_aws_cli() {
    print_status "Checking AWS CLI installation and configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        print_error "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    print_success "AWS CLI is properly configured"
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
    CSV_FILENAME="route53_exports/route53_hosted_zones_${TIMESTAMP}.csv"
    echo "$CSV_FILENAME"
}

# Function to write CSV header
write_csv_header() {
    local filename=$1
    echo "Hosted Zone Name,Type,Created By,Record Count,Description,Hosted Zone ID,Export Date" > "$filename"
    print_status "CSV header written to $filename"
}

# Function to get hosted zone type
get_zone_type() {
    local zone_id=$1
    local vpc_info
    
    vpc_info=$(aws route53 get-hosted-zone --id "$zone_id" --query 'VPCs' --output text 2>/dev/null)
    
    if [ "$vpc_info" == "None" ] || [ -z "$vpc_info" ]; then
        echo "Public"
    else
        echo "Private"
    fi
}

# Function to get record count for a hosted zone
get_record_count() {
    local zone_id=$1
    local count
    
    count=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --query 'length(ResourceRecordSets)' --output text 2>/dev/null)
    
    if [ -z "$count" ] || [ "$count" == "None" ]; then
        echo "0"
    else
        echo "$count"
    fi
}

# Function to clean and escape CSV data
clean_csv_data() {
    local data="$1"
    # Remove newlines and carriage returns, escape quotes
    echo "$data" | tr -d '\n\r' | sed 's/"/""/g'
}

# Main function to export Route 53 information
export_route53_info() {
    local csv_file=$1
    local zone_count=0
    local processed_count=0
    
    print_status "Fetching Route 53 hosted zones information..."
    
    # Get all hosted zones
    local hosted_zones
    hosted_zones=$(aws route53 list-hosted-zones --query 'HostedZones[*].[Id,Name,CallerReference,Config.Comment]' --output text 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$hosted_zones" ]; then
        print_error "Failed to retrieve hosted zones. Please check your AWS permissions."
        exit 1
    fi
    
    zone_count=$(echo "$hosted_zones" | wc -l)
    print_status "Found $zone_count hosted zone(s) to process"
    
    # Process each hosted zone
    while IFS=$'\t' read -r zone_id zone_name caller_ref description; do
        if [ -z "$zone_id" ]; then
            continue
        fi
        
        processed_count=$((processed_count + 1))
        print_status "Processing zone $processed_count/$zone_count: $zone_name"
        
        # Clean the zone ID (remove /hostedzone/ prefix)
        clean_zone_id=$(echo "$zone_id" | sed 's|/hostedzone/||')
        
        # Get zone type
        zone_type=$(get_zone_type "$clean_zone_id")
        
        # Get record count
        record_count=$(get_record_count "$clean_zone_id")
        
        # Clean data for CSV
        clean_zone_name=$(clean_csv_data "$zone_name")
        clean_caller_ref=$(clean_csv_data "$caller_ref")
        clean_description=$(clean_csv_data "$description")
        
        # Replace empty description with N/A
        if [ -z "$clean_description" ] || [ "$clean_description" == "None" ]; then
            clean_description="N/A"
        fi
        
        # Get current date and time
        export_date=$(date +"%Y-%m-%d %H:%M:%S")
        
        # Write to CSV
        echo "\"$clean_zone_name\",\"$zone_type\",\"$clean_caller_ref\",\"$record_count\",\"$clean_description\",\"$clean_zone_id\",\"$export_date\"" >> "$csv_file"
        
    done <<< "$hosted_zones"
    
    print_success "Processed $processed_count hosted zone(s)"
}

# Function to display summary
display_summary() {
    local csv_file=$1
    local record_count
    
    if [ -f "$csv_file" ]; then
        record_count=$(($(wc -l < "$csv_file") - 1)) # Subtract header row
        print_success "Export completed successfully!"
        echo
        echo "=== EXPORT SUMMARY ==="
        echo "Output file: $csv_file"
        echo "Total records exported: $record_count"
        echo "Export date: $(date +"%Y-%m-%d %H:%M:%S")"
        echo "AWS Region: $AWS_DEFAULT_REGION"
        echo
        
        if [ $record_count -gt 0 ]; then
            print_status "Sample of exported data:"
            echo "========================"
            head -n 3 "$csv_file" | column -t -s ','
            echo "========================"
        fi
    else
        print_error "Export failed - output file not found"
        exit 1
    fi
}

# Main execution
main() {
    echo "==================================================================="
    echo "              AWS Route 53 Information Export Tool"
    echo "==================================================================="
    echo "Region: $AWS_DEFAULT_REGION"
    echo "Start time: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "==================================================================="
    echo
    
    # Check prerequisites
    check_aws_cli
    
    # Create output directory
    create_output_dir
    
    # Generate filename
    CSV_FILE=$(generate_filename)
    
    # Write CSV header
    write_csv_header "$CSV_FILE"
    
    # Export Route 53 information
    export_route53_info "$CSV_FILE"
    
    # Display summary
    display_summary "$CSV_FILE"
    
    echo "==================================================================="
    echo "Export completed at: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "==================================================================="
}

# Trap to handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' INT TERM

# Execute main function
main "$@"
