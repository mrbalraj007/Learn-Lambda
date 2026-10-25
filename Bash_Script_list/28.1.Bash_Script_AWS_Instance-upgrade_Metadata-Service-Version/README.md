# AWS EC2 IMDS Version Checker and Enforcer

This Bash script inspects EC2 instances in an AWS region, reports their instance metadata service (IMDS) configuration, and can automatically enforce IMDSv2 for instances that still allow IMDSv1.

## What the script does

- Lists EC2 instances in the target AWS region
- Checks the `MetadataOptions.HttpTokens` value for each instance
- Classifies instances as:
  - IMDSv2 only (`required`)
  - IMDSv1/v2 mixed (`optional`)
  - Unknown
- Prints a summary of how many instances are secure or vulnerable
- Creates a CSV report with the detected instance metadata details
- Optionally updates instances to enforce IMDSv2 (`HttpTokens=required`)
- Enables metadata endpoint and metadata tags for the updated instances

## Why this matters

AWS IMDSv2 is the more secure metadata access mode because it requires session-oriented tokens instead of the older IMDSv1 retrieval flow. Enforcing IMDSv2 reduces the risk of SSRF and metadata exposure attacks.

## Requirements

Before running the script, ensure:

- AWS CLI is installed and available in `PATH`
- Valid AWS credentials are configured (for example via `aws configure`, environment variables, or an assumed role)
- You have permission to read EC2 metadata options and modify instance metadata settings

Typical permissions include:

- `ec2:DescribeInstances`
- `ec2:ModifyInstanceMetadataOptions`
- `sts:GetCallerIdentity`

## Script file

- `Upgrade_ec2_imds_versions.sh`

## Usage

Run the script without arguments to scan the default region (`us-east-1`):

```bash
./Upgrade_ec2_imds_versions.sh
```

Run against a specific region:

```bash
./Upgrade_ec2_imds_versions.sh us-east-1
```

Force IMDSv2 enforcement on IMDSv1-enabled instances:

```bash
./Upgrade_ec2_imds_versions.sh --enforce-imdsv2 -y
```

Target all instances in a region instead of only IMDSv1-enabled instances:

```bash
./Upgrade_ec2_imds_versions.sh eu-west-1 --upgrade --all
```

Display help:

```bash
./Upgrade_ec2_imds_versions.sh --help
```

## Supported arguments

- `region` or `--region <region>`: Set AWS region
- `--enforce-imdsv2` or `--upgrade`: Enforce IMDSv2 on target instances
- `--only-imdsv1`: Target only instances with `HttpTokens=optional` (default behavior)
- `--all`: Target all instances, excluding terminated and shutting-down ones
- `-y` or `--yes`: Skip the confirmation prompt
- `-h` or `--help`: Show usage details

## Default behavior

When the script runs normally:

1. It checks the current AWS account and region.
2. It generates a CSV report named like:
   `ec2_imds_versions_account_<ACCOUNT_ID>_<REGION>_<TIMESTAMP>.csv`
3. It prints a table of the EC2 instances and their IMDS mode.
4. If any instance is still using IMDSv1, it automatically upgrades those instances to IMDSv2.
5. It prints the final summary and confirms where the CSV report was saved.

## CSV output format

The CSV contains the following columns:

```text
InstanceId,State,Name,IMDSVersion,HttpTokens,HopLimit,Endpoint,InstanceTags,Region,Timestamp
```

Example:

```text
i-0123456789abcdef0,running,web-app,IMDSv2,required,1,enabled,production,us-east-1,2026-10-15 13:00:00
```

## Example output

```text
========================================
EC2 Instance Metadata Service Version Checker / Enforcer
Region: us-east-1
Account ID: 123456789012
CSV Output: ec2_imds_versions_account_123456789012_us-east-1_20261015_130000.csv
========================================
Fetching EC2 instances...
Instance ID          State           Name                      IMDS Tokens  Hop Limit  Endpoint  Instance Tags
--------------------------------------------------------------------------------------------------------
i-123456             running         web-app                   IMDSv2      1          enabled   production
i-987654             stopped         app-worker                IMDSv1/v2   1          enabled   dev

IMDS Configuration Summary
Total Instances: 2
IMDSv2 Only (Secure): 1
IMDSv1 Enabled (Less Secure): 1
```

## Notes

- The script does not permanently store the CSV anywhere outside the current working directory.
- It uses the current AWS profile or CLI credentials available in the environment.
- If an instance fails to update, the script reports the failure and may require additional IAM permissions or instance constraints.

## Security recommendation

Use IMDSv2-only configuration for production workloads wherever possible and keep IMDSv1 disabled unless there is a documented business requirement requiring backward compatibility.
