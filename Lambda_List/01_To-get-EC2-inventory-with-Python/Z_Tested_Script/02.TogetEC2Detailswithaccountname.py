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

# Build HTML header with Account ID and Name
html = f"""<html><body>
<h2>AWS Account Report</h2>
<p><strong>Account ID:</strong> {account_id}</p>
<p><strong>Account Name:</strong> {account_name}</p>
<table border="1">
<tr><th>Instance-Name</th><th>Instance-ID</th><th>Launch-Time</th><th>State</th><th>RootDevice</th>
<th>Private-IP-Address</th><th>Public-IP-Address</th><th>Subnet</th></tr>
"""

# Get EC2 instances
ec2 = session.resource('ec2')
for instance in ec2.instances.all():
    names = [tag.get('Value') for tag in instance.tags or [] if tag.get('Key') == 'Name']
    hname = names[0] if names else 'N/A'
    html += "<tr>"
    html += "<td>{}</td>".format(hname)
    html += "<td>{}</td>".format(instance.id)
    html += "<td>{}</td>".format(instance.launch_time)
    html += "<td>{}</td>".format(instance.state['Name'])
    html += "<td>{}</td>".format(instance.root_device_name)
    html += "<td>{}</td>".format(instance.private_ip_address)
    html += "<td>{}</td>".format(instance.public_ip_address)
    html += "<td>{}</td>".format(instance.subnet_id)
    html += "</tr>"

html += "</table></body></html>"

# Save to file
with open('account_result.html', 'w') as file_:
    file_.write(html)