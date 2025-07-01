# AWS S3 Bucket Tags Extractor

A Bash script to extract AWS S3 bucket tags and export them to CSV format with account ID and timestamp in the filename.

## Features

- Extract tags from specific S3 buckets or all buckets in a region
- Filter tags by specific tag keys
- Export data to CSV format with proper escaping
- Include AWS account ID and timestamp in filename
- Support for multiple AWS regions
- Graceful handling of buckets with no tags
- Compatible with and without `jq` JSON processor

## Prerequisites

- **AWS CLI**: Must be installed and configured with appropriate credentials
- **Bash**: Compatible with Bash 4.0+
- **jq** (optional): For better JSON processing, but script works without it

### AWS Permissions Required

Your AWS credentials must have the following permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:GetBucketTagging"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Installation

1. Clone or download the script:
```bash
git clone <repository-url>
cd 21.Bash_Script_AWS_S3_Details
```

2. Make the script executable:
```bash
chmod +x get_s3_bucket_tags_with_Account_Name.sh
```

## Usage

### Basic Syntax
```bash
./get_s3_bucket_tags_with_Account_Name.sh [OPTIONS]
```

### Options

| Option | Description | Required |
|--------|-------------|----------|
| `-b BUCKET_NAMES` | Comma-separated list of S3 bucket names | Yes* |
| `-a` | Process all buckets in the region | Yes* |
| `-t TAG_KEYS` | Comma-separated list of tag keys to filter (optional) | No |
| `-r REGION` | AWS region (default: ap-southeast-2) | No |
| `-o OUTPUT_DIR` | Output directory for CSV files (default: current directory) | No |
| `-h` | Display help message | No |

*Note: Either `-b` or `-a` must be specified

## Examples

### 1. Extract tags from specific buckets
```bash
./get_s3_bucket_tags_with_Account_Name.sh -b "my-bucket1,my-bucket2,my-bucket3"
```

### 2. Extract tags from all buckets in default region
```bash
./get_s3_bucket_tags_with_Account_Name.sh -a
```

### 3. Extract specific tag keys from all buckets
```bash
./get_s3_bucket_tags_with_Account_Name.sh -a -t "Environment,Team,Owner"
```

### 4. Extract tags from buckets in a specific region
```bash
./get_s3_bucket_tags_with_Account_Name.sh -a -r us-west-2
```

### 5. Save output to specific directory
```bash
./get_s3_bucket_tags_with_Account_Name.sh -a -o "/path/to/output"
```

### 6. Comprehensive example
```bash
./get_s3_bucket_tags_with_Account_Name.sh -b "prod-bucket,dev-bucket" -t "Environment,Team" -r us-east-1 -o "./reports"
```

## Output

### Filename Format
The script generates a CSV file with the following naming convention:
```
s3_buckets_tags_{ACCOUNT_ID}_{TIMESTAMP}.csv
```

Example: `s3_buckets_tags_123456789012_20240115_143025.csv`

### CSV Format
The CSV file contains the following columns:
- **Bucket**: S3 bucket name
- **Key**: Tag key name
- **Value**: Tag value

### Sample Output
```csv
Bucket,Key,Value
my-prod-bucket,Environment,Production
my-prod-bucket,Team,DevOps
my-prod-bucket,Owner,john.doe@company.com
my-dev-bucket,Environment,Development
my-dev-bucket,Team,DevOps
no-tags-bucket,No tags,No tags
```

## Error Handling

The script handles various error scenarios:

1. **No tags found**: Buckets without tags are recorded with "No tags" entries
2. **Access denied**: Script will report buckets that cannot be accessed
3. **Invalid bucket names**: Non-existent buckets are reported as errors
4. **Network issues**: AWS CLI errors are captured and reported

## Troubleshooting

### Common Issues

#### 1. AWS CLI not configured
**Error**: `Unable to locate credentials`
**Solution**: Configure AWS CLI with `aws configure` or set environment variables

#### 2. Insufficient permissions
**Error**: `Access Denied` or `User: ... is not authorized to perform: s3:GetBucketTagging`
**Solution**: Ensure your AWS user/role has the required permissions listed above

#### 3. Region-specific buckets
**Error**: Some buckets not appearing
**Solution**: S3 buckets are global, but some operations are region-specific. Try different regions or check bucket locations

#### 4. Large number of buckets
**Issue**: Script takes a long time
**Solution**: Use `-b` option to specify only needed buckets instead of `-a`

### Debug Mode
To enable verbose output for debugging:
```bash
bash -x ./get_s3_bucket_tags_with_Account_Name.sh -a
```

## Performance Considerations

- **Large accounts**: For accounts with many buckets, consider using `-b` to specify only required buckets
- **Network latency**: Script performance depends on AWS API response times
- **Rate limiting**: AWS may throttle requests for accounts with many buckets

## Limitations

1. The script processes buckets sequentially (not in parallel)
2. Cross-region bucket access may have additional latency
3. Very large tag values might affect CSV formatting
4. Script requires internet connectivity to access AWS APIs

## Version History

- **v1.0**: Initial release with basic tag extraction
- **v2.0**: Added account ID in filename and improved error handling

## Contributing

To contribute to this script:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify AWS permissions and CLI configuration
3. Test with a small subset of buckets first
4. Check AWS CloudTrail for API call details if needed

## License

This script is provided as-is for educational and operational purposes.
