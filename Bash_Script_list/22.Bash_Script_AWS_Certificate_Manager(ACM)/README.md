# AWS Certificate Manager Export Script

A bash script to export detailed certificate information from AWS Certificate Manager (ACM) with color-coded output and email notification capabilities.

## Features

- Exports comprehensive certificate details:
  - Certificate ID
  - Domain Name
  - Certificate Type
  - Status
  - Whether the certificate is in use
  - Days until expiry
  - Associated resources
  - Expiry date
- Color-coded terminal output for expiration warnings:
  - 🔴 Red: Certificates expiring within 30 days (critical)
  - 🟡 Yellow: Certificates expiring within 60 days (warning)
  - 🟢 Green: Certificates with more than 60 days until expiry
- Email notifications for certificates approaching expiration
- CSV export of all certificate details
- Cross-platform support (Linux and macOS)

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- `jq` for JSON parsing
- `mail` command (for email notifications)

## Configuration

You can modify the following variables at the beginning of the script:

```bash
# Configure expiry thresholds (in days)
CRITICAL_THRESHOLD=30
WARNING_THRESHOLD=60

# Email notification settings
SEND_EMAIL_NOTIFICATIONS=true
EMAIL_RECIPIENT="your-email@example.com"
EMAIL_SUBJECT="AWS Certificate Expiration Alert"
EMAIL_FROM="acm-alerts@your-domain.com"
```

## Usage

1. Make the script executable:
   ```
   chmod +x export_acm_certificates.sh
   ```

2. Run the script:
   ```
   ./export_acm_certificates.sh
   ```

3. Check the generated CSV file (named with timestamp) for complete details

## Output Example

The script will produce:

1. Terminal output with color-coded expiration warnings:
   ```
   Found 5 certificates. Processing...
   Processing certificate 1 of 5: 12345678-1234-1234-1234-123456789012
   Domain: example.com, Expires in: 120 days, Status: ISSUED
   Processing certificate 2 of 5: 87654321-1234-1234-1234-123456789012
   Domain: api.example.com, Expires in: 25 days, Status: ISSUED
   ...
   ```

2. A CSV file with all certificate details:
   ```
   Certificate ID,Domain Name,Type,Status,In Use,Expires In (Days),Associated With,Expiry Date
   "12345678-1234-1234-1234-123456789012","example.com","AMAZON_ISSUED","ISSUED","Yes","120","arn:aws:elasticloadbalancing...,arn:aws:cloudfront...","2023-12-15"
   ...
   ```

3. Email notification (if certificates are expiring soon) with HTML formatted table

## Troubleshooting

- If email notifications aren't working, check that the `mail` command is installed and configured correctly
- For AWS CLI errors, verify your AWS credentials and permissions
- For date parsing issues on macOS, the script attempts to handle BSD date format differences

## License

This script is provided as-is with no warranties. Feel free to modify and distribute as needed.
