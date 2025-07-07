# EC2 Snapshot Automation - AMI and Snapshot Tagging

This project automatically tags AMIs and EBS snapshots with retention and deletion date information using AWS Lambda and CloudFormation.

## 📁 Project Structure

```
21.snapshot-automation/RND1/
├── tag-ec2-backup.yaml       # CloudFormation template
├── tag_ami_snapshot.py       # Lambda function code
├── Readme.MD                 # This file
└── tag-ec2-backup.zip        # Deployment package (generated)
```

## 🏗️ CloudFormation Resources

The `tag-ec2-backup.yaml` template creates the following AWS resources:

### 1. IAM Role (`TagBackupLambdaRole`)
- **Purpose**: Provides necessary permissions for Lambda execution
- **Permissions**: 
  - EC2: DescribeImages, DescribeSnapshots, CreateTags
  - CloudWatch Logs: Basic execution role permissions
- **Naming**: `TagEC2BackupsLambdaRole-{Region}` (region-specific to avoid conflicts)

### 2. CloudWatch Log Group (`TagBackupLambdaLogGroup`)
- **Purpose**: Stores Lambda function logs
- **Retention**: 14 days
- **Log Group**: `/aws/lambda/TagEC2Backups`

### 3. Lambda Function (`TagBackupLambdaFunction`)
- **Name**: `TagEC2Backups`
- **Runtime**: Python 3.12
- **Timeout**: 300 seconds (5 minutes)
- **Memory**: 128 MB
- **Environment Variables**:
  - `RETENTION_DAYS`: "90" (configurable retention period)

### 4. EventBridge Rule (`LambdaScheduleRule`)
- **Schedule**: Daily execution (`rate(1 day)`)
- **Purpose**: Triggers Lambda function automatically
- **Name**: `DailyEC2BackupTagger-{Region}`

### 5. Lambda Permission (`LambdaInvokePermission`)
- **Purpose**: Allows EventBridge to invoke the Lambda function

## 📦 Lambda Function Features

The `tag_ami_snapshot.py` script:
- ✅ Tags all owned AMIs with retention information
- ✅ Tags all owned EBS snapshots with retention information
- ✅ Includes comprehensive error handling and logging
- ✅ Returns detailed execution results
- ✅ Calculates deletion dates based on retention days

### Tags Applied:
- `Retention`: `{RETENTION_DAYS}days` (e.g., "90days")
- `DeleteOn`: `YYYY-MM-DD` (calculated deletion date)

✅ 3. Zip Package (tag-ec2-backup.zip)
Structure:

```
tag-ec2-backup.zip
└── tag_ami_snapshot.py
```

To create the zip file:

```bash
zip tag-ec2-backup.zip tag_ami_snapshot.py
```

Then upload it to S3:

```bash
aws s3 cp tag-ec2-backup.zip s3://demo-terra22062025/
```

## 🚀 Deployment Steps

### Prerequisites
- AWS CLI configured with appropriate permissions
- S3 bucket for Lambda deployment package storage
- IAM permissions to create Lambda functions, IAM roles, and EventBridge rules

### Step 1: Prepare Lambda Package
```bash
# Create the deployment package
zip tag-ec2-backup.zip tag_ami_snapshot.py

# Upload to your S3 bucket
aws s3 cp tag-ec2-backup.zip s3://demo-terra22062025/
```

### Step 2: Update CloudFormation Template
1. Open `tag-ec2-backup.yaml`
2. Update the S3 bucket name in the Lambda function code section:
   ```yaml
   Code:
     S3Bucket: your-bucket-name-here  # Replace with your bucket
     S3Key: tag-ec2-backup.zip
   ```

### Step 3: Deploy CloudFormation Stack
```bash
aws cloudformation deploy \
  --template-file tag-ec2-backup.yaml \
  --stack-name TagEC2BackupsStack \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Step 4: Verify Deployment
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name TagEC2BackupsStack

# Test Lambda function manually
aws lambda invoke \
  --function-name TagEC2Backups \
  --payload '{}' \
  response.json && cat response.json
```

## ⚙️ Configuration

### Environment Variables
- `RETENTION_DAYS`: Number of days to retain backups (default: 90)

### Customization Options
1. **Schedule**: Modify `ScheduleExpression` in CloudFormation template
   - Current: `rate(1 day)` (daily)
   - Examples: `rate(12 hours)`, `cron(0 2 * * ? *)` (2 AM daily)

