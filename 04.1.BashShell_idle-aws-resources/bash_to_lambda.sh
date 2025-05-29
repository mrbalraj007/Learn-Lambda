#!/bin/bash
set -e

echo "AWS Resource Audit - Lambda Deployment Script"
echo "============================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if required files exist
if [ ! -f "lambda_function.py" ] || [ ! -f "cloudformation.yaml" ]; then
    echo "Error: Required files not found. Make sure you're in the correct directory."
    exit 1
fi

# Ask for parameters
read -p "S3 Bucket Name for reports: " S3_BUCKET_NAME
read -p "Email address for notifications: " EMAIL_ADDRESS
read -p "AWS Regions to audit (comma-separated, e.g., us-east-1,eu-west-1): " AWS_REGIONS
read -p "CloudFormation stack name [aws-resource-audit]: " STACK_NAME
STACK_NAME=${STACK_NAME:-aws-resource-audit}

# Package Lambda function
echo "Creating Lambda deployment package..."
zip -r aws_audit_lambda.zip lambda_function.py

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://cloudformation.yaml \
  --parameters \
      ParameterKey=S3BucketName,ParameterValue="$S3_BUCKET_NAME" \
      ParameterKey=EmailAddress,ParameterValue="$EMAIL_ADDRESS" \
      ParameterKey=AWSRegions,ParameterValue="$AWS_REGIONS" \
  --capabilities CAPABILITY_IAM

echo "Waiting for stack creation to complete (this may take a few minutes)..."
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"

# Get the Lambda function name
LAMBDA_FUNCTION=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionArn'].OutputValue" \
  --output text)

# Upload the Lambda code
echo "Uploading Lambda function code..."
aws lambda update-function-code \
  --function-name $(echo $LAMBDA_FUNCTION | cut -d':' -f7) \
  --zip-file fileb://aws_audit_lambda.zip

echo "Deployment complete!"
echo "IMPORTANT: Check your email and confirm the SNS subscription to receive audit reports."
echo "You can test the function by invoking it manually in the Lambda console."
