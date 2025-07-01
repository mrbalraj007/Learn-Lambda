# AWS Route 53 Detailed Records Export Tool

A professional-grade tool for exporting comprehensive Route 53 hosted zone and DNS records information to CSV format with timestamp. This enhanced version exports detailed record information including routing policies, alias targets, TTL values, and health check configurations.

## 🚀 Features

- ✅ **Comprehensive Route 53 Export**: Exports all hosted zones and their detailed DNS records
- ✅ **Detailed Record Information**: Includes Record Name, Type, Routing Policy, Alias, Value/Route Traffic to, TTL, Evaluate Target Health
- ✅ **Multiple Script Formats**: Bash script for Linux/macOS/WSL and PowerShell script for Windows
- ✅ **Professional Output**: Timestamped CSV files with professional formatting
- ✅ **Enhanced Error Handling**: Robust error handling and validation
- ✅ **Colored Console Output**: Easy-to-read colored output for better user experience
- ✅ **Pre-flight Checks**: AWS CLI validation and permission verification
- ✅ **Cross-Platform Support**: Works on Linux, macOS, Windows (WSL/PowerShell)
- ✅ **Default Region Support**: Pre-configured for ap-southeast-2 region

## 📋 Prerequisites

### Required Software
1. **AWS CLI v2** - Must be installed and configured
   - Installation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
2. **Bash shell** (for bash script) - Linux/macOS/WSL
3. **PowerShell 5.1+** (for PowerShell script) - Windows
4. **jq** (for bash script only) - JSON processor
   - Linux: `sudo apt-get install jq` or `sudo yum install jq`
   - macOS: `brew install jq`
   - Windows WSL: `sudo apt-get install jq`

### Required AWS Permissions
The following IAM permissions are required (included in `iam-policy.json`):

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
        "route53:GetHealthCheck",
        "route53:ListHealthChecks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📁 Files Included

| File | Description |
|------|-------------|
| `export_route53_records_detailed.sh` | Main bash script for Linux/macOS/WSL |
| `Export-Route53RecordsDetailed.ps1` | PowerShell script for Windows |
| `run_route53_detailed_export.bat` | Windows batch launcher |
| `iam-policy.json` | Required IAM permissions |
| `README_DETAILED.md` | This comprehensive documentation |

## 🔧 Installation & Setup

### 1. Configure AWS CLI
```bash
aws configure
```
Set your AWS Access Key ID, Secret Access Key, default region (ap-southeast-2), and output format (json).

### 2. Make Scripts Executable (Linux/macOS/WSL)
```bash
chmod +x export_route53_records_detailed.sh
```

### 3. Install Dependencies (Linux/macOS/WSL only)
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install jq

# CentOS/RHEL/Amazon Linux
sudo yum install jq

# macOS with Homebrew
brew install jq
```

## 🚀 Usage

### Method 1: Bash Script (Linux/macOS/WSL)
```bash
# Basic usage (uses default region ap-southeast-2)
./export_route53_records_detailed.sh

# The script will:
# 1. Validate AWS CLI configuration
# 2. Create output directory (route53_exports/)
# 3. Export all hosted zones and records
# 4. Generate timestamped CSV file
```

### Method 2: PowerShell Script (Windows)
```powershell
# Run directly
.\Export-Route53RecordsDetailed.ps1

# Or with custom region
.\Export-Route53RecordsDetailed.ps1 -Region "us-east-1"

# Or with custom output directory
.\Export-Route53RecordsDetailed.ps1 -Region "ap-southeast-2" -OutputDir "my_exports"
```

### Method 3: Windows Batch File (Easiest for Windows)
```cmd
# Double-click or run from command prompt
run_route53_detailed_export.bat
```

## 📊 Output Format

The script generates a CSV file with the following columns:

| Column | Description |
|--------|-------------|
| Hosted Zone Name | Name of the hosted zone (e.g., example.com) |
| Hosted Zone ID | AWS hosted zone ID |
| Zone Type | Public or Private |
| Record Name | DNS record name (e.g., www.example.com) |
| Record Type | DNS record type (A, AAAA, CNAME, MX, etc.) |
| Routing Policy | Simple, Weighted, Latency-based, Failover, etc. |
| Alias Target | Target for alias records |
| Alias Hosted Zone ID | Hosted zone ID for alias targets |
| Value/Route Traffic To | Where the record points (IP, domain, etc.) |
| TTL | Time to Live value |
| Evaluate Target Health | Health check evaluation setting |
| Set Identifier | Identifier for routing policies |
| Weight | Weight for weighted routing |
| Region | Region for latency-based routing |
| Failover | Primary/Secondary for failover routing |
| Health Check ID | Associated health check ID |
| Export Timestamp | When the record was exported |

### Sample Output
```csv
Hosted Zone Name,Hosted Zone ID,Zone Type,Record Name,Record Type,Routing Policy,Alias Target,Alias Hosted Zone ID,Value/Route Traffic To,TTL,Evaluate Target Health,Set Identifier,Weight,Region,Failover,Health Check ID,Export Timestamp
example.com,Z1234567890ABC,Public,example.com,A,Simple,,,192.0.2.1,300,,,,,,,2025-07-01 10:30:00
www.example.com,Z1234567890ABC,Public,www.example.com,CNAME,Simple,,,example.com,300,,,,,,,2025-07-01 10:30:00
api.example.com,Z1234567890ABC,Public,api.example.com,A,Weighted,,,"203.0.113.1; 203.0.113.2",60,,prod-api,100,,,,2025-07-01 10:30:00
```

## 📂 Output Files

Files are saved in the `route53_exports/` directory with timestamp:
- Format: `route53_detailed_records_YYYYMMDD_HHMMSS.csv`
- Example: `route53_detailed_records_20250701_103045.csv`

## 🛠️ Troubleshooting

### Common Issues

#### 1. AWS CLI Not Found
```
Error: AWS CLI is not installed
Solution: Install AWS CLI v2 from https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

