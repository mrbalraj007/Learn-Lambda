#!/bin/bash
# Script: get_ec2_names_current_region.sh
# Purpose: Fetch EC2 instance names and power state in the current AWS region with timestamped filename
# Author: AWS Engineer

set -euo pipefail

REGION=$(aws configure get region)
if [[ -z "$REGION" ]]; then
  echo "❌ AWS region not configured. Please run 'aws configure' or set AWS_REGION."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --no-verify-ssl)
DATE=$(date +%Y%m%d)
TIME=$(date +%H%M%S)
OUTPUT_FILE="listofEC2-${ACCOUNT_ID}-${DATE}-${TIME}.csv"

echo "⚠️  Ignoring SSL certificate validation."
echo "🔍 Region: $REGION | Account ID: $ACCOUNT_ID"
echo "💾 Exporting EC2 instance names and state to: $OUTPUT_FILE"

# Write CSV header including State column
echo "Region,InstanceID,Name,State" > "$OUTPUT_FILE"

# Fetch InstanceId, Tags, and State
aws ec2 describe-instances \
  --region "$REGION" \
  --no-verify-ssl \
  --query "Reservations[].Instances[].[InstanceId, Tags, State.Name]" \
  --output json |
jq -r --arg region "$REGION" '
  .[] |
  {
    InstanceId: .[0],
    Tags: .[1],
    State: .[2]
  } |
  {
    InstanceId,
    Name: (
      .Tags // [] |
      map(select(.Key == "Name")) |
      .[0].Value // "N/A"
    ),
    State
  } |
  "\($region),\(.InstanceId),\(.Name),\(.State)"
' >> "$OUTPUT_FILE"

echo "✅ Done! CSV saved as: $OUTPUT_FILE"
