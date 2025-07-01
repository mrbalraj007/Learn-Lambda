# EC2 Tags Export Script

A comprehensive Bash script that auto-discovers and extracts all EC2 instance details and tags from AWS accounts and exports them to CSV format.

## Features

- **Auto-discovery**: Automatically discovers all unique tags across all EC2 instances
- **Comprehensive data**: Exports instance details, tags, CloudWatch alarm status, and Elastic IP information
- **Account identification**: Includes AWS Account ID in the output filename
- **Region support**: Supports any AWS region
- **CSV format**: Clean CSV output for easy analysis in Excel or other tools

## Prerequisites

### 1. AWS CLI Installation

**On Linux/macOS:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**On Windows:**
- Download and install from: https://aws.amazon.com/cli/

### 2. jq Installation

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install jq
```

**On CentOS/RHEL:**
```bash
sudo yum install jq
```

**On macOS:**
```bash
brew install jq
```

**On Windows:**
- Download from: https://stedolan.github.io/jq/download/

### 3. AWS Configuration

Configure AWS CLI with your credentials:
```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., ap-southeast-2)
- Default output format (json)

## Script Overview

The script performs the following operations:

1. **Authentication Check**: Verifies AWS CLI and jq are installed
2. **Account Information**: Retrieves AWS Account ID and Account Name
3. **EC2 Discovery**: Fetches all EC2 instances in the specified region
4. **Tag Discovery**: Auto-discovers all unique tags across instances
5. **Additional Data**: Collects CloudWatch alarms and Elastic IP information
6. **CSV Export**: Exports all data to a timestamped CSV file

## Usage

### Basic Usage

Run the script with default settings (ap-southeast-2 region):
```bash
./ec2_tags_export_with_Account_name.sh
```

### Specify Region

Run the script for a specific AWS region:
```bash
./ec2_tags_export_with_Account_name.sh --region us-east-1
```

### Get Help

Display usage information:
```bash
./ec2_tags_export_with_Account_name.sh --help
```

## Step-by-Step Instructions

### Step 1: Make Script Executable
```bash
chmod +x ec2_tags_export_with_Account_name.sh
```

### Step 2: Test AWS Access
```bash
aws sts get-caller-identity
```
This should return your account information.

### Step 3: Run the Script
```bash
./ec2_tags_export_with_Account_name.sh
```

### Step 4: Monitor Progress
The script will display progress messages:
- Fetching AWS account information
- Fetching EC2 instances
- Fetching CloudWatch alarms
- Fetching Elastic IPs
- Discovering unique tags
- Exporting data

### Step 5: Review Output
The script creates a CSV file with the naming pattern:
```
ec2_details_tags_<ACCOUNT_ID>_<TIMESTAMP>.csv
```

Example: `ec2_details_tags_123456789012_20231215_143022.csv`

## Output Format

The CSV file contains the following columns:

### Standard Columns
- **InstanceId**: EC2 instance ID
- **InstanceName**: Value of the 'Name' tag
- **PublicIP**: Public IP address
- **PrivateIP**: Private IP address
- **InstanceType**: EC2 instance type (e.g., t3.micro)
- **AvailabilityZone**: AWS availability zone
- **AlarmStatus**: CloudWatch alarm status (OK/ALARM/N/A)
- **ElasticIP**: Associated Elastic IP address
- **SecurityGroupName**: Security group names (semicolon-separated)
- **KeyName**: SSH key pair name
- **LaunchTime**: Instance launch timestamp
- **PlatformDetails**: Operating system details

### Dynamic Tag Columns
Additional columns for each unique tag found across all instances (excluding 'Name' tag).

## Examples

### Example 1: Export from Default Region
```bash
./ec2_tags_export_with_Account_name.sh
```

### Example 2: Export from US East 1
```bash
./ec2_tags_export_with_Account_name.sh --region us-east-1
```

### Example 3: Export from Multiple Regions
```bash
# Export from multiple regions
./ec2_tags_export_with_Account_name.sh --region us-east-1
./ec2_tags_export_with_Account_name.sh --region eu-west-1
./ec2_tags_export_with_Account_name.sh --region ap-southeast-2
```

## Troubleshooting

### Common Issues

**1. Permission Denied Error**
```bash
chmod +x ec2_tags_export_with_Account_name.sh
```

**2. AWS CLI Not Found**
- Install AWS CLI following the prerequisites section

**3. jq Not Found**
- Install jq following the prerequisites section

**4. Access Denied**
- Check AWS credentials: `aws sts get-caller-identity`
- Ensure your IAM user/role has necessary permissions

**5. No Instances Found**
- Verify you're checking the correct region
- Ensure instances exist in the specified region

### Required IAM Permissions

Your AWS user/role needs the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeAddresses",
                "cloudwatch:DescribeAlarms",
                "sts:GetCallerIdentity",
                "iam:ListAccountAliases"
            ],
            "Resource": "*"
        }
    ]
}
```

## Output Analysis

### Opening in Excel
1. Open Excel
2. Go to Data > Get Data > From File > From Text/CSV
3. Select your CSV file
4. Choose "Comma" as delimiter
5. Click "Load"

### Common Analysis Tasks
- **Instance Inventory**: Count instances by type, region, or tags
- **Cost Analysis**: Group by environment or project tags
- **Security Review**: Check security groups and key pairs
- **Compliance**: Verify required tags are present

## Advanced Usage

### Batch Processing Multiple Accounts
If you have multiple AWS profiles:
```bash
# Switch profiles and run
export AWS_PROFILE=account1
./ec2_tags_export_with_Account_name.sh --region us-east-1

export AWS_PROFILE=account2
./ec2_tags_export_with_Account_name.sh --region us-east-1
```

### Automation with Cron
Add to crontab for daily exports:
```bash
# Daily EC2 export at 6 AM
0 6 * * * /path/to/ec2_tags_export_with_Account_name.sh --region us-east-1
```

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify prerequisites are met
3. Test AWS access with `aws sts get-caller-identity`
4. Ensure proper IAM permissions

## Version History

- **v1.0**: Initial release with basic EC2 export functionality
- **v1.1**: Added CloudWatch alarms and Elastic IP support
- **v1.2**: Added account ID in filename and improved error handling
