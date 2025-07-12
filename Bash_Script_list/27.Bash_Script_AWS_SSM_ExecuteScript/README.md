# AWS SSM Document Python Version Audit Script

This script helps identify AWS Systems Manager documents that use deprecated Python versions in `aws:executeScript` actions, as per AWS notification about Python runtime deprecation.

## Background

AWS is discontinuing support for Python 3.6, 3.7, 3.8, and 3.9 runtimes in Systems Manager Automation Documents starting **September 10, 2025**.

## Features

- ✅ Scans all AWS regions (or specific regions)
- ✅ Identifies documents with `aws:executeScript` actions
- ✅ Extracts Python version information
- ✅ Highlights deprecated versions (3.6, 3.7, 3.8, 3.9)
- ✅ Provides account ID and document details
- ✅ Color-coded output for easy identification
- ✅ Includes remediation instructions

## Prerequisites

- AWS CLI installed and configured
- Appropriate IAM permissions:
  - `ssm:ListDocuments`
  - `ssm:GetDocument`
  - `sts:GetCallerIdentity`
  - `ec2:DescribeRegions`

## Usage

```bash
# Make script executable
chmod +x check_ssm_python_versions.sh

# Check all regions
./check_ssm_python_versions.sh

# Check specific regions
./check_ssm_python_versions.sh us-east-1 us-west-2

# Get help
./check_ssm_python_versions.sh --help
```

## Output Example

```
=== AWS SSM Document Python Version Audit ===

AWS Account ID: 123456789012

Checking region: us-east-1
⚠️  DEPRECATED VERSION FOUND:
   Account ID: 123456789012
   Region: us-east-1
   Document: MyAutomationDocument
   Python Version: 3.8
   Action Required: Upgrade to Python 3.11 before Sep 10, 2025

✅ Document: AnotherDocument (Python 3.11 - OK)
```

## Remediation Steps

1. **Get document content:**
   ```bash
   aws ssm get-document --name YOUR_DOCUMENT_NAME --query Content --output text > document.json
   ```

2. **Edit the document:**
   - Change `"Runtime": "python3.8"` to `"Runtime": "python3.11"`
   - Update any Python 3.8-specific code if necessary

3. **Update the document:**
   ```bash
   aws ssm update-document --name YOUR_DOCUMENT_NAME --content file://document.json --document-version $LATEST
   ```

## Exit Codes

- `0`: No deprecated versions found
- `1`: Deprecated versions found - action required

## Important Notes

- Script only checks documents owned by your account (`Owner=Self`)
- Only scans Automation documents (not Command documents)
- Requires network access to AWS APIs
- Runtime may vary based on number of regions and documents
