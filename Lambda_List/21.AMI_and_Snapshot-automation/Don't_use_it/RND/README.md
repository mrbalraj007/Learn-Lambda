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

### AWS Backup Special Handling

For AWS Backup, the process includes:
1. Capture `StartBackupJob` event
2. Poll backup vault for recovery point creation (up to 60 seconds)
3. Tag the actual recovery point ARN once available

## Supported Services

- **Amazon EC2**: EBS snapshots
- **Amazon RDS**: Database snapshots and cluster snapshots
- **Amazon FSx**: File system backups
- **AWS Backup**: Backup recovery points (with polling mechanism)

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
- `CreateDBSnapshot` (RDS)
- `CreateDBClusterSnapshot` (RDS)
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
- [ ] RDS instances or clusters exist
- [ ] CloudTrail capturing RDS API calls

#### For AWS Backup:
- [ ] AWS Backup service is being used
- [ ] Backup plans are configured
- [ ] Backup vaults are created
- [ ] CloudTrail capturing AWS Backup API calls
- [ ] Resources are configured for backup

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
aws cloudformation describe-stacks --stack-name snapshot-auto-tagger
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

### Test 2: Test AWS Backup

```bash
# Create an on-demand backup job (requires existing backup vault and IAM role)
aws backup start-backup-job \
    --backup-vault-name "your-backup-vault" \
    --resource-arn "arn:aws:ec2:region:account:volume/vol-xxxxxxxxx" \
    --iam-role-arn "arn:aws:iam::account:role/AWSBackupDefaultServiceRole"
```

### Test 3: Test RDS Snapshot

```bash
# Create RDS snapshot (requires existing RDS instance)
aws rds create-db-snapshot \
    --db-instance-identifier "your-db-instance" \
    --db-snapshot-identifier "test-snapshot-$(date +%Y%m%d%H%M%S)"
```

### Test 4: Verify Tags Applied

Wait 1-2 minutes for EBS/RDS, or up to 2-3 minutes for AWS Backup, then check tags:

#### For EBS Snapshots:
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

#### For AWS Backup Recovery Points:
```bash
# List recovery points in your backup vault
aws backup list-recovery-points-by-backup-vault \
    --backup-vault-name "your-backup-vault" \
    --query 'RecoveryPoints[0].[RecoveryPointArn,RecoveryPointTags]'
```

#### For RDS Snapshots:
```bash
# Get latest RDS snapshot
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
    --query 'DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
    --output text)

# Check RDS snapshot tags
aws rds list-tags-for-resource \
    --resource-name $(aws rds describe-db-snapshots \
        --db-snapshot-identifier $SNAPSHOT_ID \
        --query 'DBSnapshots[0].DBSnapshotArn' --output text)
```

Expected output for all services:
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

### Test 5: Check Lambda Logs

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

### For Windows Console
```bash
# Get Lambda function logs
aws logs describe-log-streams --log-group-name "/aws/lambda/SnapshotTaggerFunction" --order-by LastEventTime --descending

# View recent logs
aws logs get-log-events \
    --log-group-name /aws/lambda/SnapshotTaggerFunction \
    --log-stream-name <latest-log-stream-name>
```

### Test 6: Manual AWS Backup Tag Verification

After creating a backup, manually verify and test tagging:

```bash
# 1. Get the recovery point ARN from your backup
RECOVERY_POINT_ARN="arn:aws:ec2:us-east-1:image/ami-04ae3077b12bb6b80"
VAULT_NAME="Testvault"

# 2. Check current tags
aws backup list-tags --resource-arn $RECOVERY_POINT_ARN

# 3. Manually apply tags to test permissions
aws backup tag-resource \
    --resource-arn $RECOVERY_POINT_ARN \
    --tags TestRetention=90days,TestDeleteOn=2024-03-15

# 4. Verify tags were applied
aws backup list-tags --resource-arn $RECOVERY_POINT_ARN

# 5. Check backup job that created this recovery point
aws backup list-backup-jobs \
    --by-resource-arn $(echo $RECOVERY_POINT_ARN | sed 's/:image\/.*/:volume\/vol-xxxxxxxxx/')
```

### Test 7: CloudTrail Event Verification

List the trail's S3 bucket:
```bash
aws cloudtrail describe-trails --query 'trailList[*].S3BucketName'
```
Option 1: Check if CloudTrail is logging to CloudWatch
Run the following AWS CLI command to check if your CloudTrail is configured to deliver logs to CloudWatch:
```bash
aws cloudtrail describe-trails \
  --query 'trailList[*].{Name:Name,LogGroup:CloudWatchLogsLogGroupArn}' \
  --output table
```
**Note**-: If it shows "None" or empty in LogGroup, then CloudTrail is not currently sending logs to CloudWatch.

```bash
# Check if CloudTrail is capturing backup events
aws logs filter-log-events \
    --log-group-name <your-cloudtrail-log-group> \
    --filter-pattern "{ $.eventName = StartBackupJob }" \
    --start-time $(date -d "24 hours ago" +%s)000
```

## Configuration

### Parameters

- **RetentionDays**: Number of days to retain snapshots (default: 90)
  - Modifies both the `Retention` tag value and calculates the `DeleteOn` date

### Environment Variables

The Lambda function uses:
- `RETENTION_DAYS`: Inherited from CloudFormation parameter

