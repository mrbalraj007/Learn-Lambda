#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\29.Bash_Script_AWS_NATGateway\export_nat_gateway_info.sh

# Set variables
AWS_REGION="us-east-1"
OUTPUT_FILE="nat_gateway_details.csv"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
FINAL_OUTPUT="${OUTPUT_FILE%.csv}_${DATE}.csv"

echo "Exporting NAT Gateway details from AWS region: $AWS_REGION"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Create CSV header
echo "NAT_Gateway_ID,Connectivity_Type,State,Elastic_IP,Private_IP,Network_Interface_ID,VPC_ID,Subnet_ID" > "$FINAL_OUTPUT"

# Fetch NAT Gateway information
echo "Fetching NAT Gateway information..."
nat_gateways=$(aws ec2 describe-nat-gateways --region $AWS_REGION)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve NAT Gateway information. Check your AWS credentials and permissions."
    exit 1
fi

# Process each NAT Gateway
echo "$nat_gateways" | jq -r '.NatGateways[] | 
    .NatGatewayId as $natId | 
    .ConnectivityType as $connType | 
    .State as $state | 
    .VpcId as $vpc | 
    .SubnetId as $subnet | 
    .NatGatewayAddresses[] | 
    [
        $natId,
        $connType,
        $state,
        (.PublicIp // "N/A"),
        (.PrivateIp // "N/A"),
        (.NetworkInterfaceId // "N/A"),
        $vpc,
        $subnet
    ] | @csv' >> "$FINAL_OUTPUT"

# Check if we got any data (excluding header)
if [ $(wc -l < "$FINAL_OUTPUT") -le 1 ]; then
    echo "No NAT Gateways found in region $AWS_REGION."
    rm "$FINAL_OUTPUT"  # Remove empty file
    exit 0
fi

echo "Export completed successfully. Results saved to: $FINAL_OUTPUT"
echo "Total NAT Gateways found: $(($(wc -l < "$FINAL_OUTPUT") - 1))"