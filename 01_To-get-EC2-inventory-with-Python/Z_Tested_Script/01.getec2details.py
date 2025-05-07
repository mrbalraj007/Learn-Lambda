import sys
import boto3
ec2 = boto3.resource('ec2',
    aws_access_key_id='**********************',
    aws_secret_access_key='**********************',
    region_name='us-east-1',
    )
html = """<html><table border="1">
<tr><th>Instance-Name</th><th>Instance-ID</th><th>launch-time</th><th>State</th><th>RootDevice</th><th>Private-IP-Address</th><th>Public-IP-Address</th><th>Subnet</th></tr>"""
for instance in ec2.instances.all():
    names = [tag.get('Value') for tag in instance.tags if tag.get('Key') == 'Name']
    hname = names[0] if names else None
    html += "<tr><td>{}</td>".format(hname)
    html += "<td>{}</td>".format(instance.id)
    html += "<td>{}</td>".format(instance.launch_time)
    html += "<td>{}</td>".format(instance.state['Name'])
    html += "<td>{}</td>".format(instance.root_device_name)
    html += "<td>{}</td>".format(instance.private_ip_address)
    html += "<td>{}</td>".format(instance.public_ip_address)
    html += "<td>{}</td>".format(instance.subnet)
    html += "</tr>"
html += "</table></html>"
file_ = open('result.html', 'w')
file_.write(html)
file_.close()