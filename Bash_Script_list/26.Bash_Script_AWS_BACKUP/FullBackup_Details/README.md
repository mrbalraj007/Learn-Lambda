# AWS Backup Export Script

This script exports comprehensive AWS Backup information including vaults, backup plans, backup rules, and resource assignments to CSV files.

## Prerequisites

- AWS CLI installed and configured
- `jq` command-line JSON processor installed
- Appropriate AWS permissions for AWS Backup operations

## Usage

```bash
chmod +x aws_backup_export.sh
./aws_backup_export.sh
```

## Output Files

The script creates four CSV files with account ID and timestamp in filenames:

1. **backup_vaults_[ACCOUNT_ID]_[TIMESTAMP].csv** - All backup vaults
2. **backup_plans_[ACCOUNT_ID]_[TIMESTAMP].csv** - All backup plans  
3. **backup_rules_[ACCOUNT_ID]_[TIMESTAMP].csv** - All backup rules within plans
4. **resource_assignments_[ACCOUNT_ID]_[TIMESTAMP].csv** - All resource assignments

## Required AWS Permissions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "backup:ListBackupVaults",
                "backup:ListBackupPlans", 
                "backup:GetBackupPlan",
                "backup:ListBackupSelections",
                "backup:GetBackupSelection",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Features

- Processes all backup vaults in the specified region (default: ap-southeast-2)
- Handles null values gracefully
- Creates organized output directory
- Provides progress feedback and summary statistics
- Account ID and timestamp included in filenames only
