#!/bin/bash
#
# Script: export_internet_gateways.sh
# Description: Exports AWS Internet Gateway information to a CSV file
# Default region: us-east-1
#

# Set default region
AWS_REGION="ap-southeast-2"
OUTPUT_FILE="internet_gateways_info.csv"
CURRENT_DATE=$(date +"%Y-%m-%d-%H-%M-%S")
OUTPUT_FILE="internet_gateways_${CURRENT_DATE}.csv"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Create CSV header
echo "Internet_Gateway_Name,Internet_Gateway_ID,State,VPC_ID,VPC_Name,Owner_ID" > "$OUTPUT_FILE"

# Get all Internet Gateways
echo "Fetching Internet Gateway information from region $AWS_REGION..."
IGW_LIST=$(aws ec2 describe-internet-gateways --region $AWS_REGION --query 'InternetGateways[*].[InternetGatewayId]' --output text)

if [ -z "$IGW_LIST" ]; then
    echo "No Internet Gateways found in region $AWS_REGION"
    exit 0
fi

# Count total gateways for progress reporting
TOTAL_IGW=$(echo "$IGW_LIST" | wc -w)
CURRENT_IGW=0

echo "Found $TOTAL_IGW Internet Gateway(s). Processing details..."

# Loop through each Internet Gateway
for IGW_ID in $IGW_LIST; do
    # Update progress
    CURRENT_IGW=$((CURRENT_IGW+1))
    echo "Processing Internet Gateway $CURRENT_IGW of $TOTAL_IGW: $IGW_ID"
    
    # Get Internet Gateway Name from tags
    IGW_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$IGW_ID" "Name=key,Values=Name" --region $AWS_REGION --query "Tags[0].Value" --output text 2>/dev/null)
    
    # If no name tag exists or command fails, use the ID as name
    if [ -z "$IGW_NAME" ] || [ "$IGW_NAME" == "None" ]; then
        IGW_NAME="$IGW_ID"
    fi
    
    # Get Owner ID
    OWNER_ID=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION --query "InternetGateways[0].OwnerId" --output text)
    
    # Get VPC attachments
    ATTACHMENTS=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION --query "InternetGateways[0].Attachments" --output json)
    
    # Check if there are any attachments
    ATTACHMENT_COUNT=$(echo "$ATTACHMENTS" | grep -c "VpcId")
    
    if [ "$ATTACHMENT_COUNT" -eq 0 ]; then
        # No attachments - add a row with N/A values
        echo "$IGW_NAME,$IGW_ID,detached,N/A,N/A,$OWNER_ID" >> "$OUTPUT_FILE"
    else
        # Process each attachment
        VPC_IDS=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION --query "InternetGateways[0].Attachments[*].VpcId" --output text)
        
        for VPC_ID in $VPC_IDS; do
            # Get the state of this specific attachment
            IGW_STATE=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --region $AWS_REGION --query "InternetGateways[0].Attachments[?VpcId=='$VPC_ID'].State" --output text)
            
            # Get VPC Name
            VPC_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$VPC_ID" "Name=key,Values=Name" --region $AWS_REGION --query "Tags[0].Value" --output text 2>/dev/null)
            
            # If no VPC name tag exists or command fails, use the ID as name
            if [ -z "$VPC_NAME" ] || [ "$VPC_NAME" == "None" ]; then
                VPC_NAME="$VPC_ID"
            fi
            
            # Add the row to the CSV file
            echo "$IGW_NAME,$IGW_ID,$IGW_STATE,$VPC_ID,$VPC_NAME,$OWNER_ID" >> "$OUTPUT_FILE"
        done
    fi
done

echo "Export completed successfully. Data saved to $OUTPUT_FILE"
echo "You can open this CSV file in a spreadsheet application for further analysis."
