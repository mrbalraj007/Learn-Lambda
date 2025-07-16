#!/bin/bash

# This script sets up the budget action automatically using AWS CLI
# No manual intervention required

# Set default email address
EMAIL_ADDRESS="youremailID@gmail.com"
echo "Using default email address: $EMAIL_ADDRESS"

# Step 1: Get your AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Your AWS Account ID: $ACCOUNT_ID"

# Step 2: Get the CloudFormation outputs
echo "Getting CloudFormation stack outputs..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name BudgetRestriction --query "Stacks[0].Outputs" --output json)

# Check if stack exists
if [ $? -ne 0 ]; then
    echo "Error: Could not find CloudFormation stack 'BudgetRestriction'"
    exit 1
fi

# Step 3: Extract values from outputs
POLICY_ARN=$(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="RestrictedPolicyArn") | .OutputValue')
EXECUTION_ROLE_ARN=$(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="BudgetActionRoleArn") | .OutputValue')
BUDGET_NAME=$(echo $STACK_OUTPUTS | jq -r '.[] | select(.OutputKey=="BudgetName") | .OutputValue')

# Validate extracted values
if [ "$POLICY_ARN" == "null" ] || [ "$EXECUTION_ROLE_ARN" == "null" ] || [ "$BUDGET_NAME" == "null" ]; then
    echo "Error: Could not extract required values from CloudFormation outputs"
    exit 1
fi

# Display extracted values
echo "Policy ARN: $POLICY_ARN"
echo "Execution Role ARN: $EXECUTION_ROLE_ARN"
echo "Budget Name: $BUDGET_NAME"

# Step 4: Set target role name
TARGET_ROLE_NAME="EC2UserRestrictedRole"

# Step 5: Create the budget action
echo "Creating budget action..."
aws budgets create-budget-action \
  --account-id $ACCOUNT_ID \
  --budget-name $BUDGET_NAME \
  --notification-type ACTUAL \
  --action-type APPLY_IAM_POLICY \
  --action-threshold ActionThresholdValue=100,ActionThresholdType=PERCENTAGE \
  --definition "IamActionDefinition={PolicyArn=$POLICY_ARN,Roles=[$TARGET_ROLE_NAME]}" \
  --execution-role-arn $EXECUTION_ROLE_ARN \
  --approval-model AUTOMATIC \
  --subscribers "SubscriptionType=EMAIL,Address=$EMAIL_ADDRESS" \
  --region us-east-1

if [ $? -eq 0 ]; then
    echo "Budget action created successfully. Verify in AWS console."
else
    echo "Error: Failed to create budget action"
    exit 1
fi

# Step 6: Verification steps
echo ""
echo "Verification Steps:"
echo "1. Navigate to AWS Budgets console"
echo "2. Select your budget '$BUDGET_NAME'"
echo "3. Check the 'Actions' tab to confirm the action was created"
echo "4. Verify the IAM role '$TARGET_ROLE_NAME' in the IAM console"
echo ""
echo "Verification Steps:"
echo "1. Navigate to AWS Budgets console"
echo "2. Select your budget '$BUDGET_NAME'"
echo "3. Check the 'Actions' tab to confirm the action was created"
echo "4. Verify the IAM role '$TARGET_ROLE_NAME' in the IAM console"
