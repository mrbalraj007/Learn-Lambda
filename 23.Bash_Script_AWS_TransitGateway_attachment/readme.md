# Transit Gateway Attachment Details Export Script

Here's a bash script that will export Transit Gateway attachment details to a CSV file, processing each attachment one by one:


## How to Use:

1. Save this script as `export_tgw_attachments.sh`
2. Make it executable: `chmod +x export_tgw_attachments.sh`
3. Run it: `./export_tgw_attachments.sh`

The script will:
- Use 'us-east-1' as the default region
- Process each Transit Gateway attachment individually
- Export the details to a CSV file with a timestamp in the name
- Show progress as it processes each attachment

## Prerequisites:
- AWS CLI installed and configured with appropriate permissions
- jq installed for JSON parsing

The CSV file will contain columns for Attachment ID, Resource Type, Resource ID, and State.