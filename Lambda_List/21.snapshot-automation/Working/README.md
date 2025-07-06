# AWS Universal Snapshot Tagging Automation

This solution automatically applies retention tags to snapshots/backups across ALL AWS services (EC2/EBS, RDS, FSx, AWS Backup) created manually or through automated processes, ensuring consistent lifecycle management.

## Overview

Managing snapshots and backups at scale across multiple AWS services can be challenging. This universal solution ensures all snapshots have proper retention tags by monitoring creation events across EC2, RDS, FSx, and AWS Backup services.

## Features

- **Multi-Service Support**: EC2/EBS, RDS (DB & Cluster), FSx, AWS Backup
- **Automatic Tagging**: 90-day retention with delete dates
- **Real-time Processing**: Tags applied within seconds to minutes
- **Multiple Trigger Sources**:
  - AWS Backup job completions
  - Direct snapshot/backup creation
  - CloudTrail API calls
  - Hourly cleanup (catches missed items)
  - Daily comprehensive scan
- **Parallel Processing**: Fast execution with concurrent tagging
- **Comprehensive Logging**: Detailed execution summaries

## Timing Expectations

### **Tagging Response Times:**

| Event Source | Expected Tagging Time | Notes |
|-------------|----------------------|-------|
| **EC2 Snapshot Completion** | 5-30 seconds | Via EBS Snapshot Notification |
| **AWS Backup Job Completion** | 10-60 seconds | Via Backup Job State Change |
| **Manual API Calls** | 1-5 minutes | Via CloudTrail (has slight delay) |
| **RDS Snapshot Creation** | 30-120 seconds | Via RDS Event Notifications |
| **FSx Backup Creation** | 30-120 seconds | Via CloudTrail API events |
| **Hourly Cleanup** | Every hour | Catches any missed snapshots |
| **Daily Comprehensive Scan** | 6 AM UTC daily | Full scan of last 24 hours |

### **Lambda Execution Performance:**
- **Single snapshot**: 2-5 seconds
- **Batch processing**: 10-30 seconds (with parallel processing)
- **Comprehensive scan**: 1-5 minutes (depending on volume)

## Architecture

The solution includes:

1. **Universal Lambda Function**: Handles all AWS services with parallel processing
2. **Multiple EventBridge Rules**: 
   - AWS Backup job completions
   - EC2/EBS snapshot notifications
   - RDS snapshot events
   - CloudTrail API calls
   - Hourly cleanup schedule
   - Daily comprehensive scan
3. **Optimized IAM Permissions**: Access to EC2, RDS, FSx, AWS Backup, CloudTrail

## Step-by-Step Deployment Guide

### **Prerequisites**

Before starting, ensure you have:

- [ ] AWS CLI installed and configured with appropriate credentials
- [ ] CloudFormation deployment permissions
- [ ] IAM permissions to create roles and policies
- [ ] CloudTrail enabled (for API call monitoring)

### **Step 1: Prepare Your Environment**

1. **Verify AWS CLI Configuration:**
   ```bash
   aws sts get-caller-identity
   ```

2. **Check Required Permissions:**
   ```bash
   aws iam get-user --query 'User.UserName'
   ```

3. **Ensure CloudTrail is Active:**
   ```bash
   aws cloudtrail describe-trails --query 'trailList[?IsLogging==`true`]'

### **Step 2: Download and Prepare Files**

1. **Clone/Download the Repository:**
   ```bash
   cd c:\Users\Learn-Lambda\Lambda_List\21.snapshot-automation\Working
   ```

2. **Verify Files Present:**
   ```bash
   dir
   # Should show: snapshot-automation.yaml, README.md
   ```

### **Step 3: Deploy the CloudFormation Stack**

1. **Deploy the Stack:**
   ```bash
   aws cloudformation deploy \
     --template-file snapshot-automation.yaml \
     --stack-name universal-snapshot-tagger \
     --capabilities CAPABILITY_IAM \
     --region us-east-1
   ```
   
   **Expected Duration:** 3-5 minutes

2. **Monitor Deployment Progress:**
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name universal-snapshot-tagger \
     --query 'StackEvents[0:5].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
     --output table
   ```

