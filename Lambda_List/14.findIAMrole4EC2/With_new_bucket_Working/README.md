# EC2 IAM Role Finder

This solution provides a way to scan all EC2 instances across all AWS regions and identify the IAM roles attached to them, along with detailed information about the attached policies.

## Features

- Scans all AWS regions for EC2 instances
- Identifies IAM roles attached to each instance
- Collects information about:
  - EC2 instance ID and name
  - IAM role name
  - Role creation date
  - Attached policies (both managed and inline)
  - Policy permissions
- Outputs results to a CSV file stored in S3
- Runs on a schedule (default: daily)
- Can be triggered manually via a function URL

## Deployment

Run the deployment script:

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Create a unique S3 bucket name
2. Deploy the CloudFormation stack
3. Display the outputs including the function URL

## Manual Execution

You can trigger the Lambda function manually by accessing the function URL provided in the CloudFormation outputs.

## CSV Output Format

The CSV file contains the following columns:
- Region
- Instance ID
- Instance Name
- IAM Role Name
- Role Creation Date
- Policy Name
- Policy Type (AWS Managed, Customer Managed, or Inline Policy)
- Policy Permissions (JSON document)

## Accessing Results

CSV files are stored in the S3 bucket created by the CloudFormation stack. Each file is named with a timestamp: `ec2-iam-roles-YYYY-MM-DD-HH-MM-SS.csv`.
