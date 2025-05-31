#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\15.getdetails\combined-vpc-report.sh
# This second script takes the CSV files created by the first script and combines the most important information into a single comprehensive CSV report:

# Script to combine all VPC reports into one comprehensive CSV
INPUT_DIR="./vpc-reports"
OUTPUT_FILE="vpc-comprehensive-report.csv"

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory $INPUT_DIR not found. Run vpc-details.sh first."
    exit 1
fi

# Create header for comprehensive report
echo "Resource_Type,VPC_ID,VPC_Name,Resource_ID,Description,Additional_Info" > "$OUTPUT_FILE"

# Process VPCs
if [ -f "$INPUT_DIR/vpc-details.csv" ]; then
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-details.csv" | while IFS=, read -r vpc_id cidr name state is_default; do
        echo "VPC,$vpc_id,$name,$vpc_id,\"CIDR: $cidr\",\"State: $state, Default: $is_default\"" >> "$OUTPUT_FILE"
    done
fi

# Process Subnets
if [ -f "$INPUT_DIR/vpc-subnets.csv" ]; then
    # Get VPC names for reference
    declare -A vpc_names
    if [ -f "$INPUT_DIR/vpc-details.csv" ]; then
        tail -n +2 "$INPUT_DIR/vpc-details.csv" | while IFS=, read -r vpc_id cidr name rest; do
            vpc_names["$vpc_id"]="$name"
        done
    fi
    
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-subnets.csv" | while IFS=, read -r vpc_id subnet_id cidr az state name; do
        vpc_name="${vpc_names[$vpc_id]}"
        echo "Subnet,$vpc_id,\"$vpc_name\",$subnet_id,\"CIDR: $cidr, Name: $name\",\"AZ: $az, State: $state\"" >> "$OUTPUT_FILE"
    done
fi

# Process Internet Gateways
if [ -f "$INPUT_DIR/vpc-internet-gateways.csv" ]; then
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-internet-gateways.csv" | while IFS=, read -r igw_id vpc_id name; do
        vpc_name="${vpc_names[$vpc_id]}"
        echo "InternetGateway,$vpc_id,\"$vpc_name\",$igw_id,\"Name: $name\",\"Attached to VPC: $vpc_id\"" >> "$OUTPUT_FILE"
    done
fi

# Process NAT Gateways
if [ -f "$INPUT_DIR/vpc-nat-gateways.csv" ]; then
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-nat-gateways.csv" | while IFS=, read -r natgw_id vpc_id subnet_id state public_ip private_ip name; do
        vpc_name="${vpc_names[$vpc_id]}"
        echo "NATGateway,$vpc_id,\"$vpc_name\",$natgw_id,\"Name: $name, State: $state\",\"Subnet: $subnet_id, Public IP: $public_ip\"" >> "$OUTPUT_FILE"
    done
fi

# Process Network ACLs
if [ -f "$INPUT_DIR/vpc-network-acls.csv" ]; then
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-network-acls.csv" | while IFS=, read -r nacl_id vpc_id is_default name; do
        vpc_name="${vpc_names[$vpc_id]}"
        echo "NetworkACL,$vpc_id,\"$vpc_name\",$nacl_id,\"Name: $name\",\"Default: $is_default\"" >> "$OUTPUT_FILE"
    done
fi

# Process Route Tables
if [ -f "$INPUT_DIR/vpc-route-tables.csv" ]; then
    # Skip header
    tail -n +2 "$INPUT_DIR/vpc-route-tables.csv" | while IFS=, read -r rt_id vpc_id main name; do
        vpc_name="${vpc_names[$vpc_id]}"
        echo "RouteTable,$vpc_id,\"$vpc_name\",$rt_id,\"Name: $name\",\"Main: $main\"" >> "$OUTPUT_FILE"
    done
fi

echo "Comprehensive VPC report generated: $OUTPUT_FILE"