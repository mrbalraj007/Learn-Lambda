#!/bin/bash

# AWS SSM Document Python Runtime Analysis Script
# This script retrieves SSM documents and analyzes their Python runtime usage

# Remove set -e to handle errors gracefully
set +e

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== AWS SSM Documents with Python Runtime Analysis ===${NC}"
echo ""

# Get current AWS account ID
echo -e "${YELLOW}Getting AWS Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Unable to get AWS account ID. Please check your AWS credentials.${NC}"
    exit 1
fi

echo -e "${GREEN}Account ID: ${ACCOUNT_ID}${NC}"
echo ""

# Create CSV file with account ID in filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CSV_FILE="SSM_Python_Documents_${ACCOUNT_ID}_${TIMESTAMP}.csv"
echo -e "${YELLOW}CSV export will be saved to: ${CSV_FILE}${NC}"
echo ""

# Initialize CSV file with headers
echo "Account_ID,Document_Name,Runtime_Version,Document_Type,Status,Target_Type,Created_Date,Owner,Platform_Types,Document_Version" > "$CSV_FILE"

# Function to sanitize CSV values
sanitize_csv_value() {
    local value="$1"
    # Remove any existing quotes and commas, replace with safe alternatives
    value=$(echo "$value" | sed 's/"/\\\"/g' | sed 's/,/;/g')
    # If value contains spaces, semicolons, or other special characters, wrap in quotes
    if [[ "$value" =~ [[:space:]\;\\] ]]; then
        value="\"$value\""
    fi
    echo "$value"
}

