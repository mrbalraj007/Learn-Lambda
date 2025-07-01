#!/bin/bash

# Script to get RDS instance details and export to CSV
# Default region is ap-southeast-2
REGION=${1:-ap-southeast-2}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Failed to retrieve AWS account ID. Check your AWS credentials and permissions."
    exit 1
fi

# Generate filename with timestamp and account ID
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="rds_inventory_${ACCOUNT_ID}_${TIMESTAMP}.csv"

echo "Gathering RDS inventory from region: $REGION for account: $ACCOUNT_ID"

# Create header for CSV file
echo "DB_Identifier,Status,Role,Engine,Region,AvailabilityZone,InstanceClass,VPC,MultiAZ,SubnetGroupName,SubnetGroupDescription,SubnetIDs,Tags" > $FILENAME

# Get RDS instance details using AWS CLI
aws rds describe-db-instances --region $REGION --output json > /tmp/rds_instances.json

if [ $? -ne 0 ]; then
    echo "Failed to retrieve RDS instances. Check your AWS credentials and permissions."
    exit 1
fi

# Process each instance and write to CSV
jq -r '.DBInstances[] | 
  # First, get all the base information we already had
  {
    id: .DBInstanceIdentifier,
    status: .DBInstanceStatus,
    role: (if .ReadReplicaSourceDBInstanceIdentifier then "Replica" else "Primary" end),
    engine: .Engine,
    region: "'$REGION'",
    az: .AvailabilityZone,
    instanceClass: .DBInstanceClass,
    vpc: .DBSubnetGroup.VpcId,
    multiAZ: .MultiAZ,
    # Now add the new subnet group information
    subnetGroupName: .DBSubnetGroup.DBSubnetGroupName,
    subnetGroupDesc: (.DBSubnetGroup.DBSubnetGroupDescription // ""),
    subnetIds: (.DBSubnetGroup.Subnets | map(.SubnetIdentifier) | join(";")),
    # Get the ARN for retrieving tags
    arn: .DBInstanceArn
  }' /tmp/rds_instances.json > /tmp/rds_base_info.json

# For each instance, get the tags and append them to our base information
cat /tmp/rds_base_info.json | jq -r '.arn' | while read -r arn; do
  if [ -n "$arn" ]; then
    # Get tags for this instance
    aws rds list-tags-for-resource --resource-name "$arn" --region $REGION > /tmp/rds_tags.json
    
    # Extract instance details from our base info
    instance_details=$(cat /tmp/rds_base_info.json | jq -r --arg arn "$arn" 'select(.arn == $arn)')
    
    # Format tags as key1=value1;key2=value2
    tags=$(jq -r '.TagList | map(.Key + "=" + .Value) | join(";")' /tmp/rds_tags.json)
    
    # Combine all information and output as CSV
    echo "$instance_details" | jq -r --arg tags "$tags" '[.id, .status, .role, .engine, .region, .az, .instanceClass, .vpc, .multiAZ, .subnetGroupName, .subnetGroupDesc, .subnetIds, $tags] | @csv' >> $FILENAME
  fi
done

# Clean up temporary files
rm /tmp/rds_instances.json /tmp/rds_base_info.json /tmp/rds_tags.json 2>/dev/null

echo "RDS inventory successfully exported to $FILENAME"
echo "CSV contains the following fields: DB Identifier, Status, Role, Engine, Region, AZ, Instance Class, VPC, Multi-AZ, Subnet Group Name, Subnet Group Description, Subnet IDs, Tags"
