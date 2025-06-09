#!/bin/bash

# Set the default region
AWS_REGION="us-east-1"

# Output file
OUTPUT_FILE="aws_nacls_info.csv"

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

# Create/overwrite the CSV file with headers
echo "Network ACL ID,Associated with,Default,VPC ID,Inbound Rules Count,Outbound Rules Count,Owner" > $OUTPUT_FILE

# Get all Network ACLs
echo "Retrieving Network ACL information from AWS region $AWS_REGION..."
nacls=$(aws ec2 describe-network-acls --region $AWS_REGION 2>&1)

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve Network ACL information from AWS."
    echo "AWS CLI output: $nacls"
    exit 1
fi

# Process each Network ACL
network_acl_count=$(echo "$nacls" | jq '.NetworkAcls | length')
echo "Found $network_acl_count Network ACLs."

for ((i=0; i<$network_acl_count; i++)); do
    nacl=$(echo "$nacls" | jq ".NetworkAcls[$i]")
    
    nacl_id=$(echo "$nacl" | jq -r '.NetworkAclId')
    vpc_id=$(echo "$nacl" | jq -r '.VpcId')
    is_default=$(echo "$nacl" | jq -r '.IsDefault')
    owner_id=$(echo "$nacl" | jq -r '.OwnerId')
    
    # Count inbound and outbound rules
    inbound_rules_count=$(echo "$nacl" | jq '[.Entries[] | select(.Egress==false)] | length')
    outbound_rules_count=$(echo "$nacl" | jq '[.Entries[] | select(.Egress==true)] | length')
    
    # Get associations
    association_count=$(echo "$nacl" | jq '.Associations | length')
    
    if [ "$association_count" -eq 0 ]; then
        echo "$nacl_id,None,$is_default,$vpc_id,$inbound_rules_count,$outbound_rules_count,$owner_id" >> $OUTPUT_FILE
    else
        for ((j=0; j<$association_count; j++)); do
            subnet_id=$(echo "$nacl" | jq -r ".Associations[$j].SubnetId")
            echo "$nacl_id,$subnet_id,$is_default,$vpc_id,$inbound_rules_count,$outbound_rules_count,$owner_id" >> $OUTPUT_FILE
        done
    fi
    
    echo "Processed Network ACL: $nacl_id ($((i+1))/$network_acl_count)"
done

echo "Done! Network ACL information exported to $OUTPUT_FILE"
