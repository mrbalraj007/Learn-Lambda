# S3 Bucket Tags Export Script

## Overview
This bash script retrieves and exports AWS S3 bucket tags to CSV files. It allows you to extract tags from one or more buckets, with options to filter for specific tags.

## Features
- Extract tags from a single bucket, multiple buckets, or all buckets in a region
- Filter for specific tag keys
- Export tags to CSV format
- Configurable output directory
- Default region: ap-southeast-2
- Automatic detection of jq for better JSON handling

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Bash shell
- Optional: jq (for better JSON parsing)

## Installation
1. Download the script:
   ```bash
   curl -o get_s3_bucket_tags.sh https://path/to/script/get_s3_bucket_tags.sh
   ```
2. Make it executable:
   ```bash
   chmod +x get_s3_bucket_tags.sh
   ```

## Usage
Usage Examples:
1. To get all tags from a single bucket:
```sh
./get_s3_bucket_tags.sh -b mybucket
```
2.To get specific tags from a bucket:
```sh
./get_s3_bucket_tags.sh -b mybucket -t Owner,Project,Environment
```
3. To get tags from multiple buckets:
```sh
./get_s3_bucket_tags.sh -b bucket1,bucket2,bucket3
```
4.To get tags from all buckets in a region:
```sh
./get_s3_bucket_tags.sh -a
```
5. To specify a different region:
```sh
./get_s3_bucket_tags.sh -b mybucket -r us-east-1
```
6. To output files to a specific directory:

```sh
./get_s3_bucket_tags.sh -b mybucket -o /path/to/output
```

The script is designed to gracefully handle edge cases like buckets without tags, and will automatically detect if jq is available for better JSON parsing.

==========================
Make it executable:
```sh
chmod +x get_s3_bucket_tags.sh
```
Usage
```sh
./get_s3_bucket_tags.sh [-b BUCKET_NAME1,BUCKET_NAME2,...] [-a] [-t TAG_KEY1,TAG_KEY2,...] [-r REGION] [-o OUTPUT_DIR]
```
Options
- `-b BUCKET_NAMES`: Comma-separated list of S3 bucket names
- `-a`: Process all buckets in the region
- `-t TAG_KEYS`: Comma-separated list of tag keys to filter (optional)
- `-r REGION`: AWS region (default: ap-southeast-2)
- `-o OUTPUT_DIR`: Output directory for CSV files (default: current directory)
- `-h`: Display help message
Note: Either `-b` (bucket names) or `-a` (all buckets) must be specified.

Output
The script creates one CSV file per bucket with the naming convention `{bucket-name}-tags.csv`. Each CSV file contains:

Header: `Key,Value`
One row for each tag
Examples
Get all tags from a single bucket
```sh
./get_s3_bucket_tags.sh -b my-bucket
```
Get specific tags from a bucket
```sh
./get_s3_bucket_tags.sh -b my-bucket -t Owner,Environment,Project
```
Get tags from multiple buckets
```sh
./get_s3_bucket_tags.sh -b bucket1,bucket2,bucket3
```
Get tags from all buckets in a custom region
```sh
./get_s3_bucket_tags.sh -a -r us-east-1
```
Export to a specific directory
```sh
./get_s3_bucket_tags.sh -b my-bucket -o /path/to/output
```
Troubleshooting
No tags found
If a bucket has no tags, a CSV file with only the header will be created.

Permission errors
Ensure your AWS credentials have the appropriate permissions to list buckets and get bucket tagging.

JSON parsing issues
For the best experience, install `jq` which improves the handling of JSON responses:
```sh
sudo apt-get install jq  # For Debian/Ubuntu
```
The script will automatically detect if jq is available and use it accordingly.