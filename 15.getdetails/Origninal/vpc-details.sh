#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\15.getdetails\vpc-details.sh

# Script to extract VPC and associated resource details into CSV files
# Make sure AWS CLI is configured with appropriate permissions

# Set output directory
OUTPUT_DIR="./vpc-reports"
mkdir -p $OUTPUT_DIR

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
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

# Get all VPCs
vpcs=$(aws ec2 describe-vpcs --output json)

# Process each VPC
echo $vpcs | jq -c '.Vpcs[]' | while read vpc; do
    vpc_id=$(echo $vpc | jq -r '.VpcId')
    cidr=$(echo $vpc | jq -r '.CidrBlock')
    state=$(echo $vpc | jq -r '.State')
    is_default=$(echo $vpc | jq -r '.IsDefault')
    
    # Get Name tag if exists
    tags=$(echo $vpc | jq -r '.Tags // empty')
    name=$(get_name_tag "$tags")
    
    # Add to VPC CSV
    echo "$vpc_id,$cidr,\"$name\",$state,$is_default" >> $VPC_CSV
    
    echo "Processing VPC: $vpc_id ($name)..."
    
    # Get subnets for this VPC
    echo "  Getting subnets..."
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --output json | \
    jq -c '.Subnets[]' | while read subnet; do
        subnet_id=$(echo $subnet | jq -r '.SubnetId')
        subnet_cidr=$(echo $subnet | jq -r '.CidrBlock')
        az=$(echo $subnet | jq -r '.AvailabilityZone')
        subnet_state=$(echo $subnet | jq -r '.State')
        
        # Get subnet name
        subnet_tags=$(echo $subnet | jq -r '.Tags // empty')
        subnet_name=$(get_name_tag "$subnet_tags")
        
        echo "$vpc_id,$subnet_id,$subnet_cidr,$az,$subnet_state,\"$subnet_name\"" >> $SUBNET_CSV
    done
    
    # Get Internet Gateways for this VPC
    echo "  Getting internet gateways..."
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --output json | \
    jq -c '.InternetGateways[]' | while read igw; do
        igw_id=$(echo $igw | jq -r '.InternetGatewayId')
        
        # Get IGW name
        igw_tags=$(echo $igw | jq -r '.Tags // empty')
        igw_name=$(get_name_tag "$igw_tags")
        
        echo "$igw_id,$vpc_id,\"$igw_name\"" >> $IGW_CSV
    done
    
    # Get NAT Gateways for this VPC
    echo "  Getting NAT gateways..."
    aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --output json | \
    jq -c '.NatGateways[]' | while read natgw; do
        natgw_id=$(echo $natgw | jq -r '.NatGatewayId')
        natgw_subnet=$(echo $natgw | jq -r '.SubnetId')
        natgw_state=$(echo $natgw | jq -r '.State')
        public_ip=$(echo $natgw | jq -r '.NatGatewayAddresses[0].PublicIp // "N/A"')
        private_ip=$(echo $natgw | jq -r '.NatGatewayAddresses[0].PrivateIp // "N/A"')
        
        # Get NAT GW name
        natgw_tags=$(echo $natgw | jq -r '.Tags // empty')
        natgw_name=$(get_name_tag "$natgw_tags")
        
        echo "$natgw_id,$vpc_id,$natgw_subnet,$natgw_state,$public_ip,$private_ip,\"$natgw_name\"" >> $NATGW_CSV
    done
    
    # Get Network ACLs for this VPC
    echo "  Getting network ACLs..."
    aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$vpc_id" --output json | \
    jq -c '.NetworkAcls[]' | while read nacl; do
        nacl_id=$(echo $nacl | jq -r '.NetworkAclId')
        is_default=$(echo $nacl | jq -r '.IsDefault')
        
        # Get NACL name
        nacl_tags=$(echo $nacl | jq -r '.Tags // empty')
        nacl_name=$(get_name_tag "$nacl_tags")
        
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
    
    # Get Route Tables for this VPC
    echo "  Getting route tables..."
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --output json | \
    jq -c '.RouteTables[]' | while read rt; do
        rt_id=$(echo $rt | jq -r '.RouteTableId')
        
        # Check if main route table
        main=$(echo $rt | jq -r '.Associations[] | select(.Main==true) | .Main' 2>/dev/null || echo "false")
        
        # Get RT name
        rt_tags=$(echo $rt | jq -r '.Tags // empty')
        rt_name=$(get_name_tag "$rt_tags")
        
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
    
    echo "Completed processing for VPC: $vpc_id"
done

echo ""
echo "VPC details have been exported to CSV files in the $OUTPUT_DIR directory:"
ls -la $OUTPUT_DIR/*.csv

echo "All done!"