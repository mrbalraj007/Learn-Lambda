# AWS Snapshot Automation with Auto-Tagging

## Overview

This CloudFormation template creates an automated system that tags AWS snapshots with retention information upon creation. It monitors snapshot creation events across multiple AWS services and automatically applies `Retention` and `DeleteOn` tags for lifecycle management.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS Services  │    │   CloudTrail     │    │   EventBridge   │
│   (EC2, RDS,    │───▶│   API Calls      │───▶│   Event Rule    │
│   FSx, Backup)  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │ Lambda Function │
                                               │ (Auto-Tagger)   │
                                               └─────────────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │ Apply Tags to   │
                                               │ Snapshots       │
                                               └─────────────────┘
```

## How It Works

1. **Event Detection**: When snapshots are created in AWS services (EC2, RDS, FSx, AWS Backup), CloudTrail logs the API calls
2. **Event Processing**: EventBridge captures these CloudTrail events and triggers the Lambda function
3. **Auto-Tagging**: The Lambda function automatically applies two tags:
   - `Retention`: Specifies retention period (e.g., "90days")
   - `DeleteOn`: Calculated deletion date (e.g., "2024-03-15")

## Supported Services

- **Amazon EC2**: EBS snapshots
- **Amazon RDS**: Database snapshots
- **Amazon FSx**: File system backups
- **AWS Backup**: Backup recovery points

## Prerequisites and Pre-checks

### 1. AWS Account Requirements

- [ ] AWS account with appropriate permissions
- [ ] CloudFormation deployment permissions
- [ ] IAM permissions to create roles and policies

### 2. CloudTrail Setup

**Critical Requirement**: CloudTrail must be enabled to capture API events.

#### Check CloudTrail Status:
```bash
# List existing trails
aws cloudtrail describe-trails

# Check if CloudTrail is logging
aws cloudtrail get-trail-status --name <trail-name>
```

#### Enable CloudTrail (if not already enabled):
```bash
# Create a basic CloudTrail
aws cloudtrail create-trail \
    --name snapshot-automation-trail \
    --s3-bucket-name your-cloudtrail-bucket \
    --include-global-service-events \
    --is-multi-region-trail
```

**Important**: Ensure CloudTrail is logging the following events:
- `CreateSnapshot` (EC2)
- `StartBackupJob` (AWS Backup)
- Data events for the services you're monitoring

### 3. IAM Permissions Check

Verify your deployment user/role has these permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PassRole",
                "lambda:*",
                "events:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### 4. Service-Specific Requirements

#### For EC2 Snapshots:
- [ ] EC2 instances or volumes exist
- [ ] Permissions to create EBS snapshots
- [ ] CloudTrail capturing EC2 API calls

#### For RDS Snapshots:
- [ ] RDS instances exist
- [ ] CloudTrail capturing RDS API calls

#### For AWS Backup:
- [ ] AWS Backup service is being used
- [ ] Backup plans are configured
- [ ] CloudTrail capturing AWS Backup API calls

### 5. EventBridge Requirements

- [ ] EventBridge service is available in your region
- [ ] No conflicting event rules for the same events

## Deployment Steps

### Step 1: Prepare Environment

1. **Clone/Download** the template files
2. **Verify AWS CLI** configuration:
   ```bash
   aws sts get-caller-identity
   ```

### Step 2: Validate Template

```bash
aws cloudformation validate-template --template-body file://template.yaml
```

### Step 3: Deploy Stack

#### Option A: Using AWS CLI
```bash
aws cloudformation create-stack \
    --stack-name snapshot-automation \
    --template-body file://template.yaml \
    --parameters ParameterKey=RetentionDays,ParameterValue=90 \
    --capabilities CAPABILITY_NAMED_IAM
```

#### Option B: Using AWS Console
1. Navigate to CloudFormation in AWS Console
2. Click "Create Stack"
3. Upload the `template.yaml` file
4. Set parameters:
   - **RetentionDays**: Number of days to retain snapshots (default: 90)
5. Review and create stack

### Step 4: Verify Deployment

Check stack status:
```bash
aws cloudformation describe-stacks --stack-name snapshot-automation
```

## Testing the Solution

### Test 1: Create an EBS Snapshot

```bash
# Get a volume ID
VOLUME_ID=$(aws ec2 describe-volumes --query 'Volumes[0].VolumeId' --output text)

