# ACM Certificate Monitoring Solution

This solution automatically monitors AWS Certificate Manager (ACM) certificates, generates a weekly CSV report, stores it in an S3 bucket with a timestamp in the filename, and sends an email notification.

## Components

1. **CloudFormation Template (`acm-certificate-monitor-cfn.yaml`)**: 
   - Creates the complete infrastructure (S3 bucket, Lambda function, IAM role, SNS topic, EventBridge rule)

2. **Lambda Function (`lambda_function.py`)**:
   - Queries ACM for certificate information
   - Generates a CSV report
   - Uploads to S3 with timestamp in filename
   - Sends notification via SNS


## Deployment Instructions

1. Deploy the CloudFormation template:
   ```
   aws cloudformation deploy \
     --template-file acm-certificate-monitor-cfn.yaml \
     --stack-name acm-certificate-monitor \
     --capabilities CAPABILITY_IAM \
     --parameter-overrides EmailAddress=your.email@example.com
   ```

2. Confirm the SNS subscription by clicking the link in the email you receive.

3. The solution will automatically run every Monday at midnight, or you can trigger the Lambda function manually for testing.

## Features

- Lists all ACM certificates in your account
- Reports certificate details including expiration dates
- Calculates days remaining until expiration
- Creates timestamped CSV reports
- Sends email notifications
- Automatically cleans up reports older than 90 days
- Runs weekly (every Monday at midnight)

## Customization

- To change the schedule, modify the `ScheduleExpression` in the CloudFormation template
- To adjust the report retention period, modify the `ExpirationInDays` in the S3 bucket lifecycle configuration




================

# AWS ACM Certificate Monitoring Solution

I'll create a solution to monitor AWS Certificate Manager (ACM) certificates, save the results to a CSV file in an S3 bucket with date/time format in the filename, and send weekly email notifications.

## Step-by-step solution:

1. Create a CloudFormation template that will set up:
   - S3 bucket for storing CSV reports
   - SNS topic for email notifications
   - IAM role with necessary permissions
   - Lambda function to check certificates
   - EventBridge rule for weekly scheduling

2. Create a Lambda function that will:
   - Query ACM for certificate information
   - Generate a CSV report
   - Save it to S3 with timestamp in filename
   - Send a notification email

