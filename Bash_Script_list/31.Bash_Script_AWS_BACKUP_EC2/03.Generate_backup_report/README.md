# 📋 AWS EC2 Backup Report Generator

<div align="center">

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![CSV](https://img.shields.io/badge/CSV-217346?style=for-the-badge&logo=microsoft-excel&logoColor=white)

**🚀 Automated AWS Backup Jobs Reporting Tool**

Generate comprehensive CSV reports of your AWS EC2 backup jobs with instance names and status information.

</div>

---

## 📑 Table of Contents

- [🎯 Overview](#-overview)
- [🔧 Prerequisites](#-prerequisites)
- [⚙️ Installation](#️-installation)
- [🚀 Usage](#-usage)
- [📊 Output Format](#-output-format)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [🤝 Contributing](#-contributing)

---

## 🎯 Overview

This Bash script automatically generates detailed CSV reports of AWS Backup jobs for EC2 instances. It fetches backup job information from a specified backup vault and enriches the data with EC2 instance names from their Name tags.

### ✨ Features

- 🔍 **Comprehensive Reporting**: Lists all backup jobs with detailed information
- 🏷️ **Instance Name Resolution**: Automatically resolves EC2 instance names from tags
- 📅 **Timestamped Output**: Generates uniquely named reports with timestamps
- 🏢 **Multi-Account Support**: Includes AWS Account ID in report filenames
- 📋 **CSV Format**: Easy to import into Excel or other analysis tools

---

## 🔧 Prerequisites

### 📦 Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|-------------|
| ![AWS CLI](https://img.shields.io/badge/AWS_CLI-2.0+-FF9900?style=flat-square&logo=amazon-aws) | 2.0+ | AWS API interactions | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| ![jq](https://img.shields.io/badge/jq-1.6+-0080FF?style=flat-square&logo=json) | 1.6+ | JSON parsing | [Install Guide](https://stedolan.github.io/jq/download/) |
| ![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25?style=flat-square&logo=gnu-bash) | 4.0+ | Script execution | Pre-installed on most Linux/macOS |

### 🔑 AWS Permissions

Your AWS credentials must have the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "backup:ListBackupJobs",
                "ec2:DescribeTags",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

### 🏗️ AWS Resources

- ✅ **AWS Backup Vault**: Named "SSMPatching" (configurable)
- ✅ **EC2 Instances**: With backup jobs in the specified vault
- ✅ **Backup Plan**: Active backup plan targeting your EC2 instances

---

## ⚙️ Installation

### 1️⃣ Clone or Download

```bash
# Clone the repository (if using Git)
git clone <repository-url>
cd 31.Bash_Script_AWS_BACKUP_EC2

# Or download and extract the files
```

### 2️⃣ Install Dependencies

#### On Ubuntu/Debian:
```bash
sudo apt update
sudo apt install awscli jq
```

#### On CentOS/RHEL:
```bash
sudo yum install awscli jq
```

#### On macOS:
```bash
brew install awscli jq
```

### 3️⃣ Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region, and output format
```

### 4️⃣ Make Script Executable

```bash
chmod +x generate_backup_report.sh
```

---

## 🚀 Usage

### 🎯 Basic Usage

```bash
./generate_backup_report.sh
```

### ⚙️ Configuration

Edit the script to modify the backup vault name:

```bash
# Change this line in the script
VAULT_NAME="SSMPatching"   # Replace with your vault name
```

### 📊 Example Output

```bash
$ ./generate_backup_report.sh
✅ Report saved as: backup_jobs_123456789012_20240315_143052.csv
```

---

## 📊 Output Format

The generated CSV file contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| 🆔 **JobId** | Unique backup job identifier | `12345678-abcd-1234-5678-123456789012` |
| 🔗 **ResourceArn** | AWS ARN of the backed-up resource | `arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0` |
| 🏷️ **ResourceName** | EC2 instance name from Name tag | `WebServer-01` |
| ⭐ **Status** | Current backup job status | `COMPLETED`, `RUNNING`, `FAILED` |
| 📅 **CreatedAt** | Backup job creation timestamp | `2024-03-15T14:30:52.123Z` |

### 📄 Sample CSV Output

```csv
JobId,ResourceArn,ResourceName,Status,CreatedAt
12345678-abcd-1234-5678-123456789012,arn:aws:ec2:us-east-1:123456789012:instance/i-1234567890abcdef0,WebServer-01,COMPLETED,2024-03-15T14:30:52.123Z
87654321-dcba-4321-8765-210987654321,arn:aws:ec2:us-east-1:123456789012:instance/i-0987654321fedcba0,DatabaseServer,RUNNING,2024-03-15T15:45:12.456Z
```

---

## 🛠️ Troubleshooting

### ❌ Common Issues

#### 🔐 **Permission Denied**
```bash
Error: An error occurred (AccessDenied) when calling the ListBackupJobs operation
```
**Solution**: Ensure your AWS credentials have the required permissions listed above.

#### 🏗️ **Vault Not Found**
```bash
Error: An error occurred (InvalidParameterValueException) when calling the ListBackupJobs operation
```
**Solution**: Verify the backup vault name exists and is spelled correctly.

#### 🔧 **Command Not Found**
```bash
./generate_backup_report.sh: line X: jq: command not found
```
**Solution**: Install jq using your system's package manager.

#### 📊 **Empty Report**
**Possible causes:**
- No backup jobs in the specified vault
- Backup jobs are too old (AWS Backup has retention limits)
- Incorrect vault name

### 🔍 Debug Mode

Enable verbose output by adding debugging:

```bash
# Add at the beginning of the script after #!/bin/bash
set -x  # Enable debug mode
```

---

## 🔄 Advanced Configuration

### 🕒 Scheduled Execution

Add to crontab for automated daily reports:

```bash
# Run daily at 2:00 AM
0 2 * * * /path/to/generate_backup_report.sh
```

### 📧 Email Integration

Combine with email notifications:

```bash
#!/bin/bash
./generate_backup_report.sh
echo "Daily backup report attached" | mail -s "AWS Backup Report" -A "$OUTPUT_FILE" admin@company.com
```

---

## 🤝 Contributing

1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit your changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to the branch (`git push origin feature/amazing-feature`)
5. 🔄 Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**⭐ If this tool helped you, please give it a star!**

Made with ❤️ for AWS DevOps Engineers