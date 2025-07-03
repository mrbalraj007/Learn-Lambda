# EBS Auto-Tagger

Automatically tags EBS volumes with the same tags as their associated EC2 instances every 5 minutes.

## Features

- ✅ Automatically tags EBS volumes with EC2 instance tags
- ✅ Runs every 5 minutes via EventBridge
- ✅ Comprehensive reporting in CloudWatch Logs
- ✅ Handles errors gracefully
- ✅ Filters out AWS system tags
- ✅ Only updates tags when necessary

## Deployment

1. Make the deployment script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Deploy the stack:
   ```bash
   ./deploy.sh
   ```

## How It Works

1. **EventBridge Rule**: Triggers the Lambda function every 5 minutes
2. **Lambda Function**: 
   - Scans all EC2 instances (running and stopped)
   - Gets instance tags (excludes AWS system tags)
   - Finds attached EBS volumes
   - Compares instance tags with volume tags
   - Applies missing or updated tags to volumes
3. **Reporting**: Logs detailed reports to CloudWatch

## Report Format

The function generates detailed reports including:

```json
{
  "timestamp": "2024-01-15T10:30:00.000Z",
  "total_instances_processed": 5,
  "total_volumes_tagged": 3,
  "errors": [],
  "details": [
    {
      "instance_id": "i-1234567890abcdef0",
      "instance_tags": {
        "Environment": "Production",
        "Project": "WebApp"
      },
      "volumes_processed": [
        {
          "volume_id": "vol-0123456789abcdef0",
          "tags_added": {
            "Environment": "Production"
          },
          "status": "success"
        }
      ]
    }
  ]
}
```

## Viewing Reports

1. **CloudWatch Logs Console**:
   - Navigate to CloudWatch > Log groups
   - Open `/aws/lambda/ebs-auto-tagger`
   - View the latest log streams

2. **AWS CLI**:
   ```bash
   aws logs describe-log-streams \
     --log-group-name /aws/lambda/ebs-auto-tagger \
     --order-by LastEventTime \
     --descending
   ```

## Manual Testing

Test the function manually:
```bash
aws lambda invoke \
  --function-name ebs-auto-tagger \
  --payload '{}' \
  response.json && cat response.json
```

## Customization

### Change Schedule
Modify the `ScheduleExpression` parameter in the CloudFormation template:
- Every 10 minutes: `rate(10 minutes)`
- Every hour: `rate(1 hour)`
- Daily at 2 AM: `cron(0 2 * * ? *)`

### Add Tag Filters
Modify the Lambda code to include/exclude specific tags:

```python
# Skip certain tags
filtered_tags = {k: v for k, v in instance_tags.items() 
                if not k.startswith('aws:') and k not in ['DoNotCopy']}
```

## Permissions Required

The Lambda function needs these permissions:
- `ec2:DescribeInstances`
- `ec2:DescribeVolumes`
- `ec2:DescribeTags`
- `ec2:CreateTags`
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

## Cost Considerations

- Lambda execution: ~$0.20/month (assuming 5-minute intervals)
- CloudWatch Logs: ~$0.50/month for log storage
- No additional charges for EventBridge rules

## Cleanup

Delete the stack:
```bash
aws cloudformation delete-stack --stack-name ebs-auto-tagger-stack
```
