#!/bin/bash

# Set default region
AWS_REGION="ap-southeast-2"
export AWS_DEFAULT_REGION=$AWS_REGION

# Output CSV file
OUTPUT_FILE="tgw_propagations_$(date +%Y%m%d_%H%M%S).csv"
VERBOSE=false

# Check command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -r|--region)
            AWS_REGION="$2"
            export AWS_DEFAULT_REGION=$AWS_REGION
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function for verbose logging
log_verbose() {
    if $VERBOSE; then
        echo "[DEBUG] $*"
    fi
}

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
echo '"RouteTableId","AttachmentId","ResourceType","ResourceId","State"' > $OUTPUT_FILE

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
TOTAL_PROPAGATIONS=0

echo "Found $TOTAL_TABLES Transit Gateway Route Tables. Processing..."

# For each Route Table, get propagations
for ROUTE_TABLE in $ROUTE_TABLES; do
    CURRENT_TABLE=$((CURRENT_TABLE + 1))
    echo "Processing Route Table: $ROUTE_TABLE ($CURRENT_TABLE of $TOTAL_TABLES)"
    
    # Get propagations for this route table
    # IMPORTANT: Changed from describe-transit-gateway-route-table-propagations to get-transit-gateway-route-table-propagations
    PROPAGATIONS=$(aws ec2 get-transit-gateway-route-table-propagations \
        --transit-gateway-route-table-id "$ROUTE_TABLE" \
        --output json)
    
    # Check for errors in AWS CLI response
    if [ $? -ne 0 ]; then
        echo "Error fetching propagations for Route Table $ROUTE_TABLE" >&2
        continue
    fi
    
    if $VERBOSE; then
        log_verbose "Raw response for $ROUTE_TABLE:"
        log_verbose "$(echo "$PROPAGATIONS" | jq '.')"
    fi
    
    # Extract and write details to CSV using jq
    # Updated to match the structure returned by get-transit-gateway-route-table-propagations
    PROP_DATA=$(echo "$PROPAGATIONS" | jq -r --arg rt "$ROUTE_TABLE" '.TransitGatewayRouteTablePropagations[] | 
        [$rt, 
         (.TransitGatewayAttachmentId // ""),
         (.ResourceType // ""),
         (.ResourceId // ""),
         (.State // "")] | 
        map(. | @sh) | join(",")' 2>/dev/null)
    
    # Check if we got any data
    if [ $? -ne 0 ] || [ -z "$PROP_DATA" ]; then
        echo "  → No valid propagation data found or jq error occurred"
        if $VERBOSE; then
            log_verbose "jq error or no data when processing: $ROUTE_TABLE"
            log_verbose "Raw output: $(echo "$PROPAGATIONS" | jq '.')"
        fi
        continue
    fi
    
    # Process and save each line with proper CSV formatting
    while IFS= read -r line; do
        # Convert from jq output to properly quoted CSV
        formatted_line=$(echo "$line" | sed "s/'//g" | sed 's/^/"/;s/,/","/g;s/$/"/g')
        echo "$formatted_line" >> $OUTPUT_FILE
        TOTAL_PROPAGATIONS=$((TOTAL_PROPAGATIONS + 1))
    done <<< "$PROP_DATA"
    
    # Report number of propagations found
    PROP_COUNT=$(echo "$PROPAGATIONS" | jq '.TransitGatewayRouteTablePropagations | length')
    echo "  → Found $PROP_COUNT propagations"
done

echo "Export completed. Total propagations: $TOTAL_PROPAGATIONS. Results saved to $OUTPUT_FILE"

# Validate output file
if [ $TOTAL_PROPAGATIONS -gt 0 ]; then
    echo "Sample of output data:"
    head -n 3 "$OUTPUT_FILE"
else
    echo "Warning: No propagation data was exported. The output file contains only the header."
    echo "Try running with --verbose flag to see more details."
fi
