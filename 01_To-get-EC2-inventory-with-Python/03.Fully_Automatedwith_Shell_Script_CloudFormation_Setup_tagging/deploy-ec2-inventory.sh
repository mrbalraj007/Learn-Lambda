#!/bin/bash

# Set variables
STACK_NAME="ec2-inventory-lambda-stack"
REGION="us-east-1"
CODE_BUCKET="lambda-code-deployment-bucket-$(aws sts get-caller-identity --query 'Account' --output text)"
ZIP_FILE="function.zip"
LAMBDA_FILE="lambda_function_payload.py"
#S3_KEY="ec2-inventory/$ZIP_FILE"
S3_KEY="lambda-code/$ZIP_FILE"
CFN_TEMPLATE="ec2-inventory-lambda.yaml"

# Check if the bucket exists, create if not
if ! aws s3api head-bucket --bucket "$CODE_BUCKET" 2>/dev/null; then
  echo "Creating S3 bucket: $CODE_BUCKET"
  aws s3 mb s3://$CODE_BUCKET --region $REGION
fi

# Package the Lambda function
echo "Zipping Lambda function..."
zip -j "$ZIP_FILE" "$LAMBDA_FILE"

# Upload to S3
echo "Uploading Lambda code to S3..."
aws s3 cp "$ZIP_FILE" "s3://$CODE_BUCKET/$S3_KEY"

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack: $STACK_NAME"
aws cloudformation deploy \
  --template-file "$CFN_TEMPLATE" \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    LambdaExecutionRoleName="EC2InventoryLambdaExecutionRole" \
  --region "$REGION"

# Cleanup
echo "Cleaning up local ZIP file..."
rm -f "$ZIP_FILE"

echo "✅ Deployment complete. Check CloudFormation and Lambda in region: $REGION"
echo "You can find the Lambda function in the AWS Management Console under Lambda."
echo "To test the function, you can invoke it manually or set up a CloudWatch Events rule to trigger it."
echo "To view the EC2 inventory, check the S3 bucket: s3://$CODE_BUCKET/"
echo "You can also check the CloudWatch logs for the Lambda function to see the output."
echo "To delete the stack and resources, run: aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION"
echo "To delete the S3 bucket and its contents, run: aws s3 rb s3://$CODE_BUCKET --force"
echo "To delete the Lambda function, run: aws lambda delete-function --function-name <function-name> --region $REGION"
echo "To delete the IAM role, run: aws iam delete-role --role-name EC2InventoryLambdaExecutionRole"
echo "To delete the IAM policy, run: aws iam delete-policy --policy-arn arn:aws:iam::<account-id>:policy/EC2InventoryLambdaPolicy"
echo "To delete the IAM role policy attachment, run: aws iam detach-role-policy --role-name EC2InventoryLambdaExecutionRole --policy-arn arn:aws:iam::<account-id>:policy/EC2InventoryLambdaPolicy"
echo "To delete the IAM role, run: aws iam delete-role --role-name EC2InventoryLambdaExecutionRole"
echo "To delete the IAM policy, run: aws iam delete-policy --policy-arn arn:aws:iam::<account-id>:policy/EC2InventoryLambdaPolicy"