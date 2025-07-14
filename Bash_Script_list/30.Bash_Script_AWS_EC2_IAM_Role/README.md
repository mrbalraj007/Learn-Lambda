# EC2 IAM Role Discovery Script

This bash script retrieves all EC2 instances in your AWS account and identifies which IAM roles are assigned to each instance. The output is saved to a CSV file with a timestamp and account ID in the filename.

## Prerequisites

1. **AWS CLI** - Must be installed and configured
2. **Bash shell** - Compatible with Linux, macOS, and Windows WSL/Git Bash
3. **AWS Permissions** - Appropriate permissions to describe EC2 instances

## Installation

1. Clone or download the script to your local machine
2. Make the script executable:
   ```bash
   chmod +x get_ec2_iam_roles.sh
   ```

## Usage

Run the script from the command line:

```bash
./get_ec2_iam_roles.sh
```

## Output

The script generates a CSV file with the following naming convention:
```
EC2_IAM_Roles_{ACCOUNT_ID}_{YYYYMMDD_HHMMSS}.csv
```

**Example filename:** `EC2_IAM_Roles_123456789012_20231215_143025.csv`

## CSV File Structure

The output CSV contains the following columns:

| Column | Description |
|--------|-------------|
| Instance_ID | EC2 instance identifier (e.g., i-1234567890abcdef0) |
| Instance_Name | Name tag of the instance (or "No Name" if not set) |
| Instance_Type | EC2 instance type (e.g., t3.micro, m5.large) |
| State | Current state of the instance (running, stopped, etc.) |
| IAM_Role | Assigned IAM role name (or "No Role Assigned") |
| Launch_Time | When the instance was launched (ISO format) |
| Availability_Zone | AZ where instance is running (e.g., us-east-1a) |
| Private_IP | Private IP address (or "N/A" if not assigned) |
| Public_IP | Public IP address (or "N/A" if not assigned) |

## Required AWS Permissions

Your AWS credentials must have the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Script Features

- **Error Handling**: Checks for AWS CLI installation and configuration
- **Flexible Output**: Handles instances with or without IAM roles
- **Clean Format**: Properly formatted CSV with headers
- **Timestamp**: Unique filenames prevent overwrites
- **Account Context**: Includes AWS account ID in filename
- **Progress Feedback**: Shows script execution status

## Example Output

```
Instance_ID,Instance_Name,Instance_Type,State,IAM_Role,Launch_Time,Availability_Zone,Private_IP,Public_IP
i-1234567890abcdef0,WebServer01,t3.micro,running,EC2-S3-Access-Role,2023-12-15T14:30:25.000Z,us-east-1a,10.0.1.100,54.123.45.67
i-0987654321fedcba0,DatabaseServer,m5.large,running,No Role Assigned,2023-12-14T09:15:30.000Z,us-east-1b,10.0.2.50,N/A
```

## Troubleshooting

### Common Issues:

1. **AWS CLI not found**
   - Install AWS CLI: https://aws.amazon.com/cli/
   - Verify installation: `aws --version`

2. **AWS CLI not configured**
   - Configure AWS CLI: `aws configure`
   - Or use environment variables/IAM roles

3. **Permission denied errors**
   - Ensure your AWS credentials have required permissions
   - Check IAM policies attached to your user/role

4. **No instances found**
   - Verify you're in the correct AWS region
   - Check if instances exist in your account

## Script Architecture

The script consists of several functions:

- `check_aws_cli()` - Validates AWS CLI installation and configuration
- `get_account_id()` - Retrieves AWS account ID
- `get_datetime()` - Generates timestamp for filename
- `get_ec2_iam_roles()` - Main function to fetch and format EC2 data
- `main()` - Orchestrates the entire process

## License

This script is provided as-is for educational and operational purposes. Use at your own risk and ensure you have proper permissions before running in production environments.

## Author

Created by AWS Engineering Team
