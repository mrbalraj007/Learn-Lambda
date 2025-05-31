AWS VPC Resource Details Script
I'll create a bash script that uses the AWS CLI to retrieve information about your VPCs and their associated resources like subnets, internet gateways, NACLs, and route tables. The script will output everything to CSV files for easy analysis.

Step-by-Step Solution:
Check if AWS CLI is installed
Create functions to extract data for each resource type
Create separate CSV files for each resource type
For each VPC, gather all associated resources
Format data in CSV format

How to Use
Make both scripts executable:
```sh
chmod +x vpc-details.sh combined-vpc-report.sh
```

Run the first script to gather all VPC data:
```sh
./vpc-details.sh
```
Optionally run the second script to create a combined report:
```sh
./combined-vpc-report.sh
```
The first script will create a directory called vpc-reports with detailed CSV files for each VPC resource type. The second script will create a single consolidated report.

Make sure you have the AWS CLI installed and configured with proper permissions to describe VPC resources.