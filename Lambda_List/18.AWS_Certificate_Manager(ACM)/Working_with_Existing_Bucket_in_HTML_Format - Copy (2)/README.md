# ACM Certificate Monitoring Solution

This solution automatically monitors AWS Certificate Manager (ACM) certificates, generates weekly HTML reports, stores them in an S3 bucket with timestamps, and sends an email notification with the report attached.

## Components

1. **CloudFormation Template (`acm-certificate-monitor-cfn.yaml`)**: 
   - Creates the infrastructure (Lambda function, IAM role, SNS topic, EventBridge rule)
   - Uses your existing S3 bucket

2. **Lambda Function (`lambda_function.py`)**:
   - Retrieves AWS account ID and name information
   - Queries ACM for certificate information
   - Generates HTML report with account information
   - The HTML report features color-coding:
     - 🟢 Green: Valid certificates
     - 🟡 Yellow: Certificates expiring within 30 days
     - 🔴 Red: Expired certificates
   - Uploads report to S3 with timestamp in filename
   - Sends email notification with HTML report attached (uses SES with SNS fallback)

## Deployment Instructions

1. Deploy the CloudFormation template:
   ```
   aws cloudformation deploy \
     --template-file acm-certificate-monitor-cfn.yaml \
     --stack-name acm-certificate-monitor \
     --capabilities CAPABILITY_IAM \
     --parameter-overrides EmailAddress=your.email@example.com ExistingBucketName=your-bucket-name
   ```

2. Confirm the SNS subscription by clicking the link in the email you receive.

3. The solution will automatically run every Monday at midnight, or you can trigger the Lambda function manually for testing.

## Features

- Lists all ACM certificates in your account
- Displays AWS account ID and account name
- Reports certificate details including expiration dates
- Calculates days remaining until expiration
- Creates HTML report with:
  - Account information
  - Color-coded expiration status
  - Summary statistics 
  - Attractive, easy-to-read table layout
- Creates timestamped report file
- Sends email notification with HTML report attached
- Runs weekly (every Monday at midnight)
- Uses your existing S3 bucket

## Customization

- To change the schedule, modify the `ScheduleExpression` in the CloudFormation template
- To adjust the "expiring soon" threshold (currently 30 days), modify the Lambda function
- For email configuration, the solution attempts to use Amazon SES for sending emails with attachments
- If SES is not available in your region or fails, it falls back to SNS notification

## Prerequisites

- An existing S3 bucket
- SES configuration may be required for sending emails with attachments
- Appropriate IAM permissions to create CloudFormation stacks with IAM resources