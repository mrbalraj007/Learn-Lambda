AWS Transit Gateway Route Export Script
I'll create a professional bash script that exports Transit Gateway route details to a CSV file. This script will gather information such as CIDR, Attachment ID, Resource ID, Resource Type, Route Type, and Route State for each Transit Gateway route.

Solution Overview:
- Set up script with default region 'us-east-1'
- Get all Transit Gateway route tables
- For each route table, fetch all routes
- Extract the required details for each route
- Write the information to a CSV file with proper headers

How to Use the Script
Download the script and make it executable:
```sh
chmod +x export_tgw_routes.sh
```
Run the script:
```sh
./export_tgw_routes.sh
```
Optional parameters:
To specify a different AWS region:
```sh
./export_tgw_routes.sh -r us-west-2
```
To specify a custom output file:
```sh
./export_tgw_routes.sh -o my_routes.csv
```
The script will produce a CSV file with the following columns:

-TransitGatewayRouteTableId
-DestinationCidr
-AttachmentId
-ResourceId
-ResourceType
-RouteType
-State

This CSV file can be opened in any spreadsheet application for further analysis.