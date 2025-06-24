# EC2 Instance Details and Tags Export Script

This script automatically discovers and exports EC2 instance details and all associated tags to a CSV file. It's designed to provide a complete inventory of your EC2 instances across a specified region.

## Features

- **Auto-discovery**: Automatically finds all EC2 instances and their tags
- **Comprehensive data**: Exports both instance details and all associated tags
- **No manual input required**: Detects all tag keys automatically
- **Region flexibility**: Default region is us-east-1, but can be changed with a parameter

## Prerequisites

The script requires the following components:

1. **AWS CLI**: Must be installed and configured with appropriate permissions
2. **jq**: Required for JSON processing
3. **AWS Credentials**: Your environment must have valid AWS credentials configured

## Installation

1. Download the script:
   ```bash
   git clone https://github.com/your-username/aws-ec2-export.git
   cd aws-ec2-export
   ```

2. Make the script executable:
   ```bash
   chmod +x ec2_tags_export.sh
   ```

## Usage

### Basic Usage

Run the script without any parameters to scan the default us-east-1 region:

```bash
./ec2_tags_export.sh
```

### Change Region

To scan a different AWS region:

```bash
./ec2_tags_export.sh --region eu-west-1
```

### Help Information

To display usage information:

```bash
./ec2_tags_export.sh --help
```

## How It Works

The script performs the following steps:

1. **Initialization**:
   - Checks for required dependencies (AWS CLI and jq)
   - Processes command-line arguments
   - Sets up the output file with a timestamp

2. **Data Collection**:
   - Fetches all EC2 instances in the specified region
   - Retrieves CloudWatch alarm information for the instances
   - Gets Elastic IP address associations
   - Discovers all unique tag keys across all instances

3. **CSV Header Creation**:
   - Creates a header row with all instance details
   - Adds all discovered tag keys to the header

4. **Data Processing**:
   - Processes each EC2 instance
   - Extracts instance details (ID, name, IPs, type, etc.)
   - Determines alarm status for the instance
   - Checks if an Elastic IP is associated
   - Extracts all tag values

5. **CSV Generation**:
   - Writes all collected data to a time-stamped CSV file
   - Handles special characters and formatting for CSV compatibility

## Exported Data

The script exports the following information for each EC2 instance:

### Instance Details
- Instance ID
- Instance Name (from the Name tag, if present)
- Public IP address
- Private IP address
- Instance Type
- Availability Zone
- CloudWatch Alarm Status
- Elastic IP address (if associated)
- Security Group Names
- Key Name (SSH key pair)
- Launch Time
- Platform Details

### Tags
- All tags associated with each instance (automatically discovered)

## Output File

The script generates a CSV file named `ec2_details_tags_YYYYMMDD_HHMMSS.csv` in the current directory.

## Troubleshooting

### Common Issues

1. **Permission Errors**:
   - Make sure your AWS credentials have permission to describe EC2 instances, CloudWatch alarms, and Elastic IPs

2. **Missing Dependencies**:
   - Ensure AWS CLI and jq are installed and in your PATH
   - Install AWS CLI: `pip install awscli`
   - Install jq: `apt-get install jq` or `brew install jq`

3. **No Data in Output**:
   - Verify that you have EC2 instances in the specified region
   - Check that your AWS credentials are valid and have proper permissions

## License

This script is provided under the MIT License.
