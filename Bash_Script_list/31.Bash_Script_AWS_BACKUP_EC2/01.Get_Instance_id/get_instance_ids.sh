#!/bin/bash

# Script to retrieve EC2 instance IDs based on instance names from a CSV file

# CSV file path
CSV_FILE="instance_names.csv"

# Set to false to enable SSL verification (default is to disable it due to corporate environments)
DISABLE_SSL_VERIFY=true

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if the CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file $CSV_FILE not found."
    exit 1
fi

# Set AWS CLI SSL verification option
AWS_SSL_OPTION=""
if [ "$DISABLE_SSL_VERIFY" = true ]; then
    AWS_SSL_OPTION="--no-verify-ssl"
    echo "SSL verification disabled for AWS CLI commands"
fi

# Get AWS account ID
ACCOUNT_ID=$(aws $AWS_SSL_OPTION sts get-caller-identity --query "Account" --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo "Warning: Could not retrieve AWS account ID. Using 'unknown' as account ID."
    ACCOUNT_ID="unknown"
fi

# Get current date and time for the filename
DATETIME=$(date +"%Y%m%d_%H%M%S")

# Create the output filename
OUTPUT_FILE="${ACCOUNT_ID}_instance_ids_output_${DATETIME}.csv"
echo "Output will be saved to: $OUTPUT_FILE"

# Initialize output file
echo "INSTANCE_NAME,INSTANCE_ID" > $OUTPUT_FILE

# Read the CSV file (skip header)
tail -n +2 $CSV_FILE | while IFS=, read -r instance_name; do
    # Remove any carriage returns or extra spaces
    instance_name=$(echo "$instance_name" | tr -d '\r' | xargs)
    
    echo "Looking up instance ID for $instance_name..."
    
    # Get the instance ID using AWS CLI with SSL verification disabled
    instance_id=$(aws ec2 describe-instances \
        $AWS_SSL_OPTION \
        --filters "Name=tag:Name,Values=$instance_name" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text 2>/dev/null)
    
    if [ -z "$instance_id" ]; then
        echo "Warning: No instance ID found for $instance_name"
        echo "$instance_name,NOT_FOUND" >> $OUTPUT_FILE
    else
        echo "Found instance ID: $instance_id for $instance_name"
        echo "$instance_name,$instance_id" >> $OUTPUT_FILE
    fi
done

echo "Completed! Instance IDs have been saved to $OUTPUT_FILE"
echo "The following instances were processed:"
cat $OUTPUT_FILE
