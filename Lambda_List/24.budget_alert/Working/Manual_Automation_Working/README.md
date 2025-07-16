# AWS Budget Alert with EC2 Instance Restriction

This CloudFormation template implements a cost control mechanism that automatically restricts EC2 instance creation to only t3.micro instances when your AWS budget exceeds a defined threshold.

## Features

- Creates a monthly budget with a configurable limit
- Sends email notifications when the budget reaches 80% of the limit
- Automatically applies an IAM policy when the budget reaches 100% of the limit
- The applied policy restricts EC2 instance creation to only t3.micro instances
- Includes automated setup script for budget actions

## Parameters

- **BudgetLimit**: The monthly budget limit in USD (default: 100)
- **BudgetName**: The name of the budget (default: MonthlyBudget)
- **EmailAddress**: Email address to receive budget notifications
- **TargetIAMRole**: The IAM role to which the restrictive policy will be applied (default: EC2UserRestrictedRole)

## Files Included

- `target-iam-role.yaml`: Creates the IAM role that will be restricted
- `budget-restriction-template.yaml`: Creates the budget, policies, and budget action role
- `manual-budget-action-setup.sh`: Automated script to create the budget action

## Deployment Instructions

Follow these steps for a complete automated setup:

### Step 1: Deploy the IAM Role
First, deploy the target IAM role that will be restricted:
```bash
aws cloudformation create-stack \
  --stack-name EC2UserRole \
  --template-body file://target-iam-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 2: Deploy the Budget Infrastructure
Deploy the budget and related resources:
```bash
aws cloudformation create-stack \
  --stack-name BudgetRestriction \
  --template-body file://budget-restriction-template.yaml \
  --parameters ParameterKey=EmailAddress,ParameterValue=youremailID@gmail.com \
              ParameterKey=BudgetLimit,ParameterValue=100 \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 3: Run the Automated Setup Script
Execute the automated script to create the budget action:
```bash
chmod +x manual-budget-action-setup.sh
./manual-budget-action-setup.sh
```

The script will automatically:
- Extract your AWS Account ID
- Retrieve CloudFormation stack outputs
- Create the budget action with the correct ARNs
- Use the default email address (youremailID@gmail.com)
- Provide verification steps

## How it Works

1. **Budget Monitoring**: AWS Budgets monitors your AWS account spending
2. **Email Notifications**: When spending reaches 80% of the budget, you'll receive an email notification
3. **Automatic Restriction**: When spending reaches 100% of the budget, the budget action automatically applies a restrictive IAM policy to the `EC2UserRestrictedRole`
4. **Policy Enforcement**: The applied policy allows only t3.micro EC2 instances to be launched

## Verification Steps

After running the automated setup script, verify the deployment:

1. **AWS Budgets Console**:
   - Navigate to AWS Budgets console
   - Select your budget 'MonthlyBudget'
   - Check the 'Actions' tab to confirm the action was created
   - Verify the action threshold is set to 100%

2. **IAM Console**:
   - Navigate to IAM console
   - Find the role 'EC2UserRestrictedRole'
   - Verify the role exists and has the correct permissions

3. **CloudFormation Console**:
   - Check both stacks ('EC2UserRole' and 'BudgetRestriction') are in CREATE_COMPLETE status
   - Review the outputs from the BudgetRestriction stack

## Known Issues and Solutions

### Error: "Policy arn:aws:iam::aws:policy/AWSBudgetsActions-RolePolicyForResourceAdministrationWithSSM does not exist"

This error has been resolved in the current template by using inline policies instead of the managed policy that may not be available in all regions.

### Error: "Template format error: Unrecognized resource types: [AWS::Budgets::BudgetAction]"

This error occurs because the `AWS::Budgets::BudgetAction` resource type is not available in all AWS regions. The solution implemented uses:

1. CloudFormation templates to create the budget and necessary IAM resources
2. An automated script to create the budget action via AWS CLI
3. This approach works in all regions where AWS Budgets is available

## Troubleshooting

If the automated script fails:

1. **Check AWS CLI Configuration**: Ensure AWS CLI is configured with proper credentials
2. **Verify Region**: Make sure you're deploying in the correct region (us-east-1 recommended)
3. **Check Stack Status**: Ensure both CloudFormation stacks are in CREATE_COMPLETE status
4. **Verify jq Installation**: The script requires `jq` for JSON parsing

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS Budgets   │───▶│  Budget Action   │───▶│  IAM Policy     │
│   (Monitoring)  │    │  (Trigger)       │    │  (Restriction)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │ EC2UserRestricted│
                                               │     Role        │
                                               └─────────────────┘
```

When the budget exceeds 100%, the policy is attached to the IAM role, restricting EC2 instance creation to only t3.micro instances.
