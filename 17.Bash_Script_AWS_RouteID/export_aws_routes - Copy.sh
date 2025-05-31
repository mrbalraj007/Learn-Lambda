#!/bin/bash

# Script to export AWS Route Tables information to a CSV file
# This script exports name, Destination, Target, status, and propagated status

# Exit on error
set -e

# Set default AWS region
export AWS_DEFAULT_REGION="us-east-1"

# Output file
output_file="aws_routes_$(date +%Y%m%d_%H%M%S).csv"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it and try again."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it and try again."
    exit 1
fi

# Create header for CSV file
echo "RouteTableID,RouteName,Destination,Target,Status,Propagated" > "$output_file"

# Get all route tables using AWS CLI
echo "Fetching route table information from AWS (region: $AWS_DEFAULT_REGION)..."
if ! route_tables=$(aws ec2 describe-route-tables --output json); then
    echo "Error: Failed to retrieve route tables from AWS. Check your AWS credentials and permissions."
    exit 1
fi

# Process each route table
echo "$route_tables" | jq -c '.RouteTables[]' | while read -r route_table; do
    route_table_id=$(echo "$route_table" | jq -r '.RouteTableId')
    
    # Get route table name from tags
    route_table_name=$(echo "$route_table" | jq -r '.Tags[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "NoName")
    
    # Process each route in the route table
    echo "$route_table" | jq -c '.Routes[]' | while read -r route; do
        # Extract route information
        destination=$(echo "$route" | jq -r '.DestinationCidrBlock // .DestinationPrefixListId // .DestinationIpv6CidrBlock // "N/A"')
        
        # Determine target type and extract target information
        target="N/A"
        if echo "$route" | jq -e '.GatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.GatewayId')
        elif echo "$route" | jq -e '.NatGatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.NatGatewayId')
        elif echo "$route" | jq -e '.NetworkInterfaceId' > /dev/null; then
            target=$(echo "$route" | jq -r '.NetworkInterfaceId')
        elif echo "$route" | jq -e '.VpcPeeringConnectionId' > /dev/null; then
            target=$(echo "$route" | jq -r '.VpcPeeringConnectionId')
        elif echo "$route" | jq -e '.TransitGatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.TransitGatewayId')
        elif echo "$route" | jq -e '.LocalGatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.LocalGatewayId')
        elif echo "$route" | jq -e '.CarrierGatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.CarrierGatewayId')
        elif echo "$route" | jq -e '.VpcEndpointId' > /dev/null; then
            target=$(echo "$route" | jq -r '.VpcEndpointId')
        elif echo "$route" | jq -e '.EgressOnlyInternetGatewayId' > /dev/null; then
            target=$(echo "$route" | jq -r '.EgressOnlyInternetGatewayId')
        fi
        
        # Get route state and propagation status
        state=$(echo "$route" | jq -r '.State // "N/A"')
        
        # Check if route is propagated
        propagated="false"
        if [ "$(echo "$route" | jq -r 'has("PropagatedVgwIds")')" == "true" ]; then
            propagated_count=$(echo "$route" | jq -r '.PropagatedVgwIds | length')
            if [ "$propagated_count" -gt 0 ]; then
                propagated="true"
            fi
        fi
        
        # Write to CSV file
        echo "\"$route_table_id\",\"$route_table_name\",\"$destination\",\"$target\",\"$state\",\"$propagated\"" >> "$output_file"
    done
done

route_count=$(( $(wc -l < "$output_file") - 1 ))
echo "Route information has been exported to $output_file"
echo "Total routes exported: $route_count"
        echo "\"$route_table_id\",\"$route_table_name\",\"$route_id\",\"$destination\",\"$target\",\"$state\",\"$propagated\"" >> "$output_file"
    done
done

echo "Route information has been exported to $output_file"
echo "Total routes exported: $((route_counter - 1))"
