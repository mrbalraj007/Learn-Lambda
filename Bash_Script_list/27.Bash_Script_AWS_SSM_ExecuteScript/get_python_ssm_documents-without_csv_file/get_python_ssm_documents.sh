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

# Function to analyze document content
analyze_document() {
    local doc_name=$1
    local doc_content=$2
    
    echo -e "${YELLOW}  -> Analyzing: $doc_name${NC}"
    
    # Check for Python or executeScript in content
    if echo "$doc_content" | grep -q -i "python\|executeScript"; then
        # Get document metadata
        local doc_info=$(aws ssm describe-document \
            --name "$doc_name" \
            --query '[DocumentType,DocumentVersion,Status,Owner]' \
            --output text 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$doc_info" ]; then
            local doc_type=$(echo "$doc_info" | cut -f1)
            local doc_version=$(echo "$doc_info" | cut -f2)
            local doc_status=$(echo "$doc_info" | cut -f3)
            local doc_owner=$(echo "$doc_info" | cut -f4)
            
            # Determine Python version
            local python_version="Unknown"
            
            if echo "$doc_content" | grep -q "python3"; then
                python_version="Python 3.x"
            elif echo "$doc_content" | grep -q "python2"; then
                python_version="Python 2.x"
            elif echo "$doc_content" | grep -q -i "python"; then
                python_version="Python (detected)"
            fi
            
            # Check for aws:executeScript with runtime
            if echo "$doc_content" | grep -q "aws:executeScript"; then
                local runtime_info=$(echo "$doc_content" | grep -A 5 -B 5 "runtime" | grep -o '"runtime"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"runtime"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
                
                if [ -n "$runtime_info" ]; then
                    python_version="$runtime_info"
                else
                    python_version="aws:executeScript"
                fi
            fi
            
            printf "%-40s %-20s %-30s\n" "$doc_name" "$python_version" "$doc_type"
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
echo "=============================================="
printf "%-40s %-20s %-30s\n" "Document Name" "Runtime/Type" "Document Type"
echo "=============================================="

PYTHON_DOCS_FOUND=0
EXECUTE_SCRIPT_DOCS=0

# Process each document
for doc_name in $DOCUMENTS; do
    # Skip empty names
    if [ -z "$doc_name" ]; then
        continue
    fi
    
    # Get document content
    DOC_CONTENT=$(aws ssm get-document \
        --name "$doc_name" \
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

echo "=============================================="
echo -e "${GREEN}Total documents with Python/Script content: ${PYTHON_DOCS_FOUND}${NC}"
echo -e "${GREEN}Total aws:executeScript documents: ${EXECUTE_SCRIPT_DOCS}${NC}"
echo ""

# Show some common AWS managed documents for reference
echo -e "${BLUE}Common AWS Managed Documents Check:${NC}"
echo "================================================"
printf "%-35s %-25s %-15s\n" "Document Name" "Status" "Available"
echo "================================================"

COMMON_DOCS="AWS-RunPythonScript AWS-RunShellScript AWS-ConfigureAWSPackage AWS-RunPatchBaseline AWS-UpdateSSMAgent AWS-RunPowerShellScript"

for common_doc in $COMMON_DOCS; do
    if aws ssm describe-document --name "$common_doc" >/dev/null 2>&1; then
        DOC_STATUS=$(aws ssm describe-document \
            --name "$common_doc" \
            --query 'Status' \
            --output text 2>/dev/null)
        printf "%-35s %-25s %-15s\n" "$common_doc" "$DOC_STATUS" "Yes"
    else
        printf "%-35s %-25s %-15s\n" "$common_doc" "Not Found" "No"
    fi
done

echo "================================================"
echo ""

# Final Summary
echo -e "${BLUE}=== Final Summary ===${NC}"
echo -e "${GREEN}Account ID: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}Documents analyzed: $(echo $DOCUMENTS | wc -w)${NC}"
echo -e "${GREEN}Documents with Python/Script content: ${PYTHON_DOCS_FOUND}${NC}"
echo -e "${GREEN}aws:executeScript documents: ${EXECUTE_SCRIPT_DOCS}${NC}"
echo ""

if [ $PYTHON_DOCS_FOUND -eq 0 ]; then
    echo -e "${YELLOW}Troubleshooting suggestions:${NC}"
    echo -e "${YELLOW}  1. Check if you have SSM permissions (ssm:ListDocuments, ssm:GetDocument)${NC}"
    echo -e "${YELLOW}  2. Try running: aws ssm list-documents --max-items 5${NC}"
    echo -e "${YELLOW}  3. Check your AWS region: aws configure get region${NC}"
    echo -e "${YELLOW}  4. Verify AWS credentials: aws sts get-caller-identity${NC}"
fi

echo -e "${BLUE}Script completed!${NC}"