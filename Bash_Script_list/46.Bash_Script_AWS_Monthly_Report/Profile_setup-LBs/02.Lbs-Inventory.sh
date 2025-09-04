#!/bin/bash
# AWS Load Balancer Export Script with SSO Support
# Author: AWS DevOps Engineer
# Description: Exports all Load Balancer information from multiple accounts to CSV file

# Set default region
DEFAULT_REGION="ap-southeast-2"
REGION=${AWS_DEFAULT_REGION:-$DEFAULT_REGION}

# SSO Configuration
SSO_SESSION_NAME="readonly"
PROFILES_REPORT="aws_profiles_verification.csv"
FINAL_OUTPUT_DIR="./lb_inventory_reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check AWS CLI installation and CSV file
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if JQ is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq first."
        exit 1
    fi
    
    # Check if profiles report exists
    if [ ! -f "$PROFILES_REPORT" ]; then
        print_error "Profiles report '$PROFILES_REPORT' not found. Please run 01.generate_aws_config.sh first."
        exit 1
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$FINAL_OUTPUT_DIR"
    
    print_status "Prerequisites check completed successfully."
}

# Get all valid AWS profiles from report file
get_valid_profiles() {
    print_status "Reading valid AWS profiles from $PROFILES_REPORT..."
    
    # Skip header line and only include profiles with "Success" status
    VALID_PROFILES=($(tail -n +2 "$PROFILES_REPORT" | grep "Success" | cut -d',' -f1))
    
    if [ ${#VALID_PROFILES[@]} -eq 0 ]; then
        print_error "No valid profiles found in $PROFILES_REPORT"
        exit 1
    fi
    
    print_status "Found ${#VALID_PROFILES[@]} valid AWS profiles"
    return 0
}

# Get AWS Account ID for a specific profile
get_account_id() {
    local profile=$1
    print_status "Retrieving AWS Account ID for profile $profile..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$profile" --query "Account" --output text 2>/dev/null)
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Failed to retrieve AWS Account ID for profile $profile. Check your credentials."
        return 1
    fi
    
    print_status "AWS Account ID for profile $profile: $AWS_ACCOUNT_ID"
    return 0
}

# Generate timestamp and create output file name for a specific profile
create_output_filename() {
    local profile=$1
    local account_id=$2
    
    # Generate timestamp for filename
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Create output filename with account ID
    OUTPUT_FILE="$FINAL_OUTPUT_DIR/aws_loadbalancers_${account_id}_${TIMESTAMP}.csv"
    print_status "Output for profile $profile will be saved to: $OUTPUT_FILE"
}

# Function to create CSV header
create_csv_header() {
    local output_file=$1
    echo "LoadBalancer_Name,DNS_Name,State,VPC_ID,Availability_Zones,Type,Date_Created" > "$output_file"
    print_status "CSV file created: $output_file"
}

# Function to export ALB/NLB (Version 2) Load Balancers for a specific profile
export_alb_nlb() {
    local profile=$1
    local output_file=$2
    
    print_status "Fetching Application and Network Load Balancers for profile $profile..."
    
    aws elbv2 describe-load-balancers --profile "$profile" --region "$REGION" --output json | jq -r '
        .LoadBalancers[] | 
        [
            .LoadBalancerName,
            .DNSName,
            .State.Code,
            .VpcId,
            (.AvailabilityZones | map(.ZoneName) | join(";")),
            .Type,
            .CreatedTime
        ] | @csv
    ' >> "$output_file" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        ALB_COUNT=$(aws elbv2 describe-load-balancers --profile "$profile" --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null)
        print_status "Exported $ALB_COUNT Application/Network Load Balancers for profile $profile"
    else
        print_warning "Failed to fetch ALB/NLB or no ALB/NLB found for profile $profile"
    fi
}

# Function to export Classic Load Balancers for a specific profile
export_classic_lb() {
    local profile=$1
    local output_file=$2
    
    print_status "Fetching Classic Load Balancers for profile $profile..."
    
    aws elb describe-load-balancers --profile "$profile" --region "$REGION" --output json | jq -r '
        .LoadBalancerDescriptions[] | 
        [
            .LoadBalancerName,
            .DNSName,
            "active",
            .VPCId,
            (.AvailabilityZones | join(";")),
            "classic",
            .CreatedTime
        ] | @csv
    ' >> "$output_file" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        CLB_COUNT=$(aws elb describe-load-balancers --profile "$profile" --region "$REGION" --query 'length(LoadBalancerDescriptions)' --output text 2>/dev/null)
        print_status "Exported $CLB_COUNT Classic Load Balancers for profile $profile"
    else
        print_warning "Failed to fetch Classic Load Balancers or no Classic Load Balancers found for profile $profile"
    fi
}

# Function to display summary for a specific profile
display_summary() {
    local profile=$1
    local output_file=$2
    local account_id=$3
    
    if [ -f "$output_file" ]; then
        TOTAL_RECORDS=$(($(wc -l < "$output_file") - 1))
        print_status "Export for profile $profile completed successfully!"
        print_status "Region: $REGION"
        print_status "AWS Account ID: $account_id"
        print_status "Total Load Balancers exported: $TOTAL_RECORDS"
        print_status "Output file: $output_file"
        print_status "File size: $(du -h "$output_file" | cut -f1)"
        
        # Display first few lines as preview
        echo ""
        print_status "Preview of exported data for profile $profile:"
        head -5 "$output_file" | column -t -s ','
        echo ""
    else
        print_error "Export failed for profile $profile - output file not created"
        return 1
    fi
    
    return 0
}

# Process a single AWS profile
process_profile() {
    local profile=$1
    
    print_status "Processing profile: $profile"
    
    # Get account ID for this profile
    if ! get_account_id "$profile"; then
        print_error "Failed to get account ID for profile $profile. Skipping..."
        return 1
    fi
    
    # Create output filename for this profile
    create_output_filename "$profile" "$AWS_ACCOUNT_ID"
    
    # Create CSV file with header
    create_csv_header "$OUTPUT_FILE"
    
    # Export different types of load balancers for this profile
    export_alb_nlb "$profile" "$OUTPUT_FILE"
    export_classic_lb "$profile" "$OUTPUT_FILE"
    
    # Display summary for this profile
    display_summary "$profile" "$OUTPUT_FILE" "$AWS_ACCOUNT_ID"
    
    return 0
}

# Combine all CSV files into one consolidated report
consolidate_reports() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    CONSOLIDATED_FILE="$FINAL_OUTPUT_DIR/consolidated_loadbalancers_${TIMESTAMP}.csv"
    
    print_status "Consolidating all reports into a single file: $CONSOLIDATED_FILE"
    
    # Create consolidated file with header
    echo "Account_ID,LoadBalancer_Name,DNS_Name,State,VPC_ID,Availability_Zones,Type,Date_Created" > "$CONSOLIDATED_FILE"
    
    # Find all CSV files in the output directory
    for csv_file in "$FINAL_OUTPUT_DIR"/aws_loadbalancers_*.csv; do
        if [ -f "$csv_file" ]; then
            # Extract account ID from filename
            account_id=$(basename "$csv_file" | cut -d'_' -f3)
            
            # Skip header line and prepend account ID to each line
            tail -n +2 "$csv_file" | while IFS= read -r line; do
                echo "$account_id,$line" >> "$CONSOLIDATED_FILE"
            done
        fi
    done
    
    TOTAL_RECORDS=$(($(wc -l < "$CONSOLIDATED_FILE") - 1))
    print_status "Consolidated report created with $TOTAL_RECORDS load balancers from all accounts"
    print_status "Consolidated file: $CONSOLIDATED_FILE"
}

