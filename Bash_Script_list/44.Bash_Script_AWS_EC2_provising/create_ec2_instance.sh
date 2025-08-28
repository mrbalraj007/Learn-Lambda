#!/bin/bash

# Exit on error
set -e

# EC2 Instance Configuration
AMI_ID="ami-07095edb0ebd97663"
INSTANCE_TYPE="t3.micro"
KEY_PAIR="GEAWSINFRA-PREPROD-DR"
VPC_ID="vpc-00721af23f33f287f"
SUBNET_ID="subnet-0f2174313852ad890"
IAM_ROLE="TED-EC2-PreProd-Role"

# Security Groups
SECURITY_GROUPS="sg-0f3e7b63766fd7497,sg-05f664a46d4225b62,sg-09db9ddcae211dc9c,sg-033313b750b5f9aa4,sg-0e506c08b8abb2c1f,sg-079fe78b9f2c8444a,sg-0ef0ecec777a46e6a"

# Tags
TAG_SPECIFICATION="ResourceType=instance,Tags=[{Key=Schedule,Value=NA},{Key=Backup,Value=Daily},{Key=Project,Value=NA},{Key=Environment,Value=UAT},{Key=Platform,Value=Windows},{Key=Application Name,Value=TechServ},{Key=Name,Value=Testing},{Key=OS,Value=Windows Server 2019},{Key=Server Role,Value=APP}]"

echo "Starting EC2 instance creation..."
echo "Using AMI: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"

# Create the EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_PAIR" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids $(echo $SECURITY_GROUPS | tr ',' ' ') \
  --iam-instance-profile "Name=$IAM_ROLE" \
  --tag-specifications "$TAG_SPECIFICATION" \
  --query "Instances[0].InstanceId" \
  --output text)

if [ $? -eq 0 ]; then
  echo "EC2 instance created successfully!"
  echo "Instance ID: $INSTANCE_ID"
  
  # Wait for the instance to be in running state
  echo "Waiting for instance to enter 'running' state..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  
  # Get the public IP address of the instance (if available)
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)
  
  if [ "$PUBLIC_IP" != "None" ] && [ -n "$PUBLIC_IP" ]; then
    echo "Public IP: $PUBLIC_IP"
  else
    echo "No public IP assigned to this instance."
  fi
  
  # Get private IP
  PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PrivateIpAddress" \
    --output text)
  echo "Private IP: $PRIVATE_IP"
  
  echo "Instance is now running."
else
  echo "Failed to create EC2 instance."
  exit 1
fi
