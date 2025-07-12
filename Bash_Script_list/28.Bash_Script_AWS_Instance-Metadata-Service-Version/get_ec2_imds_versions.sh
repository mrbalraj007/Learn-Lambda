#!/bin/bash
# filepath: get_ec2_imds_versions.sh

# AWS EC2 Instance Metadata Service Version Checker
# This script retrieves IMDS configuration for all EC2 instances

# Set default region
DEFAULT_REGION="ap-southeast-2"
REGION=${1:-$DEFAULT_REGION}

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# CSV file variables
CSV_FILE=""
ACCOUNT_ID=""

# Function to get account ID and set CSV filename
setup_csv_file() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text --region $REGION 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$ACCOUNT_ID" ]; then
        echo -e "${RED}Error: Unable to retrieve AWS Account ID${NC}"
        exit 1
    fi
    
    # Create CSV filename with account ID, region, and timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    CSV_FILE="ec2_imds_versions_account_${ACCOUNT_ID}_${REGION}_${TIMESTAMP}.csv"
    
    # Create CSV header
    echo "InstanceId,State,Name,IMDSVersion,HttpTokens,HopLimit,Endpoint,InstanceTags,Region,Timestamp" > "$CSV_FILE"
}

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}EC2 Instance Metadata Service Version Checker${NC}"
    echo -e "${BLUE}Region: $REGION${NC}"
    echo -e "${BLUE}Account ID: $ACCOUNT_ID${NC}"
    echo -e "${BLUE}CSV Output: $CSV_FILE${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed or not in PATH${NC}"
        exit 1
    fi
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity --region $REGION &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured or invalid${NC}"
        exit 1
    fi
}

# Function to get EC2 instance details
get_ec2_imds_details() {
    echo -e "${YELLOW}Fetching EC2 instances...${NC}"
    
    # Get all instances with their metadata options
    instances=$(aws ec2 describe-instances \
        --region $REGION \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],MetadataOptions.HttpTokens,MetadataOptions.HttpPutResponseHopLimit,MetadataOptions.HttpEndpoint,MetadataOptions.InstanceMetadataTags]' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to retrieve EC2 instances. Check your permissions.${NC}"
        exit 1
    fi
    
    if [ -z "$instances" ]; then
        echo -e "${YELLOW}No EC2 instances found in region $REGION${NC}"
        # Still create CSV with headers even if no instances
        return
    fi
    
    # Print table header
    printf "%-20s %-15s %-25s %-12s %-10s %-10s %-15s\n" \
        "Instance ID" "State" "Name" "IMDS Tokens" "Hop Limit" "Endpoint" "Instance Tags"
    echo "--------------------------------------------------------------------------------------------------------"
    
    # Process each instance
    while IFS=$'\t' read -r instance_id state name http_tokens hop_limit endpoint instance_tags; do
        # Handle empty name
        if [ "$name" = "None" ] || [ -z "$name" ]; then
            name="<No Name>"
        fi
        
        # Handle empty instance tags
        if [ "$instance_tags" = "None" ] || [ -z "$instance_tags" ]; then
            instance_tags="disabled"
        fi
        
        # Color code based on IMDS version
        if [ "$http_tokens" = "required" ]; then
            token_color="${GREEN}"
            imds_version="IMDSv2"
        elif [ "$http_tokens" = "optional" ]; then
            token_color="${YELLOW}"
            imds_version="IMDSv1/v2"
        else
            token_color="${RED}"
            imds_version="Unknown"
        fi
        
        # Color code based on instance state
        if [ "$state" = "running" ]; then
            state_color="${GREEN}"
        elif [ "$state" = "stopped" ]; then
            state_color="${YELLOW}"
        else
            state_color="${RED}"
        fi
        
        printf "%-20s ${state_color}%-15s${NC} %-25s ${token_color}%-12s${NC} %-10s %-10s %-15s\n" \
            "$instance_id" "$state" "$name" "$imds_version" "$hop_limit" "$endpoint" "$instance_tags"
        
        # Write to CSV file (escape commas in fields)
        csv_name=$(echo "$name" | sed 's/,/;/g')
        csv_tags=$(echo "$instance_tags" | sed 's/,/;/g')
        current_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        echo "$instance_id,$state,$csv_name,$imds_version,$http_tokens,$hop_limit,$endpoint,$csv_tags,$REGION,$current_timestamp" >> "$CSV_FILE"
    done <<< "$instances"
}

# Function to generate summary
generate_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}IMDS Configuration Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Count instances by IMDS configuration
    total_instances=$(aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[*].InstanceId' --output text | wc -w)
    imdsv2_only=$(aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[?MetadataOptions.HttpTokens==`required`].InstanceId' --output text | wc -w)
    imdsv1_enabled=$(aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[?MetadataOptions.HttpTokens==`optional`].InstanceId' --output text | wc -w)
    
    echo -e "Total Instances: ${BLUE}$total_instances${NC}"
    echo -e "IMDSv2 Only (Secure): ${GREEN}$imdsv2_only${NC}"
    echo -e "IMDSv1 Enabled (Less Secure): ${YELLOW}$imdsv1_enabled${NC}"
    
    if [ $imdsv1_enabled -gt 0 ]; then
        echo -e "\n${YELLOW}⚠️  Warning: $imdsv1_enabled instance(s) have IMDSv1 enabled${NC}"
        echo -e "${YELLOW}   Consider updating to IMDSv2 only for better security${NC}"
    fi
    
    if [ $imdsv2_only -eq $total_instances ] && [ $total_instances -gt 0 ]; then
        echo -e "\n${GREEN}✅ All instances are configured with IMDSv2 only${NC}"
    fi
    
    echo -e "\n${BLUE}CSV file saved: $CSV_FILE${NC}"
}

# Function to show help
show_help() {
    echo "Usage: $0 [region]"
    echo "Examples:"
    echo "  $0                    # Use default region (ap-southeast-2)"
    echo "  $0 us-east-1         # Use specific region"
    echo "  $0 eu-west-1         # Use specific region"
    echo ""
    echo "Output: CSV file will be created with format:"
    echo "  ec2_imds_versions_account_<ACCOUNT_ID>_<REGION>_<TIMESTAMP>.csv"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Validate region if provided
    if [ ! -z "$1" ]; then
        REGION="$1"
    fi
    
    check_aws_cli
    check_aws_credentials
    setup_csv_file
    print_header
    get_ec2_imds_details
    generate_summary
    
    echo -e "\n${GREEN}Script execution completed successfully!${NC}"
    echo -e "${GREEN}CSV report saved to: $CSV_FILE${NC}"
}

# Run main function
main "$@"