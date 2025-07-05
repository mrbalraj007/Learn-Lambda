# AWS Snapshot Tagging Automation

This solution automatically applies retention tags to EBS snapshots created by AWS Backup or manually created snapshots, ensuring consistent lifecycle management.

## Overview

Managing EBS snapshots at scale can be challenging, especially when they're created through different mechanisms (AWS Backup, manual creation, etc.). This solution ensures all snapshots have proper retention tags by monitoring snapshot creation events and automatically tagging them.

## Features

- Automatically tags snapshots with 90-day retention period
- Monitors multiple snapshot creation paths:
  - AWS Backup jobs
  - Direct EC2 EBS snapshot creation
  - CloudTrail API calls
- Includes daily cleanup to catch any missed snapshots
- Provides detailed logging and execution summaries

## Architecture

![Architecture Diagram](https://example.com/architecture-diagram.png)

The solution includes:

1. **Lambda Function**: Core logic that adds retention tags to snapshots
2. **EventBridge Rules**: Trigger the Lambda function on various events:
   - AWS Backup job completions
   - EBS snapshot state changes
   - CloudTrail API calls for snapshot creation
   - Scheduled daily execution
3. **IAM Roles & Permissions**: Securely grant the Lambda function appropriate access

## Deployment

### Prerequisites

- AWS CLI installed and configured
- Appropriate permissions to deploy CloudFormation templates
- Knowledge of AWS Backup and EC2 snapshot operations

### Deployment Steps

1. Clone this repository:

   ```bash
   git clone <repository-url>
   cd snapshot-automation
   ```

2. Deploy the CloudFormation template:

   ```bash
   aws cloudformation deploy \
     --template-file snapshot-automation.yaml \
     --stack-name snapshot-automation \
     --capabilities CAPABILITY_IAM
   ```

3. Verify the deployment:

   ```bash
   aws cloudformation describe-stacks --stack-name snapshot-automation
   ```

## Configuration

The default configuration:

- **Retention Period**: 90 days (applied as tags)
- **Tag Format**:
  - `Retention: 90days`
  - `DeleteOn: YYYY-MM-DD` (90 days from tagging date)
  - `AutoTaggedBy: AWSBackupSnapshotTagger`
  - `TaggedDate: YYYY-MM-DD`
- **Daily Cleanup**: Runs at 6 AM UTC

To customize these settings, modify the CloudFormation template and Lambda function code.

## How It Works

1. **Event Detection**: The solution monitors for snapshot creation events
2. **Event Processing**: Each event type is handled appropriately:
   - AWS Backup events: Extract snapshot IDs from job details
   - EBS snapshot notifications: Extract snapshot ID directly
   - CloudTrail API events: Find snapshots in API response data
3. **Tagging**: Apply retention tags with appropriate expiration date
4. **Verification**: Verify tags were applied correctly

## Troubleshooting

### Common Issues

1. **Missing Permissions**: Check IAM role permissions
2. **EventBridge Rules Not Triggering**: Verify rule patterns match events
3. **Snapshots Not Tagged**: Enable DEBUG logging and check CloudWatch Logs

### Checking Logs

View Lambda function logs:

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/AWSBackupSnapshotTagger \
  --filter-pattern "ERROR"
```

## Security

This solution uses the principle of least privilege. The IAM role has permissions limited to:

- Describing and tagging EC2 snapshots
- Describing AWS Backup jobs
- Reading CloudTrail events

## Contributing

Contributions are welcome! Please open issues or pull requests to improve this solution.

## License

[Include appropriate license here]
