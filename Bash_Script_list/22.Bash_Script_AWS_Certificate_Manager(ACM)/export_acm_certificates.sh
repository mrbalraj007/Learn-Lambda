#!/bin/bash

# Script to export AWS Certificate Manager (ACM) certificate details
# Exports: Certificate ID, Domain Name, Type, Status, In Use, Expires in, Associated with, Expiry date

set -e  # Exit on error

# Define colors for terminal output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configure expiry thresholds (in days)
CRITICAL_THRESHOLD=30
WARNING_THRESHOLD=60

# Email notification settings
SEND_EMAIL_NOTIFICATIONS=true
#EMAIL_RECIPIENT="your-email@example.com"
EMAIL_RECIPIENT="raj10ace@gmail.com"
EMAIL_SUBJECT="AWS Certificate Expiration Alert"
EMAIL_FROM="acm-alerts@your-domain.com"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if jq is installed (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install it first.${NC}"
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

# Function to get color-coded expiry text
get_colored_expiry_text() {
    local days=$1
    
    if [[ "$days" == "N/A" ]]; then
        echo "${NC}$days${NC}"
        return
    fi
    
    if (( days < 0 )); then
        echo "${RED}Expired ($days days ago)${NC}"
    elif (( days <= CRITICAL_THRESHOLD )); then
        echo "${RED}$days days${NC}"
    elif (( days <= WARNING_THRESHOLD )); then
        echo "${YELLOW}$days days${NC}"
    else
        echo "${GREEN}$days days${NC}"
    fi
}

# Function to send email notification
send_email_notification() {
    local expiring_certs=$1
    
    if [ -z "$expiring_certs" ]; then
        return
    fi
    
    # Check if mail command is available
    if ! command -v mail &> /dev/null; then
        echo -e "${YELLOW}Warning: 'mail' command not found. Email notifications cannot be sent.${NC}"
        return
    fi
    
    # Create temporary HTML file for email body
    local email_body_file=$(mktemp)
    
    # Write HTML email body
    cat > "$email_body_file" << EOF
<html>
<head>
    <style>
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .critical { color: red; font-weight: bold; }
        .warning { color: orange; }
        .good { color: green; }
    </style>
</head>
<body>
    <h2>AWS Certificate Manager - Expiring Certificates Alert</h2>
    <p>The following certificates will expire soon:</p>
    <table>
        <tr>
            <th>Domain</th>
            <th>Certificate ID</th>
            <th>Expires In</th>
            <th>Expiry Date</th>
            <th>Status</th>
            <th>In Use</th>
            <th>Associated With</th>
        </tr>
$expiring_certs
    </table>
    <p>This is an automated message from your AWS Certificate Manager monitoring script.</p>
</body>
</html>
EOF

    # Send email
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # MacOS
        mail -a "Content-Type: text/html" -s "$EMAIL_SUBJECT" "$EMAIL_RECIPIENT" < "$email_body_file"
    else
        # Linux and others
        mail -a "From: $EMAIL_FROM" -a "Content-Type: text/html" -s "$EMAIL_SUBJECT" "$EMAIL_RECIPIENT" < "$email_body_file"
    fi
    
    # Remove temporary file
    rm "$email_body_file"
    
    echo -e "${GREEN}Email notification sent to $EMAIL_RECIPIENT${NC}"
}

# Get all certificates
echo "Fetching certificates from ACM..."
CERTIFICATES=$(aws acm list-certificates --certificate-statuses ISSUED PENDING_VALIDATION EXPIRED FAILED INACTIVE VALIDATION_TIMED_OUT REVOKED --query 'CertificateSummaryList[*].CertificateArn' --output text)

# Check if we got any certificates
if [ -z "$CERTIFICATES" ]; then
    echo "No certificates found in ACM."
    exit 0
fi

TOTAL_CERTS=0
PROCESSED_CERTS=0
EXPIRING_CERTS_COUNT=0
EXPIRING_CERTS_HTML=""

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
            
            # Check if certificate is expiring soon and add to HTML for email notification
            if [ "$DAYS_TO_EXPIRY" -le "$WARNING_THRESHOLD" ]; then
                EXPIRING_CERTS_COUNT=$((EXPIRING_CERTS_COUNT + 1))
                
                # Determine CSS class for styling in HTML email
                if [ "$DAYS_TO_EXPIRY" -le "$CRITICAL_THRESHOLD" ]; then
                    CSS_CLASS="critical"
                else
                    CSS_CLASS="warning"
                fi
                
                # Get associated resources for email
                ASSOCIATED_WITH_EMAIL=$(echo "$CERT_DETAILS" | jq -r '.Certificate.InUseBy | join(", ")')
                if [ -z "$ASSOCIATED_WITH_EMAIL" ] || [ "$ASSOCIATED_WITH_EMAIL" == "null" ]; then
                    ASSOCIATED_WITH_EMAIL="None"
                fi
                
                # Add row to HTML table
                EXPIRING_CERTS_HTML+="        <tr>\n"
                EXPIRING_CERTS_HTML+="            <td>$DOMAIN_NAME</td>\n"
                EXPIRING_CERTS_HTML+="            <td>$CERT_ID</td>\n"
                EXPIRING_CERTS_HTML+="            <td class=\"$CSS_CLASS\">$DAYS_TO_EXPIRY days</td>\n"
                EXPIRING_CERTS_HTML+="            <td>$FORMATTED_EXPIRY</td>\n"
                EXPIRING_CERTS_HTML+="            <td>$STATUS</td>\n"
                EXPIRING_CERTS_HTML+="            <td>$IN_USE</td>\n"
                EXPIRING_CERTS_HTML+="            <td>$ASSOCIATED_WITH_EMAIL</td>\n"
                EXPIRING_CERTS_HTML+="        </tr>\n"
            fi
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
    
    # Print colored output to terminal
    COLORED_EXPIRY=$(get_colored_expiry_text "$DAYS_TO_EXPIRY")
    echo -e "Domain: $DOMAIN_NAME, Expires in: $COLORED_EXPIRY, Status: $STATUS"
    
    # Write to CSV with proper escaping
    echo "$(escape_csv "$CERT_ID"),$(escape_csv "$DOMAIN_NAME"),$(escape_csv "$TYPE"),$(escape_csv "$STATUS"),$(escape_csv "$IN_USE"),$(escape_csv "$DAYS_TO_EXPIRY"),$(escape_csv "$ASSOCIATED_WITH"),$(escape_csv "$FORMATTED_EXPIRY")" >> "$OUTPUT_FILE"
done

echo "Certificate details exported to $OUTPUT_FILE"
echo "Total certificates processed: $PROCESSED_CERTS"

# Send email notification if there are expiring certificates
if [ "$EXPIRING_CERTS_COUNT" -gt 0 ] && [ "$SEND_EMAIL_NOTIFICATIONS" = true ]; then
    echo "Found $EXPIRING_CERTS_COUNT certificates expiring within $WARNING_THRESHOLD days."
    send_email_notification "$EXPIRING_CERTS_HTML"
else
    echo -e "${GREEN}No certificates found that will expire within $WARNING_THRESHOLD days.${NC}"
fi
