#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\17.Bash_Script_AWS_All_Type_LBs\export_loadbalancers.sh

# AWS Load Balancer Export Script
# Author: AWS DevOps Engineer
# Description: Exports all Load Balancer information to CSV file

# Set default region
DEFAULT_REGION="ap-southeast-2"
REGION=${AWS_DEFAULT_REGION:-$DEFAULT_REGION}

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

# Function to check AWS CLI installation and credentials
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check completed successfully."
}

# Get AWS Account ID
get_account_id() {
    print_status "Retrieving AWS Account ID..."
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Failed to retrieve AWS Account ID. Check your credentials."
        exit 1
    fi
    
    print_status "AWS Account ID: $AWS_ACCOUNT_ID"
    return 0
}

# Generate timestamp and create output file name
create_output_filename() {
    # Generate timestamp for filename
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Create output filename with account ID
    OUTPUT_FILE="aws_loadbalancers_${AWS_ACCOUNT_ID}_${TIMESTAMP}.csv"
    print_status "Output will be saved to: $OUTPUT_FILE"
}

# Function to create CSV header
create_csv_header() {
    echo "LoadBalancer_Name,DNS_Name,State,VPC_ID,Availability_Zones,Type,Date_Created" > "$OUTPUT_FILE"
    print_status "CSV file created: $OUTPUT_FILE"
}

# Function to export ALB/NLB (Version 2) Load Balancers
export_alb_nlb() {
    print_status "Fetching Application and Network Load Balancers..."
    
    aws elbv2 describe-load-balancers --region "$REGION" --output json | jq -r '
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
    ' >> "$OUTPUT_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        ALB_COUNT=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null)
        print_status "Exported $ALB_COUNT Application/Network Load Balancers"
    else
        print_warning "Failed to fetch ALB/NLB or no ALB/NLB found"
    fi
}

# Function to export Classic Load Balancers
export_classic_lb() {
    print_status "Fetching Classic Load Balancers..."
    
    aws elb describe-load-balancers --region "$REGION" --output json | jq -r '
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
    ' >> "$OUTPUT_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        CLB_COUNT=$(aws elb describe-load-balancers --region "$REGION" --query 'length(LoadBalancerDescriptions)' --output text 2>/dev/null)
        print_status "Exported $CLB_COUNT Classic Load Balancers"
    else
        print_warning "Failed to fetch Classic Load Balancers or no Classic Load Balancers found"
    fi
}

# Function to display summary
display_summary() {
    if [ -f "$OUTPUT_FILE" ]; then
        TOTAL_RECORDS=$(($(wc -l < "$OUTPUT_FILE") - 1))
        print_status "Export completed successfully!"
        print_status "Region: $REGION"
        print_status "AWS Account ID: $AWS_ACCOUNT_ID"
        print_status "Total Load Balancers exported: $TOTAL_RECORDS"
        print_status "Output file: $OUTPUT_FILE"
        print_status "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
        
        # Display first few lines as preview
        echo ""
        print_status "Preview of exported data:"
        head -5 "$OUTPUT_FILE" | column -t -s ','
    else
        print_error "Export failed - output file not created"
        exit 1
    fi
}

# Main execution function
main() {
    print_status "Starting AWS Load Balancer export process..."
    print_status "Target Region: $REGION"
    print_status "Timestamp: $(date)"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWS account ID
    get_account_id
    
    # Create output filename with account ID
    create_output_filename
    
    # Create CSV file with header
    create_csv_header
    
    # Export different types of load balancers
    export_alb_nlb
    export_classic_lb
    
    # Display summary
    display_summary
    
    print_status "Script execution completed at $(date)"
}

# Script usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION    Set AWS region (default: ap-southeast-2)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_DEFAULT_REGION    Override default region"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use default region (ap-southeast-2)"
    echo "  $0 -r us-east-1       # Use specific region"
    echo "  AWS_DEFAULT_REGION=eu-west-1 $0  # Use environment variable"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
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