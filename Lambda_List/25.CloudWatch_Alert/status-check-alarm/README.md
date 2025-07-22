# CloudWatch StatusCheckFailed Alarm

This CloudFormation template creates a CloudWatch alarm that monitors the StatusCheckFailed metric for an EC2 instance and sends notifications to an SNS topic when the alarm is triggered.

## Overview

The alarm monitors EC2 instance status checks and triggers when:
- Status check fails (threshold ≥ 1)
- Evaluation period: 1 minute
- Missing data is treated as breaching

## Prerequisites

- An existing EC2 instance to monitor
- An SNS topic configured for notifications
- Appropriate IAM permissions to create CloudWatch alarms

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `EC2InstanceId` | String | The EC2 instance ID to monitor (e.g., i-1234567890abcdef0) |
| `AlarmNotificationTopicARN` | String | SNS topic ARN for alarm notifications |

## Deployment

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name ec2-status-check-alarm \
  --template-body file://status-check-alarm.yaml \
  --parameters ParameterKey=EC2InstanceId,ParameterValue=i-1234567890abcdef0 \
               ParameterKey=AlarmNotificationTopicARN,ParameterValue=arn:aws:sns:region:account:topic-name
```

### Using AWS Console

1. Navigate to CloudFormation in AWS Console
2. Click "Create Stack" → "With new resources"
3. Upload the `status-check-alarm.yaml` template
4. Provide the required parameters:
   - EC2 Instance ID
   - SNS Topic ARN
5. Review and create the stack

## Outputs

- `AlarmName`: The name of the created CloudWatch alarm

## Alarm Behavior

The alarm will trigger notifications for:
- **ALARM state**: When status check fails
- **OK state**: When status check passes
- **INSUFFICIENT_DATA state**: When there's not enough data

## Cleanup

To delete the alarm:

```bash
aws cloudformation delete-stack --stack-name ec2-status-check-alarm
```

## Notes

- The alarm uses a 1-minute period with 1 evaluation period for quick detection
- Missing data is treated as breaching to ensure failures are caught
- All alarm state changes (ALARM, OK,