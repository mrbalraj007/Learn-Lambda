# AWS Load Balancer Export Tool

This tool exports detailed information about all AWS Load Balancers in your environment to CSV files, with separate files for each load balancer type.

## Features

- Exports information for all load balancer types:
  - Classic Load Balancers (CLB)
  - Application Load Balancers (ALB)
  - Network Load Balancers (NLB)
  - Gateway Load Balancers (GLB)
- Captures associated resources:
  - Target Groups
  - Listeners
  - Health Checks
  - Security Groups
  - Subnets and Availability Zones
  - SSL Certificates
  - Tags

## Requirements

- AWS CLI installed and configured with appropriate permissions
- jq (command-line JSON processor)
- (Optional) Python with pandas and openpyxl for Excel conversion

## Usage

1. Make the script executable:
   ```
   chmod +x export-aws-loadbalancers.sh
   ```

2. Run the script:
   ```
   ./export-aws-loadbalancers.sh
   ```

3. (Optional) To combine the CSV files into a single Excel file with multiple sheets:
   ```
   pip install pandas openpyxl
   python3 aws_lb_export_YYYYMMDD_HHMMSS/convert_to_excel.py
   ```

## Output

The script creates a directory with the current timestamp containing:

- `classic_load_balancers.csv`: Information about CLBs
- `application_load_balancers.csv`: Information about ALBs
- `network_load_balancers.csv`: Information about NLBs
- `gateway_load_balancers.csv`: Information about GLBs
- `convert_to_excel.py`: Helper script to convert CSVs to an Excel file

## Notes

- The default AWS region is set to `us-east-1`. Modify the script to change the region.
- The script includes error handling for AWS API calls.
- Large environments may take some time to process all resources.


To use these new features, you can run:

'./export-aws-loadbalancer.sh -a -s' to scan all regions and automatically export load balancers from any regions where they're found
