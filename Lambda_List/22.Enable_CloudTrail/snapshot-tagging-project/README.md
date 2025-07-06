# Snapshot Auto-Tagging Project

## 📌 Purpose
Automatically tag all snapshots (EBS, RDS, FSx, AWS Backup) created manually or via AWS Backup with:
- `Retention=90days`
- `DeleteOn=YYYY-MM-DD`

## 📁 Contents
- `template.yaml` — Deploys Lambda, EventBridge, IAM Role
- `cloudtrail-template.yaml` — Enables CloudTrail logging
- `lambda/index.py` — Python code for tagging logic

## 🧪 Deployment Steps

### Step 1: Deploy CloudTrail
```bash
aws cloudformation deploy \
  --template-file cloudtrail-template.yaml \
  --stack-name enable-cloudtrail-logs \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 2: Package & Upload Lambda Code
```bash
zip lambda-code.zip index.py
aws s3 cp lambda-code.zip s3://<your-bucket-name>/
```

### Step 3: Deploy Tagging Stack
Update `template.yaml` with your `S3Bucket` and `S3Key`, then deploy:
```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name snapshot-auto-tagger \
  --capabilities CAPABILITY_NAMED_IAM
```

## ✅ Validation
Create a snapshot or backup and verify tags:
- `Retention=90days`
- `DeleteOn=<date>`

Troubleshooting

✅ To Fix: Enable CloudTrail Logging
You can create a new trail with logging enabled using the following CLI command:

bash
Copy
Edit
aws cloudtrail create-trail \
  --name snapshot-trail \
  --s3-bucket-name <your-logs-s3-bucket> \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --include-global-service-events
Then start logging:

bash
Copy
Edit
aws cloudtrail start-logging --name snapshot-trail
📌 Replace <your-logs-s3-bucket> with an existing S3 bucket for log storage. If you don't have one, create one with:

bash
Copy
Edit
aws s3 mb s3://my-cloudtrail-logs-bucket

The error you're encountering:

less
Copy
Edit
An error occurred (InsufficientS3BucketPolicyException) when calling the CreateTrail operation: Incorrect S3 bucket policy is detected for bucket: demo-terra22062025
means that the S3 bucket you're using (demo-terra22062025) does not have the required bucket policy to allow CloudTrail to write logs.

✅ Solution: Add Required Bucket Policy
Use the following bucket policy (adjusted for your bucket) and apply it using the CLI or Console:

📝 JSON Policy (replace <account-id> with your AWS Account ID):
json
Copy
Edit
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::demo-terra22062025"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::demo-terra22062025/AWSLogs/<account-id>/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
🚀 How to Apply via CLI
Replace <account-id> with your actual AWS account ID.

Save the policy to a file cloudtrail-policy.json.

Run:

bash
Copy
Edit
aws s3api put-bucket-policy \
  --bucket demo-terra22062025 \
  --policy file://cloudtrail-policy.json
🧪 After Applying the Policy
Retry your create-trail command:

bash
Copy
Edit
aws cloudtrail create-trail \
  --name snapshot-trail \
  --s3-bucket-name demo-terra22062025 \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --include-global-service-events
Let me know if you’d like this policy also added to your CloudFormation template.

If you're seeing:

bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[?IsLogging==`true`]'
[]
…it means CloudTrail exists, but is not actively logging. Creating a trail alone doesn’t start logging — you need to explicitly start it.

✅ Step to Fix: Start Logging Manually
Run the following command (replace snapshot-trail with your trail name if different):

bash
Copy
Edit
aws cloudtrail start-logging --name snapshot-trail
🔍 Then verify again:
bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[?IsLogging==`true`].[Name,HomeRegion]'
You should see something like:

json
Copy
Edit
[
  [
    "snapshot-trail",
    "us-east-1"
  ]
]

Correct usage:
bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[?IsLogging==`true`].[Name,HomeRegion]'
This command lists all trails that are logging and outputs their Name and HomeRegion.

If you still get an empty list ([]), it means no CloudTrail trails are currently logging.

Make sure you:

Created a trail.

Started logging on it using:

bash
Copy
Edit
aws cloudtrail start-logging --name your-trail-name
If the command

bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[?IsLogging==`true`].[Name,HomeRegion]'
returns an empty list [], it means no CloudTrail trail is currently logging in your account/region.

What to do next?
Check if any trails exist (whether logging or not):

bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[*].[Name,IsLogging]'
If trails exist but none are logging, start logging on a trail (replace <trail-name>):

bash
Copy
Edit
aws cloudtrail start-logging --name <trail-name>
If no trails exist, create a new trail and enable logging:

bash
Copy
Edit
aws cloudtrail create-trail --name snapshot-trail --s3-bucket-name <your-logs-bucket> --is-multi-region-trail --include-global-service-events --enable-log-file-validation

aws cloudtrail start-logging --name snapshot-trail

The output

json
Copy
Edit
[
    [
        "snapshot-trail",
        null
    ]
]
means:

You have a CloudTrail named snapshot-trail created.

But it is NOT currently logging (IsLogging is null instead of true).

What to do?
You need to start logging on the trail:

bash
Copy
Edit
aws cloudtrail start-logging --name snapshot-trail
Once started, verify again:

bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[*].[Name,IsLogging]'
It should then show:

json
Copy
Edit
[
    [
        "snapshot-trail",
        true
    ]
]

If after running

bash
Copy
Edit
aws cloudtrail start-logging --name snapshot-trail
the IsLogging still shows as null, this usually means the trail is not actually logging yet.

Possible reasons & checks:
AWS Region mismatch:

CloudTrail trails are regional resources.

Check if you’re running commands in the same region where the trail was created.

You can verify your CLI region via:

bash
Copy
Edit
aws configure get region
Or explicitly add --region <region> to your commands:

bash
Copy
Edit
aws cloudtrail describe-trails --region us-east-1 --query 'trailList[*].[Name,IsLogging]'
aws cloudtrail start-logging --name snapshot-trail --region us-east-1
Trail is multi-region:

Even multi-region trails belong to a home region.

You must query and start logging in that home region.

Next Steps:
Run:

bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[*].[Name,HomeRegion]'
Use the HomeRegion from the output to rerun your start-logging and describe-trails commands with --region <HomeRegion>.

Example:
bash
Copy
Edit
aws cloudtrail describe-trails --query 'trailList[*].[Name,HomeRegion]'

# Output might be:
# [
#   ["snapshot-trail", "us-east-1"]
# ]

aws cloudtrail start-logging --name snapshot-trail --region us-east-1
aws cloudtrail describe-trails --query 'trailList[*].[Name,IsLogging]' --region us-east-1

Thanks for the details!

Since the trail’s HomeRegion is us-east-1 (which matches your configured region) but IsLogging remains null even after running:

bash
Copy
Edit
aws cloudtrail start-logging --name snapshot-trail --region us-east-1
this suggests CloudTrail logging is not starting correctly.

Things to check and try next:
Check if you have sufficient permissions

Make sure your AWS CLI user/role has permissions:

cloudtrail:StartLogging

cloudtrail:DescribeTrails

Verify the S3 bucket policy

CloudTrail requires an S3 bucket policy that allows it to write logs. If the policy is incorrect or missing, CloudTrail silently fails to start logging.

Make sure your S3 bucket (configured when creating the trail) has the proper policy attached (see example from earlier).

Try stopping and then starting logging again

bash
Copy
Edit
aws cloudtrail stop-logging --name snapshot-trail --region us-east-1
aws cloudtrail start-logging --name snapshot-trail --region us-east-1
Check CloudTrail event history for errors

Check if there are CloudTrail events about logging errors in the AWS Console → CloudTrail → Event history or via CloudWatch Logs if configured.

Quick diagnostic command
You can run this to get detailed trail info:

bash
Copy
Edit
aws cloudtrail get-trail-status --name snapshot-trail --region us-east-1
The output will show whether logging is active, last start time, and any error messages.

Example output snippet:
```json
{
    "IsLogging": false,
    "LatestDeliveryError": "AccessDenied: ...",
    "LatestNotificationError": "",
    "StartLoggingTime": "2025-07-05T07:00:00Z",
    "StopLoggingTime": null,
    "LatestDeliveryTime": "2025-07-05T07:01:00Z"
}
```
If LatestDeliveryError shows something, it likely indicates an S3 permission or policy issue.ied: ...",
    "LatestNotificationError": "",
    "StartLoggingTime": "2025-07-05T07:00:00Z",
    "StopLoggingTime": null,
    "LatestDeliveryTime": "2025-07-05T07:01:00Z"
}
If LatestDeliveryError shows something, it likely indicates an S3 permission or policy issue.

