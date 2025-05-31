#!/bin/bash

# Script to extract VPC and associated resource details into CSV files
# Make sure AWS CLI is configured with appropriate permissions

# Default region if none specified
DEFAULT_REGION="us-east-1"

# Set output directory
OUTPUT_DIR="./vpc-reports"
mkdir -p $OUTPUT_DIR

# Parse command line options
REGION=""
DEBUG=false

while getopts "r:d" opt; do
  case ${opt} in
    r )
      REGION=$OPTARG
      ;;
    d )
      DEBUG=true
      ;;
    \? )
      echo "Usage: $0 [-r region] [-d]"
      echo "  -r: AWS region (default: uses AWS CLI default)"
      echo "  -d: Enable debug mode"
      exit 1
      ;;
  esac
done

# Region parameter for AWS CLI calls
REGION_PARAM=""
if [ -n "$REGION" ]; then
  REGION_PARAM="--region $REGION"
  echo "Using region: $REGION"
else
  echo "Using default AWS CLI region configuration"
fi

# Debug function
debug() {
  if [ "$DEBUG" = true ]; then
    echo "[DEBUG] $1"
  fi
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed. Please install it first."
    exit 1
fi

# Test AWS CLI connectivity
echo "Testing AWS connectivity..."
if ! aws $REGION_PARAM sts get-caller-identity &> /dev/null; then
    echo "ERROR: Failed to connect to AWS. Please check your credentials and region settings."
    echo "Run 'aws configure' to set up your AWS CLI."
    exit 1
else
    CALLER_IDENTITY=$(aws $REGION_PARAM sts get-caller-identity --output json)
    echo "Connected to AWS as: $(echo $CALLER_IDENTITY | jq -r .Arn)"
fi

echo "Retrieving VPC details..."

# Create VPC details CSV
VPC_CSV="$OUTPUT_DIR/vpc-details.csv"
echo "VPC_ID,CIDR_Block,Name,State,Is_Default" > $VPC_CSV

# Create Subnets CSV
SUBNET_CSV="$OUTPUT_DIR/vpc-subnets.csv"
echo "VPC_ID,Subnet_ID,CIDR_Block,Availability_Zone,State,Name" > $SUBNET_CSV

# Create Internet Gateways CSV
IGW_CSV="$OUTPUT_DIR/vpc-internet-gateways.csv"
echo "IGW_ID,VPC_ID,Name" > $IGW_CSV

# Create NAT Gateways CSV
NATGW_CSV="$OUTPUT_DIR/vpc-nat-gateways.csv"
echo "NATGW_ID,VPC_ID,Subnet_ID,State,Public_IP,Private_IP,Name" > $NATGW_CSV

# Create Network ACLs CSV
NACL_CSV="$OUTPUT_DIR/vpc-network-acls.csv"
echo "NACL_ID,VPC_ID,Is_Default,Name" > $NACL_CSV

# Create NACL Rules CSV
NACL_RULES_CSV="$OUTPUT_DIR/vpc-nacl-rules.csv"
echo "NACL_ID,Rule_Number,Protocol,Port_Range,CIDR_Block,Rule_Action,Egress" > $NACL_RULES_CSV

# Create Route Tables CSV
RT_CSV="$OUTPUT_DIR/vpc-route-tables.csv"
echo "RT_ID,VPC_ID,Main,Name" > $RT_CSV

# Create Routes CSV
ROUTES_CSV="$OUTPUT_DIR/vpc-routes.csv"
echo "RT_ID,Destination,Target,State" > $ROUTES_CSV

# Create Route Table Associations CSV
RT_ASSOC_CSV="$OUTPUT_DIR/vpc-rt-associations.csv"
echo "RT_ID,Subnet_ID,Main" > $RT_ASSOC_CSV

# Function to get name tag
get_name_tag() {
    local tags=$1
    if [ -n "$tags" ]; then
        echo $tags | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Get all VPCs - with error handling
debug "Getting all VPCs"
VPC_RESPONSE=$(aws ec2 $REGION_PARAM describe-vpcs --output json 2>&1)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to retrieve VPC information:"
    echo "$VPC_RESPONSE"
    exit 1
fi

# Check if any VPCs exist
VPC_COUNT=$(echo "$VPC_RESPONSE" | jq -r '.Vpcs | length')
if [ "$VPC_COUNT" -eq 0 ]; then
    echo "No VPCs found in the selected region. Please check your region settings or create a VPC."
    exit 0
fi

echo "Found $VPC_COUNT VPCs in the region."

# Process each VPC
echo "$VPC_RESPONSE" | jq -c '.Vpcs[]' | while read vpc; do
    vpc_id=$(echo $vpc | jq -r '.VpcId')
    cidr=$(echo $vpc | jq -r '.CidrBlock')
    state=$(echo $vpc | jq -r '.State')
    is_default=$(echo $vpc | jq -r '.IsDefault')
    
    # Get Name tag if exists
    tags=$(echo $vpc | jq -r '.Tags // empty')
    name=$(get_name_tag "$tags")
    
    debug "Processing VPC: $vpc_id, Name: $name"
    
    # Add to VPC CSV
    echo "$vpc_id,$cidr,\"$name\",$state,$is_default" >> $VPC_CSV
    
    echo "Processing VPC: $vpc_id ($name)..."
    
    # Get subnets for this VPC
    echo "  Getting subnets..."
    SUBNET_RESPONSE=$(aws ec2 $REGION_PARAM describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --output json 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Failed to retrieve subnet information for VPC $vpc_id:"
        echo "  $SUBNET_RESPONSE"
        continue
    fi
    
    SUBNET_COUNT=$(echo "$SUBNET_RESPONSE" | jq -r '.Subnets | length')
    debug "  Found $SUBNET_COUNT subnets for VPC $vpc_id"
    
    if [ "$SUBNET_COUNT" -gt 0 ]; then
        echo "$SUBNET_RESPONSE" | jq -c '.Subnets[]' | while read subnet; do
            subnet_id=$(echo $subnet | jq -r '.SubnetId')
            subnet_cidr=$(echo $subnet | jq -r '.CidrBlock')
            az=$(echo $subnet | jq -r '.AvailabilityZone')
            subnet_state=$(echo $subnet | jq -r '.State')
            
            # Get subnet name
            subnet_tags=$(echo $subnet | jq -r '.Tags // empty')
            subnet_name=$(get_name_tag "$subnet_tags")
            
            debug "    Subnet: $subnet_id, Name: $subnet_name"
            echo "$vpc_id,$subnet_id,$subnet_cidr,$az,$subnet_state,\"$subnet_name\"" >> $SUBNET_CSV
        done
    else
        echo "  No subnets found for VPC $vpc_id"
    fi
    
    # Get Internet Gateways for this VPC
    echo "  Getting internet gateways..."
    IGW_RESPONSE=$(aws ec2 $REGION_PARAM describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --output json 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Failed to retrieve internet gateway information for VPC $vpc_id:"
        echo "  $IGW_RESPONSE"
    else
        IGW_COUNT=$(echo "$IGW_RESPONSE" | jq -r '.InternetGateways | length')
        debug "  Found $IGW_COUNT internet gateways for VPC $vpc_id"
        
        if [ "$IGW_COUNT" -gt 0 ]; then
            echo "$IGW_RESPONSE" | jq -c '.InternetGateways[]' | while read igw; do
                igw_id=$(echo $igw | jq -r '.InternetGatewayId')
                
                # Get IGW name
                igw_tags=$(echo $igw | jq -r '.Tags // empty')
                igw_name=$(get_name_tag "$igw_tags")
                
                debug "    IGW: $igw_id, Name: $igw_name"
                echo "$igw_id,$vpc_id,\"$igw_name\"" >> $IGW_CSV
            done
        else
            echo "  No internet gateways found for VPC $vpc_id"
        fi
    fi
    
    # Get NAT Gateways for this VPC
    echo "  Getting NAT gateways..."
    NATGW_RESPONSE=$(aws ec2 $REGION_PARAM describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --output json 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Failed to retrieve NAT gateway information for VPC $vpc_id:"
        echo "  $NATGW_RESPONSE"
    else
        NATGW_COUNT=$(echo "$NATGW_RESPONSE" | jq -r '.NatGateways | length')
        debug "  Found $NATGW_COUNT NAT gateways for VPC $vpc_id"
        
        if [ "$NATGW_COUNT" -gt 0 ]; then
            echo "$NATGW_RESPONSE" | jq -c '.NatGateways[]' | while read natgw; do
                natgw_id=$(echo $natgw | jq -r '.NatGatewayId')
                natgw_subnet=$(echo $natgw | jq -r '.SubnetId')
                natgw_state=$(echo $natgw | jq -r '.State')
                public_ip=$(echo $natgw | jq -r '.NatGatewayAddresses[0].PublicIp // "N/A"')
                private_ip=$(echo $natgw | jq -r '.NatGatewayAddresses[0].PrivateIp // "N/A"')
                
                # Get NAT GW name
                natgw_tags=$(echo $natgw | jq -r '.Tags // empty')
                natgw_name=$(get_name_tag "$natgw_tags")
                
                debug "    NATGW: $natgw_id, Name: $natgw_name"
                echo "$natgw_id,$vpc_id,$natgw_subnet,$natgw_state,$public_ip,$private_ip,\"$natgw_name\"" >> $NATGW_CSV
            done
        else
            echo "  No NAT gateways found for VPC $vpc_id"
        fi
    fi
    
    # Get Network ACLs for this VPC
    echo "  Getting network ACLs..."
    NACL_RESPONSE=$(aws ec2 $REGION_PARAM describe-network-acls --filters "Name=vpc-id,Values=$vpc_id" --output json 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Failed to retrieve network ACL information for VPC $vpc_id:"
        echo "  $NACL_RESPONSE"
    else
        NACL_COUNT=$(echo "$NACL_RESPONSE" | jq -r '.NetworkAcls | length')
        debug "  Found $NACL_COUNT network ACLs for VPC $vpc_id"
        
        if [ "$NACL_COUNT" -gt 0 ]; then
            echo "$NACL_RESPONSE" | jq -c '.NetworkAcls[]' | while read nacl; do
                nacl_id=$(echo $nacl | jq -r '.NetworkAclId')
                is_default=$(echo $nacl | jq -r '.IsDefault')
                
                # Get NACL name
                nacl_tags=$(echo $nacl | jq -r '.Tags // empty')
                nacl_name=$(get_name_tag "$nacl_tags")
                
                debug "    NACL: $nacl_id, Name: $nacl_name"
                echo "$nacl_id,$vpc_id,$is_default,\"$nacl_name\"" >> $NACL_CSV
                
                # Get inbound rules
                echo $nacl | jq -c '.Entries[] | select(.Egress==false)' | while read rule; do
                    rule_num=$(echo $rule | jq -r '.RuleNumber')
                    protocol=$(echo $rule | jq -r '.Protocol')
                    
                    # Handle port range
                    from_port=$(echo $rule | jq -r '.PortRange.From // "-"')
                    to_port=$(echo $rule | jq -r '.PortRange.To // "-"')
                    if [ "$from_port" != "-" ] && [ "$to_port" != "-" ]; then
                        port_range="${from_port}-${to_port}"
                    else
                        port_range="All"
                    fi
                    
                    cidr=$(echo $rule | jq -r '.CidrBlock // "-"')
                    action=$(echo $rule | jq -r '.RuleAction')
                    egress="false"
                    
                    echo "$nacl_id,$rule_num,$protocol,$port_range,$cidr,$action,$egress" >> $NACL_RULES_CSV
                done
                
                # Get outbound rules
                echo $nacl | jq -c '.Entries[] | select(.Egress==true)' | while read rule; do
                    rule_num=$(echo $rule | jq -r '.RuleNumber')
                    protocol=$(echo $rule | jq -r '.Protocol')
                    
                    # Handle port range
                    from_port=$(echo $rule | jq -r '.PortRange.From // "-"')
                    to_port=$(echo $rule | jq -r '.PortRange.To // "-"')
                    if [ "$from_port" != "-" ] && [ "$to_port" != "-" ]; then
                        port_range="${from_port}-${to_port}"
                    else
                        port_range="All"
                    fi
                    
                    cidr=$(echo $rule | jq -r '.CidrBlock // "-"')
                    action=$(echo $rule | jq -r '.RuleAction')
                    egress="true"
                    
                    echo "$nacl_id,$rule_num,$protocol,$port_range,$cidr,$action,$egress" >> $NACL_RULES_CSV
                done
            done
        else
            echo "  No network ACLs found for VPC $vpc_id"
        fi
    fi
    
    # Get Route Tables for this VPC
    echo "  Getting route tables..."
    RT_RESPONSE=$(aws ec2 $REGION_PARAM describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --output json 2>&1)
    if [ $? -ne 0 ]; then
        echo "  ERROR: Failed to retrieve route table information for VPC $vpc_id:"
        echo "  $RT_RESPONSE"
    else
        RT_COUNT=$(echo "$RT_RESPONSE" | jq -r '.RouteTables | length')
        debug "  Found $RT_COUNT route tables for VPC $vpc_id"
        
        if [ "$RT_COUNT" -gt 0 ]; then
            echo "$RT_RESPONSE" | jq -c '.RouteTables[]' | while read rt; do
                rt_id=$(echo $rt | jq -r '.RouteTableId')
                
                # Check if main route table
                main=$(echo $rt | jq -r '.Associations[] | select(.Main==true) | .Main' 2>/dev/null || echo "false")
                
                # Get RT name
                rt_tags=$(echo $rt | jq -r '.Tags // empty')
                rt_name=$(get_name_tag "$rt_tags")
                
                debug "    Route Table: $rt_id, Main: $main, Name: $rt_name"
                echo "$rt_id,$vpc_id,$main,\"$rt_name\"" >> $RT_CSV
                
                # Get routes
                echo $rt | jq -c '.Routes[]' | while read route; do
                    destination=$(echo $route | jq -r '.DestinationCidrBlock // .DestinationIpv6CidrBlock // "unknown"')
                    target=""
                    
                    # Identify target type
                    if [ "$(echo $route | jq -r '.GatewayId // "null"')" != "null" ]; then
                        target=$(echo $route | jq -r '.GatewayId')
                    elif [ "$(echo $route | jq -r '.NatGatewayId // "null"')" != "null" ]; then
                        target=$(echo $route | jq -r '.NatGatewayId')
                    elif [ "$(echo $route | jq -r '.InstanceId // "null"')" != "null" ]; then
                        target=$(echo $route | jq -r '.InstanceId')
                    elif [ "$(echo $route | jq -r '.TransitGatewayId // "null"')" != "null" ]; then
                        target=$(echo $route | jq -r '.TransitGatewayId')
                    elif [ "$(echo $route | jq -r '.VpcPeeringConnectionId // "null"')" != "null" ]; then
                        target=$(echo $route | jq -r '.VpcPeeringConnectionId')
                    else
                        target="local"
                    fi
                    
                    state=$(echo $route | jq -r '.State')
                    
                    echo "$rt_id,$destination,$target,$state" >> $ROUTES_CSV
                done
                
                # Get route table associations
                echo $rt | jq -c '.Associations[]' | while read assoc; do
                    subnet_id=$(echo $assoc | jq -r '.SubnetId // "None"')
                    main=$(echo $assoc | jq -r '.Main // false')
                    
                    if [ "$subnet_id" != "None" ]; then
                        echo "$rt_id,$subnet_id,$main" >> $RT_ASSOC_CSV
                    fi
                done
            done
        else
            echo "  No route tables found for VPC $vpc_id"
        fi
    fi
    
    echo "Completed processing for VPC: $vpc_id"
done

echo ""
echo "VPC details have been exported to CSV files in the $OUTPUT_DIR directory:"
ls -la $OUTPUT_DIR/*.csv | grep -v "0 " | while read file; do
    echo "  $file"
done

files_with_data=0
for file in $OUTPUT_DIR/*.csv; do
    if [ $(wc -l < "$file") -gt 1 ]; then
        files_with_data=$((files_with_data + 1))
    fi
done

if [ $files_with_data -eq 0 ]; then
    echo "WARNING: No data was written to the CSV files. This might indicate a problem with:"
    echo "  - AWS permissions: Ensure your IAM user/role has the necessary permissions"
    echo "  - Region selection: Try specifying a region with the -r option"
    echo "  - AWS resources: Confirm that you have VPCs in the selected region"
    echo ""
    echo "To see more detailed debug information, run this script with the -d flag"
else
    echo "All done! $files_with_data files contain data."
fi