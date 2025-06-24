# AWS VPC Resource Details Script

This script extracts information about VPCs and their associated resources in your AWS account and exports the data to CSV files for easy analysis.

## Features

- Extracts details of all VPCs in a specified region or your default AWS region
- Gathers information about associated resources:
  - Subnets
  - Internet Gateways
  - NAT Gateways
  - Network ACLs (including inbound and outbound rules)
  - Route Tables (including routes and associations)
- Exports all data to CSV files
- Includes debug mode for troubleshooting
- Validates AWS connectivity before execution

## Prerequisites

Before using this script, ensure you have:

1. **AWS CLI** installed and configured
   ```
   # Check if AWS CLI is installed
   aws --version
   
   # Configure AWS CLI with your credentials
   aws configure
   ```

2. **jq** installed for JSON processing
   ```
   # Install jq on Ubuntu/Debian
   sudo apt-get install jq
   
   # Install jq on CentOS/RHEL
   sudo yum install jq
   
   # Install jq on macOS
   brew install jq
   ```

3. **Appropriate IAM permissions** to describe the following resources:
   - VPCs
   - Subnets
   - Internet Gateways
   - NAT Gateways
   - Network ACLs
   - Route Tables

## Usage

### Basic Usage

Run the script with default settings (uses your default AWS CLI region):

```bash
./vpc-details.sh
```

### Specify AWS Region

To extract VPC details from a specific region:

```bash
./vpc-details.sh -r us-east-1
```

### Enable Debug Mode

For troubleshooting or to see more detailed information during execution:

```bash
./vpc-details.sh -d
```

### Combined Options

You can combine options as needed:

```bash
./vpc-details.sh -r us-west-2 -d
```

## Output Files

The script creates a directory called `vpc-reports` and generates the following CSV files:

1. `vpc-details.csv` - Basic information about each VPC
2. `vpc-subnets.csv` - Details of all subnets in each VPC
3. `vpc-internet-gateways.csv` - Information about Internet Gateways
4. `vpc-nat-gateways.csv` - Information about NAT Gateways
5. `vpc-network-acls.csv` - Network ACL details
6. `vpc-nacl-rules.csv` - Inbound and outbound rules for each Network ACL
7. `vpc-route-tables.csv` - Information about route tables
8. `vpc-routes.csv` - Routes in each route table
9. `vpc-rt-associations.csv` - Route table associations with subnets

## Example Output

Here's what the CSV data looks like:

### vpc-details.csv
```
VPC_ID,CIDR_Block,Name,State,Is_Default
vpc-0123456789abcdef0,10.0.0.0/16,"Production VPC",available,false
vpc-0123456789abcdef1,172.31.0.0/16,"Default VPC",available,true
```

### vpc-subnets.csv
```
VPC_ID,Subnet_ID,CIDR_Block,Availability_Zone,State,Name
vpc-0123456789abcdef0,subnet-0123456789abcdef0,10.0.1.0/24,us-east-1a,available,"Production Public Subnet 1"
vpc-0123456789abcdef0,subnet-0123456789abcdef1,10.0.2.0/24,us-east-1b,available,"Production Public Subnet 2"
```

## Troubleshooting

### No Data in CSV Files

If the script runs without errors but CSV files are empty or contain only headers:

1. **Verify Region**: Make sure you have VPC resources in the specified region
   ```bash
   ./vpc-details.sh -r us-east-1
   ```

2. **Check Permissions**: Ensure your IAM user/role has the necessary permissions
   ```bash
   aws iam get-user
   ```

3. **Run in Debug Mode**: Get more detailed information
   ```bash
   ./vpc-details.sh -d
   ```

4. **Verify AWS CLI Configuration**: Make sure your AWS configuration is correct
   ```bash
   aws configure list
   ```

### Error Messages

If you see errors about missing commands or permissions:

1. **AWS CLI not installed**: Install the AWS CLI
   ```bash
   pip install awscli
   ```

2. **jq not installed**: Install jq
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **Permission Denied**: Make the script executable
   ```bash
   chmod +x vpc-details.sh
   ```

## Additional Information

- The script automatically creates the output directory if it doesn't exist
- For VPCs, subnets, and other resources with tags, the script extracts the "Name" tag
- The debug mode (-d) provides detailed information about each step of the process
- The script validates AWS connectivity before attempting to gather resource information