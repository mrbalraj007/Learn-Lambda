# Transit Gateway Information Export Script

I'll create a bash script that exports all information related to AWS Transit Gateways, including attachment details organized by Attachment ID.

## Solution Steps:
1. Set up AWS region to us-east-1
2. Query all Transit Gateways in the account
3. For each Transit Gateway, get all attachments
4. Collect the Attachment ID, Resource Type, Resource ID, and State
5. Export all information to a CSV file

## Usage Instructions:

1. Save the script to a file named `export_tgw_info.sh`
2. Make it executable: `chmod +x export_tgw_info.sh`
3. Run the script: `./export_tgw_info.sh`

The script will:
- Generate a CSV file with a timestamp in the filename
- Process each Transit Gateway and its attachments one by one
- Include TGW ID, TGW Name, Attachment ID, Resource Type, Resource ID, and State
- Group information by Attachment ID as requested

The output CSV file will contain all the requested information and can be opened in any spreadsheet application.