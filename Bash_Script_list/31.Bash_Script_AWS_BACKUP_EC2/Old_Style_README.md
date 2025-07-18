# EC2 Backup Script using AWS Backup Service

## Overview

This bash script automates the backup process for multiple EC2 instances using AWS native backup services. It reads EC2 instance IDs from a CSV file and creates comprehensive backups using AWS Backup service.

## What This Script Does

### ✅ **Comprehensive EC2 Backup**
- **Instance Backup**: Creates complete snapshots of EC2 instances
- **Volume Backup**: Automatically includes ALL attached EBS volumes (root and additional volumes)
- **Metadata Backup**: Preserves instance configuration, tags, and metadata
- **Point-in-Time Recovery**: Creates recovery points that can restore the entire instance

### ✅ **AWS Native Integration**
- Uses **AWS Backup service** for enterprise-grade backup management
- Leverages **AWS Backup Vault** for centralized backup storage
- Integrates with **AWS IAM** for secure backup operations
- Supports **cross-region** and **cross-account** backup scenarios

### ✅ **Batch Processing**
- Processes multiple EC2 instances from a CSV file
- Handles both running and stopped instances
- Validates instance existence before backup
- Provides detailed logging for each backup operation

## Features

### 🔧 **Automated Backup Management**
- **Idempotent Operations**: Prevents duplicate backups with unique tokens
- **Error Handling**: Comprehensive error detection and reporting
- **Validation**: Checks instance existence and state before backup
- **Logging**: Detailed timestamped logs for audit and troubleshooting

### 📊 **Backup Tracking**
- Real-time backup job status
- Success/failure statistics
- Backup job ID tracking
- Comprehensive reporting

### 🏷️ **Backup Tagging**
- Auto-tags backups with instance information
- Includes backup type and creation details
- Enables easy backup identification and management

## Prerequisites

### 1. AWS CLI Configuration
```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure
```

### 2. AWS Backup Vault
Create a backup vault in AWS Console or using CLI:
```bash
aws backup create-backup-vault \
    --backup-vault-name "EC2-Backup" \
    --encryption-key-arn "arn:aws:kms:region:account:key/key-id"
```

### 3. IAM Role and Permissions
The script requires an IAM role with the following permissions:
- `AWSBackupServiceRolePolicyForBackup`
- `AWSBackupServiceRolePolicyForRestores`
- EC2 read permissions for instance validation

### 4. CSV File Format
Create `ec2_instances.csv` with the following format:
```csv
instance_id
i-022bf7d6ddcf31ddc
i-0b19d4e150c8fca6e
i-1234567890abcdef0
```

## Configuration

### Script Configuration Variables
```bash
CSV_FILE="ec2_instances.csv"                    # CSV file with instance IDs
BACKUP_VAULT_NAME="EC2-Backup"                  # AWS Backup vault name
IAM_ROLE_ARN="arn:aws:iam::ACCOUNT:role/..."   # IAM role for backup operations
```

### Update IAM Role ARN
Replace the placeholder in the script:
```bash
IAM_ROLE_ARN="arn:aws:iam::YOUR-ACCOUNT-ID:role/service-role/AWSBackupDefaultServiceRole"
```

## Usage

### Basic Usage
```bash
# Make script executable
chmod +x start-ec2-backup.sh

# Run the backup script
./start-ec2-backup.sh
```

### What Happens During Backup

1. **Prerequisites Check**:
   - Validates AWS CLI installation
   - Checks AWS credentials
   - Verifies backup vault existence

2. **Instance Processing**:
   - Reads instance IDs from CSV
   - Validates each instance exists
   - Checks instance state (running/stopped)

3. **Backup Creation**:
   - Creates backup job for each instance
   - Includes ALL attached EBS volumes automatically
   - Tags backup with metadata
   - Generates unique backup job ID

4. **Logging and Reporting**:
   - Creates timestamped log file
   - Reports success/failure for each instance
   - Provides summary statistics

## Backup Coverage

### ✅ **What's Included in Backup**
- **Root EBS Volume**: Operating system and boot files
- **Additional EBS Volumes**: All attached data volumes
- **Instance Metadata**: AMI ID, instance type, security groups
- **Network Configuration**: VPC, subnet, security group associations
- **Tags**: Instance tags and custom metadata

### ❌ **What's NOT Included**
- **Instance Store Volumes**: Ephemeral storage (by design)
- **External Attachments**: Load balancers, auto-scaling groups
- **Network Interfaces**: Secondary ENIs (backed up separately)

## Output and Logging

### Log File Format
```
[2025-07-18 21:10:45] ==== Starting EC2 Backup Process ====
[2025-07-18 21:10:45] Backup Vault: EC2-Backup
[2025-07-18 21:10:45] Region: us-east-1
[2025-07-18 21:10:49] ✅ Prerequisites check passed
[2025-07-18 21:10:52] ℹ️  Instance i-022bf7d6ddcf31ddc is in state: running
[2025-07-18 21:10:54] Starting backup for instance: i-022bf7d6ddcf31ddc
[2025-07-18 21:10:56] ✅ Backup job started successfully for i-022bf7d6ddcf31ddc
[2025-07-18 21:10:56]    Job ID: 12345678-1234-1234-1234-123456789012
```

### Summary Report
```
==== Backup Process Completed ====
Total instances processed: 2
Successful backups: 2
Failed backups: 0
Log file: backup_log_2025-07-18_21:10:44.log
```

## Troubleshooting

### Common Issues

1. **"Backup vault not found"**
   - Create backup vault in AWS Console
   - Verify vault name matches script configuration

2. **"Invalid IAM role"**
   - Check IAM role ARN is correct
   - Verify role has required permissions

3. **"Instance not found"**
   - Verify instance IDs in CSV file
   - Check instances exist in the current region

4. **"Access denied"**
   - Verify AWS credentials have necessary permissions
   - Check IAM role trust relationships

## Advanced Features

### Backup Retention
- Retention policies are managed through AWS Backup Vault settings
- Configure lifecycle rules in AWS Console
- Set automatic deletion policies

### Cross-Region Backup
- Configure cross-region replication in backup vault
- Modify script for multi-region support

### Monitoring
- Integrate with AWS CloudWatch for backup monitoring
- Set up SNS notifications for backup status

## Security Considerations

- **IAM Roles**: Use least privilege principle
- **Encryption**: Backups are encrypted using AWS KMS
- **Access Control**: Restrict backup vault access
- **Audit**: All backup operations are logged in CloudTrail

## Cost Optimization

- **Backup Frequency**: Schedule backups during off-peak hours
- **Retention**: Set appropriate retention periods
- **Cross-Region**: Consider costs for cross-region replication
- **Lifecycle**: Use lifecycle policies to manage storage costs

## Support

For issues or questions:
1. Check AWS Backup documentation
2. Review CloudTrail logs for detailed error information
3. Verify IAM permissions and backup vault configuration
4. Test with a single instance before batch processing
