
# 📦 Snapshot Auto-Tagging Solution for AWS

This solution automatically tags newly created Amazon EBS snapshots with the same tags as the EC2 instance attached to the volume being snapshotted. It uses **AWS Lambda**, **Amazon EventBridge**, and **CloudFormation** to automate the workflow.

---

## ✅ Use Case

When a snapshot is created (manually or automatically), it often lacks proper tags. Over time, these untagged snapshots can lead to confusion, poor traceability, and increased costs. This solution ensures that every snapshot inherits the correct tags from the associated EC2 instance **immediately upon creation**.

---

## 📐 Architecture Overview

```
+---------------------------+
|      EC2 Instance         |
|  (has required tags)      |
+-------------+-------------+
              |
              | Snapshot Created (manual/API/AWS Backup)
              v
+-------------+-------------+
|         EventBridge Rule         |
|   Triggers on createSnapshot     |
+-------------+-------------+
              |
              v
+-------------+-------------+
|       AWS Lambda Function       |
|  - Gets snapshot and volume ID  |
|  - Finds attached EC2 instance  |
|  - Copies EC2 tags to snapshot  |
+---------------------------+
```

---

## 🛠️ Components Deployed

| Resource                   | Description                                                  |
|---------------------------|--------------------------------------------------------------|
| IAM Role                  | Lambda execution role with permissions for EC2 and logs.     |
| Lambda Function           | Tags EBS snapshots based on attached EC2 instance tags.      |
| EventBridge Rule          | Listens for snapshot creation events.                        |
| Lambda Permission         | Grants EventBridge permission to invoke the Lambda.          |

---

## 🚀 How It Works (Step by Step)

1. **Snapshot Creation**
   - You or AWS automatically create an EBS snapshot (e.g., via AWS Backup or manually).

2. **EventBridge Trigger**
   - The `createSnapshot` event is captured by EventBridge.

3. **Lambda Execution**
   - EventBridge invokes the Lambda function.
   - Lambda reads `snapshot_id` and `volume_id` from the event.
   - It queries EC2 to:
     - Get the volume details.
     - Identify the EC2 instance attached to that volume.
     - Fetch the instance's tags.

4. **Snapshot Tagging**
   - Lambda uses `ec2:createTags` to copy the EC2 tags onto the snapshot.

---

## 📦 Deployment Instructions

### 1. Upload Lambda ZIP to S3

```bash
aws s3 cp snapshot_tag_lambda.zip s3://<your-bucket-name>/lambda/snapshot_tag_lambda.zip
```

### 2. Deploy the CloudFormation Stack

```bash
aws cloudformation deploy \
  --template-file snapshot-autotag-s3.yaml \
  --stack-name SnapshotTagAutomation \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    LambdaS3Bucket=<your-bucket-name> \
    LambdaS3Key=lambda/snapshot_tag_lambda.zip
```

---

## 🔐 Required IAM Permissions (Lambda Role)

The Lambda function needs:

- `ec2:DescribeVolumes`
- `ec2:DescribeInstances`
- `ec2:CreateTags`
- `ec2:DescribeSnapshots`
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` (via AWSLambdaBasicExecutionRole)

These are automatically granted by the CloudFormation template.

---

## 📎 Outputs

- `LambdaFunctionName`: The name of the snapshot tagging Lambda function.
- `EventRuleName`: Name of the EventBridge rule used for triggering.

---

## 📌 Notes

- Only works if the volume is attached to an EC2 instance at the time of snapshot.
- Snapshots of unattached volumes will not be tagged.
- Tagging is best-effort — if tagging fails, you can add logging or alerting in the Lambda.

---

## 🧼 Optional Enhancements

- Add TTL-based cleanup for old snapshots.
- Add email/SNS alert for untagged or failed snapshot tagging events.
- Extend support to tag AMIs in a similar fashion.

---

## 👨‍💻 Author
This solution was generated and documented by a professional AWS engineer using best practices in infrastructure automation.
