# AWS EC2 ENA and PV Driver Information Script

A comprehensive bash script to retrieve detailed information about EC2 ENA (Elastic Network Adapter) drivers and AWS PV (Paravirtual) drivers across your AWS infrastructure.

## 🚀 Features

- **Fully Automated**: No interactive prompts - runs completely unattended
- **Multi-Region Support**: Query any AWS region (defaults to ap-southeast-2)
- **Comprehensive Reporting**: Detailed driver information and adoption statistics
- **Timeout Protection**: All AWS CLI calls have timeout protection
- **Color-Coded Output**: Easy-to-read formatted output with color coding
- **Detailed Logging**: Timestamped logs for audit and troubleshooting
- **SSM Integration**: Retrieves actual driver versions from running instances
- **Windows Support**: Checks PV drivers on Windows instances

## 📋 Prerequisites

### Required Tools
- **AWS CLI v2** - Must be installed and configured
- **bash** - Unix shell (Linux/macOS/WSL)
- **timeout** - Command timeout utility (usually pre-installed)

### Optional Tools
- **jq** - JSON processor for better formatting (recommended)

### AWS Permissions Required
Your AWS credentials must have the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ssm:DescribeInstanceInformation",
                "ssm:SendCommand",
                "ssm:GetCommandInvocation",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## 🛠️ Installation

1. **Clone or download the script**:
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/get_ec2_drivers.sh
   ```

2. **Make it executable**:
   ```bash
   chmod +x get_ec2_drivers.sh
   ```

3. **Verify AWS CLI configuration**:
   ```bash
   aws configure list
   aws sts get-caller-identity
   ```

## 🎯 Usage

### Basic Usage
```bash
# Run with default region (ap-southeast-2)
./get_ec2_drivers.sh

# Run with specific region
./get_ec2_drivers.sh us-east-1

# Run with specific region and save output
./get_ec2_drivers.sh eu-west-1 | tee output.txt
```

### Advanced Usage
```bash
# Run in background with nohup
nohup ./get_ec2_drivers.sh ap-southeast-2 > driver_report.log 2>&1 &

# Run for multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
    echo "Processing region: $region"
    ./get_ec2_drivers.sh $region
done
```

## 📊 Output Sections

### 1. EC2 Instance Overview
- Complete table of all instances with driver support status
- Instance ID, Type, State, Platform, ENA Support, SR-IOV Support

### 2. Detailed Driver Information
- Color-coded display of running instances
- 🟢 Green: ENA/SR-IOV enabled
- 🔴 Red: ENA disabled
- 🟡 Yellow: SR-IOV not available

### 3. ENA Driver Versions (via SSM)
- Actual driver versions from running instances
- Requires SSM agent and appropriate permissions

### 4. AWS PV Driver Information
- Windows instances with potential PV drivers
- Actual PV driver versions via PowerShell (SSM)

### 5. Summary Report
- Total instance counts
- Driver adoption rates
- Percentage statistics

## 📝 Sample Output

```
AWS EC2 ENA and PV Driver Information Script
Region: ap-southeast-2
Log file: ec2_drivers_20240115_143022.log
Mode: Fully Automated (Non-Interactive)
=============================================

=== DETAILED DRIVER INFORMATION ===
Instance ID              Instance Type      ENA Support    SR-IOV    Virtualization
---------------------------------------------------------------------------------
i-0123456789abcdef0      t3.medium         true           simple    hvm
i-0987654321fedcba0      m5.large          true           simple    hvm

=== SUMMARY REPORT ===
Total instances: 5
Running instances: 3
ENA-enabled instances: 3
SR-IOV enabled instances: 3
ENA adoption rate: 100%
SR-IOV adoption rate: 100%
```

## 📁 Log Files

Each execution creates a timestamped log file:
- **Format**: `ec2_drivers_YYYYMMDD_HHMMSS.log`
- **Location**: Same directory as script
- **Content**: Detailed execution logs with timestamps

## ⚙️ Configuration

### Environment Variables
```bash
# Set custom timeouts
export SSM_TIMEOUT=15
export AWS_CLI_TIMEOUT=30

# Disable colors for automation
export NO_COLOR=1
```

### Script Variables
Edit the script to customize:
- `DEFAULT_REGION`: Change default AWS region
- `SSM_TIMEOUT`: Adjust SSM command timeout
- `LOG_FILE`: Modify log file naming pattern

## 🔧 Troubleshooting

### Common Issues

1. **"AWS CLI not installed"**
   ```bash
   # Install AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **"AWS credentials not configured"**
   ```bash
   aws configure
   # or
   export AWS_ACCESS_KEY_ID=your_key
   export AWS_SECRET_ACCESS_KEY=your_secret
   ```

3. **"No SSM-managed instances found"**
   - Ensure SSM agent is installed and running
   - Check IAM permissions for SSM
   - Verify instances are in "Online" state in SSM

4. **"Timeout errors"**
   - Check network connectivity
   - Verify AWS region is correct
   - Increase timeout values in script

### Debug Mode
```bash
# Enable debug output
bash -x ./get_ec2_drivers.sh

# Verbose AWS CLI output
export AWS_CLI_VERBOSE=1
./get_ec2_drivers.sh
```

## 🌟 Best Practices

1. **Regular Monitoring**: Run weekly to track driver adoption
2. **Multi-Region**: Execute across all your active regions
3. **Automation**: Integrate with CI/CD pipelines or cron jobs
4. **Log Retention**: Archive log files for compliance
5. **SSM Prerequisites**: Ensure SSM agent is deployed organization-wide

## 📋 Supported Instance Types

### ENA Support
- All current generation instances (M5, C5, R5, etc.)
- Most previous generation instances (M4, C4, R4, etc.)

### SR-IOV Support
- Enhanced networking capable instances
- Most M4, M5, C4, C5, R4, R5 instance families

### PV Drivers
- Windows instances (all generations)
- Legacy Linux instances (older generations)

## 🔄 Automation Examples

### Cron Job
```bash
# Run daily at 6 AM
0 6 * * * /path/to/get_ec2_drivers.sh ap-southeast-2 >> /var/log/ec2_drivers.log 2>&1
```

### AWS Lambda Integration
```bash
# Create deployment package
zip -r ec2-drivers.zip get_ec2_drivers.sh
aws lambda create-function --function-name ec2-driver-check --runtime provided.al2 --role arn:aws:iam::123456789012:role/lambda-role --handler get_ec2_drivers.sh --zip-file fileb://ec2-drivers.zip
```

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review log files for detailed error messages
3. Verify AWS permissions and connectivity
4. Test with a single instance first

## 📄 License

This script is provided as-is for educational and operational purposes. Use at your own risk in production environments.

---

**Author**: AWS Professional Engineer  
**Version**: 1.0  
**Last Updated**: 2024-01-15
