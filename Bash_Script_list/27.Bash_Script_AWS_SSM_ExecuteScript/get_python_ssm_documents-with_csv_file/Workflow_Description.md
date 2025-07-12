# AWS SSM Document Python Runtime Analysis - Workflow Description

## Architecture Overview

The AWS SSM Document Python Runtime Analysis script follows a comprehensive workflow that interacts with multiple AWS services to discover, analyze, and export SSM document information with focus on Python runtime detection.

## Step-by-Step Workflow Description

### 1. Script Initialization & Authentication
- **Component**: DevOps Engineer → Bash Script
- **Process**: 
  - Engineer executes `get_python_ssm_documents.sh`
  - Script performs initial setup and validation
  - Creates timestamped CSV files for export

### 2. AWS Authentication & Account Verification
- **Component**: Script → AWS STS (Security Token Service)
- **Process**:
  - Script calls `aws sts get-caller-identity` to obtain AWS Account ID
  - Validates AWS credentials and permissions
  - Account ID is used for document ownership filtering and CSV naming

### 3. Document Discovery Phase
- **Component**: Script → AWS Systems Manager
- **Process**:
  - **Multi-source approach** implemented with three parallel discovery methods:
    
    #### 3.1 Self-Owned Documents
    - Query: `aws ssm list-documents --owner Self`
    - Discovers documents owned by the current AWS account
    
    #### 3.2 Account-Owned Documents  
    - Query: `aws ssm list-documents --query 'DocumentIdentifiers[?Owner==ACCOUNT_ID]'`
    - Filters documents by specific account ID
    
    #### 3.3 AWS Managed Documents
    - Query: `aws ssm list-documents --owner Amazon --query 'DocumentIdentifiers[?contains(Name, Python/python/Script)]'`
    - Discovers relevant AWS managed documents containing Python/Script keywords

### 4. Document Content Analysis
- **Component**: Script → Document Processing Engine
- **Process**:
  - For each discovered document:
    - Retrieves document content using `aws ssm get-document --document-format JSON`
    - Extracts comprehensive metadata using `aws ssm describe-document`
    - Filters documents containing Python or executeScript references

### 5. Python Runtime Detection
- **Component**: Multi-method Runtime Detection Engine
- **Process**:
  - **Method 1: Direct JSON Parsing**
    - Searches for `"runtime": "python3.x"` patterns in JSON content
    - Extracts specific Python versions (e.g., python3.6, python2.7)
  
  - **Method 2: Pattern Matching**
    - Uses regex patterns to identify Python version strings
    - Matches `python3.x`, `python2.x` patterns
  
  - **Method 3: ExecuteScript Analysis**
    - Specifically analyzes `aws:executeScript` actions
    - Extracts runtime information from inputs section
  
  - **Method 4: Fallback Detection**
    - General Python keyword detection
    - Provides fallback when specific versions aren't found

### 6. ExecuteScript Detailed Analysis
- **Component**: Specialized ExecuteScript Analyzer
- **Process**:
  - Identifies documents using `aws:executeScript` action
  - Extracts detailed runtime information
  - Captures interpreter paths and platform types
  - Provides comprehensive executeScript-specific metadata

### 7. Metadata Extraction & Enhancement
- **Component**: Document Metadata Processor
- **Process**:
  - **Document Properties**:
    - Document Type, Version, Status
    - Owner information
    - Creation date (formatted)
    - Target type (what resources document can target)
    - Platform types (Windows, Linux, etc.)
  
  - **Runtime Information**:
    - Specific Python version detected
    - Runtime environment details
    - Interpreter paths where available

### 8. CSV Export Generation
- **Component**: CSV Export Engine
- **Process**:
  - Generates three distinct CSV files:
    
    #### 8.1 Main Python Documents CSV
    - **Filename**: `SSM_Python_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`
    - **Content**: All documents with Python/Script content
    - **Columns**: Account_ID, Document_Name, Runtime_Version, Document_Type, Status, Target_Type, Created_Date, Owner, Platform_Types, Document_Version
    
    #### 8.2 ExecuteScript Details CSV
    - **Filename**: `SSM_ExecuteScript_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`
    - **Content**: Detailed analysis of aws:executeScript documents
    - **Columns**: Account_ID, Document_Name, Runtime_Version, Status, Target_Type, Created_Date, Owner, Platform_Types, Document_Version, ExecuteScript_Type
    
    #### 8.3 AWS Managed Documents CSV
    - **Filename**: `AWS_Managed_Documents_{ACCOUNT_ID}_{TIMESTAMP}.csv`
    - **Content**: Status of common AWS managed documents
    - **Columns**: Account_ID, Document_Name, Status, Available, Target_Type, Document_Type

### 9. Console Output Display
- **Component**: Console Output Engine
- **Process**:
  - **Real-time Analysis Display**:
    - Shows document discovery progress
    - Displays analysis results in tabular format
    - Provides detailed executeScript analysis
    - Shows common AWS managed documents status
  
  - **Summary Information**:
    - Total documents analyzed
    - Count of Python runtime documents found
    - Count of executeScript documents
    - CSV export file locations and record counts

### 10. Local File Storage
- **Component**: Local File System
- **Process**:
  - Saves all CSV files to current working directory
  - Implements CSV data sanitization (handles commas, quotes, special characters)
  - Provides file validation and record counting

### 11. Error Handling & Troubleshooting
- **Component**: Error Handling System
- **Process**:
  - **Graceful Error Handling**:
    - Continues processing even if individual documents fail
    - Provides specific error messages for failed operations
  
  - **Troubleshooting Guidance**:
    - AWS CLI configuration validation
    - Permission checking suggestions
    - Region verification commands
    - Connectivity testing recommendations

## Key Technical Features

### Multi-Source Discovery Strategy
- **Redundancy**: Multiple discovery methods ensure comprehensive document coverage
- **Fallback Mechanism**: If primary methods fail, script samples all available documents
- **Deduplication**: Removes duplicate documents from multiple sources

### Advanced Runtime Detection
- **Precision**: Detects specific Python versions (python3.6, python2.7, etc.)
- **Flexibility**: Multiple detection methods for different document formats
- **Context-Aware**: Understands executeScript-specific runtime specifications

### Comprehensive Metadata Capture
- **Document Properties**: Full document lifecycle information
- **Runtime Context**: Detailed runtime environment analysis
- **Platform Support**: Multi-platform compatibility information

### Export Flexibility
- **Multiple Formats**: Three different CSV outputs for different use cases
- **Data Integrity**: Proper CSV sanitization and formatting
- **Traceability**: Account ID and timestamp in all exports

## Security Considerations

### IAM Permissions Required
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

### Data Privacy
- **Local Storage**: All data stored locally, not transmitted externally
- **Account Isolation**: Only accesses documents within authorized account
- **Credential Security**: Uses existing AWS CLI credentials, no credential storage

## Performance Characteristics

### Scalability
- **Parallel Processing**: Processes multiple documents concurrently where possible
- **Memory Efficient**: Processes documents individually to minimize memory usage
- **Network Optimized**: Batches API calls where AWS CLI supports it

### Error Resilience
- **Partial Failure Handling**: Continues processing even if individual documents fail
- **Retry Logic**: Implements fallback discovery methods
- **Comprehensive Logging**: Detailed error reporting and troubleshooting guidance

This workflow provides a comprehensive, reliable, and extensible solution for analyzing AWS SSM documents with Python runtime components.
