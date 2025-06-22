#!/bin/bash

# Script: ec2_tags_export.sh
# Description: Auto-discover and extract all EC2 instance tags and export to CSV
# Usage: ./ec2_tags_export.sh [--region REGION]

# Default settings
REGION="us-east-1"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Auto-discovers and extracts all tags from EC2 instances and exports to CSV."
    echo ""
    echo "Options:"
    echo "  --region REGION     AWS region (default: us-east-1)"
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
OUTPUT_FILE="ec2_tags_${TIMESTAMP}.csv"

echo "Fetching EC2 instances in region ${REGION}..."
INSTANCES_JSON=$(aws ec2 describe-instances --region "$REGION" --output json)

# Extract all unique tag keys across all instances
echo "Discovering all unique tags across instances..."
ALL_TAGS=$(echo "$INSTANCES_JSON" | jq -r '.Reservations[].Instances[].Tags[]?.Key' | sort -u)

# Check if we found any tags
if [ -z "$ALL_TAGS" ]; then
    echo "No tags found on any instances in region ${REGION}."
    exit 0
fi

# Create header row for CSV
HEADER="InstanceId,InstanceName"

# Add all tag keys to header
for tag in $ALL_TAGS; do
    # Skip Name tag as we already include it as InstanceName
    if [ "$tag" != "Name" ]; then
        HEADER="${HEADER},${tag}"
    fi
done

echo "$HEADER" > "$OUTPUT_FILE"

# Process each instance
echo "Exporting tags for all instances..."
echo "$INSTANCES_JSON" | jq -c '.Reservations[].Instances[]' | while read -r instance; do
    instance_id=$(echo "$instance" | jq -r '.InstanceId')
    
    # Get all tags as a JSON object for easier lookup
    tags_json=$(echo "$instance" | jq -c '.Tags // []')
    
    # Try to get Name tag
    instance_name=$(echo "$tags_json" | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "N/A")
    
    # Start building the CSV line
    LINE="${instance_id},\"${instance_name//\"/\"\"}\""
    
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
