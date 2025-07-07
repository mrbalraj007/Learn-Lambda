# 🏷️ AWS Backup Resource Tagging Automation

[![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![CloudFormation](https://img.shields.io/badge/CloudFormation-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/cloudformation/)
[![Lambda](https://img.shields.io/badge/Lambda-FF9900?style=for-the-badge&logo=aws-lambda&logoColor=white)](https://aws.amazon.com/lambda/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org/)
[![EventBridge](https://img.shields.io/badge/EventBridge-FF4F8B?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eventbridge/)

> 🚀 **Automated resource lifecycle management for AWS Backup snapshots and AMIs with event-driven tagging**

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [✨ Features](#-features)
- [🏗️ Architecture](#️-architecture)
- [📋 Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📝 Step-by-Step Deployment](#-step-by-step-deployment)
- [⚙️ Configuration](#️-configuration)
- [🔍 Monitoring](#-monitoring)
- [🧪 Testing](#-testing)
- [🔧 Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)

## 🎯 Overview

This solution provides **automated tagging** for AWS resources created by AWS Backup service. It ensures proper lifecycle management by tagging snapshots and AMIs with retention metadata for automated cleanup.

### 🎪 How It Works

| Trigger | Action | Result |
|---------|--------|--------|
| 📅 **Backup Completion** | EventBridge → Lambda | Tags specific backup resources |
| ⏰ **Daily Schedule** | CloudWatch Events → Lambda | Tags all existing resources (fallback) |

## ✨ Features

- 🎯 **Event-Driven Tagging** - Responds to AWS Backup completion events
- 📅 **Scheduled Fallback** - Daily tagging for comprehensive coverage
- 🏷️ **Standardized Tags** - Consistent retention and lifecycle metadata
- 📊 **Comprehensive Logging** - CloudWatch integration for monitoring
- 🛡️ **IAM Best Practices** - Least privilege security model
- ⚡ **Cost Optimized** - Minimal resource usage and 14-day log retention

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AWS Backup  │───▶│   EventBridge   │───▶│ Lambda Function │
│   Service   │    │    (Events)     │    │ BackupAware     │
└─────────────┘    └─────────────────┘    │    Tagger       │
                            │              └─────────┬───────┘
┌─────────────┐             │                        │
│ CloudWatch  │─────────────┘                        ▼
│   Events    │                              ┌───────────────┐
│ (Scheduler) │                              │  EC2 Resources│
└─────────────┘                              │ • Snapshots   │
                                             │ • AMIs        │
                                             └───────────────┘
```

## 📋 Prerequisites

### 🔑 AWS Account Requirements

- ✅ **AWS Account** with appropriate permissions
- ✅ **AWS CLI** configured with credentials
- ✅ **CloudFormation** deployment permissions
- ✅ **AWS Backup** service already configured

### 🛠️ Technical Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| 🐍 **Python** | 3.12+ | Lambda runtime |
| ☁️ **AWS CLI** | 2.0+ | Deployment tool |
| 📝 **CloudFormation** | Latest | Infrastructure as Code |

### 🔐 IAM Permissions Required

The deploying user/role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "lambda:*",
        "iam:*",
        "logs:*",
        "events:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🚀 Quick Start

### 1️⃣ Clone Repository
```bash
git clone <your-repository>
cd snapshot-automation
```

### 2️⃣ Deploy Stack
```bash
aws cloudformation deploy \
  --template-file tag-ec2-backup.yaml \
  --stack-name backup-resource-tagger \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 3️⃣ Verify Deployment
```bash
aws cloudformation describe-stacks \
  --stack-name backup-resource-tagger \
  --query 'Stacks[0].StackStatus'
```

## 📝 Step-by-Step Deployment

### Step 1: 📥 Download Template

```bash
# Download the CloudFormation template
curl -O https://your-repo/tag-ec2-backup.yaml
```

### Step 2: 🔍 Validate Template

```bash
# Validate CloudFormation template syntax
aws cloudformation validate-template \
  --template-body file://tag-ec2-backup.yaml
```

### Step 3: 🚀 Deploy Infrastructure

```bash
# Deploy the complete stack
aws cloudformation create-stack \
  --stack-name backup-resource-tagger \
  --template-body file://tag-ec2-backup.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=RetentionDays,ParameterValue=90
```

### Step 4: ⏳ Monitor Deployment

```bash
# Watch stack creation progress
aws cloudformation describe-stack-events \
  --stack-name backup-resource-tagger \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table
```

### Step 5: ✅ Verify Resources

```bash
# List created resources
aws cloudformation list-stack-resources \
  --stack-name backup-resource-tagger \
  --output table
```

## ⚙️ Configuration

### 🎛️ Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RETENTION_DAYS` | `90` | Number of days to retain resources |

### 🏷️ Applied Tags

| Tag Key | Example Value | Purpose |
|---------|---------------|---------|
| `Retention` | `90days` | Retention period |
| `DeleteOn` | `2024-03-15` | Calculated deletion date |
| `BackupSource` | `AWS-Backup` | Source identifier |
| `BackupJobId` | `job-abc123` | Backup job reference |

### 📅 Scheduling

- **Primary**: Event-driven (AWS Backup completion)
- **Fallback**: Daily at midnight UTC
- **Retry**: Built-in Lambda retry mechanism

## 🔍 Monitoring

### 📊 CloudWatch Dashboards

Create custom dashboard to monitor:

```bash
# View Lambda function metrics
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/BackupAwareTagger"
```

### 🚨 Alarms Setup

```bash
# Create CloudWatch alarm for function errors
aws cloudwatch put-metric-alarm \
  --alarm-name "BackupTagger-Errors" \
  --alarm-description "Lambda function errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=FunctionName,Value=BackupAwareTagger
```

### 📈 Key Metrics

| Metric | Description | Threshold |
|--------|-------------|-----------|
| 🔴 **Errors** | Function execution errors | > 0 |
| ⏱️ **Duration** | Execution time | > 30s |
| 🔄 **Invocations** | Function calls | Monitor trends |

## 🧪 Testing

### 🎯 Manual Testing

#### Test Backup Event
```bash
# Trigger a test backup completion event
aws events put-events \
  --entries '[
    {
      "Source": "aws.backup",
      "DetailType": "Backup Job State Change",
      "Detail": "{\"backupJobId\":\"test-job-123\",\"state\":\"COMPLETED\",\"resourceArn\":\"arn:aws:ec2:us-east-1:123456789012:snapshot/snap-test123\"}"
    }
  ]'
```

#### Test Scheduled Event
```bash
# Invoke Lambda function directly
aws lambda invoke \
  --function-name BackupAwareTagger \
  --payload '{}' \
  response.json && cat response.json
```

### 🔬 Validation Steps

1. **Check Tags Applied**
   ```bash
   # Verify tags on snapshots
   aws ec2 describe-snapshots \
     --owner-ids self \
     --query 'Snapshots[*].[SnapshotId,Tags]'
   ```

2. **Review Logs**
   ```bash
   # Check Lambda execution logs
   aws logs filter-log-events \
     --log-group-name "/aws/lambda/BackupAwareTagger" \
     --start-time $(date -d '1 hour ago' +%s)000
   ```

## 🔧 Troubleshooting

### ❌ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| 🚫 **Permission Denied** | Insufficient IAM permissions | Update IAM policy |
| ⏰ **Function Timeout** | Large number of resources | Increase timeout/memory |
| 🏷️ **Tags Not Applied** | Resource doesn't exist | Check resource ARN format |

### 🔍 Debug Commands

```bash
# Check Lambda function configuration
aws lambda get-function --function-name BackupAwareTagger

# View recent log events
aws logs describe-log-streams \
  --log-group-name "/aws/lambda/BackupAwareTagger" \
  --order-by LastEventTime \
  --descending \
  --max-items 1

# Test IAM permissions
aws sts get-caller-identity
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ec2:CreateTags \
  --resource-arns "*"
```

### 📞 Support

- 📚 **Documentation**: [AWS Lambda Guide](https://docs.aws.amazon.com/lambda/)
- 🐛 **Issues**: [Create GitHub Issue](https://github.com/your-repo/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)

## 🔄 Updates & Maintenance

### 🔄 Stack Updates

```bash
# Update existing stack
aws cloudformation update-stack \
  --stack-name backup-resource-tagger \
  --template-body file://tag-ec2-backup.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### 🗑️ Cleanup

```bash
# Delete the complete stack
aws cloudformation delete-stack \
  --stack-name backup-resource-tagger

# Verify deletion
aws cloudformation describe-stacks \
  --stack-name backup-resource-tagger
```

## 🤝 Contributing

1. 🍴 **Fork** the repository
2. 🌿 **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. 💍 **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. 📤 **Push** to branch (`git push origin feature/amazing-feature`)
5. 🎉 **Open** a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- ☁️ **AWS Documentation** team for excellent guides
- 🐍 **Python Community** for boto3 library
- 🛠️ **CloudFormation** for Infrastructure as Code

---

<div align="center">

### 🌟 Star this repository if it helped you! 🌟

[![GitHub stars](https://img.shields.io/github/stars/your-repo/aws-backup-tagger?style=social)](https://github.com/your-repo/aws-backup-tagger)

</div>

---

> 💡 **Pro Tip**: Set up CloudWatch alarms to monitor the health of your backup tagging automation!

*Last Updated: $(date +'%Y-%m-%d')*