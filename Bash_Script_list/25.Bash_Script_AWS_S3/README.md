# Route 53 DNS Records Export Script

## Overview
This bash script exports all Route 53 hosted zones and their DNS records to a CSV file with timestamp.

## Prerequisites
- AWS CLI installed and configured
- jq (JSON processor) installed
- Appropriate AWS IAM permissions for Route 53

## Required IAM Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage
```bash
# Make script executable
chmod +x export_route53_records.sh

# Run with default region (ap-southeast-2)
./export_route53_records.sh

# Run with specific region
./export_route53_records.sh --region us-east-1
```

## Output Format
The script generates a CSV file with the following columns:
- Export_Date
- Hosted_Zone_ID
- Hosted_Zone_Name
- Record_Name
- Record_Type
- Routing_Policy
- Alias
- Value_Route_Traffic_To
- TTL
- Evaluate_Target_Health

## Features
- Colored console output
- Error handling and validation
- Automatic cleanup of temporary files
- Progress tracking
- Summary statistics
- Support for all Route 53 record types and routing policies