### Lambda Function Details

- **Runtime**: Python 3.11
- **Timeout**: 120 seconds (increased to handle AWS Backup polling)
- **Memory**: Default (128 MB)

## Monitoring and Maintenance

### CloudWatch Metrics

Monitor these metrics:
- Lambda invocation count
- Lambda error rate
- Lambda duration (especially for AWS Backup events)

### Log Analysis

Check Lambda logs for:
- Successful tag applications
- API errors
- Timeout issues
- AWS Backup polling progress

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

#### 3. AWS Backup Tags Not Applied

**Symptoms**: Backup jobs complete but recovery points aren't tagged

**Enhanced Debugging Steps**:

1. **Check if Lambda is being triggered**:
```bash
# Check Lambda logs for backup events
aws logs filter-log-events \
    --log-group-name /aws/lambda/SnapshotTaggerFunction \
    --filter-pattern "StartBackupJob" \
    --start-time $(date -d "1 hour ago" +%s)000
```

2. **Verify the backup job details**:
```bash
# Get recent backup jobs
aws backup list-backup-jobs --max-results 5

# Get specific backup job details
aws backup describe-backup-job --backup-job-id <backup-job-id>
```

3. **Check recovery point and its tags**:
```bash
# List recovery points in your vault
aws backup list-recovery-points-by-backup-vault \
    --backup-vault-name "Testvault"

# Check tags on specific recovery point
aws backup list-tags \
    --resource-arn "arn:aws:ec2:us-east-1:image/ami-04ae3077b12bb6b80"
```

4. **Manual tag application for testing**:
```bash
# Manually tag a recovery point to test permissions
aws backup tag-resource \
    --resource-arn "arn:aws:ec2:us-east-1:image/ami-04ae3077b12bb6b80" \
    --tags Retention=90days,DeleteOn=2024-03-15,TestTag=manual
```

5. **Check CloudTrail for StartBackupJob events**:
```bash
# Look for recent backup job events
aws logs filter-log-events \
    --log-group-name CloudTrail/YourCloudTrailLogGroup \
    --filter-pattern "StartBackupJob" \
    --start-time $(date -d "1 hour ago" +%s)000
```

**Common Causes and Solutions**:

- **Recovery Point ARN Mismatch**: The ARN format might be different than expected
- **Timing Issues**: Recovery points may take longer to become available for tagging
- **Permissions**: Lambda role may lack permissions for the specific backup vault
- **CloudTrail**: StartBackupJob events may not be captured by CloudTrail

**Verification Commands**:
```bash
# Verify Lambda has correct permissions
aws iam simulate-principal-policy \
    --policy-source-arn arn:aws:iam::ACCOUNT:role/SnapshotTaggerLambdaRole \
    --action-names backup:TagResource \
    --resource-arns "arn:aws:ec2:us-east-1:image/ami-04ae3077b12bb6b80"

# Check if EventBridge rule is working
aws events test-event-pattern \
    --event-pattern file://event-pattern.json \
    --event file://test-event.json
```

#### 4. Lambda Timeout Issues

**Symptoms**: Lambda function times out, especially for AWS Backup

**Solution**: 
- Current timeout is 120 seconds
- If needed, increase timeout in CloudFormation template
- Check backup vault has recovery points being created

#### 5. Tags Not Applied to All Services

**Symptoms**: Some snapshots get tagged, others don't

**Checks**:
- Verify CloudTrail captures events for all services
- Check if service-specific API calls are included in EventBridge rule
- Review Lambda logs for service-specific errors

#### 6. Wrong Deletion Date

**Symptoms**: `DeleteOn` tag has incorrect date

**Solution**: Check timezone and retention calculation in Lambda code

## Performance Considerations

### AWS Backup Polling

- The function polls for up to 60 seconds for recovery point creation
- 12 attempts with 5-second intervals
- This is necessary because recovery points aren't immediately available

### Lambda Concurrency

- Multiple snapshot creations may trigger concurrent Lambda executions
- This is normal and expected behavior
- Monitor for any throttling issues

## Cleanup

To remove the automation:

```bash
aws cloudformation delete-stack --stack-name snapshot-automation
```

**Note**: This won't remove tags already applied to snapshots.

## Cost Considerations

- **Lambda**: Pay per execution (typically < $2/month for normal usage due to increased timeout)
- **CloudTrail**: Data events may incur additional charges
- **EventBridge**: Minimal cost for rule processing

## Security Best Practices

1. Use least-privilege IAM policies
2. Enable CloudTrail log file validation
3. Monitor Lambda execution logs
4. Regular security reviews of IAM roles
5. Encrypt CloudTrail logs
6. Use AWS Config for compliance monitoring

## Support and Maintenance

For issues or enhancements:
1. Check CloudWatch logs first
2. Verify all prerequisites are met
3. Test with manual snapshot creation
4. Review IAM permissions if errors occur
5. For AWS Backup issues, verify backup vault and job status

## Known Limitations

1. **AWS Backup**: Recovery points may take up to 60 seconds to appear for tagging
2. **Cross-region**: EventBridge rules are region-specific
3. **Service Coverage**: Only covers the specified AWS services
4. **Tag Limits**: AWS services have tag limits (50 tags per resource for most services)

---

**Version**: 2.0  
**Last Updated**: 2025  
**Compatibility**: All AWS regions where services are available
