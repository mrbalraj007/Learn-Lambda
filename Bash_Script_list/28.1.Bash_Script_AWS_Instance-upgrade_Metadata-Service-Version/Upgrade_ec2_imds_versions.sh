#!/bin/bash
# filepath: Upgrade_ec2_imds_versions.sh

# AWS EC2 Instance Metadata Service Version Checker
# This script retrieves IMDS configuration for all EC2 instances

# Set default region
DEFAULT_REGION="us-east-1" # us-east-1, eu-west-1, ap-southeast-2 etc.
REGION="$DEFAULT_REGION"

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# CSV file variables
CSV_FILE=""
ACCOUNT_ID=""

# New flags for enforcing IMDSv2
ENFORCE_IMDSV2=false
ONLY_IMDSV1=true
CONFIRM_APPLY=false

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
    echo -e "${BLUE}EC2 Instance Metadata Service Version Checker / Enforcer${NC}"
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

# Enforce IMDSv2 (require tokens, enable endpoint, enable metadata tags)
enforce_imdsv2() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Enforcing IMDSv2 (HttpTokens=require)${NC}"
    echo -e "${BLUE}========================================${NC}"

    if [ "$ONLY_IMDSV1" = true ]; then
        filter_query='Reservations[*].Instances[?State.Name!=`terminated` && State.Name!=`shutting-down` && MetadataOptions.HttpTokens==`optional`].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]'
        echo -e "${YELLOW}Target filter: Instances with IMDSv1 enabled (HttpTokens=optional)${NC}"
    else
        filter_query='Reservations[*].Instances[?State.Name!=`terminated` && State.Name!=`shutting-down`].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]'
        echo -e "${YELLOW}Target filter: All instances (excluding terminated/shutting-down)${NC}"
    fi

    instances=$(aws ec2 describe-instances \
        --region "$REGION" \
        --query "$filter_query" \
        --output text 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to retrieve EC2 instances for enforcement. Check permissions.${NC}"
        return 1
    fi

    if [ -z "$instances" ]; then
        echo -e "${GREEN}No instances require changes.${NC}"
        return 0
    fi

    target_count=$(echo "$instances" | awk 'NF' | wc -l)
    echo -e "${BLUE}Instances to update: $target_count${NC}"

    if [ "$CONFIRM_APPLY" = false ]; then
        read -r -p "Proceed to enforce IMDSv2 on $target_count instance(s) in $REGION? (y/N): " ans
        case "$ans" in
            y|Y) ;;
            *) echo -e "${YELLOW}Skipped enforcing IMDSv2.${NC}"; return 0 ;;
        esac
    fi

    success=0
    failed=0
    while IFS=$'\t' read -r instance_id state name; do
        [ -z "$instance_id" ] && continue
        if [ "$name" = "None" ] || [ -z "$name" ]; then
            name="<No Name>"
        fi

        echo -e "Updating $instance_id ($name)..."
        if aws ec2 modify-instance-metadata-options \
            --region "$REGION" \
            --instance-id "$instance_id" \
            --http-tokens required \
            --http-endpoint enabled \
            --instance-metadata-tags enabled >/dev/null 2>&1; then
            echo -e "  ${GREEN}OK${NC}"
            success=$((success+1))
        else
            echo -e "  ${RED}FAILED${NC}"
            failed=$((failed+1))
        fi
    done <<< "$instances"

    echo -e "\n${BLUE}Enforcement result:${NC} ${GREEN}$success success${NC}, ${RED}$failed failed${NC}"
    [ $failed -gt 0 ] && echo -e "${YELLOW}Note: Failures may be due to IAM permissions or service limits.${NC}"
}

# Function to show help
show_help() {
    echo "Usage: $0 [region] [--region <region>] [--enforce-imdsv2|--upgrade] [--only-imdsv1|--all] [-y|--yes]"
    echo "Examples:"
    echo "  $0                            # Scan default region ($DEFAULT_REGION) and auto-upgrade IMDSv1 instances to IMDSv2"
    echo "  $0 us-east-1                  # Scan a specific region and auto-upgrade where required"
    echo "  $0 --enforce-imdsv2 -y        # Force enforcement of IMDSv2 on IMDSv1-enabled instances in $DEFAULT_REGION"
    echo "  $0 eu-west-1 --upgrade --all  # Enforce on all instances in a region (will prompt)"
    echo ""
    echo "Flags:"
    echo "  --enforce-imdsv2 | --upgrade  Require HttpTokens and enable endpoint/tags"
    echo "  --only-imdsv1                 Target only instances with HttpTokens=optional (default)"
    echo "  --all                         Target all instances"
    echo "  --region <region>             Explicitly set the region (alternative to positional)"
    echo "  -y | --yes                    Do not prompt for confirmation"
    echo ""
    echo "Output: CSV file will be created with format:"
    echo "  ec2_imds_versions_account_<ACCOUNT_ID>_<REGION>_<TIMESTAMP>.csv"
}

# Main execution
main() {
    # Parse args: region (positional) + flags
    positional_region=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            --region) shift; positional_region="$1" ;;
            --enforce-imdsv2|--upgrade) ENFORCE_IMDSV2=true ;;
            --only-imdsv1) ONLY_IMDSV1=true ;;
            --all) ONLY_IMDSV1=false ;;
            -y|--yes) CONFIRM_APPLY=true ;;
            *)
                if [[ -z "$positional_region" ]]; then
                    positional_region="$1"
                else
                    echo "Unknown argument: $1"
                    show_help
                    exit 1
                fi
                ;;
        esac
        shift
    done

    if [ -n "$positional_region" ]; then
        REGION="$positional_region"
    fi

    check_aws_cli
    check_aws_credentials
    setup_csv_file
    print_header
    get_ec2_imds_details

    # Auto-upgrade to IMDSv2 if any IMDSv1-enabled instances are found
    if [ "$ENFORCE_IMDSV2" = false ]; then
        imdsv1_to_fix=$(aws ec2 describe-instances \
            --region "$REGION" \
            --query 'Reservations[*].Instances[?State.Name!=`terminated` && State.Name!=`shutting-down` && MetadataOptions.HttpTokens==`optional`].InstanceId' \
            --output text 2>/dev/null | wc -w)
        if [ $? -eq 0 ] && [ "$imdsv1_to_fix" -gt 0 ]; then
            echo -e "\n${YELLOW}Found $imdsv1_to_fix instance(s) with IMDSv1 enabled. Auto-upgrading to IMDSv2...${NC}"
            ENFORCE_IMDSV2=true
            ONLY_IMDSV1=true
            CONFIRM_APPLY=true
        fi
    fi

    if [ "$ENFORCE_IMDSV2" = true ]; then
        enforce_imdsv2
        echo -e "\n${BLUE}Refreshing summary after enforcement...${NC}"
    fi

    generate_summary

    echo -e "\n${GREEN}Script execution completed successfully!${NC}"
    echo -e "${GREEN}CSV report saved to: $CSV_FILE${NC}"
}

# Run main function
main "$@"