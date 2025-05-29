#!/bin/bash
set -e

echo "==============================================="
echo "AWS Resource Audit - Lambda Deployment Tool"
echo "==============================================="

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Get function name (from parameter or use default)
FUNCTION_NAME=${1:-aws-resource-audit}
echo "Working with Lambda function: $FUNCTION_NAME"

# Create deployment directory
DEPLOY_DIR="lambda_deploy"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy the Lambda code
echo "Copying Lambda function code..."
cp lambda_function.py "$DEPLOY_DIR/"

# Add empty __init__.py file to make the directory a proper Python package
touch "$DEPLOY_DIR/__init__.py"

# Verify the file exists
if [ ! -f "$DEPLOY_DIR/lambda_function.py" ]; then
    echo "Error: lambda_function.py was not correctly copied!"
    exit 1
fi

# Create ZIP file
cd "$DEPLOY_DIR"
echo "Creating deployment package..."
zip -r ../lambda_deployment.zip .
cd ..

# Verify ZIP file was created
if [ ! -f "lambda_deployment.zip" ]; then
    echo "Error: Failed to create deployment ZIP!"
    exit 1
fi

# Deploy to Lambda
echo "Updating Lambda function code..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda_deployment.zip \
    --no-cli-pager

# Verify the handler setting
echo "Updating Lambda function configuration to ensure correct handler..."
aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --handler "lambda_function.lambda_handler" \
    --no-cli-pager

echo "Deployment completed successfully!"
echo "You can now test your Lambda function."