# Create a test snapshot
aws ec2 create-snapshot \
    --volume-id $VOLUME_ID \
    --description "Test snapshot for automation"
```

### Test 2: Verify Tags Applied

Wait 1-2 minutes, then check the snapshot tags:

```bash
# Get the latest snapshot
SNAPSHOT_ID=$(aws ec2 describe-snapshots \
    --owner-ids self \
    --query 'Snapshots | sort_by(@, &StartTime) | [-1].SnapshotId' \
    --output text)

# Check tags
aws ec2 describe-snapshots \
    --snapshot-ids $SNAPSHOT_ID \
    --query 'Snapshots[0].Tags'
```

Expected output:
```json
[
    {
        "Key": "Retention",
        "Value": "90days"
    },
    {
        "Key": "DeleteOn",
        "Value": "2024-03-15"
    }
]
```

### Test 3: Check Lambda Logs

```bash
# Get Lambda function logs
aws logs describe-log-streams \
    --log-group-name /aws/lambda/SnapshotTaggerFunction \
    --order-by LastEventTime \
    --descending

# View recent logs
aws logs get-log-events \
    --log-group-name /aws/lambda/SnapshotTaggerFunction \
    --log-stream-name <latest-log-stream-name>
```

## Configuration

### Parameters

- **RetentionDays**: Number of days to retain snapshots (default: 90)
  - Modifies both the `Retention` tag value and calculates the `DeleteOn` date

### Environment Variables

The Lambda function uses:
- `RETENTION_DAYS`: Inherited from CloudFormation parameter

## Monitoring and Maintenance

### CloudWatch Metrics

Monitor these metrics:
- Lambda invocation count
- Lambda error rate
- Lambda duration

### Log Analysis

Check Lambda logs for:
- Successful tag applications
- API errors
- Timeout issues

### Regular Checks

1. **Monthly**: Verify CloudTrail is still active
2. **Quarterly**: Review and update retention policies
3. **Annually**: Audit IAM permissions

## Troubleshooting

### Common Issues

#### 1. Lambda Not Triggering

**Symptoms**: Snapshots created but no tags applied

**Checks**:
- Verify CloudTrail is enabled and logging
- Check EventBridge rule is active
- Verify Lambda has proper permissions

**Solution**:
```bash
# Check EventBridge rule
aws events describe-rule --name SnapshotCreationEventRule

# Check Lambda permissions
aws lambda get-policy --function-name SnapshotTaggerFunction
```

#### 2. Permission Denied Errors

**Symptoms**: Lambda logs show permission errors

**Solution**: Verify IAM role has required permissions:
```bash
aws iam get-role-policy \
    --role-name SnapshotTaggerLambdaRole \
    --policy-name SnapshotTagPolicy
```

#### 3. Tags Not Applied to All Services

**Symptoms**: Some snapshots get tagged, others don't

**Checks**:
- Verify CloudTrail captures events for all services
- Check if service-specific API calls are included in EventBridge rule

#### 4. Wrong Deletion Date

**Symptoms**: `DeleteOn` tag has incorrect date

**Solution**: Check timezone and retention calculation in Lambda code

## Cleanup

To remove the automation:

```bash
aws cloudformation delete-stack --stack-name snapshot-automation
```

**Note**: This won't remove tags already applied to snapshots.

## Cost Considerations

- **Lambda**: Pay per execution (typically < $1/month for normal usage)
- **CloudTrail**: Data events may incur additional charges
- **EventBridge**: Minimal cost for rule processing

## Security Best Practices

1. Use least-privilege IAM policies
2. Enable CloudTrail log file validation
3. Monitor Lambda execution logs
4. Regular security reviews of IAM roles

## Support and Maintenance

For issues or enhancements:
1. Check CloudWatch logs first
2. Verify all prerequisites are met
3. Test with manual snapshot creation
4. Review IAM permissions if errors occur

---

**Version**: 1.0  
**Last Updated**: 2025  
**Compatibility**: All AWS regions where services are available
