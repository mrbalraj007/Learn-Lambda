Solution Steps:
Create a bash script that uses AWS CLI to retrieve DHCP Options Sets
Extract the required information for each DHCP Options Set
Format the data and export it to a CSV file
Add error handling and logging
Use us-east-1 as the default region

The script will:

Check for required dependencies (AWS CLI and jq)
Retrieve all DHCP Options Sets from the us-east-1 region
Process each set to extract the required information
Export the data to a timestamp-named CSV file
Provide progress updates during execution