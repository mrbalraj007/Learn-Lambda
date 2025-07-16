# AWS Budget Alert with EC2 Instance Restriction

This CloudFormation template implements a cost control mechanism that automatically restricts EC2 instance creation to only t3.micro instances when your AWS budget exceeds a defined threshold.

## Features

- Creates a monthly budget with a configurable limit
- Sends email notifications when the budget reaches 80% of the limit
- Automatically applies an IAM policy when the budget reaches 100% of the limit
- The applied policy restricts EC2 instance creation to only t3.micro instances

## Parameters

- **BudgetLimit**: The monthly budget limit in USD (default: 100)
- **BudgetName**: The name of the budget (default: MonthlyBudget)
- **EmailAddress**: Email address to receive budget notifications
- **TargetIAMRole**: The IAM role to which the restrictive policy will be applied. This IAM role must exist before deploying this template. The CloudFormation template will not create this role automatically.

## Deployment Prerequisites

1. Create the IAM role that you want to restrict when the budget is exceeded
2. Note the exact name of this IAM role for the `TargetIAMRole` parameter

## Deployment Instructions

1. Navigate to AWS CloudFormation console
2. Click "Create stack" and choose "With new resources"
3. Upload the template file or specify its S3 URL
4. Fill in the required parameters
5. Review the stack details and create the stack

## Updated Deployment Instructions

For a complete setup, follow these steps:

1. First deploy the `target-iam-role.yaml` template to create the IAM role:
   ```
   aws cloudformation create-stack \
     --stack-name EC2UserRole \
     --template-body file://target-iam-role.yaml \
     --capabilities CAPABILITY_NAMED_IAM
   ```

2. Once the role is created, deploy the `budget-restriction-template.yaml` template:
   ```
   aws cloudformation create-stack \
     --stack-name BudgetRestriction \
     --template-body file://budget-restriction-template.yaml \
     --parameters ParameterKey=EmailAddress,ParameterValue=your.email@example.com \
                 ParameterKey=BudgetLimit,ParameterValue=100 \
     --capabilities CAPABILITY_NAMED_IAM
   ```

3. Verify the deployment:
   - Check the IAM role `EC2UserRestrictedRole` in the IAM console
   - Verify the budget created in the AWS Budgets console
   - Confirm that email notifications are being sent to your email address

## How it Works

1. AWS Budgets monitors your AWS account spending
2. When spending reaches 80% of the budget, you'll receive an email notification
3. When spending reaches 100% of the budget, the template automatically applies a restrictive IAM policy
4. The policy allows only t3.micro EC2 instances to be launched

## Known Issues

### Error: "Template format error: Unrecognized resource types: [AWS::Budgets::BudgetAction]"

This error occurs because the `AWS::Budgets::BudgetAction` resource type is not available in all AWS regions. If you encounter this error, you have the following options:

1. **Deploy to a supported region**: Try deploying to a major region like `us-east-1` (N. Virginia) or `us-west-2` (Oregon) which usually have earlier access to new resource types.

2. **Alternative approach**: Use an alternative implementation that separates the budget creation from the action:

   a. Deploy the CloudFormation template without the `BudgetAction` resource
   b. Set up the Budget Action manually through the AWS Console or AWS CLI
   c. Or use an AWS Lambda function triggered by a CloudWatch Event when the budget threshold is reached

### Alternative Implementation

If you need to deploy in a region that doesn't support `AWS::Budgets::BudgetAction`, you can use the following AWS CLI command after creating the budget:

```bash
aws budgets create-budget-action \
  --account-id YOUR_ACCOUNT_ID \
  --budget-name "MonthlyBudget" \
  --notification-type ACTUAL \
  --action-type APPLY_IAM_POLICY \
  --action-threshold ActionThresholdValue=100,ActionThresholdType=PERCENTAGE \
  --definition PolicyId=costManagementPolicy,PolicyArn=POLICY_ARN,Roles=ROLE_NAME \
  --execution-role-arn BUDGET_ACTION_ROLE_ARN \
  --approval-model AUTOMATIC \
  --region us-east-1
```

This implementation follows the AWS recommended pattern of using AWS Budgets to apply a Deny IAM policy for specific resources when budget thresholds are exceeded.
