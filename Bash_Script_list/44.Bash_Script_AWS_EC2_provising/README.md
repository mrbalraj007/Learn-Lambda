# EC2 Instance Provisioning Script

This script automates the creation of an EC2 instance with specific configurations for the TechServ application in the UAT environment.

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- IAM permissions to create EC2 instances and related resources

## Usage

1. Make the script executable:
   ```bash
   chmod +x create_ec2_instance.sh
   ```

2. Run the script:
   ```bash
   ./create_ec2_instance.sh
   ```

## Configuration Details

- **AMI**: Windows Server 2019 (ami-07095edb0ebd97663)
- **Instance Type**: t3.micro
- **Environment**: UAT
- **Application**: TechServ
- **Server Role**: APP
- **Backup**: Daily

## Troubleshooting

If you encounter any issues:
1. Verify your AWS CLI configuration
2. Ensure the subnet, security groups, and VPC exist
3. Check IAM permissions
4. Review AWS service quotas for your account
