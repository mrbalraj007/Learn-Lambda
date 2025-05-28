#!/bin/bash

STACK_NAME="EC2IAMRoleFinder"
BUCKET_NAME="ec2-iam-roles-finder-output-$(date +%s)"

echo "Deploying CloudFormation stack: $STACK_NAME"
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://template.yaml \
  --parameters ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME \
  --capabilities CAPABILITY_IAM

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

echo "Stack deployed successfully!"
echo "Output bucket: $BUCKET_NAME"

# Display outputs
aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs"
