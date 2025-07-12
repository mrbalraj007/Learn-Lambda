#!/bin/bash
# filepath: c:\Users\BalraSin\OneDrive - Jetstar Airways Pty Ltd\Balraj_D_Laptop_Drive\DevOps_Master\Learn-Lambda\Bash_Script_list\27.Bash_Script_AWS_SSM_ExecuteScript\check_ssm_python_versions.sh

# AWS SSM Document Python Version Audit Script
# This script identifies Systems Manager documents using deprecated Python versions
# in aws:executeScript actions (Python 3.6, 3.7, 3.8, 3.9)
# Compatible with Windows OS (Git Bash, WSL, MSYS2)

set -euo pipefail

# Colors for output (Windows compatible)
if [[ "${OS:-}" == "Windows_NT" ]] || [[ "${OSTYPE:-}" == "msys" ]] || [[ "${MSYSTEM:-}" != "" ]]; then
    # Windows environment - use simpler colors
    RED='\033[31m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    BLUE='\033[34m'
    CYAN='\033[36m'
    NC='\033[0m'
else
    # Unix-like environment
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# Function to print colored output (Windows compatible)
print_color() {
    local color=$1
    local message=$2
    if [[ "${TERM:-}" == "dumb" ]] || [[ "${NO_COLOR:-}" == "1" ]]; then
        echo "$message"
    else
        echo -e "${color}${message}${NC}"
    fi
}

# Function to get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    # Check for AWS CLI in common Windows locations
    if ! command -v aws &> /dev/null; then
        if [[ "${OS:-}" == "Windows_NT" ]]; then
            # Try common Windows AWS CLI locations
            if [[ -f "/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]]; then
                export PATH="/c/Program Files/Amazon/AWSCLIV2:$PATH"
            elif [[ -f "/c/Program Files (x86)/Amazon/AWSCLIV2/aws.exe" ]]; then
                export PATH="/c/Program Files (x86)/Amazon/AWSCLIV2:$PATH"
            elif [[ -f "/c/Users/$USER/AppData/Local/Programs/Amazon/AWSCLIV2/aws.exe" ]]; then
                export PATH="/c/Users/$USER/AppData/Local/Programs/Amazon/AWSCLIV2:$PATH"
            else
                print_color $RED "ERROR: AWS CLI is not installed or not in PATH"
                print_color $YELLOW "Please install AWS CLI from: https://aws.amazon.com/cli/"
                exit 1
            fi
        else
            print_color $RED "ERROR: AWS CLI is not installed or not in PATH"
            exit 1
        fi
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_color $RED "ERROR: AWS CLI is not configured or credentials are invalid"
        print_color $YELLOW "Run 'aws configure' to set up your credentials"
        exit 1
    fi
}

# Function to check if jq is available (Windows compatible)
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_color $RED "ERROR: jq is not installed."
        print_color $YELLOW "For Windows, you can install jq using one of these methods:"
        print_color $YELLOW "1. Download from: https://stedolan.github.io/jq/download/"
        print_color $YELLOW "2. Using Chocolatey: choco install jq"
        print_color $YELLOW "3. Using Scoop: scoop install jq"
        print_color $YELLOW "4. Using winget: winget install stedolan.jq"
        exit 1
    fi
}

# Function to extract Python version from document content
extract_python_version() {
    local content=$1
    # Look for Runtime patterns in the document content - enhanced to catch more patterns
    echo "$content" | grep -oE '"Runtime"\s*:\s*"python[0-9]+\.[0-9]+"' | \
    grep -oE 'python[0-9]+\.[0-9]+' | \
    sed 's/python//' | \
    sort -u
}

# Function to extract all runtime values from document content
extract_all_runtimes() {
    local content=$1
    # Extract all runtime values including PowerShell, Shell, etc.
    echo "$content" | grep -oE '"Runtime"\s*:\s*"[^"]*"' | \
    grep -oE '"[^"]*"$' | \
    sed 's/"//g' | \
    sort -u
}

# Function to check if version is deprecated
is_deprecated_version() {
    local version=$1
    case $version in
        3.6|3.7|3.8|3.9)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to process documents
process_documents() {
    local account_id=$1
    local region=$2
    local found_deprecated=false
    local doc_count=0
    
    print_color $BLUE "Checking region: $region"
    print_color $BLUE "=== Document Inventory ==="
    
    # Get all SSM documents owned by the account (all types, not just Automation)
    local documents
    documents=$(aws ssm list-documents \
        --region "$region" \
        --filters "Key=Owner,Values=Self" \
        --query 'DocumentIdentifiers[].{Name:Name,Type:DocumentType,Status:Status}' \
        --output json 2>/dev/null) || {
        print_color $RED "ERROR: Failed to list documents in region $region"
        return 1
    }
    
    if [ "$documents" = "[]" ] || [ -z "$documents" ]; then
        print_color $YELLOW "No documents found in region $region"
        return 0
    fi
    
    # Parse JSON and process each document - improved for Windows/MSYS2
    local doc_names
    doc_names=$(echo "$documents" | jq -r '.[].Name // empty' 2>/dev/null) || {
        print_color $RED "ERROR: Failed to parse document list"
        return 1
    }
    
    if [ -z "$doc_names" ]; then
        print_color $YELLOW "No documents found in region $region"
        return 0
    fi
    
    # Process each document
    while IFS= read -r doc_name; do
        [[ -z "$doc_name" ]] && continue
        ((doc_count++))
        
        # Get document details - improved error handling
        local doc_type doc_status
        doc_type=$(echo "$documents" | jq -r ".[] | select(.Name == \"$doc_name\") | .Type // \"Unknown\"" 2>/dev/null)
        doc_status=$(echo "$documents" | jq -r ".[] | select(.Name == \"$doc_name\") | .Status // \"Unknown\"" 2>/dev/null)
        
        print_color $CYAN "[$doc_count] Document: $doc_name"
        echo "    Type: $doc_type"
        echo "    Status: $doc_status"
        
        # Get document content with better error handling
        local doc_content
        doc_content=$(aws ssm get-document \
            --region "$region" \
            --name "$doc_name" \
            --query 'Content' \
            --output text 2>&1) 
        
        local aws_exit_code=$?
        
        if [ $aws_exit_code -ne 0 ]; then
            if echo "$doc_content" | grep -q "AccessDenied"; then
                print_color $YELLOW "    ⚠️  Access denied - insufficient permissions"
            elif echo "$doc_content" | grep -q "InvalidDocument"; then
                print_color $YELLOW "    ⚠️  Invalid document or document not found"
            elif echo "$doc_content" | grep -q "InvalidParameter"; then
                print_color $YELLOW "    ⚠️  Invalid parameter in request"
            else
                print_color $YELLOW "    ⚠️  Unable to retrieve document content (AWS CLI error)"
            fi
            echo ""
            continue
        fi
        
        if [ -z "$doc_content" ] || [ "$doc_content" = "None" ]; then
            print_color $YELLOW "    ⚠️  Document content is empty"
            echo ""
            continue
        fi
        
        # Check if document contains aws:executeScript
        if echo "$doc_content" | grep -q "aws:executeScript"; then
            echo "    Contains: aws:executeScript action"
            
            # Extract all runtime values
            local all_runtimes=$(extract_all_runtimes "$doc_content")
            local python_versions=$(extract_python_version "$doc_content")
            
            if [ -n "$all_runtimes" ]; then
                echo "    Runtime(s): $all_runtimes"
                
                # Check Python versions specifically
                if [ -n "$python_versions" ]; then
                    for version in $python_versions; do
                        if is_deprecated_version "$version"; then
                            print_color $RED "    ⚠️  DEPRECATED PYTHON VERSION: $version"
                            echo "    Action Required: Upgrade to Python 3.11 before Sep 10, 2025"
                            found_deprecated=true
                        else
                            print_color $GREEN "    ✅ Python Version: $version (OK)"
                        fi
                    done
                fi
            else
                print_color $YELLOW "    ⚠️  Contains aws:executeScript but no runtime specified"
            fi
        else
            # Check for any runtime values even without aws:executeScript
            local all_runtimes=$(extract_all_runtimes "$doc_content")
            if [ -n "$all_runtimes" ]; then
                echo "    Runtime(s): $all_runtimes"
                
                # Check if any Python versions are present
                local python_versions=$(extract_python_version "$doc_content")
                if [ -n "$python_versions" ]; then
                    for version in $python_versions; do
                        if is_deprecated_version "$version"; then
                            print_color $RED "    ⚠️  DEPRECATED PYTHON VERSION: $version"
                            found_deprecated=true
                        else
                            print_color $GREEN "    ✅ Python Version: $version (OK)"
                        fi
                    done
                fi
            else
                echo "    Runtime(s): No runtime specified"
            fi
        fi
        
        # Add document format detection
        if echo "$doc_content" | grep -q "schemaVersion"; then
            echo "    Format: JSON/YAML SSM Document"
        elif echo "$doc_content" | grep -q "steps:"; then
            echo "    Format: YAML Document"
        elif echo "$doc_content" | grep -q "mainSteps"; then
            echo "    Format: JSON Document"
        else
            echo "    Format: Unknown/Other"
        fi
        
        echo ""
    done <<< "$doc_names"
    
    print_color $BLUE "Total documents checked: $doc_count"
    
    return $([ "$found_deprecated" = true ] && echo 1