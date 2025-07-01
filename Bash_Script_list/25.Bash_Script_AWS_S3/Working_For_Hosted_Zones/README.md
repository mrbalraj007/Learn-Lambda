# Route 53 Hosted Zones Export Script

## Overview
This bash script exports comprehensive information about all Route 53 hosted zones in your AWS account to a CSV file with timestamp. It's designed for AWS engineers who need to audit, document, or analyze their DNS infrastructure.

## What This Script Does
- Exports all Route 53 hosted zone details to CSV format
- Includes hosted zone name, type, record count, description, ID, and creation date
- Creates timestamped output files for tracking
- Provides detailed logging for troubleshooting
- Uses ap-southeast-2 as the default AWS region

## Prerequisites

### 1. System Requirements
- Linux/Unix environment or Windows with WSL/Git Bash
- Bash shell (version 4.0 or higher recommended)

### 2. Required Tools
- **AWS CLI**: Version 2.x recommended
- **jq**: JSON processor for parsing AWS API responses

### 3. AWS Permissions
Your AWS credentials must have the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Step-by-Step Setup Instructions

### Step 1: Install AWS CLI
```bash
# For Ubuntu/Debian
sudo apt update
sudo apt install awscli

# For Amazon Linux/RHEL/CentOS
sudo yum install awscli

# For macOS
brew install awscli

# Verify installation
aws --version
```

### Step 2: Install jq
```bash
# For Ubuntu/Debian
sudo apt install jq

# For Amazon Linux/RHEL/CentOS
sudo yum install jq

# For macOS
brew install jq

# Verify installation
jq --version
```

### Step 3: Configure AWS Credentials
Choose one of the following methods:

#### Option A: AWS CLI Configure
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: ap-southeast-2
# Enter default output format: json
```

#### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-2"
```

#### Option C: IAM Role (for EC2 instances)
Attach an IAM role with the required permissions to your EC2 instance.

### Step 4: Verify AWS Access
```bash
aws sts get-caller-identity
```
This should return your AWS account information without errors.

### Step 5: Download and Prepare the Script
```bash
# Navigate to the script directory
cd "c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\25.Bash_Script_AWS_S3\Working_For_Hosted_Zones"

# Make the script executable
chmod +x export_route53_info.sh
```

## Step-by-Step Usage Instructions

### Step 1: Run the Script
```bash
./export_route53_info.sh
```

### Step 2: Monitor Progress
The script will display real-time progress:
- Checking prerequisites
- Retrieving hosted zones
- Processing each zone
- Generating CSV output

### Step 3: Review Output Files
After completion, you'll find two files:
- `route53_hosted_zones_YYYYMMDD_HHMMSS.csv` - Main export data
- `export_log_YYYYMMDD_HHMMSS.log` - Detailed execution log

## Understanding the Output

### CSV File Structure
The generated CSV contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| Hosted Zone Name | Domain name without trailing dot | example.com |
| Type | Public or Private zone | Public |
| Created By | Creator information (usually N/A) | N/A |
| Record Count | Number of DNS records | 15 |
| Description | Zone description/comment | Production domain |
| Hosted Zone ID | AWS unique identifier | Z1234567890ABC |
| Creation Date | When the zone was created | 2023-01-15T10:30:00Z |

### Sample CSV Output
```csv
Hosted Zone Name,Type,Created By,Record Count,Description,Hosted Zone ID,Creation Date
example.com,Public,N/A,12,Production domain,Z1234567890ABC,2023-01-15T10:30:00.000Z
test.internal,Private,N/A,5,Internal testing,Z0987654321DEF,2023-02-20T14:45:30.000Z
```

## Configuration Options

### Change Default Region
Edit the script to modify the AWS region:
```bash
# Change this line in the script
AWS_REGION="your-preferred-region"
```

### Custom Output Directory
Modify the OUTPUT_DIR variable to change where files are saved:
```bash
# Change this line in the script
OUTPUT_DIR="/path/to/your/output/directory"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "AWS CLI is not installed or not in PATH"
- **Solution**: Install AWS CLI using the instructions in Step 1
- **Verification**: Run `which aws` to check if AWS CLI is in PATH

#### 2. "AWS credentials not configured or invalid"
- **Solution**: Configure credentials using Step 3
- **Verification**: Run `aws sts get-caller-identity`

#### 3. "jq is required but not installed"
- **Solution**: Install jq using the instructions in Step 2
- **Verification**: Run `which jq`

#### 4. "Failed to retrieve hosted zones"
- **Possible Causes**:
  - Insufficient permissions
  - Network connectivity issues
  - Invalid AWS region
- **Solution**: Check IAM permissions and network connectivity

#### 5. Permission Denied
```bash
chmod +x export_route53_info.sh
```

### Log Analysis
Check the log file for detailed error information:
```bash
tail -f export_log_YYYYMMDD_HHMMSS.log
```

## Script Features

### Error Handling
- Validates AWS CLI installation
- Checks AWS credentials
- Verifies jq availability
- Handles API call failures gracefully

### Logging
- Timestamped log entries
- Progress tracking
- Error and warning messages
- Summary statistics

### Output Format
- CSV format for easy import into Excel/databases
- Proper escaping of special characters
- Consistent timestamp format
- Clean data formatting

## Best Practices

### Security
- Use IAM roles instead of access keys when possible
- Rotate access keys regularly
- Follow principle of least privilege

### Usage
- Run script during off-peak hours for large environments
- Store output files securely
- Regular backups of Route 53 configuration

### Automation
- Schedule with cron for regular exports
- Integrate with monitoring systems
- Use in CI/CD pipelines for infrastructure auditing

## Example Cron Job
```bash
# Run every Sunday at 2 AM
0 2 * * 0 /path/to/export_route53_info.sh >> /var/log/route53_export.log 2>&1
```

## Support and Maintenance

### Version Information
- Script Version: 1.0
- Compatible with AWS CLI v2.x
- Tested on Ubuntu 20.04, Amazon Linux 2

### Updates
- Check AWS CLI documentation for API changes
- Update jq if parsing issues occur
- Monitor AWS service limits

For questions or issues, review the log files and ensure all prerequisites are met.
