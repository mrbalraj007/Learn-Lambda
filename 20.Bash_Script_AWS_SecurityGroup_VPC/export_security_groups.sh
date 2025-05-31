#!/bin/bash

# Script to export AWS Security Group information to a CSV file
# Author: GitHub Copilot
# Description: Exports SecurityGroup information including GroupID, GroupName, VPC ID, Description, and Owner

# Set default region
REGION="us-east-1"
OUTPUT_FILE="security_groups_$(date +%Y%m%d_%H%M%S).csv"

# Check dependencies
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
if ! aws sts get-caller-identity --region $REGION &> /dev/null; then
    echo "Error: Unable to validate AWS credentials. Please run 'aws configure'."
    exit 1
fi

echo "Fetching security group information from AWS region $REGION..."

# Create CSV header
echo "SecurityGroupID,GroupName,VPCID,Description,Owner" > "$OUTPUT_FILE"

# Get security group data
SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $REGION)

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve security groups."
    exit 1
fi

# Process each security group and append to CSV
echo "$SECURITY_GROUPS" | jq -r '.SecurityGroups[] | [.GroupId, .GroupName, .VpcId // "N/A", .Description // "N/A", .OwnerId] | @csv' >> "$OUTPUT_FILE"

TOTAL_GROUPS=$(echo "$SECURITY_GROUPS" | jq '.SecurityGroups | length')
echo "Successfully exported information for $TOTAL_GROUPS security groups to $OUTPUT_FILE"
echo "CSV file contains: SecurityGroupID, GroupName, VPCID, Description, Owner"
