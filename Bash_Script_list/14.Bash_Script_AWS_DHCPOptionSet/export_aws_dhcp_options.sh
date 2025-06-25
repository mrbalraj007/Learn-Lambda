#!/bin/bash

# Script: export_aws_dhcp_options.sh
# Description: Exports AWS DHCP Options Sets information to a CSV file
# Default region: us-east-1

# Set AWS region
AWS_REGION="ap-southeast-2"

# Get current timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Output CSV file
OUTPUT_FILE="aws_dhcp_options_sets_$TIMESTAMP.csv"

# Function to check AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed or not in PATH."
        echo "Please install the AWS CLI and try again."
        exit 1
    fi
}

# Function to check jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed or not in PATH."
        echo "Please install jq and try again."
        exit 1
    fi
}

# Check prerequisites
check_aws_cli
check_jq

# Print start message
echo "Starting AWS DHCP Options Sets export - $(date)"
echo "Using AWS region: $AWS_REGION"

# CSV header
echo "DHCP_Options_Set_ID,Domain_Name,Domain_Name_Servers,NTP_Servers,NetBIOS_Name_Servers,NetBIOS_Node_Type" > "$OUTPUT_FILE"

# Get all DHCP Options Sets
echo "Retrieving DHCP Options Sets..."
dhcp_ids=$(aws ec2 describe-dhcp-options --region "$AWS_REGION" --query 'DhcpOptions[].DhcpOptionsId' --output text)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve DHCP Options Sets from AWS."
    echo "Please check your AWS credentials and permissions."
    exit 1
fi

if [ -z "$dhcp_ids" ]; then
    echo "No DHCP Options Sets found in region $AWS_REGION."
    echo "Empty CSV file created: $OUTPUT_FILE"
    exit 0
fi

# Count the number of DHCP Options Sets
dhcp_count=$(echo "$dhcp_ids" | wc -w)
echo "Found $dhcp_count DHCP Options Sets to process."

# Process each DHCP Options Set
counter=0
for id in $dhcp_ids; do
    counter=$((counter+1))
    echo "Processing DHCP Options Set $counter of $dhcp_count: $id"
    
    # Get the specific DHCP Options Set details
    dhcp_details=$(aws ec2 describe-dhcp-options --region "$AWS_REGION" --dhcp-options-ids "$id" --output json)
    
    if [ $? -ne 0 ]; then
        echo "Error retrieving details for DHCP Options Set $id. Skipping."
        continue
    fi
    
    # Initialize variables
    domain_name=""
    domain_name_servers=""
    ntp_servers=""
    netbios_name_servers=""
    netbios_node_type=""
    
    # Extract domain name
    domain_name=$(echo "$dhcp_details" | jq -r '.DhcpOptions[].DhcpConfigurations[] | select(.Key=="domain-name") | .Values[].Value' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Extract domain name servers
    domain_name_servers=$(echo "$dhcp_details" | jq -r '.DhcpOptions[].DhcpConfigurations[] | select(.Key=="domain-name-servers") | .Values[].Value' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Extract NTP servers
    ntp_servers=$(echo "$dhcp_details" | jq -r '.DhcpOptions[].DhcpConfigurations[] | select(.Key=="ntp-servers") | .Values[].Value' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Extract NetBIOS name servers
    netbios_name_servers=$(echo "$dhcp_details" | jq -r '.DhcpOptions[].DhcpConfigurations[] | select(.Key=="netbios-name-servers") | .Values[].Value' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Extract NetBIOS node type
    netbios_node_type=$(echo "$dhcp_details" | jq -r '.DhcpOptions[].DhcpConfigurations[] | select(.Key=="netbios-node-type") | .Values[].Value' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    # Escape any commas in the values for CSV format
    domain_name=$(echo "$domain_name" | sed 's/,/;/g')
    domain_name_servers=$(echo "$domain_name_servers" | sed 's/,/;/g')
    ntp_servers=$(echo "$ntp_servers" | sed 's/,/;/g')
    netbios_name_servers=$(echo "$netbios_name_servers" | sed 's/,/;/g')
    
    # Write to CSV
    echo "$id,$domain_name,$domain_name_servers,$ntp_servers,$netbios_name_servers,$netbios_node_type" >> "$OUTPUT_FILE"
done

echo "Export completed successfully!"
echo "Results saved to: $OUTPUT_FILE"
echo "Finished at: $(date)"
