#!/bin/bash

STACK_NAME="EC2IAMRoleFinder"

# Prompt for S3 bucket name
read -p "Enter existing S3 bucket name: " BUCKET_NAME

# Prompt for AWS region
read -p "Enter AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Deploying CloudFormation stack: $STACK_NAME"
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://template.yaml \
  --parameters ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME \
               ParameterKey=AwsRegion,ParameterValue=$AWS_REGION \
  --capabilities CAPABILITY_IAM

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

echo "Stack deployed successfully!"
echo "Output bucket: $BUCKET_NAME"
echo "AWS Region: $AWS_REGION"

# Display outputs
aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs"
