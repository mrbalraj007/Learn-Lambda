# 📦 AWS EBS Snapshot Tagging & Stale Snapshot Detection

This project contains two AWS Lambda functions that help manage EBS snapshots by:

- **Auto-tagging** new snapshots with a retention period (DeleteOn tag = 90 days from creation)
- **Identifying** stale snapshots (older than 90 days), including metadata like:
  - Snapshot ID
  - Creation date
  - Retention tag
  - Associated volume
  - Linked EC2 instance (if any)

## 🚀 Features

- 🏷 **Auto-tag snapshots** upon creation using EventBridge and Lambda
- 📋 **List stale snapshots** to help with cleanup planning
- 🔒 **Minimal IAM permissions** via dedicated execution role
- 🔄 **Dual event triggers** - Native EC2 events + CloudTrail backup
- 🛠️ **Enhanced error handling** and detailed logging
- 🏷️ **Multiple tags** - DeleteOn, Retention, AutoTagged, TaggedBy
- 🔁 **Easy to extend** with auto-delete or S3 export if required

## 🏗️ Architecture Diagram

![AWS EBS Snapshot Automation Architecture](aws-snapshot-automation-architecture.drawio)

> **Note**: Open the `aws-snapshot-automation-architecture.drawio` file in [draw.io](https://app.diagrams.net/) to view the complete architectural diagram with AWS icons and colorful flow arrows.

## 🧱 Architecture Overview

```
[EBS Snapshot Created] 
        ↓ (Two Parallel Paths)
[Native EC2 Event] ←──────────→ [CloudTrail Event]
        ↓                              ↓
[EventBridge Rule 1] ←────────→ [EventBridge Rule 2]
        ↓                              ↓
        └──────── [TagSnapshot Lambda] ────────┘
                         ↓
              Tags snapshot with:
                • DeleteOn=YYYY-MM-DD (90 days)
                • Retention=90days
                • AutoTagged=true
                • TaggedBy=Lambda-AutoTagger

[Manual/Scheduled Trigger]
        ↓
[ListStaleSnapshots Lambda] ───── Lists:
                                  • Snapshot ID
                                  • StartTime
                                  • Age in days
                                  • Volume ID
                                  • Associated EC2 instance
                                  • DeleteOn tag
```

### 🔄 Enhanced Automated Workflow
1. **EC2 Instance** → **EBS Volume** (Attached storage)
2. **EBS Volume** → **EBS Snapshot** (Manual/automated snapshot creation)
3. **Dual Event Capture**:
   - **Path A**: Direct EC2 Event → EventBridge Rule → Lambda
   - **Path B**: CloudTrail Event → EventBridge Rule → Lambda (backup)
4. **TagSnapshot Lambda** → **EBS Snapshot** (Applies comprehensive tags)

### 👤 Manual Workflow
1. **User/Scheduler** → **ListStaleSnapshots Lambda** (Manual invocation)
2. **ListStaleSnapshots Lambda** → **EC2 API** (Queries snapshots, volumes, instances)
3. **Lambda** → **CloudWatch Logs** (Outputs stale snapshot report)

## 🧰 Technologies

- **AWS Lambda** (Python 3.12)
- **Amazon EC2 API** (boto3)
- **Amazon EventBridge** (Dual rules for reliability)
- **AWS CloudFormation** (Infrastructure-as-Code)
- **IAM roles** for least privilege
- **CloudWatch Logs** for monitoring and debugging

## 📁 Project Structure

```
snapshot-automation/
│
├── snapshot-automation.yaml                    # CloudFormation template
├── aws-snapshot-automation-architecture.drawio # Architecture diagram
├── README.md                                   # This file
```

## ⚙️ Deployment

### ✅ Prerequisites

- AWS CLI configured
- CloudFormation deploy permissions
- IAM privileges to create Lambda, IAM Role, EventBridge

### 🔧 Deploy the Stack

```bash
aws cloudformation deploy \
  --template-file snapshot-automation.yaml \
  --stack-name snapshot-tagging-monitor \
  --capabilities CAPABILITY_NAMED_IAM
```

## 🧪 How to Test

### 1. Test Auto-Tagging (Primary Method)

1. Go to **EC2** → **Elastic Block Store** → **Snapshots**
2. Manually create a snapshot of any volume
3. Wait 30-60 seconds for processing
4. ✅ Check the **Tags** tab — you should see:
   - `DeleteOn=YYYY-MM-DD` (90 days ahead)
   - `Retention=90days`
   - `AutoTagged=true`
   - `TaggedBy=Lambda-AutoTagger`

### 2. Test Auto-Tagging (Manual Lambda Test)

If automatic tagging doesn't work immediately:

1. Navigate to **AWS Lambda** → **Functions** → **TagSnapshotOnCreate**
2. Choose **Test** → **Create new test event**
3. Use this test event JSON (replace with your actual snapshot ID):
```json
{
  "detail": {
    "snapshot-id": "snap-1234567890abcdef0"
  }
}
```
4. Click **Test**
5. ✅ Check CloudWatch Logs and verify tags are applied

### 3. Test Stale Snapshot Report

1. Navigate to **AWS Lambda** → **Functions** → **ListStaleSnapshots**
2. Choose **Test** → **Create new test event** → any JSON (e.g., `{}`)
3. Click **Test**
4. ✅ Output will show all snapshots older than 90 days with associated metadata

## 🔍 Troubleshooting

### Auto-Tagging Not Working?

1. **Check CloudWatch Logs**:
   - Go to **CloudWatch** → **Log groups** → `/aws/lambda/TagSnapshotOnCreate`
   - Look for error messages or event details

2. **Verify EventBridge Rules**:
   - Go to **EventBridge** → **Rules**
   - Ensure `TagSnapshotOnCreateRule` and `TagSnapshotCloudTrailRule` are enabled

3. **Test Manually**:
   - Use the manual Lambda test method above
   - Check if the function can tag snapshots when invoked directly

4. **Check IAM Permissions**:
   - Verify the Lambda execution role has `ec2:CreateTags` permission

5. **Enable CloudTrail** (if needed):
   - Some regions may require CloudTrail for the backup event rule

### Common Issues:

- **Event Format**: The Lambda handles multiple event formats automatically
- **Timing**: Allow 30-60 seconds for automatic processing
- **Permissions**: Ensure proper IAM permissions for EC2 tagging
- **Region**: Deploy in the same region as your snapshots

## 🧹 Cleanup (Optional)

To delete resources:

```bash
aws cloudformation delete-stack --stack-name snapshot-tagging-monitor
```

## 🔒 IAM Roles & Security

Lambda is granted the following minimum set of permissions:

- `ec2:DescribeSnapshots`, `ec2:CreateTags`, `ec2:DescribeVolumes`, `ec2:DescribeInstances`
- `logs:*` for CloudWatch log publishing

## 📊 Monitoring & Logs

### CloudWatch Logs
- **TagSnapshotOnCreate**: `/aws/lambda/TagSnapshotOnCreate`
- **ListStaleSnapshots**: `/aws/lambda/ListStaleSnapshots`

### Key Metrics to Monitor
- Lambda invocation count
- Lambda error rate
- EventBridge rule match rate
- Snapshot tagging success rate

## 🧩 Future Improvements

- Export stale snapshot report to S3
- Automatically delete snapshots past retention
- Add Slack/SNS/Email alerts
- Integration with AWS Backup
- Scheduled execution for stale snapshot reports
- Cost optimization analysis

## 📋 Outputs

The CloudFormation stack provides these outputs:
- **TagSnapshotFunctionArn**: ARN of the tagging Lambda function
- **ListStaleSnapshotsFunctionArn**: ARN of the reporting Lambda function  
- **EventRuleArn**: ARN of the primary EventBridge rule

## 👨‍💼 Author

**Balraj Singh**  
*AWS Professional Engineer*

