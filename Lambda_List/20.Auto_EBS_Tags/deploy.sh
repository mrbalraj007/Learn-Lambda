#!/bin/bash

# EBS Auto-Tagger CloudFormation Deployment Script

STACK_NAME="ebs-auto-tagger-stack"
TEMPLATE_FILE="ebs-auto-tagging-cfn.yaml"
REGION="us-east-1"  # Change to your preferred region

echo "Deploying EBS Auto-Tagger CloudFormation Stack..."

# Deploy the stack
aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --region $REGION \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    LambdaFunctionName="ebs-auto-tagger" \
    ScheduleExpression="rate(5 minutes)"

if [ $? -eq 0 ]; then
    echo "✅ Stack deployed successfully!"
    echo ""
    echo "📊 To view reports, check CloudWatch Logs:"
    echo "   Log Group: /aws/lambda/ebs-auto-tagger"
    echo ""
    echo "🔧 To test the function manually:"
    echo "   aws lambda invoke --function-name ebs-auto-tagger response.json"
    echo ""
    echo "📈 Stack outputs:"
    aws cloudformation describe-stacks \
      --stack-name $STACK_NAME \
      --region $REGION \
      --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
      --output table
else
    echo "❌ Stack deployment failed!"
    exit 1
fi
