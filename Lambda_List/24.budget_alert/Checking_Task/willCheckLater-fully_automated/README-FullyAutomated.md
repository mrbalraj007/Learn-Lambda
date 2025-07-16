# AWS Budget Alert with Fully Automated EC2 Instance Restriction

This solution provides a **fully automated** AWS budget restriction system that automatically limits EC2 instance creation to only t3.micro instances when your AWS budget exceeds the defined threshold. No manual intervention required after deployment.

## 🚀 Features

- **Complete Automation**: Single CloudFormation template deploys everything
- **Monthly Budget Monitoring**: Configurable budget limits with automatic tracking
- **Email Notifications**: Alerts at 80% and 100% budget thresholds
- **Automatic Policy Application**: Restricts EC2 instances to t3.micro when budget exceeds 100%
- **Lambda-based Budget Action**: Uses AWS Lambda to create budget actions automatically
- **Self-contained**: All resources created in one deployment

## 📋 What Gets Deployed

### Core Resources
- **IAM Role**: `EC2UserRestrictedRole` - Target role that gets restricted
- **Budget**: Monthly cost budget with configurable limits
- **IAM Policies**: Restrictive policy limiting EC2 to t3.micro instances
- **Budget Action Role**: Service role for budget actions
- **Lambda Function**: Automatically creates budget actions
- **Custom Resource**: Orchestrates the budget action creation

### Files in This Solution
- `fully-automated-budget-restriction.yaml` - Complete CloudFormation template
- `deploy-fully-automated.sh` - One-click deployment script
- `README-FullyAutomated.md` - This documentation

## ⚙️ Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `BudgetLimit` | 100 | Monthly budget limit in USD |
| `BudgetName` | MonthlyBudget | Name of the budget |
| `EmailAddress` | youremailID@gmail.com | Email for budget notifications |
| `TargetIAMRole` | EC2UserRestrictedRole | IAM role to be restricted |

## 🚀 Quick Start Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Bash shell environment

### One-Command Deployment
```bash
# Make the script executable
chmod +x deploy-fully-automated.sh

# Deploy everything
./deploy-fully-automated.sh
```

That's it! The script will:
1. Deploy the CloudFormation stack
2. Wait for completion
3. Display the outputs
4. Confirm successful deployment

### Manual Deployment (Alternative)
```bash
aws cloudformation create-stack \
  --stack-name FullyAutomatedBudgetRestriction \
  --template-body file://fully-automated-budget-restriction.yaml \
  --parameters ParameterKey=EmailAddress,ParameterValue=your.email@example.com \
              ParameterKey=BudgetLimit,ParameterValue=100 \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## 🔧 How It Works

### Architecture Flow
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS Budgets   │───▶│  Budget Action   │───▶│  IAM Policy     │
│   (Monitoring)  │    │  (Auto-created)  │    │  (t3.micro only)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                ▲                        │
                                │                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │ Lambda Function │    │EC2UserRestricted│
                       │ (Creates Action)│    │     Role        │
                       └─────────────────┘    └─────────────────┘
```

### Step-by-Step Process
1. **Budget Monitoring**: AWS Budgets continuously monitors account spending
2. **Email Notifications**: 
   - 80% threshold: Warning email sent
   - 100% threshold: Critical email sent + action triggered
3. **Automatic Policy Application**: Lambda function creates budget action that applies restrictive policy
4. **EC2 Restriction**: The `EC2UserRestrictedRole` can only launch t3.micro instances
5. **Cost Control**: Prevents expensive instance launches while maintaining basic functionality

## 📊 Monitoring and Verification

### Check Deployment Status
```bash
# Monitor stack creation
aws cloudformation describe-stack-events \
  --stack-name FullyAutomatedBudgetRestriction \
  --region us-east-1

# Check stack outputs
aws cloudformation describe-stacks \
  --stack-name FullyAutomatedBudgetRestriction \
  --query "Stacks[0].Outputs" \
  --output table
```

### Verify Components

#### 1. Budget Console
- Navigate to AWS Budgets console
- Find your budget (default: "MonthlyBudget")
- Check "Actions" tab for the auto-created action
- Verify threshold is set to 100%

#### 2. IAM Console
- Find role "EC2UserRestrictedRole"
- Verify it has EC2 permissions
- Check for attached restrictive policies (applied when budget exceeded)

#### 3. Lambda Console
- Find function "BudgetActionCreatorFunction"
- Check execution logs in CloudWatch
- Verify successful budget action creation

## 🔍 Troubleshooting

### Common Issues

#### Stack Creation Fails
```bash
# Check stack events for errors
aws cloudformation describe-stack-events \
  --stack-name FullyAutomatedBudgetRestriction \
  --region us-east-1 \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"
```

