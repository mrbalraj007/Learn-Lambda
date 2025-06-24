import boto3
import sys

# Initialize session
session = boto3.Session(
    aws_access_key_id='**********************',
    aws_secret_access_key='**********************',
    region_name='us-east-1',
)


# Get AWS Account ID
sts_client = session.client('sts')
account_id = sts_client.get_caller_identity()["Account"]

# Get Account Name from Organizations
org_client = session.client('organizations')
try:
    account_info = org_client.describe_account(AccountId=account_id)
    account_name = account_info['Account']['Name']
except Exception as e:
    account_name = f"(Name not accessible: {str(e)})"

# Start building HTML
html = f"""<html><body>
<h2>AWS Account Report</h2>
<p><strong>Account ID:</strong> {account_id}</p>
<p><strong>Account Name:</strong> {account_name}</p>
<table border="1">
<tr>
<th>Instance-Name</th>
<th>Instance-ID</th>
<th>Launch-Time</th>
<th>State</th>
<th>RootDevice</th>
<th>Private-IP-Address</th>
<th>Public-IP-Address</th>
<th>Subnet</th>
<th>Tags</th>
</tr>
"""

# Define preferred tag order
preferred_tag_keys = ['Name', 'env', 'owner', 'techowner']

# Get EC2 instances
ec2 = session.resource('ec2')
for instance in ec2.instances.all():
    tags = instance.tags or []
    tag_dict = {tag['Key']: tag['Value'] for tag in tags}

    # Prepare ordered tag string
    ordered_tags = []
    for key in preferred_tag_keys:
        if key in tag_dict:
            ordered_tags.append(f"{key}={tag_dict[key]}")
    remaining_tags = sorted(k for k in tag_dict if k not in preferred_tag_keys)
    for key in remaining_tags:
        ordered_tags.append(f"{key}={tag_dict[key]}")

    tag_string = ", ".join(ordered_tags)
    name = tag_dict.get('Name', 'N/A')

    html += "<tr>"
    html += f"<td>{name}</td>"
    html += f"<td>{instance.id}</td>"
    html += f"<td>{instance.launch_time}</td>"
    html += f"<td>{instance.state['Name']}</td>"
    html += f"<td>{instance.root_device_name}</td>"
    html += f"<td>{instance.private_ip_address}</td>"
    html += f"<td>{instance.public_ip_address}</td>"
    html += f"<td>{instance.subnet_id}</td>"
    html += f"<td>{tag_string}</td>"
    html += "</tr>"

html += "</table></body></html>"

# Write the result to file
with open('account_result.html', 'w') as file_:
    file_.write(html)