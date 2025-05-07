import boto3
import csv
import os
from datetime import datetime

# Initialize session using default credentials/config
session = boto3.Session(region_name='us-east-1')

# Account Info
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
csv_filename = os.path.join(output_dir, f"account_result_{timestamp}.csv")

# S3 setup
s3_client = session.client('s3')
bucket_name = 'mrsinghbucket080320222'  # replace with your actual bucket

# Preferred tag keys
preferred_tag_keys = ['Name', 'Application', 'Availability', 'Backup', 'CostCentre', 'CreatedBy',
                      'Division', 'Environment', 'ManagedBy', 'Owner']

# EC2 resource
ec2 = session.resource('ec2')

# CSV header
csv_header = [
    "Account ID", "Account Name", "Name", "Application", "Availability", "Backup", "CostCentre", "CreatedBy",
    "Division", "Environment", "ManagedBy", "Owner", "Instance ID", "Instance State", "Instance Type",
    "Status Checks", "Alarm Status", "Availability Zone", "Public IPv4 DNS", "Public IPv4 Address",
    "Private IP Address", "Monitoring", "Security Groups", "Key Name", "Launch Time", "Subnet ID", "Platform",
    'EBS Volume ID', 'EBS Volume Type', 'EBS Volume Size (GB)', 'EBS Volume State'
]

csv_rows = []

# Loop over instances
for instance in ec2.instances.all():
    tags = instance.tags or []
    tag_dict = {tag['Key']: tag['Value'] for tag in tags}

    # Gather EC2 instance data
    base_data = [
        account_id, account_name,
        tag_dict.get('Name', 'N/A'), tag_dict.get('Application', 'N/A'), tag_dict.get('Availability', 'N/A'),
        tag_dict.get('Backup', 'N/A'), tag_dict.get('CostCentre', 'N/A'), tag_dict.get('CreatedBy', 'N/A'),
        tag_dict.get('Division', 'N/A'), tag_dict.get('Environment', 'N/A'), tag_dict.get('ManagedBy', 'N/A'),
        tag_dict.get('Owner', 'N/A'), instance.id, instance.state['Name'], instance.instance_type,
        instance.status_checks['Status'], instance.monitoring['State'], instance.placement['AvailabilityZone'],
        instance.public_dns_name, instance.public_ip_address, instance.private_ip_address,
        instance.monitoring['State'], [sg['GroupName'] for sg in instance.security_groups], instance.key_name,
        instance.launch_time, instance.subnet_id, instance.platform
    ]

    # Gather EBS volume data
    volume_data = []
    for volume in instance.volumes.all():
        volume_data.append([
            volume.id, volume.volume_type, volume.size, volume.state
        ])

    # Handle CSV: one row per EBS volume
    if volume_data:
        csv_rows.append(base_data + volume_data[0])
        for vol in volume_data[1:]:
            csv_rows.append(['-'] * (len(base_data)) + vol)
    else:
        csv_rows.append(base_data + ['N/A'] * 4)

# Write CSV
with open(csv_filename, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(csv_header)
    writer.writerows(csv_rows)

# Upload to S3
try:
    s3_client.upload_file(csv_filename, bucket_name, os.path.basename(csv_filename))
    print(f"✅ Uploaded: {csv_filename} to S3 bucket {bucket_name}")
except Exception as e:
    print(f"❌ Error uploading to S3: {str(e)}")
