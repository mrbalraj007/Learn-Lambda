#!/bin/bash

REGION="ap-southeast-2"
OUTPUT_FILE="imdsv1_usage_report.csv"

echo "InstanceId,MetadataNoTokenCount" > "$OUTPUT_FILE"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region $REGION \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ")

for INSTANCE_ID in $INSTANCE_IDS
do
    VALUE=$(aws cloudwatch get-metric-statistics \
        --region $REGION \
        --namespace AWS/EC2 \
        --metric-name MetadataNoToken \
        --dimensions Name=InstanceId,Value=$INSTANCE_ID \
        --statistics Sum \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 86400 \
        --query "sum(Datapoints[].Sum)" \
        --output text 2>/dev/null)

    if [ "$VALUE" == "None" ] || [ -z "$VALUE" ]; then
        VALUE=0
    fi

    echo "$INSTANCE_ID,$VALUE" >> "$OUTPUT_FILE"
done

echo "Report written to $OUTPUT_FILE"


#InstanceId,MetadataNoTokenCount
#i-0123456789abcdef0,0
#i-0fedcba9876543210,15
#i-0abc123def456ghi7,3

# Where:
# 0 = No IMDSv1 usage detected during the lookback period
# >0 = IMDSv1 requests detected, investigate before enforcing IMDSv2