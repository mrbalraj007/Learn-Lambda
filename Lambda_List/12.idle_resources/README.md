# AWS Idle Resources Audit

## Overview
This solution deploys a scheduled audit of AWS resources to identify cost-saving opportunities. It uses:
- A CloudFormation template to create required IAM roles, S3 buckets, SNS topics, and Lambda functions.  
- A Python Lambda function that inspects idle EBS volumes, snapshots, stopped EC2 instances, unused security groups, IAM roles without policies, and idle Lambda functions.  
- Output in CSV and Excel (XLSX) formats stored in S3 and a notification sent via SNS.

## Architecture
1. **CloudFormation Template**  
   - Parameters: S3 bucket names, Lambda runtime, existing vs. new bucket, SNS email.  
   - Creates (conditionally) an S3 bucket, IAM role with needed policies, Lambda layer for `openpyxl`, two Lambda functions, SNS topic, EventBridge rule.  
2. **Lambda Function**  
   - Written in Python 3.8–3.12, uses `boto3` and `openpyxl`.  
   - Queries AWS services (EC2, IAM, Lambda, CloudWatch, CloudTrail, SNS).  
   - Builds an Excel workbook with multiple sheets, uploads to S3 (`.xlsx`), and publishes an SNS notification.

## Execution Flow
1. **Event Trigger**  
   - Scheduled weekly via CloudWatch Events (EventBridge) at Monday 8 AM UTC.  
2. **Resource Inspection**  
   - Idle EBS Volumes: status `available`.  
   - Snapshot Expiry: missing/invalid `ExpiryDate` tags, orphaned snapshots.  
   - Stopped EC2 Instances: state `stopped`.  
   - Unused Security Groups: not attached to any ENI and not the default group.  
   - IAM Roles: no attached or inline policies.  
   - Idle Lambda Functions: no invocations in the last 30 days.  
   - Uses CloudTrail lookup to capture “CreatedBy” info for each resource.

## Output
- **CSV**: (Optional) printed via `redirect_stdout` during execution.  
- **Excel (`.xlsx`)**:  
  - Sheets: `IdleEBS`, `SnapshotExpiry`, `StoppedInstances`, `UnusedSecurityGroups`, `IAMRolesNoPolicies`, `IdleLambdas`.  
  - Uploaded to S3 under `report/<timestamp>.xlsx`.

## Notifications
- An SNS topic sends an email summary with:
  - Count of idle resources per category.  
  - Direct link to the S3 object in the AWS Console.

## Deployment
1. Package Lambda code and `openpyxl` dependencies into ZIPs.  
2. ### Upload both ZIPs to the deployment S3 bucket.  
3. Deploy or update the CloudFormation stack:  
   ```bash
   aws cloudformation deploy \
     --template-file cloudformation.yaml \
     --stack-name IdleResourcesAudit \
     --parameter-overrides \
       S3BucketName=<your-bucket> \
       NotificationEmail=<you@example.com> \
       UseExistingBucket=true \
       CodeS3Key=src/lambda_function.zip \
       LayerS3Key=src/openpyxl_layer.zip \
     --capabilities CAPABILITY_NAMED_IAM
   ```  
4. Confirm subscription to the SNS email and monitor the weekly audit report.

