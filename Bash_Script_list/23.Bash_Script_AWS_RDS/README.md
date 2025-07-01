# AWS RDS Inventory Export Script

This script exports AWS RDS instance details to a CSV file with comprehensive information including subnet groups, tags, and metadata.

## Features

- Exports RDS instances from specified AWS region
- Includes AWS Account ID in filename
- Comprehensive RDS details including subnet groups and tags
- CSV format for easy analysis
- Error handling and validation

## Prerequisites

### 1. Install Required Tools

#### AWS CLI
```bash
# For Linux/macOS
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# For Windows (using PowerShell)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

#### jq (JSON processor)
```bash
# For Ubuntu/Debian
sudo apt-get install jq

# For CentOS/RHEL
sudo yum install jq

# For macOS
brew install jq

# For Windows
choco install jq
```

### 2. AWS Configuration

Configure AWS credentials with appropriate permissions:

```bash
aws configure
```

Required IAM permissions:
- `rds:DescribeDBInstances`
- `rds:ListTagsForResource`
- `sts:GetCallerIdentity`

Example IAM policy:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:ListTagsForResource",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

### Basic Usage

Run with default region (ap-southeast-2):
```bash
./export_aws_rds_inventory_with_Account_Name.sh
```

### Specify Region

Run with specific AWS region:
```bash
./export_aws_rds_inventory_with_Account_Name.sh us-east-1
```

### Make Script Executable

```bash
chmod +x export_aws_rds_inventory_with_Account_Name.sh
```

## Output

### File Naming Convention

The script generates CSV files with the following naming pattern:
```
rds_inventory_{ACCOUNT_ID}_{TIMESTAMP}.csv
```

Example: `rds_inventory_123456789012_20231215_143022.csv`

### CSV Columns

| Column | Description |
|--------|-------------|
| DB_Identifier | RDS instance identifier |
| Status | Current status of the instance |
| Role | Primary or Replica |
| Engine | Database engine (MySQL, PostgreSQL, etc.) |
| Region | AWS region |
| AvailabilityZone | Specific AZ within the region |
| InstanceClass | EC2 instance class |
| VPC | VPC ID where instance is deployed |
| MultiAZ | Multi-AZ deployment status |
| SubnetGroupName | DB subnet group name |
| SubnetGroupDescription | DB subnet group description |
| SubnetIDs | Semicolon-separated list of subnet IDs |
| Tags | Key=Value pairs separated by semicolons |

## Examples

### Sample Output

```csv
DB_Identifier,Status,Role,Engine,Region,AvailabilityZone,InstanceClass,VPC,MultiAZ,SubnetGroupName,SubnetGroupDescription,SubnetIDs,Tags
"prod-db-01","available","Primary","mysql","ap-southeast-2","ap-southeast-2a","db.t3.medium","vpc-12345678",false,"prod-subnet-group","Production DB Subnet Group","subnet-abc123;subnet-def456","Environment=Production;Owner=DevOps"
```

### Running in Different Scenarios

#### For Multiple Regions
```bash
# Run for multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
    ./export_aws_rds_inventory_with_Account_Name.sh $region
done
```

#### Scheduled Execution
Add to crontab for regular exports:
```bash
# Run daily at 2 AM
0 2 * * * /path/to/export_aws_rds_inventory_with_Account_Name.sh
```

## Troubleshooting

### Common Issues

#### 1. AWS CLI Not Found
```
Error: AWS CLI is not installed. Please install it first.
```
**Solution**: Install AWS CLI following the prerequisites section.

#### 2. jq Not Found
```
Error: jq is not installed. Please install it first.
```
**Solution**: Install jq following the prerequisites section.

#### 3. AWS Credentials Issue
```
Error: Failed to retrieve AWS account ID. Check your AWS credentials and permissions.
```
**Solutions**:
- Run `aws configure` to set up credentials
- Verify IAM permissions include required actions
- Check if AWS credentials are expired

#### 4. Permission Denied
```
Error: Failed to retrieve RDS instances. Check your AWS credentials and permissions.
```
**Solution**: Ensure your IAM user/role has the required RDS permissions listed above.

#### 5. No RDS Instances Found
The script will create a CSV with headers only if no RDS instances exist in the specified region.

### Debug Mode

For troubleshooting, run with debug output:
```bash
bash -x ./export_aws_rds_inventory_with_Account_Name.sh
```

## Script Maintenance

### Temporary Files

The script creates temporary files in `/tmp/`:
- `/tmp/rds_instances.json`
- `/tmp/rds_base_info.json`
- `/tmp/rds_tags.json`

These are automatically cleaned up after execution.

### Customization

To modify the CSV output, edit the jq commands in the script. The main areas for customization:
- Header line (line 32)
- jq processing logic (lines 42-57)
- CSV output format (line 72)

## Support

For issues or feature requests, please check:
1. AWS CLI version: `aws --version`
2. jq version: `jq --version`
3. AWS credentials: `aws sts get-caller-identity`
4. RDS permissions: `aws rds describe-db-instances --region your-region --dry-run`
