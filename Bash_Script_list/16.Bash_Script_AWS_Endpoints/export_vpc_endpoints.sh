#!/bin/bash
#
# Script to export AWS VPC Endpoint information to a CSV file
# Exports: Name, VPC Endpoint ID, VPC ID, VPC Name, Service Name, Endpoint Type

# Set the AWS region
AWS_REGION="ap-southeast-2"
export AWS_DEFAULT_REGION=$AWS_REGION

# CSV file to store the output
OUTPUT_FILE="vpc_endpoints_info.csv"

# Function to properly format CSV fields
format_csv_field() {
    local field="$1"
    # Replace any double quotes with two double quotes and wrap in quotes
    echo "\"${field//\"/\"\"}\""
}

# Create CSV header
echo "Name,VPC Endpoint ID,VPC ID,VPC Name,Service Name,Endpoint Type" > $OUTPUT_FILE

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Check if aws CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed. Please install AWS CLI first."
    exit 1
fi

echo "Fetching VPC endpoints from region $AWS_REGION..."

# Get all VPC endpoints
vpc_endpoints=$(aws ec2 describe-vpc-endpoints 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch VPC endpoints. Please check your AWS credentials and permissions."
    exit 1
fi

# Get count of endpoints
endpoint_count=$(echo $vpc_endpoints | jq '.VpcEndpoints | length')

if [ "$endpoint_count" -eq 0 ]; then
    echo "No VPC Endpoints found in region $AWS_REGION"
    exit 0
fi

echo "Found $endpoint_count VPC endpoints. Processing..."

# Process each endpoint
for ((i=0; i<endpoint_count; i++)); do
    # Extract endpoint data
    endpoint=$(echo $vpc_endpoints | jq ".VpcEndpoints[$i]")
    
    vpc_endpoint_id=$(echo $endpoint | jq -r '.VpcEndpointId')
    vpc_id=$(echo $endpoint | jq -r '.VpcId')
    service_name=$(echo $endpoint | jq -r '.ServiceName')
    endpoint_type=$(echo $endpoint | jq -r '.VpcEndpointType')
    
    echo "Processing endpoint: $vpc_endpoint_id ($((i+1))/$endpoint_count)"
    
    # Extract Name tag if it exists
    name=$(echo $endpoint | jq -r '.Tags[] | select(.Key=="Name") | .Value' 2>/dev/null)
    if [ -z "$name" ] || [ "$name" == "null" ]; then
        name="N/A"
    fi
    
    # Get VPC details to find its name
    vpc_details=$(aws ec2 describe-vpcs --vpc-ids "$vpc_id" --output json 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Warning: Could not fetch details for VPC $vpc_id"
        vpc_name="N/A"
    else
        vpc_name=$(echo $vpc_details | jq -r '.Vpcs[0].Tags[] | select(.Key=="Name") | .Value' 2>/dev/null)
        if [ -z "$vpc_name" ] || [ "$vpc_name" == "null" ]; then
            vpc_name="N/A"
        fi
    fi
    
    # Format fields for CSV
    name_csv=$(format_csv_field "$name")
    vpc_id_csv=$(format_csv_field "$vpc_id")
    vpc_endpoint_id_csv=$(format_csv_field "$vpc_endpoint_id")
    vpc_name_csv=$(format_csv_field "$vpc_name")
    service_name_csv=$(format_csv_field "$service_name")
    endpoint_type_csv=$(format_csv_field "$endpoint_type")
    
    # Write to CSV
    echo "$name_csv,$vpc_endpoint_id_csv,$vpc_id_csv,$vpc_name_csv,$service_name_csv,$endpoint_type_csv" >> $OUTPUT_FILE
done

echo "VPC Endpoints information has been exported to $OUTPUT_FILE"
