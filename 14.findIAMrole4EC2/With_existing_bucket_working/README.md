# EC2 IAM Role Finder

This CloudFormation solution scans all EC2 instances across AWS regions to identify attached IAM roles and their associated permissions. The findings are saved to a CSV file in an existing S3 bucket.

## Features

- **Multi-Region Scanning**: Scans EC2 instances across all AWS regions
- **Scheduled Execution**: Runs automatically on a weekly schedule (configurable)
- **Manual Triggering**: Includes a function URL endpoint for on-demand execution
- **Comprehensive Information Collection**:
  - EC2 instance details (ID and name)
  - IAM role names
  - Role creation dates
  - Attached policy information (both managed and inline)
  - Policy types (AWS Managed, Customer Managed, or Inline)
- **Organized Output**: CSV reports are stored in a 'report' folder within your specified S3 bucket

## Prerequisites

- An existing S3 bucket where reports will be stored
- AWS CLI configured with appropriate permissions
- Permissions to deploy CloudFormation templates and create IAM roles

## Deployment

### Using the AWS Management Console

1. Go to the AWS CloudFormation console
2. Click "Create stack" and select "With new resources (standard)"
3. Upload the template.yaml file
4. Fill in the required parameters:
   - **S3BucketName**: Name of your existing S3 bucket (must have a 'report' folder)
   - **ScheduleExpression**: How frequently to run the scan (default: 'rate(7 days)')
   - **AwsRegion**: The AWS region to scan first (default: 'us-east-1')
5. Click through the stack creation wizard and acknowledge IAM role creation
6. Wait for stack creation to complete

### Using the AWS CLI

Create a file named `parameters.json`:

```json
[
  {
    "ParameterKey": "S3BucketName",
    "ParameterValue": "your-bucket-name"
  },
  {
    "ParameterKey": "ScheduleExpression",
    "ParameterValue": "rate(7 days)"
  },
  {
    "ParameterKey": "AwsRegion",
    "ParameterValue": "us-east-1"
  }
]
```

Deploy the stack:

```bash
aws cloudformation create-stack \
  --stack-name EC2IAMRoleFinder \
  --template-body file://template.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM
```

## Parameters Explained

- **S3BucketName**: Name of an existing S3 bucket where CSV reports will be stored. Reports will be saved to a 'report' folder in this bucket.

- **ScheduleExpression**: Controls how frequently the Lambda function runs. Uses AWS EventBridge schedule expressions:
  - Default: `rate(7 days)` (runs once every week)
  - Other examples:
    - `rate(1 day)` - Runs once every day
    - `rate(12 hours)` - Runs every 12 hours
    - `cron(0 0 ? * MON *)` - Runs at midnight every Monday

- **AwsRegion**: The AWS region where the scanning process will begin. This region will also be used to discover all other AWS regions.

## Output Format

The solution creates CSV files with the following columns:
- Region
- Instance ID
- Instance Name
- IAM Role Name
- Role Creation Date
- Policy Name
- Policy Type

CSV files are named with a timestamp pattern: `ec2-iam-roles-YYYY-MM-DD-HH-MM-SS.csv` and saved in the 'report' folder of your S3 bucket.

## Accessing the Results

1. Navigate to your S3 bucket in the AWS Management Console
2. Go to the 'report' folder
3. Download the desired CSV file

## Manual Execution

The solution creates a Lambda Function URL that allows you to trigger the scan on demand:

1. Get the Function URL from the CloudFormation outputs
2. Open the URL in your browser or use curl/wget to trigger the execution
3. A new scan will begin immediately, and results will be stored in S3

## Adjusting the Solution

### Changing the Schedule

1. Update the CloudFormation stack
2. Modify the `ScheduleExpression` parameter
3. For daily runs: `rate(1 day)`
4. For hourly runs: `rate(1 hour)`
5. For specific times: Use cron expressions like `cron(0 12 * * ? *)`

### Using a Different S3 Location

1. Create a new folder in your S3 bucket
2. Update the Lambda function code to use this folder path instead of 'report/'

## Recent Changes

1. **Weekly Scheduling**: Changed from daily to weekly execution (`rate(7 days)`)
2. **Folder Organization**: Now saves reports to a 'report' subfolder in the S3 bucket
3. **Custom Region**: Added ability to specify a starting AWS region
4. **Existing Bucket**: Now uses an existing S3 bucket instead of creating a new one

## Troubleshooting

- **Function Timeout**: If the scan takes too long, increase the Lambda function timeout in the CloudFormation template
- **Missing Instances**: Verify that the IAM role has permissions to describe instances in all regions
- **S3 Access Denied**: Ensure the IAM role has proper permissions to write to the specified S3 bucket folder
