# EC2 Health Status Check Script

This bash script monitors AWS EC2 instances for system status and instance status check issues, saving detailed results to a timestamped CSV file.

## Features

- Checks both system status and instance status for all EC2 instances
- Supports single region or all regions scanning
- Generates detailed CSV reports with timestamps
- Provides colored console output for easy identification of issues
- Logs all activities with timestamps
- Shows status check ratios (e.g., 2/3 checks passed)
- Error handling and AWS CLI validation

## Prerequisites

- AWS CLI installed and configured
- Appropriate IAM permissions for EC2 describe operations
- Bash shell environment

## Required IAM Permissions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeRegions"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

### Basic Usage (Current Region)
```bash
chmod +x ec2_health_check.sh
./ec2_health_check.sh
```

### Check All Regions
```bash
CHECK_ALL_REGIONS=true ./ec2_health_check.sh
```

## Output Files

1. **CSV Report**: `ec2_health_status_YYYYMMDD_HHMMSS.csv`
2. **Log File**: `ec2_health_check.log`

## CSV Output Format

| Column | Description |
|--------|-------------|
| Region | AWS region |
| InstanceId | EC2 instance ID |
| Name | Instance name tag |
| InstanceType | Instance type (e.g., t3.micro) |
| State | Instance state (running, stopped, etc.) |
| SystemStatus | System status check result |
| InstanceStatus | Instance status check result |
| StatusCheckRatio | Passed checks ratio (e.g., 2/3) |
| OverallHealth | HEALTHY/UNHEALTHY/NOT_RUNNING |
| Issues | Description of any issues found |
| CheckTime | Timestamp of the check |

## Status Check Explanations

- **System Status**: Checks AWS infrastructure (hardware, network)
- **Instance Status**: Checks instance software/OS level issues
- **Possible Values**: ok, impaired, insufficient-data, not-applicable

## Example Output

```
Region,InstanceId,Name,InstanceType,State,SystemStatus,InstanceStatus,StatusCheckRatio,OverallHealth,Issues,CheckTime
"us-east-1","i-1234567890abcdef0","WebServer","t3.micro","running","ok","impaired","1/2","UNHEALTHY","Instance Check Failed","2024-01-15 10:30:00"
```

## Troubleshooting

1. **AWS CLI not configured**: Run `aws configure`
2. **Permission denied**: Ensure proper IAM permissions
3. **No instances found**: Verify region and instance existence
4. **Script fails**: Check the log file for detailed error messages
