# AWS S3 Bucket Tags Extraction Tool

This script extracts AWS S3 bucket tags and exports them to a single consolidated CSV file, making it easier to analyze and manage tag information across multiple buckets.

## Features

- Export tags from all S3 buckets or specified buckets
- Filter by specific tag keys
- Specify AWS region
- Customize output directory
- Single CSV output with bucket name, tag key, and tag value columns

## Prerequisites

- **AWS CLI**: Must be installed and configured with appropriate credentials
- **jq** (optional but recommended): Improves JSON parsing capabilities
- **Bash shell**: Compatible with Linux, macOS, and Windows (via WSL or Git Bash)
- **AWS IAM permissions**: Requires permissions to list buckets and get bucket tagging

## Installation

1. Download the script:
   ```
   curl -O https://raw.githubusercontent.com/your-repo/get_s3_bucket_tags.sh
   ```
   Or copy it manually to your desired location.

2. Make the script executable:
   ```
   chmod +x get_s3_bucket_tags.sh
   ```

## Usage
```sh
./get_s3_bucket_tags.sh [-b BUCKET_NAME1,BUCKET_NAME2,...] [-a] [-t TAG_KEY1,TAG_KEY2,...] [-r REGION] [-o OUTPUT_DIR]
```
### Parameters

- `-b BUCKET_NAMES`: Comma-separated list of S3 bucket names to process
- `-a`: Process all buckets in the region
- `-t TAG_KEYS`: (Optional) Comma-separated list of tag keys to filter
- `-r REGION`: AWS region (default: ap-southeast-2)
- `-o OUTPUT_DIR`: Output directory for the CSV file (default: current directory)
- `-h`: Display help message

**Note**: Either `-b` or `-a` must be specified

### Examples

1. **Get tags for all buckets in the default region**:
```sh
./get_s3_bucket_tags.sh -a
```
2. **Get tags for specific S3 buckets**:
```sh
./get_s3_bucket_tags.sh -b mybucket1,mybucket2,mybucket3
```
3. **Get only specific tags from all buckets**:
```sh
./get_s3_bucket_tags.sh -a -t Owner,Environment,Project
```
4. **Specify a different region**:

```sh
./get_s3_bucket_tags.sh -a -r us-east-1
```
5. **Save the output file in a specific directory**:
```sh
./get_s3_bucket_tags.sh -a -o /path/to/output/directory
```
6. **Combine multiple options**:
```sh
./get_s3_bucket_tags.sh -b mybucket1,mybucket2 -t Environment,Project -r us-west-2 -o /reports
```
## Output

The script generates a single CSV file named `s3_buckets_tags.csv` in the specified output directory (or current directory by default). The file contains:

- Header row: `Bucket,Key,Value`
- One row for each tag of each bucket with:
  - First column: Bucket name
  - Second column: Tag key
  - Third column: Tag value
- For buckets with no tags, a row with "No tags" values is added

Example output:

```sh
Bucket,Key,Value my-website-bucket,Project,Website my-website-bucket,Environment,Production data-analytics-bucket,Department,Analytics data-analytics-bucket,CostCenter,12345 backup-bucket,No tags,No tags
```

## Troubleshooting

1. **Error: AWS CLI is not installed**
   - Install the AWS CLI using your package manager or from the [AWS website](https://aws.amazon.com/cli/)
   - Run `aws configure` to set up credentials

2. **Error: Failed to list buckets**
   - Verify your AWS credentials are correct
   - Check IAM permissions for the user/role

3. **Error: Permission denied when running the script**
   - Ensure the script has execution permission: `chmod +x get_s3_bucket_tags.sh`

4. **For better performance**:
   - Install the `jq` utility for improved JSON parsing: `apt-get install jq` or `brew install jq`

## Notes

- For large environments with many buckets, the script might take some time to run
- The script handles CSV escaping for values containing commas or quotes
- Empty buckets or buckets without tags are clearly marked in the output



### Basic Syntax

