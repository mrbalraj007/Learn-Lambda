https://www.youtube.com/watch?v=Nni_8TUI_zA


I'll create a Lambda function and CloudWatch Event to monitor EC2 instance state changes and send email notifications. This will require setting up an SNS topic for email notifications.

I'll create a new CloudFormation template file in your project directory.
````

````

Made changes.



I'll fix the CloudFormation template by replacing the YAML shorthand notation with proper syntax:
```


Made changes.


```


Let me fix all the remaining CloudFormation syntax issues by correcting the entire file:
```


Made changes.


```


I've created a new CloudFormation template called ec2-state-monitor-cloudformation.yaml that addresses your requirement to monitor EC2 instance state changes and send email notifications. Here's what the template includes:

1. **SNS Topic and Email Subscription:**
   - Creates an SNS topic for sending EC2 state change notifications
   - Sets up an email subscription with the email address you provide when deploying

2. **Lambda Function:**
   - Monitors EC2 instance state changes
   - Gets detailed information about the instances
   - Formats a comprehensive notification message
   - Sends the notification to the SNS topic (which forwards to your email)

3. **IAM Role and Permissions:**
   - Grants necessary permissions to the Lambda function to read EC2 information
   - Allows Lambda to publish messages to the SNS topic

4. **CloudWatch Event Rule:**
   - Automatically triggers the Lambda function when any EC2 instance changes state
   - Ensures you receive real-time notifications for all state transitions

To deploy this template, you'll need to:
1. Open AWS CloudFormation console
2. Create a new stack using this template
3. Provide your email address as a parameter
4. Confirm the subscription email you'll receive

The Lambda function is designed to handle both automatic triggering from CloudWatch Events and manual invocation for testing.