#### 2. AWS Credentials Not Configured
```
Error: AWS CLI is not configured or credentials are invalid
Solution: Run 'aws configure' and set up your credentials
```

#### 3. Insufficient Permissions
```
Error: Insufficient permissions to access Route 53
Solution: Attach the IAM policy from iam-policy.json to your user/role
```

#### 4. jq Not Found (Bash Script Only)
```
Error: jq command not found
Solution: Install jq using your package manager
```

#### 5. PowerShell Execution Policy (Windows)
```
Error: Execution of scripts is disabled on this system
Solution: Run PowerShell as Administrator and execute:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Debugging

#### Enable Debug Mode (Bash)
```bash
# Add this line at the top of the script after #!/bin/bash
set -x
```

#### Verbose Output (PowerShell)
```powershell
# Add -Verbose parameter
.\Export-Route53RecordsDetailed.ps1 -Verbose
```

### Testing Permissions
Use the included validation script:
```bash
./validate_permissions.sh
```

## 🔍 Advanced Usage

### Custom Region
```bash
# Bash
export AWS_DEFAULT_REGION="us-west-2"
./export_route53_records_detailed.sh

# PowerShell
.\Export-Route53RecordsDetailed.ps1 -Region "us-west-2"
```

### Processing Large Number of Zones
For accounts with many hosted zones, the script includes:
- Progress indicators
- Error handling for individual zones
- Memory-efficient processing
- Detailed logging

### Automation & Scheduling

#### Linux/macOS Cron Job
```bash
# Daily export at 2 AM
0 2 * * * /path/to/export_route53_records_detailed.sh

# Weekly export on Sundays at 3 AM
0 3 * * 0 /path/to/export_route53_records_detailed.sh
```

#### Windows Task Scheduler
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (daily, weekly, etc.)
4. Set action to start program: `powershell.exe`
5. Add arguments: `-File "C:\path\to\Export-Route53RecordsDetailed.ps1"`

## 📈 Performance Considerations

- **Small environments** (1-10 zones): Completes in seconds
- **Medium environments** (10-50 zones): Completes in 1-2 minutes
- **Large environments** (50+ zones): May take several minutes
- **Rate limiting**: AWS API rate limits are automatically handled

## 🔐 Security Best Practices

1. **Use IAM roles** instead of hardcoded credentials when possible
2. **Apply least privilege** - only grant necessary Route 53 permissions
3. **Secure CSV files** - contain sensitive DNS information
4. **Regular rotation** of AWS access keys
5. **Monitor usage** through CloudTrail

## 📝 Logging

Both scripts provide comprehensive logging:
- Colored console output for easy reading
- Detailed progress information
- Error messages with context
- Summary statistics at completion

## 🤝 Support & Contribution

### Getting Help
1. Check this README for common issues
2. Verify AWS CLI configuration: `aws sts get-caller-identity`
3. Test Route 53 access: `aws route53 list-hosted-zones --max-items 1`
4. Check file permissions and dependencies

### Script Customization
The scripts are well-documented and can be customized for:
- Additional output formats (JSON, XML)
- Specific record type filtering
- Custom CSV column ordering
- Integration with other tools

## 📋 Version History

- **v2.0** - Comprehensive detailed records export with routing policies
- **v1.0** - Basic hosted zone information export

## 🏷️ Tags
`aws` `route53` `dns` `export` `devops` `bash` `powershell` `csv` `automation` `professional`

---

**Professional AWS DevOps Engineer Script**  
*Created for comprehensive Route 53 management and documentation*
