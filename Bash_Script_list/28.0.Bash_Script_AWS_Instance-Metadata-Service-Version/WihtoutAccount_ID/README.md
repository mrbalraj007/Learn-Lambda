# EC2 Instance Metadata Service (IMDS) Version Checker

A comprehensive bash script to audit and report on EC2 Instance Metadata Service (IMDS) configurations across your AWS infrastructure. This tool helps identify security risks by detecting instances that still allow IMDSv1, which is less secure than IMDSv2.

## 🚀 Features

- ✅ **Multi-region support** - Check any AWS region
- ✅ **Security assessment** - Identifies IMDSv1 vs IMDSv2 configurations
- ✅ **CSV export** - Generates detailed CSV reports with account ID in filename
- ✅ **Color-coded output** - Easy visual identification of security issues
- ✅ **Comprehensive reporting** - Instance details, metadata options, and security summary
- ✅ **Error handling** - Robust validation and error messages
- ✅ **Professional formatting** - Clean tabular output with proper alignment

## 📋 Prerequisites

### Required Tools
- **AWS CLI v2** - Latest version recommended
- **Bash** - Version 4.0 or higher
- **Standard Unix tools** - `sed`, `wc`, `date`

### AWS Permissions
The script requires the following IAM permissions:
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

### AWS Configuration
Ensure your AWS credentials are configured:
```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-2"
```

## 🛠️ Installation

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/get_ec2_imds_versions.sh
   # or
   curl -O https://raw.githubusercontent.com/your-repo/get_ec2_imds_versions.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x get_ec2_imds_versions.sh
   ```

3. **Verify installation:**
   ```bash
   ./get_ec2_imds_versions.sh --help
   ```

## 📖 Usage

### Basic Usage
```bash
# Use default region (ap-southeast-2)
./get_ec2_imds_versions.sh

# Specify a different region
./get_ec2_imds_versions.sh us-east-1

# Show help
./get_ec2_imds_versions.sh --help
```

### Examples
```bash
# Check instances in US East 1
./get_ec2_imds_versions.sh us-east-1

# Check instances in EU West 1
./get_ec2_imds_versions.sh eu-west-1

# Check instances in Asia Pacific (Sydney) - default
./get_ec2_imds_versions.sh ap-southeast-2
```

## 📊 Output

### Console Output
The script provides color-coded console output:
- 🟢 **Green**: Secure configurations (IMDSv2 only, running instances)
- 🟡 **Yellow**: Warning conditions (IMDSv1 enabled, stopped instances)
- 🔴 **Red**: Error conditions (unknown configurations, terminated instances)

### CSV Export
Automatically generates a CSV file with the format:
```
ec2_imds_versions_account_<ACCOUNT_ID>_<REGION>_<TIMESTAMP>.csv
```

**Example filename:**
```
ec2_imds_versions_account_123456789012_ap-southeast-2_20231215_143022.csv
```

### CSV Columns
| Column | Description |
|--------|-------------|
| InstanceId | EC2 instance identifier |
| State | Instance state (running, stopped, etc.) |
| Name | Instance name from Name tag |
| IMDSVersion | IMDS version (IMDSv2, IMDSv1/v2, Unknown) |
| HttpTokens | Token requirement (required, optional) |
| HopLimit | HTTP PUT response hop limit |
| Endpoint | Metadata service endpoint status |
| InstanceTags | Instance metadata tags setting |
| Region | AWS region |
| Timestamp | Report generation time |

## 🔍 Understanding IMDS Versions

### IMDSv1 (Instance Metadata Service Version 1)
- **Security**: Less secure
- **Authentication**: No authentication required
- **Risk**: Vulnerable to SSRF attacks
- **Recommendation**: Disable in favor of IMDSv2

### IMDSv2 (Instance Metadata Service Version 2)
- **Security**: More secure
- **Authentication**: Session token required
- **Protection**: Resistant to SSRF attacks
- **Recommendation**: Use exclusively for better security

## 🔧 Script Configuration

### Default Settings
```bash
DEFAULT_REGION="ap-southeast-2"  # Default AWS region
```

### Color Codes
```bash
RED='\033[0;31m'      # Errors and critical issues
GREEN='\033[0;32m'    # Success and secure configurations
YELLOW='\033[1;33m'   # Warnings and less secure configurations
BLUE='\033[0;34m'     # Information and headers
NC='\033[0m'          # No Color (reset)
```

## 🚨 Security Recommendations

### High Priority
1. **Disable IMDSv1**: Set `HttpTokens=required` on all instances
2. **Regular audits**: Run this script monthly to monitor compliance
3. **Automation**: Integrate into CI/CD pipelines for continuous monitoring

### Implementation Steps
1. **Identify vulnerable instances** using this script
2. **Update instance metadata options**:
   ```bash
   aws ec2 modify-instance-metadata-options \
     --instance-id i-1234567890abcdef0 \
     --http-tokens required \
     --http-put-response-hop-limit 1
   ```
3. **Verify changes** by running the script again

## 🔄 Automation

### Cron Job Setup
```bash
# Run weekly security audit
0 2 * * 1 /path/to/get_ec2_imds_versions.sh us-east-1 >> /var/log/imds-audit.log 2>&1
```

### AWS Lambda Integration
Consider converting to AWS Lambda for serverless execution:
- Schedule with CloudWatch Events
- Store results in S3
- Send alerts via SNS

## 🐛 Troubleshooting

### Common Issues

**1. AWS CLI not found**
```bash
Error: AWS CLI is not installed or not in PATH
```
**Solution**: Install AWS CLI v2 and ensure it's in your PATH

**2. Invalid credentials**
```bash
Error: AWS credentials not configured or invalid
```
**Solution**: Run `aws configure` or set environment variables

**3. Permission denied**
```bash
Error: Failed to retrieve EC2 instances. Check your permissions.
```
**Solution**: Ensure IAM user/role has required permissions

**4. No instances found**
```bash
No EC2 instances found in region us-west-2
```
**Solution**: Verify the region has EC2 instances or check a different region

### Debug Mode
Add debug output by modifying the script:
```bash
set -x  # Enable debug mode
# Your script content
set +x  # Disable debug mode
```

## 📈 Performance Considerations

- **Large accounts**: Script may take several minutes for accounts with 1000+ instances
- **Rate limits**: AWS API calls are subject to rate limiting
- **Parallel execution**: Consider running multiple regions in parallel for faster results

## 🔐 Security Best Practices

1. **Least privilege**: Use IAM roles with minimal required permissions
2. **Secure storage**: Store CSV files in secure locations
3. **Regular updates**: Keep AWS CLI and script updated
4. **Audit logs**: Monitor script execution and results

## 📝 Change Log

### v1.0.0 (Current)
- Initial release
- Basic IMDS version checking
- CSV export functionality
- Multi-region support
- Color-coded output

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This script is provided as-is under the MIT License. See LICENSE file for details.

## 📞 Support

For issues and questions:
- Create an issue in the repository
- Contact the AWS security team
- Review AWS documentation on IMDS

## 🔗 Useful Links

- [AWS EC2 Instance Metadata Service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
- [IMDSv2 Security Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- [AWS CLI Installation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [IAM Permissions for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)

---

**⚠️ Security Notice**: This script is designed for security auditing purposes. Always follow your organization's security policies and procedures when running infrastructure audits.
