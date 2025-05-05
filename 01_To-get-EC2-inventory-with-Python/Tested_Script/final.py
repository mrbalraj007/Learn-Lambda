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
preferred_tag_keys = ['Name', 'env', 'owner', 'techowner']

# EC2 resource
ec2 = session.resource('ec2')

# CSV header
csv_header = [
    "Account ID", "Account Name", "Instance-Name", "Instance-ID", "AMI-ID", "Launch-Time", "State",
    "RootDevice", "Private-IP", "Public-IP", "Subnet"
] + preferred_tag_keys + ['EBS Volume ID', 'EBS Volume Type', 'EBS Volume Size (GB)', 'EBS Volume State']

csv_rows = []

# Loop over instances
for instance in ec2.instances.all():
    tags = instance.tags or []
    tag_dict = {tag['Key']: tag['Value'] for tag in tags}
    name = tag_dict.get('Name', 'N/A')

    base_data = [
        account_id, account_name, name, instance.id, instance.image_id, instance.launch_time,
        instance.state['Name'], instance.root_device_name, instance.private_ip_address,
        instance.public_ip_address, instance.subnet_id
    ]
    tag_values = [tag_dict.get(k, 'N/A') for k in preferred_tag_keys]

    # Gather EBS volumes
    volume_data = []
    for volume in instance.volumes.all():
        volume_data.append([
            volume.id,
            volume.volume_type,
            volume.size,
            volume.state
        ])

    # Handle CSV: one row per EBS volume
    if volume_data:
        csv_rows.append(base_data + tag_values + volume_data[0])
        for vol in volume_data[1:]:
            csv_rows.append(['-'] * (len(base_data) + len(tag_values)) + vol)
    else:
        csv_rows.append(base_data + tag_values + ['N/A'] * 4)

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
