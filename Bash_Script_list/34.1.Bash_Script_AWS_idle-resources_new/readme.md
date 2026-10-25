# AWS Unused Resources Audit

This folder contains Bash scripts that query the AWS account selected by the AWS CLI and save reports about resources that may be unused or worth reviewing. The scripts only call AWS `describe` and `list` operations; they do not delete or modify AWS resources.

## Files

- [`aws_unused_resources_report-in-csv-format.sh`](./aws_unused_resources_report-in-csv-format.sh) writes CSV files and a summary report.
- [`aws_unused_resources_report-txt-format/aws_unused_resources_report-Saveoutput-in-txt-format.sh`](./aws_unused_resources_report-txt-format/aws_unused_resources_report-Saveoutput-in-txt-format.sh) writes human-readable text files.
- [`aws_unused_resources_architecture.drawio`](./aws_unused_resources_architecture.drawio) is the associated architecture diagram.

## Step-by-step guide

### 1. Choose a Bash environment

Run the scripts from Bash. On Windows, use WSL or Git Bash with AWS CLI and the required Unix command-line utilities available. The scripts use GNU `date` options, so WSL is recommended if Git Bash does not support those options.

### 2. Install and check the AWS CLI

Install AWS CLI v2, then verify it is available:

```bash
aws --version
```

The CSV script also uses common shell utilities including `sed`, `wc`, and `tail`.

### 3. Configure credentials and select the account

Configure an AWS CLI profile using your organization's approved authentication method. For example, with AWS IAM Identity Center:

```bash
aws configure sso --profile audit
aws sso login --profile audit
```

Select the profile and a default region for regional services:

```bash
export AWS_PROFILE=audit
export AWS_REGION=ap-southeast-2
```

Check the identity before running the audit:

```bash
aws sts get-caller-identity
```

Confirm the returned account and role are the intended ones. IAM and Route 53 are global services; most of the other checks run in the configured region. Repeat the audit for each region you need to review.

### 4. Grant read-only permissions

Use an appropriately scoped, read-only role. The checks need permission for the following AWS API actions:

- `ec2:DescribeVolumes`, `ec2:DescribeInstances`, `ec2:DescribeAddresses`, `ec2:DescribeSecurityGroups`, `ec2:DescribeNetworkInterfaces`, `ec2:DescribeImages`, `ec2:DescribeNatGateways`
- `elasticloadbalancing:DescribeLoadBalancers`, `elasticloadbalancing:DescribeTargetGroups`, `elasticloadbalancing:DescribeTargetHealth`
- `s3:ListAllMyBuckets`, `s3:ListBucket`
- `iam:ListUsers`, `iam:GetUser`
- `route53:ListHostedZones`
- `rds:DescribeDBInstances`, `rds:DescribeDBSnapshots`
- `cloudwatch:DescribeAlarms`

S3 bucket listing permissions may need to be granted on the relevant buckets. Follow your organization's policy and least-privilege requirements.

### 5. Review the TLS setting in the CSV script

The CSV script currently passes `--no-verify-ssl` to its AWS CLI calls. This disables TLS certificate verification and makes the connection less secure. Prefer fixing the local AWS CLI certificate/CA configuration and removing this option from the script before running it, especially on an untrusted network. Do not treat this option as a general SSL troubleshooting fix.

The text-format script does not use this option for most checks, but does use it for its IAM and Route 53 checks.

### 6. Run one report

From this folder, run either script:

```bash
bash aws_unused_resources_report-in-csv-format.sh
```

Or:

```bash
bash aws_unused_resources_report-txt-format/aws_unused_resources_report-Saveoutput-in-txt-format.sh
```

The output directory is created in the current working directory. Its name uses the local date, for example `aws-unused-report-2026-10-26`. Running a script more than once on the same date reuses that directory and replaces report files with the same names.

### 7. Review the report files

The CSV script creates these files:

| File | Contents |
| --- | --- |
| `summary-report.csv` | Counts and filenames for the resource reports |
| `ebs-unattached.csv` | EBS volumes with `available` status |
| `ec2-stopped.csv` | Stopped EC2 instances |
| `eip-unused.csv` | Elastic IP addresses with no association |
| `sg-unused.csv` | Non-default security groups not found on a network interface |
| `ami-unused.csv` | All AMIs owned by the account; the script does not determine whether they are old or unused |
| `elb-unused.csv` | ELBv2 load balancers with no target-health descriptions found across their target groups |
| `s3-empty.csv` | Buckets for which the script finds no listed objects |
| `iam-inactive-users.csv` | IAM users with no password-last-used value or a password last used over 90 days ago |
| `route53-hostedzones.csv` | Hosted zones for manual review |
| `classic-elb-unused.csv` | Classic load balancers with no registered instances |
| `rds-stopped.csv` | Stopped RDS instances |
| `rds-old-snapshots.csv` | Manual RDS snapshots older than 30 days |
| `nat-gateways.csv` | Available NAT Gateways, which may incur hourly charges |
| `cloudwatch-unused-alarms.csv` | Alarms currently in `OK` or `INSUFFICIENT_DATA` state |

The text-format script creates corresponding `.txt` reports, but does not create a summary file.

## Important interpretation notes

These reports are investigation leads, not proof that a resource is safe to remove. Review ownership, dependencies, retention rules, and production requirements with the service owner before taking action.

- The AMI report includes every AMI owned by the account; it does not check age or whether an AMI is referenced by running instances.
- The ELBv2 check tests for target-health descriptions, not whether targets are healthy or whether the load balancer receives traffic. A load balancer with no target groups may also be reported.
- The IAM check looks at `PasswordLastUsed`, not all forms of user or access-key activity.
- The CloudWatch report selects alarms by their current state. It does not check whether that state has persisted for 30 days.
- Route 53 hosted zones and available NAT Gateways are intentionally surfaced for manual assessment rather than conclusively classified as unused.
- The CSV script suppresses AWS CLI error output for many calls and does not reliably propagate failures through pipelines. A failed list or attachment query can look like no results, particularly for S3 buckets and security groups. Validate permissions and do not treat an empty report as proof that no resources exist.
- The CSV script converts tab-separated AWS CLI output to commas; values containing commas are not escaped as standard CSV fields.
