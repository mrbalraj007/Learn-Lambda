import boto3
import csv
import os
from datetime import datetime

# Initialize session using default credentials/config
session = boto3.Session(region_name='us-east-1')

# Get account info
sts_client = session.client('sts')
account_id = sts_client.get_caller_identity()["Account"]

org_client = session.client('organizations')
try:
    account_info = org_client.describe_account(AccountId=account_id)
    account_name = account_info['Account']['Name']
except Exception as e:
    account_name = f"(Name not accessible: {str(e)})"

# Output directory and filename
output_dir = "Output_Results"
os.makedirs(output_dir, exist_ok=True)
timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
csv_filename = os.path.join(output_dir, f"ec2_inventory_{timestamp}.csv")

# S3 setup
s3_client = session.client('s3')
bucket_name = 'mrsinghbucket080320222'  # Replace with your actual bucket
s3_folder = 'EC2_Inventory'

# Desired tags in required order
preferred_tag_keys = [
    'Name', 'Application', 'Availability', 'Backup', 'CostCentre', 'CreatedBy',
    'Division', 'Environment', 'ManagedBy', 'Owner'
]

# EC2 resource
ec2 = session.resource('ec2')

# CSV header
csv_header = [
    "Name", "Application", "Availability", "Backup", "CostCentre", "CreatedBy",
    "Division", "Environment", "ManagedBy", "Owner",
    "Instance ID", "Instance State", "Instance Type", "Status Checks", "Alarm Status",
    "Availability Zone", "Public IPv4 DNS", "Public IPv4 Address", "Private IP Address",
    "Monitoring", "Security Groups", "Key Name", "Launch Time", "Subnet ID", "Platform"
]

csv_rows = []

# Get EC2 instances
for instance in ec2.instances.all():
    tags = instance.tags or []
    tag_dict = {tag['Key']: tag['Value'] for tag in tags}
    tag_values = [tag_dict.get(k, 'N/A') for k in preferred_tag_keys]

    instance_state = instance.state['Name']
    status_checks = 'N/A'
    alarm_status = 'N/A'

    # Get security groups
    security_groups = ', '.join([sg['GroupName'] for sg in instance.security_groups])

    # Get platform (Linux/Windows)
    platform = instance.platform if instance.platform else 'Linux/UNIX'

    row = tag_values + [
        instance.id,
        instance_state,
        instance.instance_type,
        status_checks,
        alarm_status,
        instance.placement['AvailabilityZone'],
        instance.public_dns_name,
        instance.public_ip_address,
        instance.private_ip_address,
        'enabled' if instance.monitoring['State'] == 'enabled' else 'disabled',
        security_groups,
        instance.key_name,
        instance.launch_time,
        instance.subnet_id,
        platform
    ]

    csv_rows.append(row)

# Write CSV to local file
with open(csv_filename, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(csv_header)
    writer.writerows(csv_rows)

# Upload CSV to S3 under EC2_Inventory folder
try:
    s3_key = f"{s3_folder}/{os.path.basename(csv_filename)}"
    s3_client.upload_file(csv_filename, bucket_name, s3_key)
    print(f"✅ Uploaded: {csv_filename} to s3://{bucket_name}/{s3_key}")
except Exception as e:
    print(f"❌ Error uploading to S3: {str(e)}")
