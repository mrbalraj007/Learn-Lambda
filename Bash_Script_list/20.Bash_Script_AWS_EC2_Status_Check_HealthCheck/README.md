# AWS EC2 Status Check Script

A bash script that automatically checks all your EC2 instances for System and Instance Status Check issues across AWS regions.

## Description

This script helps you identify EC2 instances that may be experiencing problems by scanning their status checks. It:
- Scans all EC2 instances across all regions (or specified regions)
- Checks both System Status and Instance Status checks
- Reports instances with failing checks
- Generates a comprehensive CSV report with timestamp
- Provides a summary of findings

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- `jq` command-line JSON processor installed
- Bash shell environment

## Installation

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/yourusername/your-repo/main/ec2_status_check.sh
   ```
   
2. Make it executable:
   ```bash
   chmod +x ec2_status_check.sh
   ```

## Usage

### Basic Usage

Run the script to check all EC2 instances across all regions:

```bash
./ec2_status_check.sh
```

### Check Specific Regions

To check instances in specific regions, provide them as space-separated arguments:

```bash
./ec2_status_check.sh "us-east-1 us-west-2 eu-west-1"
```

## Output

The script generates:

1. A CSV file named `ec2_status_check_YYYY-MM-DD_HH-MM-SS.csv` containing:
   - Instance ID
   - Instance Name (from Name tag)
   - Instance Type
   - Instance State
   - System Status Check result
   - Instance Status Check result
   - Whether there are issues (Yes/No)
   - AWS Region

2. Console output with:
   - Progress information
   - Total instances checked
   - Number of instances with issues
   - Location of the CSV report

## Example Output

