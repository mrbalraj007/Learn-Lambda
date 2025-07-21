# 🔍 AWS IAM Identity Center User Group Lookup

[![AWS](https://img.shields.io/badge/AWS-IAM_Identity_Center-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/single-sign-on/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

> 🚀 A powerful Bash script to retrieve all groups a user belongs to in AWS IAM Identity Center and export the results to a CSV file.

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Installation](#-installation)
- [🚀 Usage](#-usage)
- [📊 Output Format](#-output-format)
- [🔍 Examples](#-examples)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [📝 Logs](#-logs)
- [🤝 Contributing](#-contributing)

## 🎯 Overview

This script helps you quickly identify all the groups a specific user belongs to in AWS IAM Identity Center (formerly AWS SSO). Perfect for:

- 🔐 Security audits
- 👥 User access reviews
- 📋 Compliance reporting
- 🔄 User onboarding/offboarding processes

## 🔧 Prerequisites

Before running the script, ensure you have the following installed and configured:

### 🛠️ Required Tools

| Tool | Version | Installation | Status |
|------|---------|-------------|--------|
| **AWS CLI** | v2.0+ | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | ✅ Required |
| **jq** | Latest | [Install jq](https://stedolan.github.io/jq/download/) | ✅ Required |
| **Bash** | 4.0+ | Pre-installed on most systems | ✅ Required |

### 🔑 AWS Configuration

1. **Configure AWS CLI credentials:**
   ```bash
   aws configure
   ```

2. **Required AWS Permissions:**
   Your AWS user/role must have the following permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "sso-admin:ListInstances",
           "identitystore:ListUsers",
           "identitystore:ListGroupMembershipsForMember",
           "identitystore:DescribeGroup"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

3. **Verify AWS Configuration:**
   ```bash
   aws sts get-caller-identity
   ```

## 📥 Installation

1. **Clone or download the script:**
   ```bash
   git clone <repository-url>
   cd 33.Bash_Script_AWS_Users_Group
   ```

2. **Make the script executable:**
   ```bash
   chmod +x get_user_groups.sh
   ```

3. **Verify prerequisites:**
   ```bash
   # Check AWS CLI
   aws --version
   
   # Check jq
   jq --version
   
   # Check Bash version
   bash --version
   ```

## 🚀 Usage

### Basic Syntax

```bash
./get_user_groups.sh <username>
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `<username>` | The username in IAM Identity Center | `john.doe@company.com` |

## 📊 Output Format

The script generates two types of output:

### 🗂️ CSV File
- **Filename:** `user_groups_YYYYMMDDHHMMSS.csv`
- **Location:** Same directory as the script
- **Format:**
  ```csv
  Username,Group ID,Group Name
  john.doe@company.com,1234567890-abcd-efgh,Developers
  john.doe@company.com,0987654321-wxyz-1234,Administrators
  ```

### 📋 Log File
- **Filename:** `aws_groups_log_YYYYMMDDHHMMSS.log`
- **Contains:** Detailed execution logs and error messages

## 🔍 Examples

### Example 1: Basic Usage
```bash
./get_user_groups.sh john.doe@company.com
```

**Output:**
```
=== IAM Identity Center User Group Lookup ===
User: john.doe@company.com
Output CSV: ./user_groups_20231215143022.csv
Found 3 group(s)
✔ john.doe@company.com -> 1234567890-abcd -> Developers
✔ john.doe@company.com -> 0987654321-wxyz -> Administrators  
✔ john.doe@company.com -> 5555555555-aaaa -> ReadOnly-Users
```

### Example 2: User with No Groups
```bash
./get_user_groups.sh newuser@company.com
```

**Output:**
```
=== IAM Identity Center User Group Lookup ===
User: newuser@company.com
Output CSV: ./user_groups_20231215143045.csv
Found 0 group(s)
No groups found for user
```

### Example 3: User Not Found
```bash
./get_user_groups.sh nonexistent@company.com
```

**Output:**
```
User not found: nonexistent@company.com
```

## 🛠️ Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| 🚫 `AWS CLI not found` | AWS CLI not installed | Install AWS CLI v2 |
| 🚫 `jq not found` | jq not installed | Install jq JSON processor |
| 🚫 `AWS credentials not configured` | Missing AWS credentials | Run `aws configure` |
| 🚫 `Failed to get Identity Store ID` | No IAM Identity Center instance | Enable IAM Identity Center |
| 🚫 `User not found` | Invalid username | Verify username exists |

### Debug Mode

Enable verbose logging by modifying the script:
```bash
# Add at the top of the script after set -e
set -x  # Enable debug mode
```

## 📝 Logs

### Log File Contents
- Script execution timestamp
- Username and output file paths
- AWS CLI command outputs
- Error messages and stack traces

### Log File Location
```
./aws_groups_log_YYYYMMDDHHMMSS.log
```

## 🎨 Script Features

- ✅ **Color-coded output** for better readability
- ✅ **CSV export** for easy data processing
- ✅ **Comprehensive logging** for troubleshooting
- ✅ **Error handling** with clear messages
- ✅ **Input validation** and prerequisites checking
- ✅ **Cross-platform compatibility**

## 🔒 Security Notes

- 🛡️ Script requires read-only permissions
- 🔐 No sensitive data is stored in logs
- 📊 CSV files contain only group membership data
- 🚫 No passwords or secrets are processed

## 📄 File Structure

```
33.Bash_Script_AWS_Users_Group/
├── get_user_groups.sh          # Main script
├── README.md                   # This file
├── user_groups_*.csv          # Generated CSV files
└── aws_groups_log_*.log       # Generated log files
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

<div align="center">

**Made with ❤️ for AWS DevOps Engineers**

[![AWS](https://img.shields.io/badge/AWS-Certified-FF9900?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![DevOps](https://img.shields.io/badge/DevOps-Friendly-blue?style=flat&logo=devops&logoColor=white)](https://github.com)

</div>
