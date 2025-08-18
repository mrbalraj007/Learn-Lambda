# 🔍 EC2 CloudTrail Audit Tool

<div align="center">
  
  ![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
  ![Bash](https://img.shields.io/badge/Bash-%234EAA25.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
  ![CloudTrail](https://img.shields.io/badge/CloudTrail-%232E77BC.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
  
</div>

> Investigate EC2 instance activities in CloudTrail logs with a focus on stop and terminate events.

This tool helps AWS administrators and security teams audit EC2 instance activities by analyzing CloudTrail logs for the past 72 hours. It specifically focuses on identifying who stopped or terminated EC2 instances, providing detailed information about each event.

## ✨ Features

- 📊 Process multiple EC2 instances from a CSV input file
- 🕒 Searches CloudTrail logs for the last 72 hours
- 🔎 Focuses on stop and terminate activities
- 👤 Identifies who performed the actions
- 📝 Exports findings to a structured CSV file
- 🖥️ Works on both Linux and macOS environments

## 📋 Prerequisites

Before using this tool, ensure you have the following prerequisites installed:

| Requirement | Purpose | Installation |
|-------------|---------|-------------|
| 🔸 **AWS CLI** | Interact with AWS services | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| 🔸 **jq** | Process JSON data | Linux: `apt-get install jq` or macOS: `brew install jq` |
| 🔸 **AWS Credentials** | Access CloudTrail logs | Configure with `aws configure` |
| 🔸 **Bash Shell** | Run the script | Default on Linux/macOS |

> 💡 **Note:** Ensure your AWS credentials have sufficient permissions to access CloudTrail logs.

## 🚀 Installation

1. Clone or download this repository:

```bash
git clone <repository-url>
cd <repository-directory>/EC2_Investigate
```

2. Make the script executable:

```bash
chmod +x ec2_cloudtrail_audit.sh
```

## 📘 Usage

### Step 1: Prepare your input file
Create a CSV file (e.g., `instances.csv`) with EC2 instance IDs, one per line:

```
i-0abc123def456789
i-0123456789abcdef0
```

### Step 2: Run the script
Execute the script with input and output file parameters:

```bash
./ec2_cloudtrail_audit.sh instances.csv results.csv
```

### Step 3: Review the results
The script will generate a CSV file with the following columns:

- **InstanceID**: The EC2 instance identifier
- **EventTime**: When the action occurred
- **EventName**: The type of action (e.g., StopInstances, TerminateInstances)
- **UserName**: Who performed the action
- **UserType**: The type of AWS identity
- **SourceIP**: The IP address where the request originated
- **UserAgent**: The client used to make the request
- **EventSource**: The AWS service that processed the request
- **Region**: The AWS region where the action occurred

## 📊 Example Output

```
InstanceID,EventTime,EventName,UserName,UserType,SourceIP,UserAgent,EventSource,Region
i-0abc123def456789,2023-06-15T14:30:45Z,StopInstances,john.doe,IAMUser,192.168.1.100,console.amazonaws.com,ec2.amazonaws.com,us-east-1
```

## ⚠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| **Permission Denied** | Ensure your AWS credentials have sufficient permissions to access CloudTrail logs |
| **No Events Found** | Verify the instance ID is correct and that the instance had activity within the last 72 hours |
| **AWS CLI Error** | Make sure AWS CLI is installed and configured correctly |
| **jq Not Found** | Install jq using your package manager (`apt-get install jq` or `brew install jq`) |

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---

<div align="center">
  
  Made with ❤️ for AWS Cloud Engineers
  
</div>
