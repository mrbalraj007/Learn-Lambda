# 🚀 EC2 Backup Automation Script

<div align="center">

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

**🔄 Automated EC2 Instance Backup using AWS Native Services**

*Professional-grade backup solution for multiple EC2 instances with comprehensive volume coverage*

</div>

---

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [✨ Features](#-features)
- [📦 What's Included in Backup](#-whats-included-in-backup)
- [🔧 Prerequisites](#-prerequisites)
- [⚙️ Setup Guide](#️-setup-guide)
- [🚀 Usage](#-usage)
- [📊 Output & Logging](#-output--logging)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [💰 Cost Optimization](#-cost-optimization)
- [🔒 Security](#-security)

---

## 🎯 Overview

This **bash script** automates the backup process for multiple EC2 instances using **AWS Backup service**. It reads EC2 instance IDs from a CSV file and creates comprehensive backups including all attached EBS volumes.

### 🌟 Key Benefits

> 🔄 **Automated Batch Processing**  
> 📊 **Comprehensive Logging**  
> 🛡️ **Enterprise-grade Security**  
> 💾 **Complete Volume Coverage**  
> 🏷️ **Intelligent Tagging**  

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🔧 **Backup Management**
- ✅ **Idempotent Operations** - Prevents duplicates
- ✅ **Error Handling** - Comprehensive error detection
- ✅ **Validation** - Instance existence checks
- ✅ **Logging** - Detailed audit trails

</td>
<td width="50%">

### 📊 **Monitoring & Tracking**
- ✅ **Real-time Status** - Live backup progress
- ✅ **Success/Failure Stats** - Detailed reporting
- ✅ **Job ID Tracking** - Unique backup identifiers
- ✅ **Comprehensive Reports** - Summary statistics

</td>
</tr>
</table>

---

## 📦 What's Included in Backup

### 🟢 **Included Components**

| Component | Description | Status |
|-----------|-------------|--------|
| 💽 **Root EBS Volume** | Operating system and boot files | ✅ **Included** |
| 📁 **Additional EBS Volumes** | All attached data volumes | ✅ **Included** |
| 🏷️ **Instance Metadata** | AMI ID, instance type, security groups | ✅ **Included** |
| 🌐 **Network Configuration** | VPC, subnet, security group associations | ✅ **Included** |
| 📋 **Tags** | Instance tags and custom metadata | ✅ **Included** |

### 🔴 **Not Included**

| Component | Reason | Alternative |
|-----------|--------|-------------|
| 💨 **Instance Store Volumes** | Ephemeral storage (by design) | Use EBS volumes |
| ⚖️ **Load Balancers** | External resource | Separate backup strategy |
| 🔗 **Auto Scaling Groups** | Configuration resource | CloudFormation templates |

---

## 🔧 Prerequisites

### 1️⃣ **AWS CLI Setup**

```bash
# 📥 Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# ✅ Verify installation
aws --version

# 🔑 Configure credentials
aws configure
```

### 2️⃣ **AWS Backup Vault Creation**

**Option A: Using AWS Console** 🖥️
1. Navigate to **AWS Backup** service
2. Click **Backup vaults** → **Create backup vault**
3. Enter vault name: `EC2-Backup`
4. Select encryption key
5. Click **Create backup vault**

**Option B: Using CLI** 💻
```bash
aws backup create-backup-vault \
    --backup-vault-name "EC2-Backup" \
    --encryption-key-arn "arn:aws:kms:region:account:key/key-id"
```

### 3️⃣ **IAM Role Configuration**

**Required Permissions:**
- `AWSBackupServiceRolePolicyForBackup`
- `AWSBackupServiceRolePolicyForRestores`
- EC2 read permissions

**Trust Relationship:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "backup.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 4️⃣ **CSV File Preparation**

Create `ec2_instances.csv` with instance IDs:

```csv
instance_id
i-022bf7d6ddcf31ddc
i-0b19d4e150c8fca6e
i-1234567890abcdef0
```

---

## ⚙️ Setup Guide

### 🔧 **Step 1: Download and Configure**

```bash
# 📂 Create project directory
mkdir ec2-backup-automation
cd ec2-backup-automation

# 📥 Download script (if from repository)
# Or create the script file manually

# 🔧 Make executable
chmod +x start-ec2-backup.sh
```

### 🔧 **Step 2: Update Configuration**

Edit the script configuration variables:

```bash
# 📝 Edit configuration section
nano start-ec2-backup.sh

# Update these variables:
CSV_FILE="ec2_instances.csv"
BACKUP_VAULT_NAME="EC2-Backup"
IAM_ROLE_ARN="arn:aws:iam::YOUR-ACCOUNT-ID:role/service-role/AWSBackupDefaultServiceRole"
```

### 🔧 **Step 3: Prepare Instance List**

```bash
# 📝 Create CSV file
nano ec2_instances.csv

# Add your instance IDs (one per line after header)
```

---

<!-- # AWS EC2 Backup with AWS Backup CLI

This guide provides useful AWS CLI commands for managing EC2 backups using AWS Backup. Follow the steps below to get IAM role ARNs, start backup jobs, and monitor backup status.

--- -->


### Get IAM Role ARN

To retrieve the ARN for your AWS Backup roles:

```bash
aws iam get-role --role-name AWSBackupDefaultServiceRole --query 'Role.Arn' --output text
```

Or for a custom role:

```bash
aws iam get-role --role-name AWSBackupEC2Role --query 'Role.Arn' --output text
```

Use the resulting ARN in your Bash scripts as `IAM_ROLE_ARN`.

---

## 🚀 Usage

### 🎯 **Basic Execution**

```bash
# 🚀 Run the backup script
./start-ec2-backup.sh
```

### 📋 **What Happens During Execution**

<details>
<summary>🔍 <strong>Click to expand execution flow</strong></summary>

#### **Phase 1: Prerequisites Check** 🔍
- ✅ Validates AWS CLI installation
- ✅ Checks AWS credentials
- ✅ Verifies backup vault existence

#### **Phase 2: Instance Processing** 📋
- ✅ Reads instance IDs from CSV
- ✅ Validates each instance exists
- ✅ Checks instance state (running/stopped)

#### **Phase 3: Backup Creation** 💾
- ✅ Creates backup job for each instance
- ✅ Includes ALL attached EBS volumes automatically
- ✅ Tags backup with metadata
- ✅ Generates unique backup job ID

#### **Phase 4: Logging and Reporting** 📊
- ✅ Creates timestamped log file
- ✅ Reports success/failure for each instance
- ✅ Provides summary statistics

</details>

---

## 📊 Output & Logging

### 📝 **Log File Format**

```bash
[2025-07-18 21:10:45] 🚀 ==== Starting EC2 Backup Process ====
[2025-07-18 21:10:45] 🏗️  Backup Vault: EC2-Backup
[2025-07-18 21:10:45] 🌍 Region: us-east-1
[2025-07-18 21:10:49] ✅ Prerequisites check passed
[2025-07-18 21:10:52] ℹ️  Instance i-022bf7d6ddcf31ddc is in state: running
[2025-07-18 21:10:54] 🔄 Starting backup for instance: i-022bf7d6ddcf31ddc
[2025-07-18 21:10:56] ✅ Backup job started successfully for i-022bf7d6ddcf31ddc
[2025-07-18 21:10:56]    📋 Job ID: 12345678-1234-1234-1234-123456789012
```


## Monitor Backup Jobs

### Get the Status of a Backup Job

Once a backup job is submitted, monitor its status with:

```bash
aws backup describe-backup-job --backup-job-id <backup-job-id>
```
Replace `<backup-job-id>` with your actual job ID.


### List All Backup Jobs for a Vault

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --query 'BackupJobs[*].{JobId:BackupJobId,Resource:ResourceArn,Status:State,CreatedAt:CreationDate}' \
  --output table
```

### List Only Recent Jobs (Last 24 Hours)

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --by-created-after "$(date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'BackupJobs[*].{JobId:BackupJobId,Resource:ResourceArn,Status:State,CreatedAt:CreationDate}' \
  --output table
```

---

### Export Backup Jobs to CSV

#### Option 1: Export All Jobs

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --query 'BackupJobs[*].[BackupJobId,ResourceArn,State,CreationDate]' \
  --output text | \
  awk 'BEGIN {print "JobId,Resource,Status,CreatedAt"} {print $1","$2","$3","$4}' \
  > backup_jobs.csv
```
---

## Advanced Queries

### Get Last 6 Backup Jobs (Most Recent)

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --query 'reverse(sort_by(BackupJobs, &CreationDate))[:6].{JobId:BackupJobId,Resource:ResourceArn,Status:State,CreatedAt:CreationDate}' \
  --output table
```
*Gets the last 6 jobs, sorted by creation time (descending).*

---

### Get Jobs from the Last 6 Hours (CSV Output)

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --by-created-after "$(date -u -d '-6 hours' +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'BackupJobs[*].[BackupJobId,ResourceArn,State,CreationDate]' \
  --output text | \
  awk 'BEGIN {print "JobId,Resource,Status,CreatedAt"} {print $1","$2","$3","$4}' \
  > last_6_hours_backup_jobs.csv
```
*Filters jobs created in the last 6 hours and saves results to `last_6_hours_backup_jobs.csv`.*

---

### Bonus: Get Jobs from the Last 24 Hours (CSV Output)

```bash
aws backup list-backup-jobs \
  --by-backup-vault-name "EC2-Backup" \
  --by-created-after "$(date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'BackupJobs[*].[BackupJobId,ResourceArn,State,CreationDate]' \
  --output text | \
  awk 'BEGIN {print "JobId,Resource,Status,CreatedAt"} {print $1","$2","$3","$4}' \
  > last_24_hours_backup_jobs.csv
```
---

## Notes

- Replace `"EC2-Backup"` with your actual backup vault name.
- You can open the `.csv` files in Excel or import them into dashboards for further analysis.

### 📈 **Summary Report**

```bash
🏁 ==== Backup Process Completed ====
📊 Total instances processed: 2
✅ Successful backups: 2
❌ Failed backups: 0
📄 Log file: backup_log_2025-07-18_21:10:44.log
```

---

## 🛠️ Troubleshooting

<details>
<summary>🔧 <strong>Common Issues & Solutions</strong></summary>

### ❌ **"Backup vault not found"**
```bash
# 🔍 Check vault exists
aws backup describe-backup-vault --backup-vault-name "EC2-Backup"

# 🛠️ Solution: Create backup vault or update script configuration
```

### ❌ **"Invalid IAM role"**
```bash
# 🔍 Verify IAM role ARN
aws iam get-role --role-name AWSBackupDefaultServiceRole

# 🛠️ Solution: Update IAM_ROLE_ARN in script
```

### ❌ **"Instance not found"**
```bash
# 🔍 Check instance exists
aws ec2 describe-instances --instance-ids i-1234567890abcdef0

# 🛠️ Solution: Verify instance IDs in CSV file
```

### ❌ **"Access denied"**
```bash
# 🔍 Check AWS credentials
aws sts get-caller-identity

# 🛠️ Solution: Configure proper AWS credentials
```

</details>

---

## 💰 Cost Optimization

### 💡 **Best Practices**

| Strategy | Description | Impact |
|----------|-------------|---------|
| ⏰ **Scheduled Backups** | Run during off-peak hours | 🔽 **Reduced costs** |
| 📅 **Retention Policies** | Set appropriate retention periods | 🔽 **Storage savings** |
| 🌍 **Regional Strategy** | Consider cross-region costs | 🔽 **Transfer costs** |
| 📊 **Monitoring** | Track backup storage usage | 🔽 **Optimization** |

### 💵 **Cost Factors**

- **Backup Storage**: $0.05 per GB per month
- **Cross-Region Copy**: $0.02 per GB transferred
- **Restore Operations**: $0.02 per GB restored

---

## 🔒 Security

### 🛡️ **Security Measures**

```mermaid
graph LR
    A[🔐 IAM Roles] --> B[🔒 Encryption]
    B --> C[🚫 Access Control]
    C --> D[📋 Audit Logging]
```

| Security Layer | Implementation | Status |
|----------------|---------------|--------|
| 🔐 **IAM Roles** | Least privilege principle | ✅ **Implemented** |
| 🔒 **Encryption** | AWS KMS encryption | ✅ **Implemented** |
| 🚫 **Access Control** | Backup vault policies | ✅ **Implemented** |
| 📋 **Audit Trail** | CloudTrail logging | ✅ **Implemented** |

---

## 🤝 Support & Contributing

### 📞 **Getting Help**

1. 📚 Check [AWS Backup Documentation](https://docs.aws.amazon.com/aws-backup/)
2. 🔍 Review CloudTrail logs for detailed error information
3. ✅ Verify IAM permissions and backup vault configuration
4. 🧪 Test with a single instance before batch processing

### 🏷️ **Version Information**

- **Script Version**: 1.0.0
- **AWS CLI Version**: 2.0+
- **Bash Version**: 4.0+

---

<div align="center">

**🌟 Star this project if it helps you! 🌟**

![AWS Backup](https://img.shields.io/badge/AWS-Backup-orange)
![Automation](https://img.shields.io/badge/Automation-Bash-green)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)

---

*Made with ❤️ for AWS DevOps Engineers*

</div>






