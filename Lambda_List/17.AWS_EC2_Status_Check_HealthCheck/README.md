# AWS EC2 Health Check Solution

This solution provides automated monitoring for EC2 instance health across all AWS regions and sends notifications when instances have health check issues.

## Components

- **CloudFormation Template**: Sets up all required infrastructure including Lambda, IAM roles, and SNS topic
- **Lambda Function**: Checks EC2 instance status and sends notifications for unhealthy instances
- **Bash Script**: For manual execution of EC2 health checks (reference implementation)

## Health Check Status Types

The solution monitors three distinct health aspects of each EC2 instance:

1. **System Status** - Hardware/AWS infrastructure layer health
2. **Instance Status** - Software/OS layer health
3. **Instance State** - Running status of the instance

Health check ratio is reported as X/3, where X is the number of checks passing.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Ability to deploy CloudFormation templates
- Valid email address for notifications

## Deployment Instructions

### Option 1: CloudFormation Deployment (Automated)

1. **Prepare the CloudFormation Template**
   - Ensure `ec2_health_check_cloudformation.yaml` is available

2. **Deploy the CloudFormation Stack**
   ```bash
   aws cloudformation create-stack \
     --stack-name EC2StatusCheck \
     --template-body file://ec2_health_check_cloudformation.yaml \
     --parameters \
       ParameterKey=EmailAddress,ParameterValue=your-email@example.com \
       ParameterKey=ScheduleExpression,ParameterValue="rate(1 hour)" \
       ParameterKey=RegionsToCheck,ParameterValue="" \
     --capabilities CAPABILITY_IAM
   ```

3. **Confirm Email Subscription**
   - You will receive an email from AWS SNS
   - Click the confirmation link to activate notifications

4. **Verify Deployment**
   ```bash
   aws cloudformation describe-stacks --stack-name EC2StatusCheck
   ```

### Option 2: Manual Lambda Deployment

1. **Create SNS Topic**
   ```bash
   aws sns create-topic --name EC2StatusCheckTopic
   ```

2. **Subscribe to SNS Topic**
   ```bash
   aws sns subscribe \
     --topic-arn <SNS-TOPIC-ARN> \
     --protocol email \
     --notification-endpoint your-email@example.com
   ```

3. **Create IAM Role**
   - Create a role with permissions for EC2 describe actions and SNS publish

4. **Create Lambda Function**
   - Create function using `lambda_function.py`
   - Set environment variables:
     - `SNS_TOPIC_ARN`: ARN of the created SNS topic
     - `REGIONS`: Comma-separated list of regions to check (leave empty for all)

5. **Set CloudWatch Schedule**
   ```bash
   aws events put-rule \
     --name EC2StatusCheckSchedule \
     --schedule-expression "rate(1 hour)"
   ```

6. **Connect Schedule to Lambda**
   ```bash
   aws events put-targets \
     --rule EC2StatusCheckSchedule \
     --targets '{"Id": "1", "Arn": "<LAMBDA-FUNCTION-ARN>"}'
   ```

### Option 3: Using the Bash Script (Manual Check)

1. **Make Script Executable**
   ```bash
   chmod +x ec2_status_check.sh
   ```

2. **Run the Script**
   ```bash
   ./ec2_status_check.sh          # Check all regions
   ./ec2_status_check.sh us-east-1 # Check specific region
   ```

## Understanding the Health Check Ratio

The health check ratio appears as X/3 where:

- **3/3**: Instance is completely healthy
- **2/3**: One check is failing
- **1/3**: Two checks are failing
- **0/3**: All checks are failing

Example notifications will include:
```
EC2 Instance Status Alert - 1 instance(s) with issues detected

Instance ID: i-0123456789abcdef0
Name: WebServer01
Type: t2.micro
State: running
System Status: ok
Instance Status: impaired
Health Check Ratio: 2/3
```

## Troubleshooting

- **No Notifications**: Verify SNS subscription is confirmed
- **Lambda Errors**: Check CloudWatch Logs for the Lambda function
- **Missing Instances**: Ensure IAM permissions are sufficient
- **High Execution Time**: Consider limiting regions being checked

## References

- [AWS EC2 Status Checks Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-system-instance-status-check.html)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)