3. **Verify Successful Deployment:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name universal-snapshot-tagger \
     --query 'Stacks[0].StackStatus'
   ```
   
   **Expected Output:** `"CREATE_COMPLETE"`

### **Step 4: Verify Components Created**

1. **Check Lambda Function:**
   ```bash
   aws lambda get-function --function-name UniversalSnapshotTagger
   ```

2. **Verify EventBridge Rules:**
   ```bash
   aws events list-rules --query 'Rules[?contains(Name,`Snapshot`) || contains(Name,`Backup`)].Name'
   ```

3. **Check IAM Role:**
   ```bash
   aws iam get-role --role-name $(aws cloudformation describe-stack-resource --stack-name universal-snapshot-tagger --logical-resource-id SnapshotTaggerRole --query 'StackResourceDetail.PhysicalResourceId' --output text)
   ```

### **Step 5: Test the Solution**

#### **Test 1: Manual EC2 Snapshot (Fastest Test)**

1. **Create a Test EBS Snapshot:**
   ```bash
   # Get a volume ID
   VOLUME_ID=$(aws ec2 describe-volumes --query 'Volumes[0].VolumeId' --output text)
   
   # Create snapshot
   SNAPSHOT_ID=$(aws ec2 create-snapshot \
     --volume-id $VOLUME_ID \
     --description "Test snapshot for tagging automation" \
     --query 'SnapshotId' --output text)
   
   echo "Created snapshot: $SNAPSHOT_ID"
   ```

2. **Wait and Check for Tags (Expected: 1-5 minutes):**
   ```bash
   # Check immediately
   aws ec2 describe-snapshots --snapshot-ids $SNAPSHOT_ID --query 'Snapshots[0].Tags'
   
   # Wait 2 minutes and check again
   timeout 120 bash -c 'while true; do 
     TAGS=$(aws ec2 describe-snapshots --snapshot-ids '$SNAPSHOT_ID' --query "Snapshots[0].Tags[?Key==\`Retention\`]" --output text)
     if [ ! -z "$TAGS" ]; then 
       echo "Tags applied successfully!"
       aws ec2 describe-snapshots --snapshot-ids '$SNAPSHOT_ID' --query "Snapshots[0].Tags"
       break
     fi
     echo "Waiting for tags..."
     sleep 10
   done'
   ```

#### **Test 2: AWS Backup Test (If Backup is Configured)**

1. **Trigger a Backup Job (if you have backup plans):**
   ```bash
   aws backup start-backup-job \
     --backup-vault-name default \
     --resource-arn arn:aws:ec2:us-east-1:ACCOUNT-ID:volume/vol-xxxxxxxx \
     --iam-role-arn arn:aws:iam::ACCOUNT-ID:role/service-role/AWSBackupDefaultServiceRole
   ```

2. **Monitor the Backup Job and Tagging:**
   ```bash
   aws backup list-backup-jobs --by-state RUNNING
   ```

### **Step 6: Monitor and Verify Operations**

#### **Real-time Monitoring:**

1. **Watch Lambda Logs:**
   ```bash
   aws logs tail /aws/lambda/UniversalSnapshotTagger --follow
   ```

2. **Check Recent Lambda Executions:**
   ```bash
   aws logs filter-log-events \
     --log-group-name /aws/lambda/UniversalSnapshotTagger \
     --start-time $(date -d '1 hour ago' +%s)000 \
     --query 'events[*].[timestamp,message]' \
     --output table
   ```

#### **EventBridge Rule Monitoring:**

1. **Check Rule Invocations:**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Events \
     --metric-name SuccessfulInvocations \
     --dimensions Name=RuleName,Value=EC2SnapshotStateChangeRule \
     --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Sum
   ```

### **Step 7: Validate Tag Application**

#### **Check All Recent Snapshots:**

1. **EC2 Snapshots:**
   ```bash
   aws ec2 describe-snapshots \
     --owner-ids self \
     --query 'Snapshots[?StartTime>=`2024-01-01`].[SnapshotId,StartTime,Tags[?Key==`Retention`].Value|[0],Tags[?Key==`DeleteOn`].Value|[0]]' \
     --output table
   ```

2. **RDS Snapshots:**
   ```bash
   aws rds describe-db-snapshots \
     --snapshot-type manual \
     --query 'DBSnapshots[0:5].[DBSnapshotIdentifier,SnapshotCreateTime]' \
     --output table
   ```

## Configuration Customization

### **Modify Retention Period:**

To change from 90 days to a different period, edit the Lambda function code:

```python
# Change this line in create_retention_tags():
delete_date = today + datetime.timedelta(days=90)  # Change 90 to desired days
```

### **Adjust Cleanup Schedule:**

Modify the cron expressions in the CloudFormation template:

