# AWS SSM Document Python Runtime Analysis

This script analyzes AWS Systems Manager (SSM) documents to identify those using Python runtime, specifically focusing on `aws:executeScript` documents.

## Prerequisites

- AWS CLI installed and configured
- Proper IAM permissions for SSM operations:
  - `ssm:ListDocuments`
  - `ssm:GetDocument`
  - `ssm:DescribeDocument`
  - `sts:GetCallerIdentity`

## Usage

```bash
chmod +x get_python_ssm_documents.sh
./get_python_ssm_documents.sh
```

## Output

The script provides:
1. Current AWS Account ID
2. List of all SSM documents using Python runtime
3. Detailed analysis of `aws:executeScript` documents
4. Runtime version information where available
5. Document type and status

## Features

- Color-coded output for better readability
- Error handling with proper exit codes
- Temporary file cleanup
- Detailed runtime version detection
- Summary statistics

## IAM Policy Example

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:ListDocuments",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```
