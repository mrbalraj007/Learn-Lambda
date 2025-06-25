#!/bin/bash

# Set AWS region
AWS_REGION="ap-southeast-2"

# CSV file name with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CSV_FILE="tgw_attachments_${TIMESTAMP}.csv"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed. Please install AWS CLI first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Add CSV header
echo "Attachment ID,Resource Type,Resource ID,State" > "$CSV_FILE"

echo "Retrieving Transit Gateway attachments from region $AWS_REGION..."

# Get all transit gateway attachments
ATTACHMENTS=$(aws ec2 describe-transit-gateway-attachments --region $AWS_REGION 2>&1)

# Check if the AWS CLI command was successful
if [ $? -ne 0 ]; then
    echo "Error retrieving Transit Gateway attachments: $ATTACHMENTS"
    exit 1
fi

# Extract and process attachments 
echo "Processing attachments..."
ATTACHMENT_COUNT=$(echo "$ATTACHMENTS" | jq -r '.TransitGatewayAttachments | length')

if [ "$ATTACHMENT_COUNT" -eq 0 ]; then
    echo "No Transit Gateway attachments found in region $AWS_REGION."
    exit 0
fi

echo "Found $ATTACHMENT_COUNT Transit Gateway attachments."

for (( i=0; i<$ATTACHMENT_COUNT; i++ ))
do
    ATTACHMENT_ID=$(echo "$ATTACHMENTS" | jq -r ".TransitGatewayAttachments[$i].TransitGatewayAttachmentId")
    RESOURCE_TYPE=$(echo "$ATTACHMENTS" | jq -r ".TransitGatewayAttachments[$i].ResourceType")
    RESOURCE_ID=$(echo "$ATTACHMENTS" | jq -r ".TransitGatewayAttachments[$i].ResourceId")
    STATE=$(echo "$ATTACHMENTS" | jq -r ".TransitGatewayAttachments[$i].State")
    
    echo "Processing attachment $((i+1))/$ATTACHMENT_COUNT: $ATTACHMENT_ID ($RESOURCE_TYPE: $RESOURCE_ID)"
    echo "$ATTACHMENT_ID,$RESOURCE_TYPE,$RESOURCE_ID,$STATE" >> "$CSV_FILE"
done

echo "Completed! Transit Gateway attachment details have been exported to $CSV_FILE"
