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
- 🔁 **Easy to extend** with auto-delete or S3 export if required

## 🏗️ Architecture Diagram

![AWS EBS Snapshot Automation Architecture](aws-snapshot-automation-architecture.drawio)

```csharp
[EBS Snapshot Created] 
        ↓ 
[EventBridge Rule] 
        ↓ 
[TagSnapshot Lambda] ───── Tags snapshot with:
                             • Retention=90days
                             • DeleteOn=<YYYY-MM-DD>

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
> **Note**: Open the `aws-snapshot-automation-architecture.drawio` file in [draw.io](https://app.diagrams.net/) to view the complete architectural diagram with AWS icons and colorful flow arrows.

## 🧱 Architecture Overview

```
[EBS Snapshot Created] 
        ↓ 
[EventBridge Rule] 
        ↓ 
[TagSnapshot Lambda] ───── Tags snapshot with:
                             • Retention=90days
                             • DeleteOn=<YYYY-MM-DD>

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

### 🔄 Automated Workflow
1. **EC2 Instance** → **EBS Volume** (Attached storage)
2. **EBS Volume** → **EBS Snapshot** (Manual/automated snapshot creation)
3. **EBS Snapshot** → **AWS CloudTrail** (API call logging)
4. **CloudTrail** → **EventBridge** (Event pattern matching for `CreateSnapshot`)
5. **EventBridge** → **TagSnapshot Lambda** (Automatic trigger)
6. **TagSnapshot Lambda** → **EBS Snapshot** (Applies `DeleteOn` and `Retention` tags)

### 👤 Manual Workflow
1. **User/Scheduler** → **ListStaleSnapshots Lambda** (Manual invocation)
2. **ListStaleSnapshots Lambda** → **EC2 API** (Queries snapshots, volumes, instances)
3. **Lambda** → **CloudWatch Logs** (Outputs stale snapshot report)

## 🧰 Technologies

- **AWS Lambda** (Python 3.12)
- **Amazon EC2 API** (boto3)
- **Amazon EventBridge** (CloudWatch Events)
- **AWS CloudFormation** (Infrastructure-as-Code)
- **IAM roles** for least privilege

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

### 1. Test Auto-Tagging

1. Go to **EC2** → **Elastic Block Store** → **Snapshots**
2. Manually create a snapshot of any volume
3. Wait a few seconds
4. ✅ Check the **Tags** tab — you should see:
   - `DeleteOn=YYYY-MM-DD` (90 days ahead)
   - `Retention=90days`

### 2. Test Snapshot Report

1. Navigate to **AWS Lambda** → **Functions** → **ListStaleSnapshots**
2. Choose **Test** → **Create new test event** → any JSON (e.g., `{}`)
3. Click **Test**
4. ✅ Output will show all snapshots older than 90 days with associated metadata

## 🧹 Cleanup (Optional)

To delete resources:

```bash
aws cloudformation delete-stack --stack-name snapshot-tagging-monitor
```

## 🔒 IAM Roles & Security

Lambda is granted the following minimum set of permissions:

- `ec2:DescribeSnapshots`, `ec2:CreateTags`, `ec2:DescribeVolumes`, `ec2:DescribeInstances`
- `logs:*` for CloudWatch log publishing

## 🧩 Future Improvements

- Export stale snapshot report to S3
- Automatically delete snapshots past retention
- Add Slack/SNS/Email alerts
- Integration with AWS Backup

## 👨‍💼 Author

**Balraj Singh**  
*AWS Professional Engineer*

