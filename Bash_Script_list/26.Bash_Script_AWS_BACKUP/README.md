# AWS Backup Export Script

This script exports AWS Backup information including backup plans, associated vault names, and resource assignments to a single CSV file.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Setup](#setup)
- [Usage](#usage)
- [Output Format](#output-format)
- [Troubleshooting](#troubleshooting)
- [AWS Permissions](#aws-permissions)

## Prerequisites

### 1. AWS CLI Installation
First, ensure AWS CLI is installed on your system:

**Windows:**
```bash
# Download and install AWS CLI v2 from:
# https://awscli.amazonaws.com/AWSCLIV2.msi
```

**Linux/macOS:**
```bash
# Install using curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Or using package manager (Linux)
sudo apt update
sudo apt install awscli

# macOS using Homebrew
brew install awscli
```

### 2. jq Installation
Install jq for JSON processing:

**Windows:**
```bash
# Download jq from: https://stedolan.github.io/jq/download/
# Or use chocolatey
choco install jq
```

**Linux:**
```bash
sudo apt update
sudo apt install jq
```

**macOS:**
```bash
brew install jq
```

### 3. Verify Installations
```bash
# Check AWS CLI version
aws --version

# Check jq version
jq --version
```

## Installation

### Step 1: Download the Script
```bash
# Create directory structure
mkdir -p c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\26.Bash_Script_AWS_BACKUP
cd c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\26.Bash_Script_AWS_BACKUP

# Download or copy the script file
# Save as: aws_backup_export.sh
```

### Step 2: Make Script Executable
```bash
# Make the script executable
chmod +x aws_backup_export.sh
```

## Setup

### Step 1: Configure AWS Credentials
You need to configure AWS CLI with appropriate credentials:

```bash
# Configure AWS CLI
aws configure

# You'll be prompted for:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name (script uses ap-southeast-2)
# - Default output format (json recommended)
```

**Alternative: Using AWS Profiles**
```bash
# Configure with a specific profile
aws configure --profile your-profile-name

# Export profile before running script
export AWS_PROFILE=your-profile-name
```

**Alternative: Using Environment Variables**
```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=ap-southeast-2
```

### Step 2: Verify AWS Access
```bash
# Test AWS connectivity
aws sts get-caller-identity

# Should return your account ID, user ARN, and user ID
```

## Usage

### Step 1: Navigate to Script Directory
```bash
cd c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\26.Bash_Script_AWS_BACKUP
```

### Step 2: Run the Script
```bash
# Basic execution
./aws_backup_export.sh
```

### Step 3: Monitor Progress
The script will display:
- Account ID and region being processed
- Number of backup plans found
- Progress as each backup plan is processed
- Resource assignments being processed

### Step 4: Check Output
After completion, the script will show:
- Output directory name
- CSV file location
- Summary of total entries exported

## Output Format

### Directory Structure
```
aws_backup_export_[ACCOUNT_ID]_[TIMESTAMP]/
└── backup_summary_[ACCOUNT_ID]_[TIMESTAMP].csv
```

### CSV File Columns
| Column | Description |
|--------|-------------|
| BackupPlanName | Name of the backup plan |
| BackupPlanId | Unique identifier for the backup plan |
| BackupVaultName | Target vault name(s) for backups |
| ResourceAssignmentName | Name of the resource assignment/selection |
| IamRoleArn | IAM role ARN used for the backup |
| CreationDate | When the backup plan was created |

### Sample Output
```csv
BackupPlanName,BackupPlanId,BackupVaultName,ResourceAssignmentName,IamRoleArn,CreationDate
MyBackupPlan,12345678-abcd-1234-efgh-123456789012,MyBackupVault,EC2-Resources,arn:aws:iam::123456789012:role/BackupRole,2023-01-15T10:30:00.000Z
```

## Troubleshooting

### Common Issues

#### 1. "Unable to retrieve AWS Account ID"
**Problem:** AWS credentials not configured properly
**Solution:**
```bash
# Check current configuration
aws configure list

# Reconfigure if needed
aws configure
```

#### 2. "Failed to retrieve backup plans"
**Problem:** Insufficient permissions or wrong region
**Solution:**
```bash
# Check current region
aws configure get region

# Test backup permissions
aws backup list-backup-plans --region ap-southeast-2
```

#### 3. "jq: command not found"
**Problem:** jq not installed
**Solution:**
```bash
# Install jq (see Prerequisites section)
```

#### 4. "Permission denied" when running script
**Problem:** Script not executable
**Solution:**
```bash
chmod +x aws_backup_export.sh
```

#### 5. Empty CSV file or no data
**Problem:** No backup plans exist in the region
**Solution:**
```bash
# Verify backup plans exist
aws backup list-backup-plans --region ap-southeast-2

# Check different regions if needed
aws backup list-backup-plans --region us-east-1
```

### Debug Mode
To run the script with debug output:
```bash
# Enable bash debug mode
bash -x ./aws_backup_export.sh
```

## AWS Permissions

### Required IAM Permissions
Your AWS user/role needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "backup:ListBackupPlans",
                "backup:GetBackupPlan",
                "backup:ListBackupSelections",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

### Creating IAM Policy
1. Go to AWS Console → IAM → Policies
2. Click "Create Policy"
3. Use JSON tab and paste the above policy
4. Name it "BackupExportPolicy"
5. Attach to your user/role

### Minimum Required Role
If using an IAM role, ensure it has:
- `AWSBackupServiceRolePolicyForBackup` (AWS managed policy)
- Or the custom policy above

## Script Customization

### Change Default Region
Edit the script to change the default region:
```bash
# Change this line in the script:
AWS_REGION="us-east-1"  # Change from ap-southeast-2
```

### Add More Columns
To add more backup plan details, modify the CSV header and data extraction sections in the script.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify AWS permissions
3. Test AWS CLI commands manually
4. Check AWS CloudTrail for API errors

## Version History

- v1.0: Initial release with basic backup plan export
- v1.1: Added resource assignment details
- v1.2: Simplified to single CSV output format
