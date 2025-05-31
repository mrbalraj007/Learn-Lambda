#!/bin/bash

# Script to export AWS Network ACL information to a CSV file
# Default region: us-east-1

# Set AWS region
export AWS_DEFAULT_REGION="us-east-1"

# Define output CSV file
output_file="network_acl_info.csv"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq and try again."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed. Please install AWS CLI and try again."
    exit 1
fi

# Write CSV header
echo "NetworkACL_ID,Associated_With,Default,VPC_ID,Inbound_Rules_Count,Outbound_Rules_Count,Owner" > "$output_file"

echo "Fetching Network ACL information from region us-east-1..."

# Get all Network ACLs
network_acls=$(aws ec2 describe-network-acls --output json)

# Process each Network ACL
echo "$network_acls" | jq -c '.NetworkAcls[]' | while read -r acl; do
    # Extract basic info
    network_acl_id=$(echo "$acl" | jq -r '.NetworkAclId')
    is_default=$(echo "$acl" | jq -r '.IsDefault')
    vpc_id=$(echo "$acl" | jq -r '.VpcId')
    owner_id=$(echo "$acl" | jq -r '.OwnerId')
    
    # Count inbound and outbound rules
    inbound_count=$(echo "$acl" | jq '[.Entries[] | select(.Egress == false)] | length')
    outbound_count=$(echo "$acl" | jq '[.Entries[] | select(.Egress == true)] | length')
    
    # Get subnet associations with names
    subnet_associations=""
    subnet_ids=$(echo "$acl" | jq -r '.Associations[].SubnetId')
    
    if [ -n "$subnet_ids" ]; then
        for subnet_id in $subnet_ids; do
            # Get subnet name from tags
            subnet_info=$(aws ec2 describe-subnets --subnet-ids "$subnet_id" --output json)
            subnet_name=$(echo "$subnet_info" | jq -r '.Subnets[0].Tags[] | select(.Key=="Name") | .Value' 2>/dev/null)
            
            # If no name tag, use "Unnamed"
            if [ -z "$subnet_name" ] || [ "$subnet_name" == "null" ]; then
                subnet_name="Unnamed"
            fi
            
            # Append to the list
            if [ -n "$subnet_associations" ]; then
                subnet_associations="$subnet_associations;$subnet_id ($subnet_name)"
            else
                subnet_associations="$subnet_id ($subnet_name)"
            fi
        done
    else
        subnet_associations="None"
    fi
    
    # Write to CSV
    echo "$network_acl_id,$subnet_associations,$is_default,$vpc_id,$inbound_count,$outbound_count,$owner_id" >> "$output_file"
    
    echo "Processed Network ACL: $network_acl_id"
done

# Check if export was successful
if [ $? -eq 0 ]; then
    echo "Network ACL information successfully exported to $output_file"
else
    echo "Error occurred while exporting Network ACL information"
    exit 1
fi
