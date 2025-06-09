#!/bin/bash

# Set default region
AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION=$AWS_REGION

# Output CSV file
OUTPUT_FILE="tgw_propagations_$(date +%Y%m%d_%H%M%S).csv"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed. Please install AWS CLI."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq."
    exit 1
fi

# Create CSV header
echo "RouteTableId,AttachmentId,ResourceType,ResourceId,State" > $OUTPUT_FILE

echo "Fetching Transit Gateway Route Tables..."
ROUTE_TABLES=$(aws ec2 describe-transit-gateway-route-tables --query 'TransitGatewayRouteTables[*].TransitGatewayRouteTableId' --output text)

if [ $? -ne 0 ]; then
    echo "Error fetching Transit Gateway Route Tables. Please check your AWS credentials and permissions."
    exit 1
fi

if [ -z "$ROUTE_TABLES" ]; then
    echo "No Transit Gateway Route Tables found in region $AWS_REGION"
    exit 0
fi

TOTAL_TABLES=$(echo "$ROUTE_TABLES" | wc -w)
CURRENT_TABLE=0

echo "Found $TOTAL_TABLES Transit Gateway Route Tables. Processing..."

# For each Route Table, get propagations
for ROUTE_TABLE in $ROUTE_TABLES; do
    CURRENT_TABLE=$((CURRENT_TABLE + 1))
    echo "Processing Route Table: $ROUTE_TABLE ($CURRENT_TABLE of $TOTAL_TABLES)"
    
    # Get propagations for this route table
    PROPAGATIONS=$(aws ec2 describe-transit-gateway-route-table-propagations \
        --transit-gateway-route-table-id "$ROUTE_TABLE" \
        --output json)
    
    # Check for errors in AWS CLI response
    if [ $? -ne 0 ]; then
        echo "Error fetching propagations for Route Table $ROUTE_TABLE" >&2
        continue
    fi
    
    # Extract and write details to CSV using jq
    echo "$PROPAGATIONS" | jq -r --arg rt "$ROUTE_TABLE" '.TransitGatewayRouteTablePropagations[] | 
        [$rt, .TransitGatewayAttachmentId, .ResourceType // "N/A", .ResourceId // "N/A", .State] | 
        @csv' >> $OUTPUT_FILE
    
    # Report number of propagations found
    PROP_COUNT=$(echo "$PROPAGATIONS" | jq '.TransitGatewayRouteTablePropagations | length')
    echo "  → Found $PROP_COUNT propagations"
done

echo "Export completed. Results saved to $OUTPUT_FILE"