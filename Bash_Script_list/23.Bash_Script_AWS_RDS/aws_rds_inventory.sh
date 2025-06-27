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

# Generate filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="rds_inventory_${TIMESTAMP}.csv"

echo "Gathering RDS inventory from region: $REGION"

# Create header for CSV file
echo "DB_Identifier,Status,Role,Engine,Region,AvailabilityZone,InstanceClass,VPC,MultiAZ" > $FILENAME

# Get RDS instance details using AWS CLI
aws rds describe-db-instances --region $REGION --output json > /tmp/rds_instances.json

if [ $? -ne 0 ]; then
    echo "Failed to retrieve RDS instances. Check your AWS credentials and permissions."
    exit 1
fi

# Process each instance and write to CSV
jq -r '.DBInstances[] | 
  [
    .DBInstanceIdentifier,
    .DBInstanceStatus,
    if .ReadReplicaSourceDBInstanceIdentifier then "Replica" else "Primary" end,
    .Engine,
    "'$REGION'",
    .AvailabilityZone,
    .DBInstanceClass,
    .DBSubnetGroup.VpcId,
    .MultiAZ
  ] | @csv' /tmp/rds_instances.json >> $FILENAME

# Clean up temporary file
rm /tmp/rds_instances.json

echo "RDS inventory successfully exported to $FILENAME"
echo "CSV contains the following fields: DB Identifier, Status, Role, Engine, Region, AZ, Instance Class, VPC, Multi-AZ"