# Function to extract runtime from JSON content
extract_runtime() {
    local content=$1
    
    # Method 1: Direct runtime extraction with various formats
    local runtime=$(echo "$content" | grep -o '"runtime"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"runtime"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    
    # Method 2: Try with single quotes
    if [ -z "$runtime" ]; then
        runtime=$(echo "$content" | grep -o "'runtime'[[:space:]]*:[[:space:]]*'[^']*'" | sed "s/.*'runtime'[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/" | head -1)
    fi
    
    # Method 3: Try without quotes
    if [ -z "$runtime" ]; then
        runtime=$(echo "$content" | grep -o "runtime[[:space:]]*:[[:space:]]*[a-zA-Z0-9._-]*" | sed 's/.*runtime[[:space:]]*:[[:space:]]*\([a-zA-Z0-9._-]*\).*/\1/' | head -1)
    fi
    
    # Method 4: Parse JSON properly for executeScript actions
    if [ -z "$runtime" ]; then
        runtime=$(echo "$content" | jq -r '.mainSteps[]?.action // .steps[]?.action // empty' 2>/dev/null | grep -i "executeScript" | head -1)
        if [ -n "$runtime" ]; then
            runtime=$(echo "$content" | jq -r '.mainSteps[]?.inputs.runtime // .steps[]?.inputs.runtime // empty' 2>/dev/null | grep -v null | head -1)
        fi
    fi
    
    echo "$runtime"
}

# Function to analyze document content
analyze_document() {
    local doc_name=$1
    local doc_content=$2
    
    echo -e "${YELLOW}  -> Analyzing: $doc_name${NC}"
    
    # Check for Python or executeScript in content
    if echo "$doc_content" | grep -q -i "python\|executeScript"; then
        # Get comprehensive document metadata - fix the field extraction
        local doc_metadata=$(aws ssm describe-document \
            --name "$doc_name" \
            --output json 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$doc_metadata" ]; then
            # Extract fields using jq for better parsing
            local doc_type=$(echo "$doc_metadata" | jq -r '.Document.DocumentType // "Unknown"' 2>/dev/null)
            local doc_version=$(echo "$doc_metadata" | jq -r '.Document.DocumentVersion // "Unknown"' 2>/dev/null)
            local doc_status=$(echo "$doc_metadata" | jq -r '.Document.Status // "Unknown"' 2>/dev/null)
            local doc_owner=$(echo "$doc_metadata" | jq -r '.Document.Owner // "Unknown"' 2>/dev/null)
            local created_date=$(echo "$doc_metadata" | jq -r '.Document.CreatedDate // "Unknown"' 2>/dev/null)
            local target_type=$(echo "$doc_metadata" | jq -r '.Document.TargetType // "Unknown"' 2>/dev/null)
            local platform_types=$(echo "$doc_metadata" | jq -r '.Document.PlatformTypes[]? // "Unknown"' 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            
            # Fallback to text parsing if jq fails
            if [ -z "$doc_type" ] || [ "$doc_type" = "null" ] || [ "$doc_type" = "Unknown" ]; then
                local doc_info=$(aws ssm describe-document \
                    --name "$doc_name" \
                    --query '[DocumentType,DocumentVersion,Status,Owner,CreatedDate,TargetType]' \
                    --output text 2>/dev/null)
                
                if [ $? -eq 0 ] && [ -n "$doc_info" ]; then
                    doc_type=$(echo "$doc_info" | cut -f1)
                    doc_version=$(echo "$doc_info" | cut -f2)
                    doc_status=$(echo "$doc_info" | cut -f3)
                    doc_owner=$(echo "$doc_info" | cut -f4)
                    created_date=$(echo "$doc_info" | cut -f5)
                    target_type=$(echo "$doc_info" | cut -f6)
                fi
            fi
            
            # Format creation date
            if [ -n "$created_date" ] && [ "$created_date" != "None" ] && [ "$created_date" != "null" ] && [ "$created_date" != "Unknown" ]; then
                # Handle different date formats
                if echo "$created_date" | grep -q "T"; then
                    created_date=$(date -d "$created_date" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_date" | cut -c1-16)
                fi
            else
                created_date="Not available"
            fi
            
            # Handle target type - fix the None/null issue
            if [ -z "$target_type" ] || [ "$target_type" = "None" ] || [ "$target_type" = "null" ] || [ "$target_type" = "Unknown" ]; then
                target_type="Not specified"
            fi
            
            # Handle document type - fix the None/null issue
            if [ -z "$doc_type" ] || [ "$doc_type" = "None" ] || [ "$doc_type" = "null" ]; then
                doc_type="Unknown"
            fi
            
            # Handle platform types
            if [ -z "$platform_types" ] || [ "$platform_types" = "None" ] || [ "$platform_types" = "null" ] || [ "$platform_types" = "Unknown" ]; then
                platform_types="Not specified"
            fi
            
            # Extract runtime version with enhanced parsing
            local python_version="Unknown"
            
            # First try to extract specific runtime version
            local runtime_info=$(extract_runtime "$doc_content")
            
            if [ -n "$runtime_info" ] && [ "$runtime_info" != "null" ] && [ "$runtime_info" != "Unknown" ]; then
                python_version="$runtime_info"
            else
                # Fallback to pattern matching
                if echo "$doc_content" | grep -q "python3\\."; then
                    python_version=$(echo "$doc_content" | grep -o "python3\.[0-9][0-9]*" | head -1)
                elif echo "$doc_content" | grep -q "python2\\."; then
                    python_version=$(echo "$doc_content" | grep -o "python2\.[0-9][0-9]*" | head -1)
                elif echo "$doc_content" | grep -q "python3"; then
                    python_version="python3"
                elif echo "$doc_content" | grep -q "python2"; then
                    python_version="python2"
                elif echo "$doc_content" | grep -q -i "python"; then
                    python_version="Python (detected)"
                fi
                
                # Check for aws:executeScript
                if echo "$doc_content" | grep -q "aws:executeScript"; then
                    if [ "$python_version" = "Unknown" ]; then
                        python_version="aws:executeScript"
                    fi
                fi
            fi
            
            # Truncate long fields for display
            local display_target_type=$(echo "$target_type" | cut -c1-15)
            local display_created_date=$(echo "$created_date" | cut -c1-15)
            
            printf "%-35s %-15s %-15s %-12s %-15s %-15s\n" "$doc_name" "$python_version" "$doc_type" "$doc_status" "$display_target_type" "$display_created_date"
            
            # Export to CSV - properly sanitize values
            csv_doc_name=$(sanitize_csv_value "$doc_name")
            csv_python_version=$(sanitize_csv_value "$python_version")
            csv_doc_type=$(sanitize_csv_value "$doc_type")
            csv_doc_status=$(sanitize_csv_value "$doc_status")
            csv_target_type=$(sanitize_csv_value "$target_type")
            csv_created_date=$(sanitize_csv_value "$created_date")
            csv_doc_owner=$(sanitize_csv_value "$doc_owner")
            csv_platform_types=$(sanitize_csv_value "$platform_types")
            csv_doc_version=$(sanitize_csv_value "$doc_version")
            
            # Write to CSV with proper column alignment
            echo "${ACCOUNT_ID},${csv_doc_name},${csv_python_version},${csv_doc_type},${csv_doc_status},${csv_target_type},${csv_created_date},${csv_doc_owner},${csv_platform_types},${csv_doc_version}" >> "$CSV_FILE"
            
            # Show additional details for executeScript documents
            if echo "$doc_content" | grep -q "aws:executeScript"; then
                echo -e "${GREEN}    └── executeScript Details:${NC}"
                echo -e "${GREEN}        Platform Types: $platform_types${NC}"
                echo -e "${GREEN}        Document Version: $doc_version${NC}"
                echo -e "${GREEN}        Owner: $doc_owner${NC}"
                echo -e "${GREEN}        Full Target Type: $target_type${NC}"
                echo -e "${GREEN}        Full Created Date: $created_date${NC}"
                
                # Try to extract all runtime references
                local all_runtimes=$(echo "$doc_content" | grep -o '"runtime"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"runtime"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
                if [ -n "$all_runtimes" ]; then
                    echo -e "${GREEN}        Runtime(s) found: $all_runtimes${NC}"
                fi
                
                # Try to find interpreter path
                local interpreter=$(echo "$doc_content" | grep -o '"interpreter"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"interpreter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
                if [ -n "$interpreter" ]; then
                    echo -e "${GREEN}        Interpreter: $interpreter${NC}"
                fi
            fi
            
            return 0
        fi
    fi
    return 1
}

# Try multiple approaches to find documents
echo -e "${YELLOW}Searching for SSM documents...${NC}"
echo ""

# Approach 1: Try Self-owned documents
echo -e "${YELLOW}1. Checking Self-owned documents...${NC}"
SELF_DOCS=$(aws ssm list-documents \
    --owner Self \
    --query 'DocumentIdentifiers[].Name' \
    --output text 2>/dev/null)

# Approach 2: Try documents owned by account ID
echo -e "${YELLOW}2. Checking documents owned by account ID...${NC}"
ACCOUNT_DOCS=$(aws ssm list-documents \
    --query 'DocumentIdentifiers[?Owner==`'$ACCOUNT_ID'`].Name' \
    --output text 2>/dev/null)

# Approach 3: Check AWS managed documents with Python
echo -e "${YELLOW}3. Checking AWS managed documents with Python...${NC}"
AWS_PYTHON_DOCS=$(aws ssm list-documents \
    --owner Amazon \
    --query 'DocumentIdentifiers[?contains(Name, `Python`) || contains(Name, `python`) || contains(Name, `Script`)].Name' \
    --output text 2>/dev/null)

# Combine all found documents
ALL_FOUND_DOCS="$SELF_DOCS $ACCOUNT_DOCS $AWS_PYTHON_DOCS"

# Remove duplicates and empty entries
DOCUMENTS=$(echo $ALL_FOUND_DOCS | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')

echo -e "${GREEN}Total documents found: $(echo $DOCUMENTS | wc -w)${NC}"
echo ""

if [ -z "$DOCUMENTS" ] || [ "$(echo $DOCUMENTS | wc -w)" -eq 0 ]; then
    echo -e "${RED}No documents found. Let's try a different approach...${NC}"
    
    # Try to get a sample of all documents
    echo -e "${YELLOW}Trying to get all available documents...${NC}"
    DOCUMENTS=$(aws ssm list-documents \
        --max-items 50 \
        --query 'DocumentIdentifiers[].Name' \
        --output text 2>/dev/null)
    
    if [ -z "$DOCUMENTS" ]; then
        echo -e "${RED}Still no documents found. Checking AWS CLI configuration...${NC}"
        aws sts get-caller-identity
        aws ssm list-documents --max-items 5
        exit 1
    fi
fi

# Header for output
echo -e "${BLUE}Documents Analysis Results:${NC}"
echo "==============================================================================================================="
printf "%-35s %-15s %-15s %-12s %-15s %-15s\n" "Document Name" "Runtime" "Doc Type" "Status" "Target Type" "Created Date"
echo "==============================================================================================================="

PYTHON_DOCS_FOUND=0
EXECUTE_SCRIPT_DOCS=0

# Process each document
for doc_name in $DOCUMENTS; do
    # Skip empty names
    if [ -z "$doc_name" ]; then
        continue
    fi
    
    # Get document content as JSON
    DOC_CONTENT=$(aws ssm get-document \
        --name "$doc_name" \
        --document-format JSON \
        --query 'Content' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$DOC_CONTENT" ]; then
        if analyze_document "$doc_name" "$DOC_CONTENT"; then
            PYTHON_DOCS_FOUND=$((PYTHON_DOCS_FOUND + 1))
            
            # Check if it's executeScript
            if echo "$DOC_CONTENT" | grep -q "aws:executeScript"; then
                EXECUTE_SCRIPT_DOCS=$((EXECUTE_SCRIPT_DOCS + 1))
            fi
        fi
    else
        echo -e "${RED}  -> Failed to get content for: $doc_name${NC}"
    fi
done

echo "==============================================================================================================="
echo -e "${GREEN}Total documents with Python/Script content: ${PYTHON_DOCS_FOUND}${NC}"
echo -e "${GREEN}Total aws:executeScript documents: ${EXECUTE_SCRIPT_DOCS}${NC}"
echo ""

# Additional detailed analysis for executeScript documents
if [ $EXECUTE_SCRIPT_DOCS -gt 0 ]; then
    echo -e "${BLUE}Detailed aws:executeScript Runtime Analysis:${NC}"
    echo "==============================================================================================="
    printf "%-30s %-20s %-12s %-15s %-15s %-15s\n" "Document Name" "Runtime Version" "Status" "Target Type" "Created Date" "Owner"
    echo "==============================================================================================="
    
    # Create separate CSV for executeScript documents with proper headers
    EXECUTE_SCRIPT_CSV="SSM_ExecuteScript_Documents_${ACCOUNT_ID}_${TIMESTAMP}.csv"
    echo "Account_ID,Document_Name,Runtime_Version,Status,Target_Type,Created_Date,Owner,Platform_Types,Document_Version,ExecuteScript_Type" > "$EXECUTE_SCRIPT_CSV"
    
    for doc_name in $DOCUMENTS; do
        # Skip empty names
        if [ -z "$doc_name" ]; then
            continue
        fi
        
        DOC_CONTENT=$(aws ssm get-document \
            --name "$doc_name" \
            --document-format JSON \
            --query 'Content' \
            --output text 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$DOC_CONTENT" ]; then
            if echo "$DOC_CONTENT" | grep -q "aws:executeScript"; then
                # Use JSON parsing for better accuracy
                DOC_METADATA=$(aws ssm describe-document \
                    --name "$doc_name" \
                    --output json 2>/dev/null)
                
                if [ $? -eq 0 ]; then
                    DOC_STATUS=$(echo "$DOC_METADATA" | jq -r '.Document.Status // "Unknown"' 2>/dev/null)
                    DOC_OWNER=$(echo "$DOC_METADATA" | jq -r '.Document.Owner // "Unknown"' 2>/dev/null)
                    DOC_CREATED=$(echo "$DOC_METADATA" | jq -r '.Document.CreatedDate // "Unknown"' 2>/dev/null)
                    DOC_TARGET_TYPE=$(echo "$DOC_METADATA" | jq -r '.Document.TargetType // "Unknown"' 2>/dev/null)
                    
                    # Format creation date
                    if [ -n "$DOC_CREATED" ] && [ "$DOC_CREATED" != "None" ] && [ "$DOC_CREATED" != "null" ] && [ "$DOC_CREATED" != "Unknown" ]; then
                        if echo "$DOC_CREATED" | grep -q "T"; then
                            DOC_CREATED=$(date -d "$DOC_CREATED" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$DOC_CREATED" | cut -c1-16)
                        fi
                    else
                        DOC_CREATED="Not available"
                    fi
                    
                    # Handle target type
                    if [ -z "$DOC_TARGET_TYPE" ] || [ "$DOC_TARGET_TYPE" = "None" ] || [ "$DOC_TARGET_TYPE" = "null" ] || [ "$DOC_TARGET_TYPE" = "Unknown" ]; then
                        DOC_TARGET_TYPE="Not specified"
                    fi
                    
                    # Extract specific runtime version
                    SPECIFIC_RUNTIME=$(extract_runtime "$DOC_CONTENT")
                    
                    if [ -z "$SPECIFIC_RUNTIME" ] || [ "$SPECIFIC_RUNTIME" = "null" ] || [ "$SPECIFIC_RUNTIME" = "Unknown" ]; then
                        SPECIFIC_RUNTIME="Not specified"
                    fi
                    
                    # Truncate for display
                    DOC_TARGET_TYPE_DISPLAY=$(echo "$DOC_TARGET_TYPE" | cut -c1-15)
                    DOC_CREATED_DISPLAY=$(echo "$DOC_CREATED" | cut -c1-15)
                    
                    printf "%-30s %-20s %-12s %-15s %-15s %-15s\n" "$doc_name" "$SPECIFIC_RUNTIME" "$DOC_STATUS" "$DOC_TARGET_TYPE_DISPLAY" "$DOC_CREATED_DISPLAY" "$DOC_OWNER"
                    
                    # Export executeScript details to CSV with proper sanitization
                    csv_doc_name=$(sanitize_csv_value "$doc_name")
                    csv_runtime=$(sanitize_csv_value "$SPECIFIC_RUNTIME")
                    csv_status=$(sanitize_csv_value "$DOC_STATUS")
                    csv_target=$(sanitize_csv_value "$DOC_TARGET_TYPE")
                    csv_created=$(sanitize_csv_value "$DOC_CREATED")
                    csv_owner=$(sanitize_csv_value "$DOC_OWNER")
                    
                    # Get additional metadata for executeScript CSV
                    platform_info=$(echo "$DOC_METADATA" | jq -r '.Document.PlatformTypes[]? // "Unknown"' 2>/dev/null | tr '\n' ';' | sed 's/;$//')
                    doc_ver=$(echo "$DOC_METADATA" | jq -r '.Document.DocumentVersion // "Unknown"' 2>/dev/null)
                    
                    csv_platform_info=$(sanitize_csv_value "$platform_info")
                    csv_doc_ver=$(sanitize_csv_value "$doc_ver")
                    
                    # Write to ExecuteScript CSV with proper column alignment
                    echo "${ACCOUNT_ID},${csv_doc_name},${csv_runtime},${csv_status},${csv_target},${csv_created},${csv_owner},${csv_platform_info},${csv_doc_ver},aws:executeScript" >> "$EXECUTE_SCRIPT_CSV"
                fi
            fi
        fi
    done
    
    echo "==============================================================================================="
    echo -e "${GREEN}ExecuteScript details exported to: ${EXECUTE_SCRIPT_CSV}${NC}"
fi

# Show some common AWS managed documents for reference
echo -e "${BLUE}Common AWS Managed Documents Check:${NC}"
echo "=========================================================================="
printf "%-35s %-15s %-15s %-15s\n" "Document Name" "Status" "Available" "Target Type"
echo "=========================================================================="

# Create CSV for common AWS managed documents with proper headers
COMMON_DOCS_CSV="AWS_Managed_Documents_${ACCOUNT_ID}_${TIMESTAMP}.csv"
echo "Account_ID,Document_Name,Status,Available,Target_Type,Document_Type" > "$COMMON_DOCS_CSV"

COMMON_DOCS="AWS-RunPythonScript AWS-RunShellScript AWS-ConfigureAWSPackage AWS-RunPatchBaseline AWS-UpdateSSMAgent AWS-RunPowerShellScript"

for common_doc in $COMMON_DOCS; do
    if aws ssm describe-document --name "$common_doc" >/dev/null 2>&1; then
        DOC_INFO=$(aws ssm describe-document \
            --name "$common_doc" \
            --query '[Status,TargetType,DocumentType]' \
            --output text 2>/dev/null)
        
        DOC_STATUS=$(echo "$DOC_INFO" | cut -f1)
        DOC_TARGET_TYPE=$(echo "$DOC_INFO" | cut -f2)
        DOC_TYPE=$(echo "$DOC_INFO" | cut -f3)
        
        if [ -z "$DOC_TARGET_TYPE" ] || [ "$DOC_TARGET_TYPE" = "None" ]; then
            DOC_TARGET_TYPE="Not specified"
        fi
        
        printf "%-35s %-15s %-15s %-15s\n" "$common_doc" "$DOC_STATUS" "Yes" "$DOC_TARGET_TYPE"
        
        # Export to CSV with proper sanitization
        csv_common_doc=$(sanitize_csv_value "$common_doc")
        csv_doc_status=$(sanitize_csv_value "$DOC_STATUS")
        csv_target_type=$(sanitize_csv_value "$DOC_TARGET_TYPE")
        csv_doc_type=$(sanitize_csv_value "$DOC_TYPE")
        
        echo "${ACCOUNT_ID},${csv_common_doc},${csv_doc_status},Yes,${csv_target_type},${csv_doc_type}" >> "$COMMON_DOCS_CSV"
    else
        printf "%-35s %-15s %-15s %-15s\n" "$common_doc" "Not Found" "No" "N/A"
        csv_common_doc=$(sanitize_csv_value "$common_doc")
        echo "${ACCOUNT_ID},${csv_common_doc},Not Found,No,N/A,Unknown" >> "$COMMON_DOCS_CSV"
    fi
done

echo "=========================================================================="
echo ""

# Final Summary
echo -e "${BLUE}=== Final Summary ===${NC}"
echo -e "${GREEN}Account ID: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}Documents analyzed: $(echo $DOCUMENTS | wc -w)${NC}"
echo -e "${GREEN}Documents with Python/Script content: ${PYTHON_DOCS_FOUND}${NC}"
echo -e "${GREEN}aws:executeScript documents: ${EXECUTE_SCRIPT_DOCS}${NC}"
echo ""

# CSV Export Summary
echo -e "${BLUE}=== CSV Export Summary ===${NC}"
echo -e "${GREEN}Main export file: ${CSV_FILE}${NC}"
if [ -f "$CSV_FILE" ]; then
    echo -e "${YELLOW}  Column structure: Account_ID | Document_Name | Runtime_Version | Document_Type | Status | Target_Type | Created_Date | Owner | Platform_Types | Document_Version${NC}"
fi

if [ $EXECUTE_SCRIPT_DOCS -gt 0 ]; then
    echo -e "${GREEN}ExecuteScript details: ${EXECUTE_SCRIPT_CSV}${NC}"
    if [ -f "$EXECUTE_SCRIPT_CSV" ]; then
        echo -e "${YELLOW}  Column structure: Account_ID | Document_Name | Runtime_Version | Status | Target_Type | Created_Date | Owner | Platform_Types | Document_Version | ExecuteScript_Type${NC}"
    fi
fi

echo -e "${GREEN}AWS managed documents: ${COMMON_DOCS_CSV}${NC}"
if [ -f "$COMMON_DOCS_CSV" ]; then
    echo -e "${YELLOW}  Column structure: Account_ID | Document_Name | Status | Available | Target_Type | Document_Type${NC}"
fi

echo ""

# Show CSV file contents summary
if [ -f "$CSV_FILE" ]; then
    CSV_RECORDS=$(wc -l < "$CSV_FILE")
    echo -e "${GREEN}Total records in main CSV: $((CSV_RECORDS - 1))${NC}"
fi

if [ -f "$EXECUTE_SCRIPT_CSV" ]; then
    EXECUTE_CSV_RECORDS=$(wc -l < "$EXECUTE_SCRIPT_CSV")
    echo -e "${GREEN}Total executeScript records: $((EXECUTE_CSV_RECORDS - 1))${NC}"
fi

if [ -f "$COMMON_DOCS_CSV" ]; then
    COMMON_CSV_RECORDS=$(wc -l < "$COMMON_DOCS_CSV")
    echo -e "${GREEN}Total common document records: $((COMMON_CSV_RECORDS - 1))${NC}"
fi

echo ""

# Troubleshooting tips
echo -e "${YELLOW}If you encountered issues, consider the following:${NC}"
echo -e "${YELLOW}  - Check AWS CLI configuration and permissions.${NC}"
echo -e "${YELLOW}  - Ensure correct region is set: aws configure get region${NC}"
echo -e "${YELLOW}  - Validate AWS credentials: aws sts get-caller-identity${NC}"
echo -e "${YELLOW}  - Review SSM document availability in your account.${NC}"

echo -e "${BLUE}Script completed!${NC}"
echo -e "${YELLOW}CSV files created in current directory with account ID ${ACCOUNT_ID} in filename.${NC}"