#!/bin/bash

# Prerequisites:
# - AWS CLI must be configured with required permissions.
# - Provide EC2 instance ID as an argument or set INSTANCE_ID below.

# Usage: ./export_ec2_sg_rules.sh i-0123456789abcdef

INSTANCE_ID="$1"
OUTPUT_FILE="ec2_sg_rules_${INSTANCE_ID}.csv"

if [ -z "$INSTANCE_ID" ]; then
  echo "Usage: $0 <EC2_INSTANCE_ID>"
  exit 1
fi

echo "Fetching Security Group Rules for EC2 Instance: $INSTANCE_ID"
echo "Output will be saved to $OUTPUT_FILE"

# CSV header
echo "SecurityGroupId,Direction,Protocol,PortRange,SourceOrDestination,Description" > "$OUTPUT_FILE"

# Get associated Security Groups
SG_IDS=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' \
  --output text)

for SG_ID in $SG_IDS; do
  # Inbound Rules
  aws ec2 describe-security-groups --group-ids "$SG_ID" \
    --query "SecurityGroups[].IpPermissions[]" --output json | jq -c '.[]' | while read -r rule; do
    PROTOCOL=$(echo "$rule" | jq -r '.IpProtocol')
    FROM_PORT=$(echo "$rule" | jq -r '.FromPort // "All"')
    TO_PORT=$(echo "$rule" | jq -r '.ToPort // "All"')
    PORT_RANGE="${FROM_PORT}-${TO_PORT}"
    [ "$FROM_PORT" = "All" ] && PORT_RANGE="All"

    # CIDR blocks
    echo "$rule" | jq -c '.IpRanges[]?' | while read -r iprange; do
      CIDR=$(echo "$iprange" | jq -r '.CidrIp')
      DESC=$(echo "$iprange" | jq -r '.Description // "-"')
      echo "$SG_ID,Inbound,$PROTOCOL,$PORT_RANGE,$CIDR,$DESC" >> "$OUTPUT_FILE"
    done

    # IPv6 CIDR blocks
    echo "$rule" | jq -c '.Ipv6Ranges[]?' | while read -r iprange; do
      CIDR=$(echo "$iprange" | jq -r '.CidrIpv6')
      DESC=$(echo "$iprange" | jq -r '.Description // "-"')
      echo "$SG_ID,Inbound,$PROTOCOL,$PORT_RANGE,$CIDR,$DESC" >> "$OUTPUT_FILE"
    done

    # Security group references
    echo "$rule" | jq -c '.UserIdGroupPairs[]?' | while read -r ref; do
      SOURCE_SG=$(echo "$ref" | jq -r '.GroupId')
      DESC=$(echo "$ref" | jq -r '.Description // "-"')
      echo "$SG_ID,Inbound,$PROTOCOL,$PORT_RANGE,$SOURCE_SG,$DESC" >> "$OUTPUT_FILE"
    done
  done

  # Outbound Rules
  aws ec2 describe-security-groups --group-ids "$SG_ID" \
    --query "SecurityGroups[].IpPermissionsEgress[]" --output json | jq -c '.[]' | while read -r rule; do
    PROTOCOL=$(echo "$rule" | jq -r '.IpProtocol')
    FROM_PORT=$(echo "$rule" | jq -r '.FromPort // "All"')
    TO_PORT=$(echo "$rule" | jq -r '.ToPort // "All"')
    PORT_RANGE="${FROM_PORT}-${TO_PORT}"
    [ "$FROM_PORT" = "All" ] && PORT_RANGE="All"

    echo "$rule" | jq -c '.IpRanges[]?' | while read -r iprange; do
      CIDR=$(echo "$iprange" | jq -r '.CidrIp')
      DESC=$(echo "$iprange" | jq -r '.Description // "-"')
      echo "$SG_ID,Outbound,$PROTOCOL,$PORT_RANGE,$CIDR,$DESC" >> "$OUTPUT_FILE"
    done

    echo "$rule" | jq -c '.Ipv6Ranges[]?' | while read -r iprange; do
      CIDR=$(echo "$iprange" | jq -r '.CidrIpv6')
      DESC=$(echo "$iprange" | jq -r '.Description // "-"')
      echo "$SG_ID,Outbound,$PROTOCOL,$PORT_RANGE,$CIDR,$DESC" >> "$OUTPUT_FILE"
    done

    echo "$rule" | jq -c '.UserIdGroupPairs[]?' | while read -r ref; do
      DEST_SG=$(echo "$ref" | jq -r '.GroupId')
      DESC=$(echo "$ref" | jq -r '.Description // "-"')
      echo "$SG_ID,Outbound,$PROTOCOL,$PORT_RANGE,$DEST_SG,$DESC" >> "$OUTPUT_FILE"
    done
  done
done

echo "Export completed: $OUTPUT_FILE"
