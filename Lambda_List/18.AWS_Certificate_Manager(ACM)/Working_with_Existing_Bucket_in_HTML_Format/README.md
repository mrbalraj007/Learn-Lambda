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
- **Email delivery options:**
  - Primary: Amazon SES with HTML report attachment (requires email verification)
  - Fallback: SNS notification with S3 link (if SES fails or isn't configured)

## Customization

- To change the schedule, modify the `ScheduleExpression` in the CloudFormation template
- To adjust the "expiring soon" threshold (currently 30 days), modify the Lambda function
- For email configuration, the solution attempts to use Amazon SES for sending emails with attachments
- If SES is not available in your region or fails, it falls back to SNS notification

## Prerequisites

- An existing S3 bucket
- **Amazon SES configuration for email attachments:**
  - Verify your email address in Amazon SES console
  - If using SES Sandbox mode, verify both sender and recipient emails
  - For production use, consider requesting to move out of SES Sandbox
- Appropriate IAM permissions to create CloudFormation stacks with IAM resources

## SES Setup Instructions

To enable email with HTML attachments:

1. **Verify Email Address in SES:**
   ```bash
   aws ses verify-email-identity --email-address your.email@example.com
   ```

2. **Check verification status:**
   ```bash
   aws ses get-identity-verification-attributes --identities your.email@example.com
   ```

3. **If you're in SES Sandbox mode (default):**
   - You can only send emails to verified email addresses
   - Both sender and recipient must be verified
   - To send to any email address, request production access in SES console

4. **Alternative: Use SNS only (no attachments):**
   - If you prefer to avoid SES setup, the solution will fall back to SNS
   - SNS sends notifications without the HTML attachment
   - The report is still saved to S3 and can be accessed there

## Troubleshooting

### SES Email Issues

1. **"User not authorized to perform ses:SendRawEmail":**
   - Ensure your email is verified in SES
   - Check that you're using the correct AWS region for SES

2. **"Email address not verified":**
   ```bash
   aws ses verify-email-identity --email-address your.email@example.com
   ```

3. **"MessageRejected: Email address not verified":**
   - In SES Sandbox mode, both sender and recipient must be verified
   - Consider requesting production access for unrestricted sending