# Main execution function
main() {
    print_status "Starting AWS Load Balancer export process with SSO..."
    print_status "Target Region: $REGION"
    print_status "Timestamp: $(date)"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Get valid AWS profiles
    get_valid_profiles
    
    # Process each valid profile
    SUCCESSFUL_PROFILES=0
    for profile in "${VALID_PROFILES[@]}"; do
        echo "--------------------------------------------------------------"
        if process_profile "$profile"; then
            ((SUCCESSFUL_PROFILES++))
        fi
        echo "--------------------------------------------------------------"
        echo ""
    done
    
    # Consolidate all reports into a single file
    consolidate_reports
    
    # Display final summary
    print_status "AWS Load Balancer export completed!"
    print_status "Successfully processed $SUCCESSFUL_PROFILES out of ${#VALID_PROFILES[@]} profiles"
    print_status "Output directory: $FINAL_OUTPUT_DIR"
    print_status "Script execution completed at $(date)"
}

# Script usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION    Set AWS region (default: ap-southeast-2)"
    echo "  -p, --profiles FILE    Profiles report CSV file (default: aws_profiles_verification.csv)"
    echo "  -o, --output DIR       Output directory (default: ./lb_inventory_reports)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_DEFAULT_REGION     Override default region"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use default settings"
    echo "  $0 -r us-east-1              # Use specific region"
    echo "  $0 -p my_profiles.csv        # Use custom profiles file"
    echo "  $0 -o /path/to/output        # Use custom output directory"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--profiles)
            PROFILES_REPORT="$2"
            shift 2
            ;;
        -o|--output)
            FINAL_OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute main function
main