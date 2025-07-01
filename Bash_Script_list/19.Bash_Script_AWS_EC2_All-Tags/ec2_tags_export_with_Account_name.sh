#!/bin/bash

# Script: ec2_tags_export.sh
# Description: Auto-discover and extract all EC2 instance details and tags and export to CSV
# Usage: ./ec2_tags_export.sh [--region REGION]

# Default settings
REGION="ap-southeast-2"  # Default AWS region

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Auto-discovers and extracts all instance details and tags from EC2 instances and exports to CSV."
    echo ""
    echo "Options:"
    echo "  --region REGION     AWS region (default: ap-southeast-2)"
    echo "  --help              Show this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --region eu-west-1"
    exit 0
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --*)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Create timestamp for file naming
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="ec2_details_tags_${TIMESTAMP}.csv"

# Get AWS account information
echo "Fetching AWS account information..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "N/A")
ACCOUNT_NAME=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || echo "N/A")

if [ "$ACCOUNT_NAME" = "None" ] || [ -z "$ACCOUNT_NAME" ]; then
    ACCOUNT_NAME="N/A"
fi

echo "Account ID: $ACCOUNT_ID"
echo "Account Name: $ACCOUNT_NAME"

echo "Fetching EC2 instances in region ${REGION}..."
INSTANCES_JSON=$(aws ec2 describe-instances --region "$REGION" --output json)

# Get alarm status for each instance
echo "Fetching CloudWatch alarms for EC2 instances..."
ALARMS_JSON=$(aws cloudwatch describe-alarms --region "$REGION" --output json)

# Get elastic IPs data
echo "Fetching Elastic IPs..."
EIP_JSON=$(aws ec2 describe-addresses --region "$REGION" --output json)

# Extract all unique tag keys across all instances
echo "Discovering all unique tags across instances..."
ALL_TAGS=$(echo "$INSTANCES_JSON" | jq -r '.Reservations[].Instances[].Tags[]?.Key' | sort -u)

# Create header row for CSV with instance details and tags
HEADER="AccountID,AccountName,InstanceId,InstanceName,PublicIP,PrivateIP,InstanceType,AvailabilityZone,AlarmStatus,ElasticIP,SecurityGroupName,KeyName,LaunchTime,PlatformDetails"

# Add all tag keys to header
for tag in $ALL_TAGS; do
    # Skip Name tag as we already include it as InstanceName
    if [ "$tag" != "Name" ]; then
        HEADER="${HEADER},${tag}"
    fi
done

echo "$HEADER" > "$OUTPUT_FILE"

# Process each instance
echo "Exporting instance details and tags for all instances..."
echo "$INSTANCES_JSON" | jq -c '.Reservations[].Instances[]' | while read -r instance; do
    instance_id=$(echo "$instance" | jq -r '.InstanceId')
    
    # Get instance details
    public_ip=$(echo "$instance" | jq -r '.PublicIpAddress // "N/A"')
    private_ip=$(echo "$instance" | jq -r '.PrivateIpAddress // "N/A"')
    instance_type=$(echo "$instance" | jq -r '.InstanceType // "N/A"')
    availability_zone=$(echo "$instance" | jq -r '.Placement.AvailabilityZone // "N/A"')
    security_group_names=$(echo "$instance" | jq -r '.SecurityGroups[].GroupName // "N/A"' | paste -sd ";" -)
    key_name=$(echo "$instance" | jq -r '.KeyName // "N/A"')
    launch_time=$(echo "$instance" | jq -r '.LaunchTime // "N/A"')
    platform_details=$(echo "$instance" | jq -r '.PlatformDetails // "N/A"')
    
    # Get all tags as a JSON object for easier lookup
    tags_json=$(echo "$instance" | jq -c '.Tags // []')
    
    # Try to get Name tag
    instance_name=$(echo "$tags_json" | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "N/A")
    
    # Check for Elastic IP associated with this instance
    elastic_ip=$(echo "$EIP_JSON" | jq -r --arg instance_id "$instance_id" '.Addresses[] | select(.InstanceId==$instance_id) | .PublicIp' 2>/dev/null || echo "N/A")
    
    # Check for alarms related to this instance
    alarm_status="N/A"
    alarm_names=$(echo "$ALARMS_JSON" | jq -r --arg instance_id "$instance_id" '.MetricAlarms[] | select(.Dimensions[] | .Name=="InstanceId" and .Value==$instance_id) | .StateValue' 2>/dev/null)
    if [ ! -z "$alarm_names" ]; then
        # If there are alarms in ALARM state, mark as "ALARM", otherwise "OK"
        if echo "$alarm_names" | grep -q "ALARM"; then
            alarm_status="ALARM"
        else
            alarm_status="OK"
        fi
    fi
    
    # Start building the CSV line with instance details
    LINE="\"${ACCOUNT_ID}\",\"${ACCOUNT_NAME//\"/\"\"}\",${instance_id},\"${instance_name//\"/\"\"}\",\"${public_ip}\",\"${private_ip}\",\"${instance_type}\",\"${availability_zone}\",\"${alarm_status}\",\"${elastic_ip}\",\"${security_group_names//\"/\"\"}\",\"${key_name//\"/\"\"}\",\"${launch_time}\",\"${platform_details//\"/\"\"}\""
    
    # Process each discovered tag (except Name which we already handled)
    for tag in $ALL_TAGS; do
        if [ "$tag" != "Name" ]; then
            # Find the tag value
            tag_value=$(echo "$tags_json" | jq -r ".[] | select(.Key==\"$tag\") | .Value" 2>/dev/null || echo "N/A")
            
            # Quote and escape the value for CSV
            LINE="${LINE},\"${tag_value//\"/\"\"}\""
        fi
    done
    
    echo "$LINE" >> "$OUTPUT_FILE"
done

echo "Export completed. Found $(echo "$ALL_TAGS" | wc -w) unique tags across all instances."
echo "Results saved to $OUTPUT_FILE"