#### Lambda Function Issues
```bash
# Check Lambda logs
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/BudgetActionCreatorFunction"
```

#### Budget Action Not Created
1. Check Lambda function logs
2. Verify IAM permissions for Lambda execution role
3. Ensure budget exists before Lambda function runs

### Error Resolution

#### "CloudWatch Log Stream" Custom Resource Errors
If you see errors like "See the details in CloudWatch Log Stream", follow these steps:

1. **Check Lambda Logs Directly**:
```bash
# Get the exact error from Lambda logs
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/BudgetActionCreatorFunction" \
  --region us-east-1

# Get latest log stream
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/BudgetActionCreatorFunction" \
  --region us-east-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# View the actual error messages
aws logs get-log-events \
  --log-group-name "/aws/lambda/BudgetActionCreatorFunction" \
  --log-stream-name "STREAM_NAME_FROM_ABOVE" \
  --region us-east-1
```

2. **Common Issues and Solutions**:
   - **Budget not found**: Wait longer between budget creation and action creation
   - **IAM permissions**: Ensure Lambda execution role has budget permissions
   - **Budget action already exists**: Function now handles existing actions gracefully
   - **Resource timing**: Increased wait times in Lambda function

3. **Manual Verification**:
```bash
# Check if budget exists
aws budgets describe-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget-name MonthlyBudget

# Check existing budget actions
aws budgets describe-budget-actions \
  --account-id YOUR_ACCOUNT_ID \
  --budget-name MonthlyBudget
```

#### "AccessDenied" Errors
- Ensure your AWS credentials have sufficient permissions
- Required permissions: IAM, Budgets, Lambda, CloudFormation

#### "ResourceAlreadyExists" Errors
- Delete existing stack: `aws cloudformation delete-stack --stack-name FullyAutomatedBudgetRestriction`
- Wait for deletion to complete before redeploying

## 🧪 Testing the Solution

### Simulate Budget Threshold
```bash
# Create test EC2 instances to increase costs
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.micro \
  --count 1 \
  --region us-east-1
```

### Test Role Restriction
```bash
# Assume the restricted role (after policy is applied)
aws sts assume-role \
  --role-arn "arn:aws:iam::ACCOUNT_ID:role/EC2UserRestrictedRole" \
  --role-session-name "test-session"

# Try launching non-t3.micro instance (should fail)
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \
  --instance-type t3.small \
  --count 1
```

## 🛠️ Customization Options

### Modify Budget Threshold
Edit the Lambda function to change the action threshold:
```python
'ActionThreshold': {
    'ActionThresholdValue': 90,  # Change from 100 to 90%
    'ActionThresholdType': 'PERCENTAGE'
}
```

### Add More Instance Types
Modify the EC2RestrictPolicy to allow additional instance types:
```yaml
Condition:
  StringEquals:
    'ec2:InstanceType': 
      - 't3.micro'
      - 't3.small'  # Add more types
```

### Multiple Email Recipients
Update the Lambda function to support multiple subscribers:
```python
'Subscribers': [
    {'SubscriptionType': 'EMAIL', 'Address': 'admin@company.com'},
    {'SubscriptionType': 'EMAIL', 'Address': 'finance@company.com'}
]
```

## 📋 Stack Outputs

After successful deployment, you'll see:

| Output | Description |
|--------|-------------|
| `BudgetName` | Name of the created budget |
| `BudgetLimit` | Budget limit in USD |
| `RestrictedPolicyArn` | ARN of the EC2 restriction policy |
| `BudgetActionRoleArn` | ARN of the budget action execution role |
| `EC2UserRoleArn` | ARN of the target IAM role |
| `BudgetActionId` | ID of the automatically created budget action |
| `DeploymentStatus` | Confirmation of successful deployment |

## 🧹 Cleanup

To remove all resources:
```bash
aws cloudformation delete-stack \
  --stack-name FullyAutomatedBudgetRestriction \
  --region us-east-1
```

## 🎯 Benefits

- **Zero Manual Steps**: Complete automation after initial deployment
- **Cost Control**: Prevents expensive instance launches
- **Immediate Response**: Automatic restriction when budget exceeded
- **Flexible Configuration**: Easily adjustable parameters
- **Production Ready**: Includes proper error handling and logging

## 📞 Support

For issues or questions:
1. Check CloudFormation events for deployment errors
2. Review Lambda function logs for budget action creation issues
3. Verify IAM permissions for all roles
4. Ensure AWS Budgets service is available in your region

---

**Note**: This solution is designed for cost control and should be thoroughly tested in a non-production environment before deployment to production accounts.
