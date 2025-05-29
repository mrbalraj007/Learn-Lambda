# AWS Resource Audit Automation

This project automates the AWS resource audit process using Lambda, CloudFormation, S3, and SNS. The system runs weekly, generates an HTML report of potential AWS cost savings opportunities, stores the report in an S3 bucket, and sends an email notification with a link to the report.

## Architecture Overview

![Architecture Diagram](https://via.placeholder.com/800x400?text=AWS+Resource+Audit+Architecture)

Components:
- **AWS Lambda**: Runs the resource audit code
- **Amazon CloudWatch Events**: Schedules weekly execution
- **Amazon S3**: Stores the HTML reports
- **Amazon SNS**: Sends email notifications
- **IAM Role**: Provides necessary permissions

## Prerequisites

1. An existing S3 bucket where reports will be stored
2. AWS CLI configured with appropriate permissions
3. Email address to receive notifications

## Deployment Instructions

### Option 1: AWS Management Console

1. **Package the Lambda function**:
   ```bash
   zip -r aws_audit_lambda.zip lambda_function.py
   ```

2. **Deploy the CloudFormation Stack**:
   - Open the AWS Management Console
   - Navigate to CloudFormation
   - Click "Create stack" → "With new resources"
   - Upload the `cloudformation.yaml` file
   - Fill in the parameters:
     - S3BucketName: Your existing bucket name
     - S3BucketPrefix: Where to store reports (default: reports/)
     - EmailAddress: Where to send notifications
     - ScheduleExpression: How often to run (default: weekly)
     - AWSRegions: Comma-separated regions to audit

3. **Upload the Lambda code**:
   - Navigate to the Lambda console
   - Find the created function (named aws-resource-audit)
   - Upload the zip file in the Code Source section

4. **Confirm the SNS subscription**:
   - Check your email for an AWS Notification
   - Click the confirmation link to activate notifications

### Option 2: AWS CLI

1. **Package the Lambda function**:
   ```bash
   zip -r aws_audit_lambda.zip lambda_function.py
   ```

2. **Deploy the CloudFormation stack**:
   ```bash
   aws cloudformation create-stack \
     --stack-name aws-resource-audit-automation \
     --template-body file://cloudformation.yaml \
     --parameters \
         ParameterKey=S3BucketName,ParameterValue=your-bucket-name \
         ParameterKey=EmailAddress,ParameterValue=your-email@example.com \
     --capabilities CAPABILITY_IAM
   ```

3. **Upload the Lambda code**:
   ```bash
   aws lambda update-function-code \
     --function-name aws-resource-audit \
     --zip-file fileb://aws_audit_lambda.zip
   ```

## Customization

### Adding More Regions

To audit multiple regions, provide a comma-separated list in the `AWSRegions` parameter, such as:
```
us-east-1,eu-west-1,ap-southeast-2
```

### Changing the Schedule

The default schedule runs weekly. To change it, modify the `ScheduleExpression` parameter:
- Daily: `rate(1 day)`
- Monthly: `rate(30 days)`
- Cron expression: `cron(0 12 ? * MON *)`  # Runs every Monday at 12:00 UTC

## Troubleshooting

1. **Missing Reports**: Check the Lambda CloudWatch Logs for errors
2. **No Email Notifications**: Verify SNS subscription was confirmed
3. **Permission Errors**: Ensure the S3 bucket allows the Lambda IAM role to put objects

## Security Considerations

- The Lambda function runs with read-only permissions to your AWS environment
- Reports are stored in your S3 bucket and could contain sensitive information
- Consider enabling default encryption on your S3 bucket

## Cost Considerations

This solution uses:
- AWS Lambda: First 1 million requests per month are free
- Amazon S3: Storage costs for reports
- Amazon SNS: First 1,000 email deliveries per month are free
- CloudWatch Events: First 10 custom events per month are free
