#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\18.Bash_Script_AWS_Subnet_Association\export_subnet_associations.sh

# Script: export_subnet_associations.sh
# Description: Exports AWS subnet association information to a CSV file

# Set AWS default region
AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION=$AWS_REGION

# Output CSV file
OUTPUT_FILE="subnet_associations.csv"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS credentials not configured or insufficient permissions"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

# Function to escape CSV fields
escape_csv() {
    local field="$1"
    # If field contains comma, quote it
    if [[ $field == *,* ]]; then
        echo "\"$field\""
    else
        echo "$field"
    fi
}

echo "Starting subnet association export for region $AWS_REGION..."

# Create CSV header
echo "SubnetID,IPv4 CIDR,IPv6 CIDR,Route Table ID,Route Table Name" > $OUTPUT_FILE

# Get all subnets
echo "Retrieving subnets..."
subnets=$(aws ec2 describe-subnets --query "Subnets[*].SubnetId" --output text)

if [ -z "$subnets" ]; then
    echo "No subnets found in region $AWS_REGION"
    exit 0
fi

# Process each subnet
for subnet_id in $subnets; do
    echo "Processing subnet: $subnet_id"
    
    # Get subnet IPv4 and IPv6 CIDR
    ipv4_cidr=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0].CidrBlock' --output text)
    
    # IPv6 is trickier since it may not exist
    ipv6_cidr=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' --output text 2>/dev/null)
    if [ "$ipv6_cidr" == "None" ] || [ -z "$ipv6_cidr" ]; then
        ipv6_cidr="N/A"
    fi
    
    # Get route table associated with the subnet
    route_table_id=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$subnet_id" --query 'RouteTables[0].RouteTableId' --output text)
    
    # If no direct association found, get the main route table
    if [ "$route_table_id" == "None" ] || [ -z "$route_table_id" ]; then
        route_table_id=$(aws ec2 describe-route-tables --filters "Name=association.main,Values=true" --query 'RouteTables[0].RouteTableId' --output text)
        route_table_name="Main Route Table (implicit)"
    else
        # Try to get route table name from tags
        route_table_name=$(aws ec2 describe-route-tables --route-table-ids $route_table_id --query 'RouteTables[0].Tags[?Key==`Name`].Value' --output text)
        
        # If no name tag found
        if [ "$route_table_name" == "None" ] || [ -z "$route_table_name" ]; then
            route_table_name="Unnamed"
        fi
    fi
    
    # Escape fields
    subnet_id_esc=$(escape_csv "$subnet_id")
    ipv4_cidr_esc=$(escape_csv "$ipv4_cidr")
    ipv6_cidr_esc=$(escape_csv "$ipv6_cidr")
    route_table_id_esc=$(escape_csv "$route_table_id")
    route_table_name_esc=$(escape_csv "$route_table_name")
    
    # Write to CSV
    echo "$subnet_id_esc,$ipv4_cidr_esc,$ipv6_cidr_esc,$route_table_id_esc,$route_table_name_esc" >> $OUTPUT_FILE
done

echo "Subnet association information has been exported to $OUTPUT_FILE"
echo "Process completed successfully!"