#!/bin/bash

# Script Name: export_tgw_routes.sh
# Description: Export AWS Transit Gateway route details to a CSV file
# Author: AWS Engineer
# Default region: us-east-1

# Set default region
AWS_REGION="ap-southeast-2"
OUTPUT_FILE="tgw_routes_$(date +%Y%m%d_%H%M%S).csv"

# Function to display usage information
function display_usage {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --region    AWS region (default: us-east-1)"
    echo "  -o, --output    Output CSV file (default: tgw_routes_timestamp.csv)"
    echo "  -h, --help      Display this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--region)
        AWS_REGION="$2"
        shift 2
        ;;
        -o|--output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
        -h|--help)
        display_usage
        exit 0
        ;;
        *)
        echo "Unknown option: $1"
        display_usage
        exit 1
        ;;
    esac
done

echo "Using AWS Region: $AWS_REGION"
echo "Output will be written to: $OUTPUT_FILE"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed (needed for JSON processing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Create CSV header
echo "TransitGatewayRouteTableId,DestinationCidr,AttachmentId,ResourceId,ResourceType,RouteType,State" > "$OUTPUT_FILE"

# Get all Transit Gateway Route Tables
echo "Fetching Transit Gateway Route Tables..."
TGW_ROUTE_TABLES=$(aws ec2 describe-transit-gateway-route-tables --region $AWS_REGION --query 'TransitGatewayRouteTables[*].TransitGatewayRouteTableId' --output text)

if [ -z "$TGW_ROUTE_TABLES" ]; then
    echo "No Transit Gateway Route Tables found in region $AWS_REGION"
    exit 0
fi

# Process each Transit Gateway Route Table
for TGW_ROUTE_TABLE in $TGW_ROUTE_TABLES; do
    echo "Processing routes for Transit Gateway Route Table: $TGW_ROUTE_TABLE"
    
    # Use search-transit-gateway-routes instead of get-transit-gateway-route-table-routes
    ROUTES_JSON=$(aws ec2 search-transit-gateway-routes \
        --transit-gateway-route-table-id "$TGW_ROUTE_TABLE" \
        --filters "Name=type,Values=static,propagated" \
        --region "$AWS_REGION" \
        --output json)
    
    # Check if the command was successful
    if [ $? -ne 0 ]; then
        echo "  Error occurred while fetching routes for $TGW_ROUTE_TABLE"
        continue
    fi
    
    # Count routes
    ROUTE_COUNT=$(echo "$ROUTES_JSON" | jq '.Routes | length')
    
    if [ "$ROUTE_COUNT" -eq 0 ]; then
        echo "  No routes found for this route table"
        continue
    fi
    
    echo "  Found $ROUTE_COUNT routes"
    
    # Process each route and append to CSV
    echo "$ROUTES_JSON" | \
    jq -r '.Routes[] | [
        "'$TGW_ROUTE_TABLE'",
        .DestinationCidrBlock,
        (.TransitGatewayAttachments[0].TransitGatewayAttachmentId // "None"),
        (.TransitGatewayAttachments[0].ResourceId // "None"),
        (.TransitGatewayAttachments[0].ResourceType // "None"),
        .Type,
        .State
    ] | @csv' >> "$OUTPUT_FILE"
    
    echo "  Completed processing routes for $TGW_ROUTE_TABLE"
done

echo "Export complete. Results saved to $OUTPUT_FILE"