2. **Retention Period**: Update `RETENTION_DAYS` environment variable
3. **Memory/Timeout**: Adjust Lambda function configuration as needed

## 📊 Monitoring

### CloudWatch Logs
- Log Group: `/aws/lambda/TagEC2Backups`
- Retention: 14 days
- View logs: AWS Console → CloudWatch → Log Groups

### Function Metrics
- Execution count, duration, and errors available in CloudWatch
- Set up alarms for failed executions if needed

## 🔒 Security Considerations

- IAM role follows least privilege principle
- Only allows tagging of owned resources (`Owners=['self']`)
- No broad resource access permissions
- Region-specific resource naming prevents conflicts

## ✅ Expected Behavior

This automation will:
- ✅ Run every 24 hours automatically
- ✅ Tag all owned AMIs and snapshots with:
  - `Retention=90days`
  - `DeleteOn=YYYY-MM-DD` (calculated based on current date + retention days)
- ✅ Log all tagging activities to CloudWatch
- ✅ Handle errors gracefully without stopping execution
- ✅ Return execution summary with counts of tagged resources

## 🚨 Troubleshooting

### 🔴 Runtime.ImportModuleError: No module named 'tag_ami_snapshot'

This error occurs when the Lambda deployment package is incorrect. Follow these steps:

#### 1. Check Current Lambda Code
```bash
# Download current code from Lambda
aws lambda get-function --function-name TagEC2Backups --query 'Code.Location' --output text
```

#### 2. Recreate Deployment Package
```bash
# Delete old package
rm -f tag-ec2-backup.zip

# Create new package with verbose output
zip -v tag-ec2-backup.zip tag_ami_snapshot.py

# Verify contents
unzip -l tag-ec2-backup.zip
```

#### 3. Update Lambda Function Code
```bash
# Re-upload to S3
aws s3 cp tag-ec2-backup.zip s3://demo-terra22062025/ --force

# Update Lambda function code directly (alternative method)
aws lambda update-function-code \
  --function-name TagEC2Backups \
  --s3-bucket demo-terra22062025 \
  --s3-key tag-ec2-backup.zip
```

#### 4. Test Again
```bash
aws lambda invoke \
  --function-name TagEC2Backups \
  --payload '{}' \
  response.json && cat response.json
```

### Alternative: Inline Code Update
If S3 upload continues to fail, update the code inline:

```bash
# Encode Python file to base64
base64 tag_ami_snapshot.py > encoded.txt

# Update function code directly
aws lambda update-function-code \
  --function-name TagEC2Backups \
  --zip-file fileb://tag-ec2-backup.zip
```

### Common Issues:
1. **S3 Access Denied**: Ensure Lambda execution role has access to S3 bucket
2. **No Resources Tagged**: Check if you have AMIs/snapshots in the region
3. **Permission Errors**: Verify IAM role has required EC2 permissions
4. **Timeout**: Increase Lambda timeout if you have many resources
5. **Import Module Error**: Recreate and re-upload the deployment package

### Debug Commands:
```bash
# Check recent executions
aws logs describe-log-streams --log-group-name "/aws/lambda/TagEC2Backups"

# View latest logs
aws logs get-log-events --log-group-name "/aws/lambda/TagEC2Backups" \
  --log-stream-name "$(aws logs describe-log-streams --log-group-name "/aws/lambda/TagEC2Backups" --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text)"

# Check Lambda function configuration
aws lambda get-function-configuration --function-name TagEC2Backups

# List S3 bucket contents
aws s3 ls s3://demo-terra22062025/
```

### Quick Fix Script
Create this script to automate the fix:

```bash
#!/bin/bash
# fix-lambda-deployment.sh

echo "Fixing Lambda deployment package..."

# Recreate package
rm -f tag-ec2-backup.zip
zip tag-ec2-backup.zip tag_ami_snapshot.py

# Verify package
echo "Package contents:"
unzip -l tag-ec2-backup.zip

# Upload to S3
aws s3 cp tag-ec2-backup.zip s3://demo-terra22062025/

# Update Lambda function
aws lambda update-function-code \
  --function-name TagEC2Backups \
  --s3-bucket demo-terra22062025 \
  --s3-key tag-ec2-backup.zip

# Test function
echo "Testing function..."
aws lambda invoke \
  --function-name TagEC2Backups \
  --payload '{}' \
  response.json && cat response.json

echo "Fix complete!"
```

Make it executable and run:
```bash
chmod +x fix-lambda-deployment.sh
./fix-lambda-deployment.sh
```