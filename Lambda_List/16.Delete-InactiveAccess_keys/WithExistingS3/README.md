# AWS Inactive Access Keys Management Solution

This solution automatically detects and deletes inactive AWS IAM access keys, generating reports and sending email notifications. It helps maintain security best practices by removing unused access keys.

## Features

- Automatically identifies access keys that:
  - Are already in 'Inactive' status
  - Haven't been used for 14+ days
- Deletes identified inactive keys
- Generates CSV reports of deleted keys
- Sends email notifications for deleted keys
- Runs automatically every 14 days

## Architecture

![Architecture Diagram](https://mermaid.ink/img/pako:eNqNkstOwzAQRX9l5FWRSPNol91FQkIqAqnAiiA2kTOZtqZORPJAQPXfcZKWNAVBWcX2vezxvXPiQlWoqS7VnH0aMnswtHIXy7hWDpwVcQ0XBmg5wqNXS7DkkGHXLjR_oDKWSlROWXq7q3OTMODLksldKXX9DeM1rRDYAAMLB5Q1sH8NU6HnQstK2vI4s_MQA5STOBauWQP_MsR9jESa52VRFgVfA-upraBV2eFNB0SAGWoczYhgdtQMdOwQGOWaA90Ka6s9S5C-SectQpRO-3Blf0hqUMJReE_RbCQtHpK_4Trpe56xtkgyVfR6C32Q4RmTsmsE5B_IZeqtJCO8H6SurtE0j1W0i_pRKvopuG80sDNV2FChBY6mCoZKmOBSt4HXUHc2WNuA8jr2pI62yDulSy3pfahlNVGzIMhA2VcWWNsmM__jFdh-xxz_vrUN1KRgUKiWV14hKYWxYLDkisG3NziBOPqX-QUPGGQ4?type=png)

## Prerequisites

- AWS CLI installed and configured
- Existing S3 bucket for storing reports
- IAM permissions to create IAM roles, Lambda functions, and EventBridge rules

## Deployment

### Using AWS Management Console

1. Navigate to CloudFormation in the AWS Console
2. Choose "Create stack" > "With new resources (standard)"
3. Upload the `template.yaml` file
4. Provide required parameters:
   - `ReportBucketName`: Name of your existing S3 bucket
   - `NotificationEmail`: Email address for notifications
5. Follow the wizard to complete stack creation
6. Confirm the subscription email sent by SNS

### Using AWS CLI

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name inactive-access-keys-cleanup \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    ReportBucketName=your-bucket-name \
    NotificationEmail=your-email@example.com
```

## How It Works

1. **Scheduled Execution**: The Lambda function runs every 14 days via an EventBridge rule.

2. **Key Detection**: The function scans all IAM users for:
   - Keys with 'Inactive' status
   - Active keys not used in the last 14 days

3. **Key Deletion**: Identified keys are automatically deleted.

4. **Reporting**: The function generates:
   - A CSV file with details of deleted keys
   - Email notification via SNS containing a summary

5. **Storage**: Reports are stored in:
   - S3: `s3://{bucket-name}/inactive_keys/deleted_keys_{timestamp}.csv`

## CSV Report Format

The deleted keys report includes:

| Column | Description |
|--------|-------------|
| UserName | IAM user name |
| AccessKeyId | The deleted access key ID |
| Status | Status of the key when detected |
| CreateDate | When the key was created |
| LastUsed | When the key was last used |
| Region | AWS region where deletion occurred |
| DeletionTime | When the key was deleted |

## Troubleshooting

**Issue**: Lambda function fails with timezone error.
**Solution**: The solution has been fixed to handle timezone-aware datetime objects.

**Issue**: No email notification received.
**Solution**: Check spam folder and confirm the SNS subscription.

**Issue**: The function runs but doesn't delete keys.
**Solution**: Check IAM permissions; the Lambda role needs iam:DeleteAccessKey permission.

## Security Considerations

- The Lambda function has the minimum required permissions
- S3 reports should be secured with appropriate bucket policies
- Consider enabling S3 bucket versioning for report auditing

## Customization

- To change the inactivity threshold, modify the `inactive_threshold` variable in the Lambda code
- To change the execution frequency, update the EventBridge rule's `ScheduleExpression` value
