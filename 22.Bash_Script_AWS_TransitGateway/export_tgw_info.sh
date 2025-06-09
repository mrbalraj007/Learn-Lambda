#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\22.Bash_Script_AWS_TransitGateway\export_tgw_info.sh
# Script to export AWS Transit Gateway information with attachment details
# Output is organized by Attachment ID and saved to a CSV file

# Set default region
AWS_REGION="us-east-1"
OUTPUT_FILE="tgw_attachment_info_$(date +%Y%m%d_%H%M%S).csv"

# Function to escape CSV fields that may contain commas
escape_csv() {
    local field="$1"
    if [[ "$field" == *","* || "$field" == *"\""* ]]; then
        field="${field//\"/\"\"}"
        echo "\"$field\""
    else
        echo "$field"
    fi
}

echo "Starting Transit Gateway information export..."
echo "Using AWS region: $AWS_REGION"
echo "Output will be saved to: $OUTPUT_FILE"

# Create CSV header
echo "TGW_ID,TGW_Name,Attachment_ID,Resource_Type,Resource_ID,State" > "$OUTPUT_FILE"

# Get list of all Transit Gateways
TRANSIT_GATEWAY_IDS=$(aws ec2 describe-transit-gateways \
                      --region "$AWS_REGION" \
                      --query "TransitGateways[*].TransitGatewayId" \
                      --output text)

if [ -z "$TRANSIT_GATEWAY_IDS" ]; then
    echo "No Transit Gateways found in region $AWS_REGION."
    exit 0
fi

# Process each Transit Gateway
for TGW_ID in $TRANSIT_GATEWAY_IDS; do
    # Get Transit Gateway Name (if it exists)
    TGW_NAME=$(aws ec2 describe-transit-gateways \
              --transit-gateway-ids "$TGW_ID" \
              --region "$AWS_REGION" \
              --query "TransitGateways[0].Tags[?Key=='Name'].Value | [0]" \
              --output text)
    
    # If TGW_NAME is 'None', set it to empty
    if [ "$TGW_NAME" == "None" ]; then
        TGW_NAME=""
    fi
    
    echo "Processing Transit Gateway: $TGW_ID ($TGW_NAME)"
    
    # Get all attachments for this Transit Gateway
    ATTACHMENTS=$(aws ec2 describe-transit-gateway-attachments \
                 --filters "Name=transit-gateway-id,Values=$TGW_ID" \
                 --region "$AWS_REGION" \
                 --query "TransitGatewayAttachments[*].[TransitGatewayAttachmentId,ResourceType,ResourceId,State]" \
                 --output text)
    
    # If no attachments found
    if [ -z "$ATTACHMENTS" ]; then
        echo "  - No attachments found for this Transit Gateway"
        echo "$(escape_csv "$TGW_ID"),$(escape_csv "$TGW_NAME"),No attachments,,," >> "$OUTPUT_FILE"
        continue
    fi
    
    # Process each attachment
    while IFS=$'\t' read -r ATTACHMENT_ID RESOURCE_TYPE RESOURCE_ID STATE; do
        echo "  - Processing Attachment: $ATTACHMENT_ID ($RESOURCE_TYPE: $RESOURCE_ID) - $STATE"
        
        # Write to CSV with escaped values
        echo "$(escape_csv "$TGW_ID"),$(escape_csv "$TGW_NAME"),$(escape_csv "$ATTACHMENT_ID"),$(escape_csv "$RESOURCE_TYPE"),$(escape_csv "$RESOURCE_ID"),$(escape_csv "$STATE")" >> "$OUTPUT_FILE"
    done <<< "$ATTACHMENTS"
done

echo "Transit Gateway information export completed!"
echo "Results saved to: $OUTPUT_FILE"