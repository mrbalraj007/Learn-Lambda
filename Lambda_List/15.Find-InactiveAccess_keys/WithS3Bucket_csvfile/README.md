# Inactive IAM Access Keys Detector

A serverless solution that automatically detects inactive IAM access keys across your AWS account and sends notification reports.

## Solution Overview

This solution deploys an AWS Lambda function that periodically scans all IAM users in your account for inactive access keys. The function:

1. Identifies all IAM users in your account
2. Checks the status and last usage of their access keys 
3. Generates a detailed CSV report of inactive keys
4. Stores the report in an S3 bucket
5. Sends a notification email via SNS with a summary

![Architecture Diagram](https://via.placeholder.com/800x400?text=Architecture+Diagram)

## Prerequisites

- AWS CLI configured with appropriate permissions
- Permission to create IAM roles
- S3 bucket to store reports (can be created separately or as part of the stack)

## Deployment Instructions

### Using AWS CloudFormation Console

1. Navigate to the AWS CloudFormation console
2. Click "Create stack" > "With new resources"
3. Upload the template file `inactive-access-keys-lambda-with-sns.yaml`
4. Provide required parameters:
   - Stack name
   - NotificationEmail: Email address for receiving reports
   - ReportBucketName: Name of S3 bucket to store CSV reports
   - ScheduleExpression: Frequency of checks (default: every 7 days)
5. Create the stack and wait for deployment to complete

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name inactive-access-keys-detector \
  --template-body file://inactive-access-keys-lambda-with-sns.yaml \
  --parameters \
    ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
    ParameterKey=ReportBucketName,ParameterValue=your-report-bucket-name \
    ParameterKey=ScheduleExpression,ParameterValue="rate(7 days)" \
  --capabilities CAPABILITY_NAMED_IAM
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| ScheduleExpression | CloudWatch schedule expression | rate(7 days) |
| NotificationEmail | Email address to receive notifications | - |
| ReportBucketName | S3 bucket name where CSV reports will be stored | - |

## Resources Created

The CloudFormation template creates the following resources:

- **Lambda Function**: Scans IAM users and their access keys
- **IAM Role**: Grants necessary permissions to the Lambda function
- **CloudWatch Events Rule**: Triggers the Lambda function on schedule
- **SNS Topic**: Sends email notifications with report summaries

## How It Works

1. The Lambda function is triggered on a schedule (default: every 7 days)
2. It lists all IAM users and their access keys
3. For each key, it determines:
   - Current status (Active/Inactive)
   - Creation date
   - Last used date and service
   - Days since last use
4. Inactive keys are compiled into a CSV report
5. The report is uploaded to the specified S3 bucket
6. An SNS notification is sent to the specified email with a summary

## Output Information

After the stack is created, you can view these outputs:

- **LambdaFunctionName**: Name of the created Lambda function
- **LambdaFunctionArn**: ARN of the Lambda function
- **SNSTopicArn**: ARN of the SNS topic for notifications

## Security Considerations

- The Lambda function is granted least-privilege permissions
- Access to IAM information is read-only
- S3 write permissions are limited to the specific bucket
- SNS publish permissions are limited to the created topic

## Customization Options

- Modify the Lambda code to change inactive key identification criteria
- Adjust the schedule expression for more or less frequent checks
- Add additional notification channels by subscribing to the SNS topic
- Enhance the report format or add additional security checks

## Troubleshooting

- **No email received**: Confirm you've accepted the SNS subscription
- **No report generated**: Check Lambda function logs in CloudWatch Logs
- **Permission errors**: Verify the IAM role has correct permissions
