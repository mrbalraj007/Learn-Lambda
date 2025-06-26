#!/bin/bash

# Script to export AWS Certificate Manager (ACM) certificate details
# Exports: Certificate ID, Domain Name, Type, Status, In Use, Expires in, Associated with, Expiry date

set -e  # Exit on error

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Output file
OUTPUT_FILE="acm_certificates_$(date +%Y%m%d_%H%M%S).csv"

# Write CSV header
echo "Certificate ID,Domain Name,Type,Status,In Use,Expires In (Days),Associated With,Expiry Date" > "$OUTPUT_FILE"

# Get current date in seconds since epoch
CURRENT_DATE=$(date +%s)

# Function to convert ISO8601 date to seconds since epoch
date_to_seconds() {
    local iso_date="$1"
    
    if [[ "$iso_date" == "null" ]]; then
        echo "null"
        return
    fi
    
    # Check if we have GNU date or BSD date (macOS)
    if date --version >/dev/null 2>&1; then
        # GNU date
        date -d "$iso_date" +%s 2>/dev/null || echo "null"
    else
        # BSD date (macOS)
        local converted_date=$(echo "$iso_date" | sed 's/T/ /' | sed 's/\.[0-9]*Z$//')
        date -j -f "%Y-%m-%d %H:%M:%S" "$converted_date" +%s 2>/dev/null || echo "null"
    fi
}

# Function to format ISO8601 date to YYYY-MM-DD
format_date() {
    local iso_date="$1"
    
    if [[ "$iso_date" == "null" ]]; then
        echo "N/A"
        return
    fi
    
    # Check if we have GNU date or BSD date (macOS)
    if date --version >/dev/null 2>&1; then
        # GNU date
        date -d "$iso_date" +"%Y-%m-%d" 2>/dev/null || echo "Invalid Date"
    else
        # BSD date (macOS)
        local converted_date=$(echo "$iso_date" | sed 's/T/ /' | sed 's/\.[0-9]*Z$//')
        date -j -f "%Y-%m-%d %H:%M:%S" "$converted_date" +"%Y-%m-%d" 2>/dev/null || echo "Invalid Date"
    fi
}

# Function to escape CSV fields
escape_csv() {
    local field="$1"
    # Replace double quotes with two double quotes and enclose in double quotes
    echo "\"${field//\"/\"\"}\""
}

# Get all certificates
echo "Fetching certificates from ACM..."
CERTIFICATES=$(aws acm list-certificates --include-deleted --query 'CertificateSummaryList[*].CertificateArn' --output text)

# Check if we got any certificates
if [ -z "$CERTIFICATES" ]; then
    echo "No certificates found in ACM."
    exit 0
fi

TOTAL_CERTS=0
PROCESSED_CERTS=0

# Count total certificates
for cert in $CERTIFICATES; do
    TOTAL_CERTS=$((TOTAL_CERTS + 1))
done

echo "Found $TOTAL_CERTS certificates. Processing..."

# Process each certificate
for CERT_ARN in $CERTIFICATES; do
    PROCESSED_CERTS=$((PROCESSED_CERTS + 1))
    echo "Processing certificate $PROCESSED_CERTS of $TOTAL_CERTS: ${CERT_ARN##*/}"
    
    # Get certificate details
    CERT_DETAILS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN")
    
    # Extract certificate ID (last part of the ARN)
    CERT_ID=$(echo "$CERT_ARN" | awk -F/ '{print $NF}')
    
    # Extract domain name
    DOMAIN_NAME=$(echo "$CERT_DETAILS" | jq -r '.Certificate.DomainName')
    
    # Extract certificate type
    TYPE=$(echo "$CERT_DETAILS" | jq -r '.Certificate.Type')
    
    # Extract status
    STATUS=$(echo "$CERT_DETAILS" | jq -r '.Certificate.Status')
    
    # Check if certificate is in use (has any resources using it)
    IN_USE_COUNT=$(echo "$CERT_DETAILS" | jq -r '.Certificate.InUseBy | length')
    if [ "$IN_USE_COUNT" -gt 0 ]; then
        IN_USE="Yes"
    else
        IN_USE="No"
    fi
    
    # Extract expiry date and calculate days until expiry
    EXPIRY_DATE=$(echo "$CERT_DETAILS" | jq -r '.Certificate.NotAfter')
    
    if [ "$EXPIRY_DATE" != "null" ]; then
        # Convert to seconds since epoch
        EXPIRY_SECONDS=$(date_to_seconds "$EXPIRY_DATE")
        
        if [ "$EXPIRY_SECONDS" != "null" ]; then
            # Calculate days until expiry
            DAYS_TO_EXPIRY=$(( (EXPIRY_SECONDS - CURRENT_DATE) / 86400 ))
            
            # Format expiry date to be more readable
            FORMATTED_EXPIRY=$(format_date "$EXPIRY_DATE")
        else
            DAYS_TO_EXPIRY="N/A"
            FORMATTED_EXPIRY="Invalid Date"
        fi
    else
        DAYS_TO_EXPIRY="N/A"
        FORMATTED_EXPIRY="N/A"
    fi
    
    # Get associated resources
    ASSOCIATED_WITH=$(echo "$CERT_DETAILS" | jq -r '.Certificate.InUseBy | join(", ")')
    if [ -z "$ASSOCIATED_WITH" ] || [ "$ASSOCIATED_WITH" == "null" ]; then
        ASSOCIATED_WITH="None"
    fi
    
    # Write to CSV with proper escaping
    echo "$(escape_csv "$CERT_ID"),$(escape_csv "$DOMAIN_NAME"),$(escape_csv "$TYPE"),$(escape_csv "$STATUS"),$(escape_csv "$IN_USE"),$(escape_csv "$DAYS_TO_EXPIRY"),$(escape_csv "$ASSOCIATED_WITH"),$(escape_csv "$FORMATTED_EXPIRY")" >> "$OUTPUT_FILE"
done

echo "Certificate details exported to $OUTPUT_FILE"
echo "Total certificates processed: $PROCESSED_CERTS"
