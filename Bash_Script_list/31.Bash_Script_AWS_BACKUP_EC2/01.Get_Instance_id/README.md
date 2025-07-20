# 🚀 AWS EC2 Instance ID Retrieval Tool

![AWS](https://img.shields.io/badge/AWS-EC2-orange?style=for-the-badge&logo=amazon-aws)
![Bash](https://img.shields.io/badge/Shell-Bash-green?style=for-the-badge&logo=gnu-bash)

> A powerful bash script to retrieve AWS EC2 instance IDs by their instance names.

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Usage](#-usage)
- [How it Works](#-how-it-works)
- [Troubleshooting](#-troubleshooting)
- [Example Output](#-example-output)

## 🔧 Prerequisites

Before using this script, ensure you have:

| Requirement | Details |
|-------------|---------|
| ✅ **AWS CLI** | The script requires AWS CLI to be installed on your system |
| ✅ **AWS Credentials** | Valid AWS credentials configured (via `aws configure` or environment variables) |
| ✅ **Input CSV file** | A CSV file named `instance_names.csv` with instance names |

### AWS CLI Installation

<details>
<summary>Click to expand installation instructions</summary>

#### 🪟 Windows
```powershell
# Install with chocolatey
choco install awscli

# Or download the official MSI installer
```

#### 🐧 Linux
```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install awscli

# For Amazon Linux/RHEL/CentOS
sudo yum install awscli
```

#### 🍎 macOS
```bash
# Using Homebrew
brew install awscli
```

</details>

### AWS Credentials Setup

```bash
aws configure
```

### CSV File Format

Your `instance_names.csv` should follow this format:

```csv
instance_name
xxxAWSxxxx01
xxxAWSxxxx02
```

## 💻 Installation

1. **Download the script**:
   ```bash
   # Clone the repository or download the script directly
   curl -O https://path-to-repo/get_instance_ids.sh
   ```

2. **Make the script executable**:
   ```bash
   chmod +x get_instance_ids.sh
   ```

## 🚀 Usage

Run the script:

```bash
./get_instance_ids.sh
```

The script will:
- Read instance names from `instance_names.csv`
- Query AWS for matching instance IDs
- Output results to a file named `[ACCOUNT_ID]_instance_ids_output_[DATETIME].csv`

## 🔍 How it Works

1. **Initialization**:
   - Validates AWS CLI installation
   - Checks for input CSV file
   - Sets up SSL verification options

2. **Account ID Retrieval**:
   - Gets AWS account ID for the output filename
   - Falls back to "unknown" if retrieval fails

3. **Instance Processing**:
   - Reads each instance name from the CSV file
   - Queries AWS EC2 API to find matching instance IDs
   - Records successful and failed lookups

4. **Output Generation**:
   - Creates a CSV file with results
   - Names the file with account ID and timestamp

## ⚠️ Troubleshooting

### SSL Certificate Issues

If you're in a corporate environment, you might encounter SSL certificate validation issues. The script handles this automatically by disabling SSL verification.

To enable SSL verification, change this line in the script:

```bash
DISABLE_SSL_VERIFY=false
```

### Alternative SSL Solutions

If disabling SSL verification is not acceptable, you can:

1. **Set AWS_CA_BUNDLE environment variable**:
   ```bash
   export AWS_CA_BUNDLE=/path/to/certificate/bundle.pem
   ```

2. **Configure AWS CLI to use a certificate bundle**:
   ```bash
   aws configure set ca_bundle /path/to/certificate/bundle.pem
   ```

3. **Add the corporate root certificate to your system's certificate store**

### Instance Not Found

If instances aren't found, verify:
- Instance names are correct
- Instances exist in the region your AWS CLI is configured to use
- Your AWS credentials have permission to describe EC2 instances

## 📊 Example Output

The output file will contain:

```csv
INSTANCE_NAME,INSTANCE_ID
xxxAWSxxxx01,i-0abc1234567890
xxxAWSxxxx02,i-01234567890000
```

If an instance can't be found, its ID will be marked as `NOT_FOUND`.
