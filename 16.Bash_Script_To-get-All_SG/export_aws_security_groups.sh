#!/bin/bash

# Script to export AWS Security Groups with their inbound and outbound rules to CSV
# Author: GitHub Copilot

# Set default region
AWS_REGION="us-east-1"

# Check for dependencies
command -v aws >/dev/null 2>&1 || { echo "Error: AWS CLI is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Aborting."; exit 1; }

# Check AWS CLI configuration
aws sts get-caller-identity --region ${AWS_REGION} >/dev/null 2>&1 || { echo "Error: AWS CLI not configured properly. Run 'aws configure' first."; exit 1; }

# Set output filename with timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="aws_security_groups_export_${timestamp}.csv"

echo "Starting AWS Security Group export in region ${AWS_REGION}..."

# Create CSV with headers
echo "SecurityGroupID,SecurityGroupName,VPCID,Description,RuleType,Protocol,PortRange,Source/Destination,RuleDescription" > "${OUTPUT_FILE}"

# Get all security groups
echo "Fetching security groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups --region ${AWS_REGION} --output json)
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve security groups. Check your AWS credentials and permissions."
    exit 1
fi

# Count total security groups for progress reporting
SG_COUNT=$(echo "$SECURITY_GROUPS" | jq '.SecurityGroups | length')
echo "Found $SG_COUNT security groups to process."

# Process each security group
CURRENT=0
echo "$SECURITY_GROUPS" | jq -c '.SecurityGroups[]' | while read -r SG; do
    CURRENT=$((CURRENT + 1))
    
    # Extract basic security group info
    SG_ID=$(echo "$SG" | jq -r '.GroupId')
    SG_NAME=$(echo "$SG" | jq -r '.GroupName')
    VPC_ID=$(echo "$SG" | jq -r '.VpcId')
    SG_DESC=$(echo "$SG" | jq -r '.Description' | sed 's/"/\\"/g')
    
    echo "Processing security group $CURRENT of $SG_COUNT: $SG_ID ($SG_NAME)"
    
    # Process inbound rules
    echo "$SG" | jq -c '.IpPermissions[]?' 2>/dev/null | while read -r RULE; do
        if [ -n "$RULE" ]; then
            PROTOCOL=$(echo "$RULE" | jq -r '.IpProtocol')
            
            # Format protocol and port range
            if [ "$PROTOCOL" = "-1" ]; then
                PROTOCOL="All"
                PORT_RANGE="All"
            else
                FROM_PORT=$(echo "$RULE" | jq -r '.FromPort // "N/A"')
                TO_PORT=$(echo "$RULE" | jq -r '.ToPort // "N/A"')
                
                if [ "$FROM_PORT" = "$TO_PORT" ]; then
                    PORT_RANGE="$FROM_PORT"
                else
                    PORT_RANGE="$FROM_PORT-$TO_PORT"
                fi
                
                # Handle common protocols
                if [ "$PROTOCOL" = "tcp" ]; then
                    PROTOCOL="TCP"
                elif [ "$PROTOCOL" = "udp" ]; then
                    PROTOCOL="UDP"
                elif [ "$PROTOCOL" = "icmp" ]; then
                    PROTOCOL="ICMP"
                fi
            fi
            
            # Process IP ranges (IPv4)
            echo "$RULE" | jq -c '.IpRanges[]?' 2>/dev/null | while read -r IP_RANGE; do
                if [ -n "$IP_RANGE" ]; then
                    CIDR=$(echo "$IP_RANGE" | jq -r '.CidrIp')
                    RULE_DESC=$(echo "$IP_RANGE" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Inbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$CIDR\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
            
            # Process IPv6 ranges
            echo "$RULE" | jq -c '.Ipv6Ranges[]?' 2>/dev/null | while read -r IPV6_RANGE; do
                if [ -n "$IPV6_RANGE" ]; then
                    CIDR=$(echo "$IPV6_RANGE" | jq -r '.CidrIpv6')
                    RULE_DESC=$(echo "$IPV6_RANGE" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Inbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$CIDR\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
            
            # Process security group references
            echo "$RULE" | jq -c '.UserIdGroupPairs[]?' 2>/dev/null | while read -r GROUP_PAIR; do
                if [ -n "$GROUP_PAIR" ]; then
                    TARGET_GROUP=$(echo "$GROUP_PAIR" | jq -r '.GroupId')
                    RULE_DESC=$(echo "$GROUP_PAIR" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Inbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$TARGET_GROUP (Security Group)\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
        fi
    done
    
    # Process outbound rules
    echo "$SG" | jq -c '.IpPermissionsEgress[]?' 2>/dev/null | while read -r RULE; do
        if [ -n "$RULE" ]; then
            PROTOCOL=$(echo "$RULE" | jq -r '.IpProtocol')
            
            # Format protocol and port range
            if [ "$PROTOCOL" = "-1" ]; then
                PROTOCOL="All"
                PORT_RANGE="All"
            else
                FROM_PORT=$(echo "$RULE" | jq -r '.FromPort // "N/A"')
                TO_PORT=$(echo "$RULE" | jq -r '.ToPort // "N/A"')
                
                if [ "$FROM_PORT" = "$TO_PORT" ]; then
                    PORT_RANGE="$FROM_PORT"
                else
                    PORT_RANGE="$FROM_PORT-$TO_PORT"
                fi
                
                # Handle common protocols
                if [ "$PROTOCOL" = "tcp" ]; then
                    PROTOCOL="TCP"
                elif [ "$PROTOCOL" = "udp" ]; then
                    PROTOCOL="UDP"
                elif [ "$PROTOCOL" = "icmp" ]; then
                    PROTOCOL="ICMP"
                fi
            fi
            
            # Process IP ranges (IPv4)
            echo "$RULE" | jq -c '.IpRanges[]?' 2>/dev/null | while read -r IP_RANGE; do
                if [ -n "$IP_RANGE" ]; then
                    CIDR=$(echo "$IP_RANGE" | jq -r '.CidrIp')
                    RULE_DESC=$(echo "$IP_RANGE" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Outbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$CIDR\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
            
            # Process IPv6 ranges
            echo "$RULE" | jq -c '.Ipv6Ranges[]?' 2>/dev/null | while read -r IPV6_RANGE; do
                if [ -n "$IPV6_RANGE" ]; then
                    CIDR=$(echo "$IPV6_RANGE" | jq -r '.CidrIpv6')
                    RULE_DESC=$(echo "$IPV6_RANGE" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Outbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$CIDR\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
            
            # Process security group references
            echo "$RULE" | jq -c '.UserIdGroupPairs[]?' 2>/dev/null | while read -r GROUP_PAIR; do
                if [ -n "$GROUP_PAIR" ]; then
                    TARGET_GROUP=$(echo "$GROUP_PAIR" | jq -r '.GroupId')
                    RULE_DESC=$(echo "$GROUP_PAIR" | jq -r '.Description // "N/A"' | sed 's/"/\\"/g')
                    
                    echo "\"$SG_ID\",\"$SG_NAME\",\"$VPC_ID\",\"$SG_DESC\",\"Outbound\",\"$PROTOCOL\",\"$PORT_RANGE\",\"$TARGET_GROUP (Security Group)\",\"$RULE_DESC\"" >> "${OUTPUT_FILE}"
                fi
            done
        fi
    done
    
    # Add a blank line between security groups in CSV
    echo "\"----------\",\"----------\",\"----------\",\"----------\",\"----------\",\"----------\",\"----------\",\"----------\",\"----------\"" >> "${OUTPUT_FILE}"
done

echo "Export complete! Security groups have been exported to: ${OUTPUT_FILE}"