```yaml
# For more frequent cleanup (every 30 minutes):
ScheduleExpression: 'cron(0,30 * * * ? *)'

# For less frequent cleanup (twice daily):
ScheduleExpression: 'cron(0 6,18 * * ? *)'
```

## Troubleshooting Guide

### **Common Issues and Solutions:**

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| **Function definition errors (name 'get_recent_fsx_backups' is not defined)** | Incomplete Lambda code deployment | Redeploy CloudFormation stack with complete code |
| **Tags not applied within 5 minutes** | EventBridge rule not triggering | Check rule patterns and CloudTrail |
| **Permission denied errors** | IAM role lacks permissions | Review and update IAM policies |
| **Lambda timeouts** | Too many snapshots to process | Increase timeout or memory |
| **Missing CloudTrail events** | CloudTrail not configured | Enable CloudTrail with data events |

### **Quick Fix for Function Definition Errors:**

If you encounter "name 'function_name' is not defined" errors:

1. **Update the CloudFormation stack:**
   ```bash
   aws cloudformation update-stack \
     --stack-name universal-snapshot-tagger \
     --template-body file://snapshot-automation.yaml \
     --capabilities CAPABILITY_IAM
   ```

2. **Wait for update completion:**
   ```bash
   aws cloudformation wait stack-update-complete \
     --stack-name universal-snapshot-tagger
   ```

3. **Test the function:**
   ```bash
   aws lambda invoke \
     --function-name UniversalSnapshotTagger \
     --payload '{"process_recent": true, "hours": 1}' \
     response.json
   
   cat response.json
   ```

### **Fix for UPDATE_FAILED State:**

If your CloudFormation stack is in UPDATE_FAILED state due to Lambda runtime issues:

1. **Check the stack status:**
   ```bash
   aws cloudformation describe-stacks \
     --stack-name universal-snapshot-tagger \
     --query 'Stacks[0].StackStatus'
   ```

2. **If in UPDATE_FAILED state, cancel the update:**
   ```bash
   aws cloudformation cancel-update-stack \
     --stack-name universal-snapshot-tagger
   ```

3. **Wait for rollback to complete:**
   ```bash
   aws cloudformation wait stack-update-rollback-complete \
     --stack-name universal-snapshot-tagger
   ```

4. **Redeploy with the corrected template:**
   ```bash
   aws cloudformation update-stack \
     --stack-name universal-snapshot-tagger \
     --template-body file://snapshot-automation.yaml \
     --capabilities CAPABILITY_IAM
   ```

5. **If rollback fails, delete and recreate:**
   ```bash
   # Delete the stack
   aws cloudformation delete-stack \
     --stack-name universal-snapshot-tagger
   
   # Wait for deletion
   aws cloudformation wait stack-delete-complete \
     --stack-name universal-snapshot-tagger
   
   # Recreate the stack
   aws cloudformation create-stack \
     --stack-name universal-snapshot-tagger \
     --template-body file://snapshot-automation.yaml \
     --capabilities CAPABILITY_IAM
   ```

### **Diagnostic Commands:**

#### **Check CloudTrail Logs:**

1. **Find the latest events for a specific snapshot:**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=ResourceName,AttributeValue=$SNAPSHOT_ID \
     --max-results 5 \
     --query 'Events[*].[EventTime,EventName,Username,Resources]' \
     --output table
   ```

2. **Check for specific error messages in Lambda logs:**
   ```bash
   aws logs filter-log-events \
     --log-group-name /aws/lambda/UniversalSnapshotTagger \
     --filter-pattern "ERROR" \
     --start-time $(date -d '1 hour ago' +%s)000 \
     --query 'events[*].[timestamp,message]' \
     --output table
   ```

## Security Considerations

- **Least Privilege**: IAM role has minimal required permissions
- **Resource-Specific Access**: Permissions scoped to snapshot/backup resources
- **Audit Trail**: All actions logged in CloudWatch
- **No Deletion Permissions**: Function can only read and tag, not delete

## Cost Considerations

**Monthly Costs (estimated for moderate usage):**
- Lambda executions: $0.01 - $0.10
- CloudWatch Logs: $0.01 - $0.05
- EventBridge rule invocations: $0.00 - $0.01

**Total estimated monthly cost: $0.02 - $0.16**

## Support and Maintenance

- **Monitor CloudWatch dashboards** for execution metrics
- **Review logs monthly** for any persistent errors
- **Update retention policies** as business requirements change
- **Test new AWS service integrations** as they become available

## Contributing

Contributions welcome! Please test thoroughly and update documentation for any changes.
