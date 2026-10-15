# EC2 Instance Metadata Service (IMDS) Version Checker

A Bash script that checks EC2 instance metadata options for one AWS region at a time. It reports whether each instance requires IMDSv2 or allows IMDSv1, displays an account and instance summary, and writes the results to a CSV file. The script only reads configuration; it does not change instances.

## 🚀 Features

- ✅ **Single-region audit** - Check one AWS region per run and pass a region argument when needed
- **Security assessment** - Identifies instances that require IMDSv2 or allow IMDSv1
- **CSV export** - Includes the AWS account ID in the filename and report
- **Color-coded output** - Highlights instance state and IMDS token configuration
- **Instance details** - Reports instance state, Name tag, metadata options, and region
- **Summary** - Counts total instances, IMDSv2-only instances, and instances that allow IMDSv1
- **Read-only operation** - Does not modify EC2 instances

## 📋 Prerequisites

### Required Tools
- **AWS CLI v2** - Latest version recommended
- **Bash** - Bash shell
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
Configure AWS credentials using the AWS CLI, an IAM role, or another supported AWS credential provider. The identity needs the permissions listed above. The script passes the selected region explicitly to AWS CLI commands, so setting `AWS_DEFAULT_REGION` is not required.
```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

## 🛠️ Installation

1. Save or copy `get_ec2_imds_versions.sh` to your working directory.

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
# Use the default region (us-east-1)
./get_ec2_imds_versions.sh

# Use a specific region
./get_ec2_imds_versions.sh ap-southeast-2

# Show help
./get_ec2_imds_versions.sh --help
```

### Examples
```bash
# Check instances in US East 1
./get_ec2_imds_versions.sh us-east-1

# Check instances in EU West 1
./get_ec2_imds_versions.sh eu-west-1

# Check instances in Asia Pacific (Sydney)
./get_ec2_imds_versions.sh ap-southeast-2

# Show usage information
./get_ec2_imds_versions.sh --help
```

The optional first argument is the AWS region for the current run. If omitted, the script uses `us-east-1`. It does not scan multiple regions in a single execution.

### What the script reads
The script calls `aws ec2 describe-instances` with the selected region and reads these instance fields:
- `InstanceId`
- `State.Name`
- `Tags[?Key==Name].Value|[0]`
- `MetadataOptions.HttpTokens`
- `MetadataOptions.HttpPutResponseHopLimit`
- `MetadataOptions.HttpEndpoint`
- `MetadataOptions.InstanceMetadataTags`

It then classifies the instance as `IMDSv2`, `IMDSv1/v2`, or `Unknown` based on the `HttpTokens` value.

## 📊 Output

### Console Output
The console output shows the AWS account ID and, for each instance, its instance ID, state, Name tag, IMDS classification, hop limit, endpoint status, and instance metadata tags setting.

Colors are applied separately to state and IMDS classification:
- **Green**: Running state; IMDSv2 when tokens are required
- **Yellow**: Stopped state; IMDSv1/v2 when tokens are optional
- **Red**: Other instance states; unknown IMDS token configuration

### CSV Export
Automatically generates a CSV file with the format:
```
imds_<ACCOUNT_ID>_<REGION>_<TIMESTAMP>.csv
```

**Example filename:**
```
imds_123456789012_us-east-1_20261015_110000.csv
```

The timestamp in the filename uses `YYYYMMDD_HHMMSS` format. The CSV is created in the current working directory. The shortened filename helps keep the full path below Excel's 259-character limit when run from a deeply nested folder. If no instances are returned, the script still writes the CSV header.

### CSV Columns
| Column | Description |
|--------|-------------|
| Account ID | AWS account identifier |
| InstanceId | EC2 instance identifier |
| State | Instance state (running, stopped, etc.) |
| Name | Instance name from Name tag |
| IMDSVersion | Script classification: `IMDSv2` when tokens are `required`, `IMDSv1/v2` when `optional`, otherwise `Unknown` |
| HttpTokens | EC2 token setting (`required`, `optional`, or the value returned by AWS) |
| HopLimit | HTTP PUT response hop limit |
| Endpoint | Metadata service endpoint setting |
| InstanceTags | Instance metadata tags setting |
| Region | AWS region |
| Timestamp | Row generation time in `YYYY-MM-DD HH:MM:SS` format |

The CSV columns appear in the order shown above. Commas in the instance Name and instance metadata tags values are replaced with semicolons when written to the CSV.

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

### Default Region
```bash
DEFAULT_REGION="us-east-1"
```

Pass a region as the first argument to use another region.

### Color Codes
```bash
RED='\033[0;31m'      # Errors and critical issues
GREEN='\033[0;32m'    # Success and secure configurations
YELLOW='\033[1;33m'   # Warnings and less secure configurations
BLUE='\033[0;34m'     # Information and headers
NC='\033[0m'          # No Color (reset)
```

## 🚨 Security Recommendations

1. **Disable IMDSv1 where possible**: Set `HttpTokens=required` on instances that support IMDSv2.
2. **Regular audits**: Run the script periodically to monitor the selected region.
3. **Review before changing configuration**: This script only reports settings; it does not update instances.

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

The script can be scheduled with a system scheduler. For example, this cron entry runs it weekly in `us-east-1` and appends console output to a log:
```bash
# Run weekly security audit
0 2 * * 1 /path/to/get_ec2_imds_versions.sh us-east-1 >> /var/log/imds-audit.log 2>&1
```

The script itself does not configure scheduled runs, upload reports, or send alerts.

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
**Solution**: Verify that the selected region has EC2 instances or run the script with a different region.

### Debug Mode
To enable Bash tracing for a single run, invoke the script with `bash -x`:
```bash
bash -x ./get_ec2_imds_versions.sh us-east-1
```

Debug output may include operational details; handle it according to your organization's logging and security policies.

## 📈 Performance Considerations

- The script checks one region per run; run it separately for each region you want to audit.
- AWS API calls are subject to AWS service quotas and throttling.

## 🔐 Security Best Practices

1. **Least privilege**: Use IAM roles with minimal required permissions
2. **Secure storage**: Store CSV files in secure locations
3. **Regular updates**: Keep AWS CLI and script updated
4. **Audit logs**: Monitor script execution and results

## 📝 Change Log

### Current
- Reports EC2 IMDS settings for one selected region (default: `us-east-1`)
- Includes the AWS account ID in console output and CSV reports
- Creates a timestamped CSV report and prints a configuration summary

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

No `LICENSE` file is present in this directory or the repository root. Confirm the applicable project license before redistributing this script.

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
