import boto3
import csv
import sys
# Initialize session
session = boto3.Session(
    aws_access_key_id='**********************',
    aws_secret_access_key='**********************',
    region_name='us-east-1',
)

# Get Account Info
sts_client = session.client('sts')
account_id = sts_client.get_caller_identity()["Account"]

org_client = session.client('organizations')
try:
    account_info = org_client.describe_account(AccountId=account_id)
    account_name = account_info['Account']['Name']
except Exception as e:
    account_name = f"(Name not accessible: {str(e)})"

# Setup preferred tag order
preferred_tag_keys = ['Name', 'env', 'owner', 'techowner']

# Initialize EC2 resource
ec2 = session.resource('ec2')

# Start HTML and CSV data collection
html = f"""<html><body>
<h2>AWS Account Report</h2>
<p><strong>Account ID:</strong> {account_id}</p>
<p><strong>Account Name:</strong> {account_name}</p>
<table border="1">
<tr>
<th>Instance-Name</th><th>Instance-ID</th><th>AMI-ID</th><th>Launch-Time</th><th>State</th>
<th>RootDevice</th><th>Private-IP</th><th>Public-IP</th><th>Subnet</th>"""

# Dynamic Columns for Tags
tag_columns = preferred_tag_keys + ['Additional Tags']
for key in preferred_tag_keys:
    html += f"<th>{key}</th>"  # Creating separate column for each tag in HTML
csv_header = ["Instance-Name", "Instance-ID", "AMI-ID", "Launch-Time", "State", "RootDevice", "Private-IP", "Public-IP", "Subnet"] + preferred_tag_keys

csv_rows = []

# Loop through instances
for instance in ec2.instances.all():
    tags = instance.tags or []
    tag_dict = {tag['Key']: tag['Value'] for tag in tags}

    # HTML row for instance
    html += "<tr>"
    name = tag_dict.get('Name', 'N/A')
    html += f"<td>{name}</td><td>{instance.id}</td><td>{instance.image_id}</td>"
    html += f"<td>{instance.launch_time}</td><td>{instance.state['Name']}</td>"
    html += f"<td>{instance.root_device_name}</td><td>{instance.private_ip_address}</td>"
    html += f"<td>{instance.public_ip_address}</td><td>{instance.subnet_id}</td>"

    # Add tag values to corresponding columns in HTML
    for key in preferred_tag_keys:
        html += f"<td>{tag_dict.get(key, 'N/A')}</td>"

    # CSV row for instance (add tag values in separate columns)
    csv_row = [
        name, instance.id, instance.image_id, instance.launch_time,
        instance.state['Name'], instance.root_device_name, instance.private_ip_address,
        instance.public_ip_address, instance.subnet_id
    ]

    for key in preferred_tag_keys:
        csv_row.append(tag_dict.get(key, 'N/A'))

    # Add Additional Tags as separate columns
    remaining_tags = sorted(k for k in tag_dict if k not in preferred_tag_keys)
    for key in remaining_tags:
        html += f"<td>{tag_dict[key]}</td>"
        csv_row.append(tag_dict[key])

    html += "</tr>"
    csv_rows.append(csv_row)

html += "</table></body></html>"

# Write HTML
with open('account_result.html', 'w') as f:
    f.write(html)

# Write CSV
with open('account_result.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(csv_header)
    writer.writerows(csv_rows)

print("✅ account_result.html and account_result.csv generated with separate columns for tags.")
