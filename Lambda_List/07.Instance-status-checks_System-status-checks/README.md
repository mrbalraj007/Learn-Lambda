# EC2 Status Check Monitoring Solution

This solution monitors all EC2 instances for status check failures and sends email notifications when issues are detected.

## Components

1. **CloudWatch Events (EventBridge)** - Monitors for EC2 status check failures
2. **Lambda Function** - Processes events and formats notification messages
3. **SNS Topic** - Delivers email notifications

## How It Works

1. When an EC2 instance fails either an instance status check or a system status check, CloudWatch Events triggers the Lambda function
2. The Lambda function:
   - Gets details about the affected instance
   - Determines which type of check failed
   - Formats a detailed notification message
3. The SNS topic sends an email to the specified email address

## Deployment Instructions

1. Deploy the CloudFormation template:
   ```
   aws cloudformation create-stack \
     --stack-name ec2-status-monitor \
     --template-body file://ec2-status-monitor.yaml \
     --capabilities CAPABILITY_IAM \
     --parameters ParameterKey=EmailAddress,ParameterValue=your-email@example.com
   ```

2. Check your email and confirm the SNS subscription

3. The monitoring solution is now active and will send notifications whenever an EC2 instance fails a status check

## Testing

To test the solution, you can:
1. Stop an EC2 instance using the AWS console or CLI
2. Watch for email notifications related to status check failures

## Troubleshooting

If you're not receiving notifications:

1. Check CloudWatch Logs for the Lambda function to see any errors
2. Verify your email subscription is confirmed
3. Try manually publishing a test message to the SNS topic:
   ```
   aws sns publish \
     --topic-arn <your-sns-topic-arn> \
     --subject "Test EC2 Notification" \
     --message "This is a test message"
   ```
4. Ensure your EC2 instances are actually failing status checks
5. Review the Lambda function permissions to ensure it can access EC2 and SNS
