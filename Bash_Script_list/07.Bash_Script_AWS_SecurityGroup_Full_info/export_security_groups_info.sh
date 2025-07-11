#!/bin/bash

# Script to export AWS Security Group information to CSV
# Default region: us-east-1

# Set the AWS region
AWS_REGION="ap-southeast-2"

# Create a timestamp for the filename
DATETIME=$(date +"%Y-%m-%d_%H%M%S")

# Create CSV file with header and timestamp in filename
OUTPUT_FILE="security_groups_info_${DATETIME}.csv"
echo "SecurityGroupName,SecurityGroupID,SecurityGroupRuleID,IPVersion,Type,Protocol,PortRange,Destination,Description" > $OUTPUT_FILE

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to run this script."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install AWS CLI to run this script."
    exit 1
fi

# Check AWS CLI configuration
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not properly configured. Please run 'aws configure' to set up your credentials."
    exit 1
fi

echo "Starting export of AWS Security Group information..."
echo "Region: $AWS_REGION"
echo "Output file: $OUTPUT_FILE"

# Get all security groups
echo "Retrieving security groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $AWS_REGION --output json)

if [ -z "$SECURITY_GROUPS" ]; then
    echo "No security groups found in region $AWS_REGION"
    exit 0
fi

# Process each security group
echo "$SECURITY_GROUPS" | jq -c '.SecurityGroups[]' | while read -r sg; do
    SG_ID=$(echo "$sg" | jq -r '.GroupId')
    SG_NAME=$(echo "$sg" | jq -r '.GroupName')
    
    echo "Processing Security Group: $SG_NAME ($SG_ID)"
    
    # Get security group rules and sort them (ingress first, then egress)
    RULES=$(aws ec2 describe-security-group-rules --region $AWS_REGION --filters Name=group-id,Values=$SG_ID --output json)
    
    # Process ingress rules first
    echo "$RULES" | jq -r --arg SG_NAME "$SG_NAME" --arg SG_ID "$SG_ID" '.SecurityGroupRules[] | select(.IsEgress==false) | [
        $SG_NAME,
        $SG_ID,
        .SecurityGroupRuleId,
        if .IpProtocol == "-1" then "All" else 
            if has("CidrIpv4") then "IPv4" 
            elif has("CidrIpv6") then "IPv6" 
            else "N/A" 
            end 
        end,
        "Ingress",
        if .IpProtocol == "-1" then "All" else .IpProtocol end,
        if ((.FromPort | tostring) == "null" or (.ToPort | tostring) == "null") then "All" 
        elif .FromPort == .ToPort then (.FromPort | tostring)
        else (.FromPort | tostring) + "-" + (.ToPort | tostring) 
        end,
        if has("CidrIpv4") then .CidrIpv4 
        elif has("CidrIpv6") then .CidrIpv6 
        elif has("ReferencedGroupId") then .ReferencedGroupId 
        else "N/A" 
        end,
        if has("Description") and .Description != null then .Description else "N/A" end
    ] | @csv' >> $OUTPUT_FILE
    
    # Then process egress rules
    echo "$RULES" | jq -r --arg SG_NAME "$SG_NAME" --arg SG_ID "$SG_ID" '.SecurityGroupRules[] | select(.IsEgress==true) | [
        $SG_NAME,
        $SG_ID,
        .SecurityGroupRuleId,
        if .IpProtocol == "-1" then "All" else 
            if has("CidrIpv4") then "IPv4" 
            elif has("CidrIpv6") then "IPv6" 
            else "N/A" 
            end 
        end,
        "Egress",
        if .IpProtocol == "-1" then "All" else .IpProtocol end,
        if ((.FromPort | tostring) == "null" or (.ToPort | tostring) == "null") then "All" 
        elif .FromPort == .ToPort then (.FromPort | tostring)
        else (.FromPort | tostring) + "-" + (.ToPort | tostring) 
        end,
        if has("CidrIpv4") then .CidrIpv4 
        elif has("CidrIpv6") then .CidrIpv6 
        elif has("ReferencedGroupId") then .ReferencedGroupId 
        else "N/A" 
        end,
        if has("Description") and .Description != null then .Description else "N/A" end
    ] | @csv' >> $OUTPUT_FILE
    
    if [ $? -ne 0 ]; then
        echo "Warning: Error processing security group $SG_ID"
    else
        echo "Completed processing for Security Group: $SG_NAME ($SG_ID)"
    fi
done

echo "Security group information has been exported to $OUTPUT_FILE"
echo "CSV columns: SecurityGroupName, SecurityGroupID, SecurityGroupRuleID, IPVersion, Type, Protocol, PortRange, Destination, Description"
