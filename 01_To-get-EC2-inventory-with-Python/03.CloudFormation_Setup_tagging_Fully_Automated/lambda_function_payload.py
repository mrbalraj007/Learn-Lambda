import boto3
import csv
import os
from datetime import datetime

def lambda_handler(event, context):
    region_name = os.environ.get('REGION_NAME', 'us-east-1')
    bucket_name = os.environ.get('S3_BUCKET_NAME')
    s3_folder = 'EC2_Inventory'

    session = boto3.Session(region_name=region_name)
    
    sts_client = session.client('sts')
    account_id = sts_client.get_caller_identity()["Account"]

    org_client = session.client('organizations')
    try:
        account_info = org_client.describe_account(AccountId=account_id)
        account_name = account_info['Account']['Name']
    except Exception as e:
        account_name = f"(Name not accessible: {str(e)})"

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    filename = f"ec2_inventory_{timestamp}.csv"
    file_path = f"/tmp/{filename}"

    s3_client = session.client('s3')

    preferred_tag_keys = [
        'Name', 'Application', 'Availability', 'Backup', 'CostCentre', 'CreatedBy',
        'Division', 'Environment', 'ManagedBy', 'Owner'
    ]

    ec2 = session.resource('ec2')

    csv_header = [
        "Name", "Application", "Availability", "Backup", "CostCentre", "CreatedBy",
        "Division", "Environment", "ManagedBy", "Owner",
        "Instance ID", "Instance State", "Instance Type", "Status Checks", "Alarm Status",
        "Availability Zone", "Public IPv4 DNS", "Public IPv4 Address", "Private IP Address",
        "Monitoring", "Security Groups", "Key Name", "Launch Time", "Subnet ID", "Platform"
    ]

    csv_rows = []

    for instance in ec2.instances.all():
        tags = instance.tags or []
        tag_dict = {tag['Key']: tag['Value'] for tag in tags}
        tag_values = [tag_dict.get(k, 'N/A') for k in preferred_tag_keys]

        instance_state = instance.state['Name']
        status_checks = 'N/A'
        alarm_status = 'N/A'
        security_groups = ', '.join([sg['GroupName'] for sg in instance.security_groups])
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
            str(instance.launch_time),
            instance.subnet_id,
            platform
        ]

        csv_rows.append(row)

    with open(file_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(csv_header)
        writer.writerows(csv_rows)

    try:
        s3_key = f"{s3_folder}/{filename}"
        s3_client.upload_file(file_path, bucket_name, s3_key)
        return {
            'statusCode': 200,
            'body': f"Uploaded to s3://{bucket_name}/{s3_key}"
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Upload failed: {str(e)}"
        }
