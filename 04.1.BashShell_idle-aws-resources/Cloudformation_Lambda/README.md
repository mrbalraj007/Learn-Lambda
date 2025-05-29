# AWS Resource Audit Automation

This project automates the detection of idle, unoptimized, or potentially cost-inefficient AWS resources across your account. It uses AWS CloudFormation to deploy a Lambda function that generates detailed HTML reports and stores them in an S3 bucket.

## Features

- **Comprehensive resource scanning**: Analyzes EC2 instances, EBS volumes, S3 buckets, RDS instances, Lambda functions, Load Balancers, EKS clusters, and more
- **Scheduled execution**: Automatically runs weekly or at your preferred schedule
- **HTML reports**: Generates detailed, styled HTML reports for easy analysis
- **Email notifications**: Sends notifications when new reports are available
- **Cost optimization focused**: Identifies opportunities to reduce AWS costs

## Prerequisites

1. An AWS account with appropriate permissions
2. An existing S3 bucket where reports will be stored
3. AWS CLI installed and configured (for deployment)
4. Basic knowledge of CloudFormation

## Deployment Instructions

### Option 1: AWS Management Console

1. Sign in to the AWS Management Console
2. Navigate to CloudFormation
3. Click "Create stack" > "With new resources (standard)"
4. Choose "Upload a template file" and upload the `aws-resource-audit-template.yaml` file
5. Click "Next"
6. Enter a stack name (e.g., "aws-resource-audit")
7. Configure the parameters:
   - **S3BucketName**: Name of your existing S3 bucket where reports will be stored
   - **ReportsPrefix**: Directory within the bucket to store reports (default: "reports")
   - **EmailAddress**: Email address to receive notifications when reports are ready
   - **TargetRegion**: AWS region to scan (leave empty to use the Lambda's region)
   - **ScheduleExpression**: How often to run the audit (default: "rate(7 days)")
8. Click "Next" twice, acknowledge the IAM resource creation, and click "Create stack"
9. Wait for the stack creation to complete

### Option 2: AWS CLI

1. Open a terminal or command prompt
2. Navigate to the directory containing the CloudFormation template
3. Run the following command:

```bash
aws cloudformation create-stack \
  --stack-name aws-resource-audit \
  --template-body file://aws-resource-audit-template.yaml \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=YOUR_BUCKET_NAME \
    ParameterKey=ReportsPrefix,ParameterValue=reports \
    ParameterKey=EmailAddress,ParameterValue=your.email@example.com \
    ParameterKey=TargetRegion,ParameterValue=us-east-1 \
    ParameterKey=ScheduleExpression,ParameterValue="rate(7 days)" \
  --capabilities CAPABILITY_IAM
```

Replace `YOUR_BUCKET_NAME` and `your.email@example.com` with your actual values.

## Verifying the Setup

1. **Confirm SNS subscription**: You will receive an email asking to confirm your subscription to the SNS topic. Click the "Confirm subscription" link in that email.

2. **Run a test execution**:
   - Go to the AWS Lambda console
   - Find the function named like `aws-resource-audit-ResourceAuditFunction-XXXX`
   - Click "Test" and use the default test event
   - After execution, check the specified S3 bucket for the HTML report

3. **Check CloudWatch Logs**: If you encounter issues, check the CloudWatch Logs for the Lambda function to troubleshoot.

## Working with Audit Reports

1. **Accessing Reports**:
   - Log in to the AWS Management Console
   - Navigate to S3 and browse to your bucket and the reports directory
   - Download the HTML report files to view them in your browser
   - Alternatively, follow the link in the email notification

2. **Interpreting Results**:
   - Green checkmarks (✅) indicate optimal configurations
   - Warning symbols (⚠️) highlight potential issues or cost optimization opportunities
   - Each section provides specific recommendations for improvements

3. **Taking Action**:
   - Review idle resources and consider stopping or terminating them
   - Implement lifecycle policies for S3 buckets
   - Clean up unattached EBS volumes
   - Convert On-Demand instances to Reserved Instances or Savings Plans
   - Remove unnecessary security group rules

## Customization

To customize the Lambda function:

1. Make your changes to the code in the CloudFormation template
2. Update the stack with the modified template:

```bash
aws cloudformation update-stack \
  --stack-name aws-resource-audit \
  --template-body file://aws-resource-audit-template.yaml \
  --capabilities CAPABILITY_IAM
```

## Troubleshooting

1. **Reports not generating**:
   - Check the Lambda function's CloudWatch Logs
   - Verify S3 bucket permissions
   - Ensure the Lambda execution role has sufficient permissions

2. **Email notifications not received**:
   - Verify you confirmed the SNS subscription
   - Check your spam folder
   - Ensure the Lambda function executed successfully

3. **Lambda timeout errors**:
   - Increase the Lambda timeout value in the template
   - Consider splitting the audit into multiple functions if scanning many regions

## Cleanup

To remove all resources created by this stack:

```bash
aws cloudformation delete-stack --stack-name aws-resource-audit
```

Note: This will delete the Lambda function, IAM role, SNS topic, and EventBridge rule, but will NOT delete your S3 bucket or any reports already generated.

## Security Considerations

- The Lambda function requires extensive read permissions to audit your AWS resources
- No destructive actions are performed; the function only reads resource configurations
- Reports stored in S3 may contain sensitive information about your infrastructure

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This project was inspired by a collection of shell scripts designed to identify idle AWS resources.
