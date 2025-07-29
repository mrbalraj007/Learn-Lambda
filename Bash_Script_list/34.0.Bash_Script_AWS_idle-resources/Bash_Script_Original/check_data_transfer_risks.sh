########################################################################
#  ___         _           _____                       __           
# |   \  __ _ | |_  __ _  |_   _|_ _  __ _  _ _   ___ / _| ___  _ _ 
# | |) |/ _` ||  _|/ _` |   | | | '_|/ _` || ' \ (_-<|  _|/ -_)| '_|
# |___/ \__,_| \__|\__,_|   |_| |_|  \__,_||_||_|/__/|_|  \___||_|  
#                                                                   
# To learn more, see https://maxat-akbanov.com/
########################################################################

#!/bin/bash

source ./utils.sh

REGION=$(aws configure get region)

log_info "Auditing data transfer risks in $REGION"
echo "--------------------------------------------------"

# ✅ 1. Detect EC2 instances with public IPs
log_info "🔍 EC2 Instances with Public IPs:"
# Retrieve details of running EC2 instances
# The 'aws ec2 describe-instances' command queries instance information
# --filters limits to instances in the "running" state
# --query extracts InstanceId and PublicIpAddress for each instance
instances=$(aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,PublicIP:PublicIpAddress}' \
  --output json)

# Parse the instances JSON using jq to identify instances with non-null PublicIP
# For each instance with a public IP, print a warning with the instance ID and public IP
echo "$instances" | jq -r '.[][] | select(.PublicIP != null) | "⚠️  Instance: \(.ID) has Public IP: \(.PublicIP)"'

# ✅ 2. Detect allocated Elastic IPs (EIPs)
log_info "🔍 Elastic IP Addresses (EIPs):"
# Retrieve details of allocated Elastic IPs
eips=$(aws ec2 describe-addresses --query 'Addresses[*].{PublicIP:PublicIp,InstanceId:InstanceId}' --output json)

# Check if no Elastic IPs were found (eips is empty or an empty array "[]")
if [ -z "$eips" ] || [ "$eips" == "[]" ]; then
  log_success "✅ No Elastic IPs allocated."
else
  # Parse the EIPs JSON using jq
  # For each EIP:
  # - If InstanceId is null, print a warning indicating an unused EIP
  # - If InstanceId is present, print a success message indicating the EIP is attached to an instance
  echo "$eips" | jq -r '.[] | 
    if .InstanceId == null then
      "⚠️  Unused Elastic IP: \(.PublicIP)"
    else
      "✅ Elastic IP \(.PublicIP) attached to instance: \(.InstanceId)"
    end'
fi

# ✅ 3. Detect subnets spread across Availability Zones (AZs)
log_info "🔍 Subnet-AZ Mapping (check same-AZ design):"
# Retrieve details of subnets
# The 'aws ec2 describe-subnets' command queries subnet information
# --query extracts SubnetId, AvailabilityZone, and the Name tag (if present)
# The output is piped to jq to format each subnet's details
# - Name is used if available; otherwise, SubnetId is used
# - Prints the subnet name (or ID) and its Availability Zone
aws ec2 describe-subnets \
  --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output json | jq -r '.[] | "  ↳ Subnet: \(.Name // .ID), AZ: \(.AZ)"'

# ✅ 4. Detect S3 and DynamoDB VPC Endpoints
log_info "🔍 VPC Endpoints (S3 & DynamoDB):"
# Retrieve S3 VPC endpoint details
# The 'aws ec2 describe-vpc-endpoints' command queries VPC endpoint information
# --query filters for endpoints with a ServiceName containing 's3'
s3_vpce=$(aws ec2 describe-vpc-endpoints \
  --query "VpcEndpoints[?contains(ServiceName, 's3')].ServiceName" \
  --output text)

# Retrieve DynamoDB VPC endpoint details
ddb_vpce=$(aws ec2 describe-vpc-endpoints \
  --query "VpcEndpoints[?contains(ServiceName, 'dynamodb')].ServiceName" \
  --output text)

# Check if an S3 VPC endpoint was found
if [ -z "$s3_vpce" ]; then
  log_warn "No VPC endpoint for S3 detected"
else
  log_success "S3 VPC endpoint present: $s3_vpce"
fi

# Check if a DynamoDB VPC endpoint was found
if [ -z "$ddb_vpce" ]; then
  log_warn "No VPC endpoint for DynamoDB detected"
else
  log_success "DynamoDB VPC endpoint present: $ddb_vpce"
fi

log_success "Data transfer risk audit completed."