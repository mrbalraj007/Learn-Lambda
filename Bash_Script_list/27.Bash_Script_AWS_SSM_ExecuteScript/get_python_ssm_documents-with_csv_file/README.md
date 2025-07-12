# AWS SSM Document Python Runtime Analysis

This advanced script analyzes AWS Systems Manager (SSM) documents to identify those using Python runtime, with special focus on `aws:executeScript` documents. It provides comprehensive analysis and exports data to CSV files for further processing.

## Note: Script is tested on Windows OS. *JQ* need to be installed first then it will works.

## Features

- **Multi-source Document Discovery**: Checks Self-owned, Account-owned, and AWS managed documents
- **Python Runtime Detection**: Identifies specific Python versions (python3.6, python2.7, etc.)
- **ExecuteScript Analysis**: Detailed analysis of `aws:executeScript` documents
- **CSV Export**: Exports results to multiple CSV files with account ID in filename
- **Enhanced Metadata**: Captures creation date, target type, document status, and platform types
- **Color-coded Output**: Improved readability with colored terminal output
- **Error Handling**: Graceful error handling with troubleshooting suggestions

## Prerequisites

- AWS CLI installed and configured
- `jq` command-line JSON processor (optional but recommended)
- Proper IAM permissions for SSM operations:
  - `ssm:ListDocuments`
  - `ssm:GetDocument`
  - `ssm:DescribeDocument`
  - `sts:GetCallerIdentity`

## Installation

```bash
# Download the script
curl -o get_python_ssm_documents.sh https://your-repo/get_python_ssm_documents.sh

# Make it executable
chmod +x get_python_ssm_documents.sh
```

## Usage

```bash
./get_python_ssm_documents.sh
```

## Output Files

The script generates three CSV files with timestamps and account ID:

### 1. Main Python Documents CSV
**File**: `SSM_Python_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`

**Columns**:
- Account_ID
- Document_Name
- Runtime_Version
- Document_Type
- Status
- Target_Type
- Created_Date
- Owner
- Platform_Types
- Document_Version

### 2. ExecuteScript Details CSV
**File**: `SSM_ExecuteScript_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`

**Columns**:
- Account_ID
- Document_Name
- Runtime_Version
- Status
- Target_Type
- Created_Date
- Owner
- Platform_Types
- Document_Version
- ExecuteScript_Type

### 3. AWS Managed Documents CSV
**File**: `AWS_Managed_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`

**Columns**:
- Account_ID
- Document_Name
- Status
- Available
- Target_Type
- Document_Type

## Script Analysis Approach

The script uses multiple methods to discover and analyze documents:

1. **Self-owned Documents**: Documents owned by your account
2. **Account ID Filter**: Documents filtered by account ID
3. **AWS Managed Documents**: Common AWS managed documents with Python/Script content
4. **Fallback Discovery**: Samples all available documents if above methods fail

## Runtime Detection Methods

The script employs several techniques to identify Python runtimes:

1. **Direct JSON Parsing**: Extracts runtime from JSON structure
2. **Pattern Matching**: Identifies python3.x, python2.x patterns
3. **ExecuteScript Analysis**: Specific analysis for aws:executeScript actions
4. **Fallback Detection**: General Python keyword detection

## Console Output

The script provides detailed console output including:

- Account ID verification
- Document discovery progress
- Analysis results table
- ExecuteScript detailed analysis
- Common AWS managed documents check
- CSV export summary
- Troubleshooting suggestions

## IAM Policy Requirements

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

## Troubleshooting

If you encounter issues:

1. **Check AWS CLI Configuration**:
   ```bash
   aws configure list
   aws sts get-caller-identity
   ```

2. **Verify Region Setting**:
   ```bash
   aws configure get region
   ```

3. **Test SSM Permissions**:
   ```bash
   aws ssm list-documents --max-items 5
   ```

4. **Check for jq Installation**:
   ```bash
   which jq
   ```

## Common Issues and Solutions

### No Documents Found
- Verify you have the correct AWS credentials
- Check if you're in the correct region
- Ensure you have SSM permissions
- Try running with `--max-items 10` to test basic connectivity

### CSV Formatting Issues
- Ensure your terminal supports UTF-8 encoding
- Open CSV files with a proper CSV editor (Excel, LibreOffice Calc)
- Check for special characters in document names

### Runtime Detection Issues
- Some documents may not explicitly specify runtime versions
- The script provides fallback detection methods
- Check the detailed executeScript analysis for more information

## Examples

### Basic Usage
```bash
./get_python_ssm_documents.sh
```

### Expected Output
```
=== AWS SSM Documents with Python Runtime Analysis ===
Account ID: 123456789012
CSV export will be saved to: SSM_Python_Documents_123456789012_20241213_143022.csv

Total documents found: 25

Documents Analysis Results:
===============================================================================================================
Document Name                       Runtime         Doc Type        Status      Target Type     Created Date
===============================================================================================================
Copy-AWS-DeleteEbsVolumeSnapshots   python3.6       Command         Active      /AWS::EC2::Volu 2024-05-23 18:1
...
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This script is provided as-is under the MIT License.

## Version History

- **v1.0**: Initial release with basic Python detection
- **v2.0**: Added executeScript analysis and CSV export
- **v3.0**: Enhanced metadata extraction and multiple discovery methods
- **v3.1**: Fixed CSV formatting and added comprehensive documentation
