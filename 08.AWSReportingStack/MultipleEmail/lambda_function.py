import boto3
import csv
import datetime
import os
import json
import logging
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
ec2_client = boto3.client('ec2')
sts_client = boto3.client('sts')
optimizer_client = boto3.client('compute-optimizer')

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_tag_value(tags, key):
    """Helper function to get the value of a tag by its key"""
    for t in tags or []:
        if t['Key'].lower() == key.lower():
            return t['Value']
    return '-'


def run_idle_audit(output_file='/tmp/AWS_resource_Reporting_audit.csv', resource_types=None):
    account_id = sts_client.get_caller_identity()['Account']
    region = os.environ['AWS_REGION']

    if resource_types is None:
        resource_types = ['EC2', 'EBS', 'Snapshot', 'Network Interface', 'Security Group']

    all_columns = [
        'ResourceType', 'ResourceID', 'Name', 'Application', 'Environment', 'CreatedBy','ManagedBy', 'AvailabilityZone','VolumeStatus','VolumeIOPS','OptimizerFinding','VolumeSnapshotID','VolumeCreatedDate','VolumeState','VolumeSize','Encryption','VolumeType','RequesterID','AttachmentStatus','VolumeThroughput','AttachedResourceID','InterfaceType','NetworkInterfaceState',
        'InstanceState', 'InstanceType', 'PrivateIP', 'SubnetID', 'Platform','AttachmentID','KeyName','Monitoring','LaunchTime','PublicIPv4 Address', 'SnapshotVolumeID', 'VPCID','SnapshotState', 'SnapshotStartTime', 'ExpiryDate','NetworkInterfaceStatus','PublicIPv4 DNS','AlarmStatus','StatusCheck','InboundRulesCount','OutboundRulesCount','Expired'
        'Description','ENIAttachmentStatus', 'AttachedSecurityGroups', 'SnapshotInstanceID', 'SecurityGroups','FullSnapshotSize', 'Progress','AllocationID' 
        
    ]

    rows = []  

    # === EC2 ===
    if 'EC2' in resource_types:
        paginator = ec2_client.get_paginator('describe_instances')
        for page in paginator.paginate():
            for reservation in page['Reservations']:
                for instance in reservation['Instances']:
                    tags = instance.get('Tags', [])
                    instance_id = instance['InstanceId']
                    name = get_tag_value(tags, 'Name')
                    application = get_tag_value(tags, 'Application')
                    environment = get_tag_value(tags, 'Environment')
                    created_by = get_tag_value(tags, 'CreatedBy')
                    managed_by = get_tag_value(tags, 'ManagedBy')
                    availability_zone = instance.get('Placement', {}).get('AvailabilityZone', 'N/A')
                    instance_state = instance['State']['Name']
                    instance_type = instance.get('InstanceType', 'N/A')
                    private_ip = instance.get('PrivateIpAddress', 'N/A')
                    public_ip = instance.get('PublicIpAddress', 'N/A')
                    public_dns = instance.get('PublicDnsName', 'N/A')
                    key_name = instance.get('KeyName', 'N/A')
                    subnet_id = instance.get('SubnetId', 'N/A')
                    launch_time = instance.get('LaunchTime').strftime('%Y-%m-%dT%H:%M:%SZ') if instance.get('LaunchTime') else 'N/A'
                    monitoring = instance.get('Monitoring', {}).get('State', 'N/A')
                    security_groups = ", ".join([sg.get('GroupName', sg.get('GroupId')) for sg in instance.get('SecurityGroups', [])]) or 'N/A'
                    platform_details = instance.get('PlatformDetails', 'Linux/UNIX')
                    platform = 'Windows' if 'windows' in platform_details.lower() else 'Linux/UNIX'

                    try:
                        status_resp = ec2_client.describe_instance_status(InstanceIds=[instance_id])
                        instance_status = status_resp['InstanceStatuses'][0]['InstanceStatus']['Status'] if status_resp['InstanceStatuses'] else 'N/A'
                    except ClientError:
                        instance_status = 'N/A'

                    row = {
                        'ResourceType': 'EC2',
                        'ResourceID': instance_id,
                        'Name': name,
                        'Application': application,
                        'Environment': environment,
                        'CreatedBy': created_by,
                        'ManagedBy': managed_by,
                        'AvailabilityZone': availability_zone,
                        'InstanceState': instance_state,
                        'InstanceType': instance_type,
                        'PrivateIP': private_ip,
                        'PublicIPv4 Address': public_ip,
                        'PublicIPv4 DNS': public_dns,
                        'Monitoring': monitoring,
                        'SecurityGroups': security_groups,
                        'KeyName': key_name,
                        'LaunchTime': launch_time,
                        'Platform': platform,
                        'SubnetID': subnet_id,
                        'StatusCheck': instance_status,
                        'VPCID': instance.get('VpcId', 'N/A'),
                        'AlarmStatus': 'N/A',
                        'VolumeStatus': 'N/A', 'VolumeIOPS': 'N/A', 'VolumeSnapshotID': 'N/A', 'VolumeCreatedDate': 'N/A',
                        'SnapshotState': 'N/A', 'SnapshotStartTime': 'N/A', 'SnapshotVolumeID': 'N/A', 'SnapshotInstanceID': 'N/A',
                        'FullSnapshotSize': 'N/A', 'Progress': 'N/A', 'VolumeSize': 'N/A', 'Encryption': 'N/A', 'VolumeType': 'N/A',
                        'VolumeThroughput': 'N/A', 'AttachedResourceID': 'N/A', 'NetworkInterfaceState': 'N/A',
                        'AllocationID': 'N/A',  'RequesterID': 'N/A', 'AttachmentStatus': 'N/A','Description': 'N/A',
                        'AttachmentID': 'N/A', 'ENIAttachmentStatus': 'N/A', 'AttachedSecurityGroups': 'N/A', 'InterfaceType': 'N/A'
                    }
                    rows.append(row)
    # === EBS ===
    if 'EBS' in resource_types:
        paginator = ec2_client.get_paginator('describe_volumes')
        for page in paginator.paginate():
            for volume in page['Volumes']:
                tags = volume.get('Tags', [])
                volume_id = volume['VolumeId']
                attached_resource_id = volume['Attachments'][0].get('InstanceId', 'N/A') if volume['Attachments'] else 'N/A'
                volume_state = volume.get('State', 'N/A')
                volume_type = volume.get('VolumeType', 'N/A')
                volume_iops = volume.get('Iops', 'N/A')
                volume_throughput = volume.get('Throughput', 'N/A')
                availability_zone = volume.get('AvailabilityZone', 'N/A')
                optimizer_finding = 'NotAvailable'
                volume_status_check = 'N/A'

                try:
                    status_response = ec2_client.describe_volume_status(VolumeIds=[volume_id])
                    if status_response['VolumeStatuses']:
                        volume_status_check = status_response['VolumeStatuses'][0].get('VolumeStatus', {}).get('Status', 'N/A')
                except ClientError:
                    pass

                try:
                    volume_arn = f"arn:aws:ec2:{region}:{account_id}:volume/{volume_id}"
                    opt_response = optimizer_client.get_ebs_volume_recommendations(VolumeArns=[volume_arn])
                    if opt_response['VolumeRecommendations']:
                        optimizer_finding = opt_response['VolumeRecommendations'][0].get('Finding', 'N/A')
                except Exception:
                    pass

                row = {
                    'ResourceType': 'EBS',
                    'ResourceID': volume_id,
                    'Name': get_tag_value(tags, 'Name'),
                    'Application': get_tag_value(tags, 'Application'),
                    'Environment': get_tag_value(tags, 'Environment'),
                    'CreatedBy': get_tag_value(tags, 'CreatedBy'),
                    'ManagedBy': get_tag_value(tags, 'ManagedBy'),
                    'AvailabilityZone': availability_zone,
                    'VolumeStatus': 'Attached' if volume['Attachments'] else 'Not Attached',
                    'VolumeIOPS': volume_iops,
                    'VolumeSnapshotID': volume.get('SnapshotId', 'N/A'),
                    'VolumeCreatedDate': volume['CreateTime'].strftime('%Y-%m-%d %H:%M'),
                    'VolumeState': volume_state,
                    'OptimizerFinding': optimizer_finding,
                    'VolumeType': volume_type,
                    'StatusCheck': volume_status_check,
                    'VolumeThroughput': volume_throughput,'VolumeSize': volume.get('Size', 'N/A'),
                    'AttachedResourceID': attached_resource_id,'Encryption': 'Yes' if volume.get('Encrypted', False) else 'No',
                    'InstanceState': 'N/A', 'InstanceType': 'N/A', 'PrivateIP': 'N/A', 'PublicIPv4 Address': 'N/A', 'PublicIPv4 DNS': 'N/A', 
                    'Monitoring': 'N/A', 'SecurityGroups': 'N/A', 'KeyName': 'N/A', 'LaunchTime': 'N/A', 'Platform': 'N/A', 'SubnetID': 'N/A',
                    'AlarmStatus': 'N/A', 'SnapshotState': 'N/A', 'SnapshotStartTime': 'N/A', 'SnapshotVolumeID': 'N/A',
                    'SnapshotInstanceID': 'N/A', 'FullSnapshotSize': 'N/A', 'Progress': 'N/A','NetworkInterfaceState': 'N/A', 'AllocationID': 'N/A',
                    'VPCID': 'N/A', 'RequesterID': 'N/A', 'AttachmentStatus': 'N/A', 'AttachmentID': 'N/A', 'ENIAttachmentStatus': 'N/A',
                    'AttachedSecurityGroups': 'N/A', 'InterfaceType': 'N/A', 'Description': 'N/A'
                }
                rows.append(row)

    # === Snapshots ===
    if 'Snapshot' in resource_types:
        paginator = ec2_client.get_paginator('describe_snapshots')
        for page in paginator.paginate(OwnerIds=['self']):
            for snapshot in page['Snapshots']:
                tags = snapshot.get('Tags', [])
                
                # Get and evaluate expiry date
                expiry_str = get_tag_value(tags, 'ExpiryDate')
                expired = 'N/A'
                if expiry_str and expiry_str != '-':
                    try:
                        expiry_date = datetime.datetime.strptime(expiry_str, '%Y-%m-%d').date()
                        expired = 'Yes' if expiry_date < datetime.date.today() else 'No'
                    except ValueError:
                        expired = 'Invalid Format'
                                                      
                row = {
                    'ResourceType': 'Snapshot',
                    'ResourceID': snapshot['SnapshotId'],
                    'Name': get_tag_value(tags, 'Name'),
                    'Application': get_tag_value(tags, 'Application'),
                    'Environment': get_tag_value(tags, 'Environment'),
                    'CreatedBy': get_tag_value(tags, 'CreatedBy'),
                    'ManagedBy': get_tag_value(tags, 'ManagedBy'),
                    'AvailabilityZone': 'N/A','Expired': expired,
                    'SnapshotState': snapshot['State'],
                    'ExpiryDate': get_tag_value(tags, 'ExpiryDate'),
                    'VolumeCreatedDate': snapshot['StartTime'].strftime('%Y-%m-%d %H:%M'),
                    'SnapshotStartTime': snapshot['StartTime'].strftime('%Y-%m-%d %H:%M'),
                    'SnapshotVolumeID': snapshot.get('VolumeId', 'N/A'),
                    'SnapshotInstanceID': get_tag_value(tags, 'InstanceId'),
                    'FullSnapshotSize': snapshot.get('VolumeSize', 'N/A'),
                    'Progress': snapshot.get('Progress', 'N/A'),
                    'VolumeSize': snapshot.get('VolumeSize', 'N/A'),
                    'Encryption': 'Yes' if snapshot.get('Encrypted', False) else 'No',
                    'InstanceState': 'N/A', 'InstanceType': 'N/A', 'PrivateIP': 'N/A', 'PublicIPv4 Address': 'N/A', 'PublicIPv4 DNS': 'N/A', 
                    'Monitoring': 'N/A', 'SecurityGroups': 'N/A', 'KeyName': 'N/A', 'LaunchTime': 'N/A', 'Platform': 'N/A', 'SubnetID': 'N/A',
                    'AlarmStatus': 'N/A', 'VolumeStatus': 'N/A', 'VolumeIOPS': 'N/A', 'VolumeSnapshotID': 'N/A',
                    'VolumeState': 'N/A', 'VolumeType': 'N/A', 'StatusCheck': 'N/A', 'VolumeThroughput': 'N/A', 'AttachedResourceID': 'N/A',
                    'NetworkInterfaceState': 'N/A', 'AllocationID': 'N/A', 'VPCID': 'N/A', 'RequesterID': 'N/A', 'AttachmentStatus': 'N/A',
                    'AttachmentID': 'N/A', 'ENIAttachmentStatus': 'N/A', 'AttachedSecurityGroups': 'N/A', 'InterfaceType': 'N/A', 'Description': 'N/A'
                }
                rows.append(row)


    # === ENIs ===
    if 'Network Interface' in resource_types:
        paginator = ec2_client.get_paginator('describe_network_interfaces')
        for page in paginator.paginate():
            for eni in page['NetworkInterfaces']:
                tags = eni.get('Tags', [])
                attachment = eni.get('Attachment', {})
                association = eni.get('Association', {})
                row = {
                   'ResourceType': 'Network Interface',
                   'ResourceID': eni['NetworkInterfaceId'],
                   'Name': get_tag_value(tags, 'Name'),
                   'Application': get_tag_value(tags, 'Application'),
                   'Environment': get_tag_value(tags, 'Environment'),
                   'CreatedBy': get_tag_value(tags, 'CreatedBy'),
                   'ManagedBy': get_tag_value(tags, 'ManagedBy'),
                   'AvailabilityZone': eni.get('AvailabilityZone', 'N/A'),
                   'PrivateIP': eni.get('PrivateIpAddress', 'N/A'),
                   'PublicIPv4 Address': association.get('PublicIp', 'N/A'),
                   'AllocationID': association.get('AllocationId', '-'),'SubnetID': eni.get('SubnetId', 'N/A'),
                   'VPCID': eni.get('VpcId', '-'), 'RequesterID': eni.get('RequesterId', '-'),
                   'AttachedSecurityGroups': ', '.join([sg.get('GroupName', 'N/A') for sg in eni.get('Groups', [])]),
                   'NetworkInterfaceState': eni.get('Status', 'N/A'),'AttachmentStatus': attachment.get('Status', 'N/A'),'AttachmentID': attachment.get('AttachmentId', 'N/A'),
                   'ENIAttachmentStatus': attachment.get('Status', 'N/A'),'Expired': 'N/A',
                   'InterfaceType': eni.get('InterfaceType', 'N/A'),'Description': eni.get('Description', 'N/A'),
                   'PublicIPv4 DNS': 'N/A',
                   'Monitoring': 'N/A', 'SecurityGroups': 'N/A', 'KeyName': 'N/A', 'LaunchTime': 'N/A', 'Platform': 'N/A', 
                   'AlarmStatus': 'N/A', 'InstanceState': 'N/A', 'InstanceType': 'N/A', 'VolumeStatus': 'N/A', 'VolumeIOPS': 'N/A',
                   'VolumeSnapshotID': 'N/A', 'VolumeCreatedDate': 'N/A', 'VolumeState': 'N/A', 'SnapshotState': 'N/A', 'SnapshotStartTime': 'N/A',
                   'SnapshotVolumeID': 'N/A', 'SnapshotInstanceID': 'N/A', 'FullSnapshotSize': 'N/A', 'Progress': 'N/A', 'VolumeSize': 'N/A',
                   'Encryption': 'N/A', 'VolumeType': 'N/A', 'StatusCheck': 'N/A', 'VolumeThroughput': 'N/A', 'AttachedResourceID': 'N/A',
                   
                }
                rows.append(row)
                
    # === Security Groups ===
    if 'Security Group' in resource_types:
        paginator = ec2_client.get_paginator('describe_security_groups')
        for page in paginator.paginate():
            for sg in page['SecurityGroups']:
                tags = sg.get('Tags', [])
                sg_id = sg['GroupId']
                name = get_tag_value(tags, 'Name') or sg.get('GroupName', 'N/A')
                vpc_id = sg.get('VpcId', 'N/A')
                description = sg.get('Description', 'N/A')

                inbound_count = len(sg.get('IpPermissions', []))
                outbound_count = len(sg.get('IpPermissionsEgress', []))
                
                row = {
                    'ResourceType': 'Security Group',
                    'ResourceID': sg_id,
                    'Name': name,
                    'Description': description,
                    'VPCID': vpc_id,'CreatedBy': get_tag_value(tags, 'CreatedBy'), 
                    'ManagedBy': get_tag_value(tags, 'ManagedBy'), 'Application': get_tag_value(tags, 'Application'), 
                    'Environment': get_tag_value(tags, 'Environment'), 'VolumeType': 'N/A', 
                    'InboundRulesCount': inbound_count,'OutboundRulesCount': outbound_count,
                    'AttachedSecurityGroups': 'N/A','Expired': 'N/A',
                    'SecurityGroups': 'N/A', 
                    'InstanceState': 'N/A', 'InstanceType': 'N/A', 'PrivateIP': 'N/A', 'PublicIPv4 Address': 'N/A', 
                    'PublicIPv4 DNS': 'N/A', 'Monitoring': 'N/A', 'KeyName': 'N/A', 'LaunchTime': 'N/A', 'Platform': 'N/A', 
                    'SubnetID': 'N/A', 'AlarmStatus': 'N/A', 'VolumeStatus': 'N/A', 'VolumeIOPS': 'N/A', 
                    'VolumeSnapshotID': 'N/A', 'VolumeCreatedDate': 'N/A', 'VolumeState': 'N/A', 'SnapshotState': 'N/A', 
                    'SnapshotStartTime': 'N/A', 'SnapshotVolumeID': 'N/A', 'SnapshotInstanceID': 'N/A', 
                    'FullSnapshotSize': 'N/A', 'Progress': 'N/A', 'VolumeSize': 'N/A', 'Encryption': 'N/A', 'VolumeType': 'N/A', 
                    'StatusCheck': 'N/A', 'VolumeThroughput': 'N/A', 'AttachedResourceID': 'N/A', 
                    'NetworkInterfaceState': 'N/A', 'AllocationID': 'N/A', 'RequesterID': 'N/A', 'AttachmentStatus': 'N/A', 
                    'AttachmentID': 'N/A', 'ENIAttachmentStatus': 'N/A', 'InterfaceType': 'N/A', 
                    'AvailabilityZone': 'N/A'
                }

                for col in all_columns:
                    row.setdefault(col, 'N/A')

                rows.append(row)
           

    output = ''
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=all_columns)
        writer.writeheader()  
        for row in rows:
            writer.writerow(row)

    print(f"AWS resource audit complete. Report saved to {output_file}")

def lambda_handler(event, context):
    output_file = '/tmp/AWS_resource_Reporting_audit.csv'

    if isinstance(event, dict) and event.get("source") == "aws.events":
        trigger_type = "Scheduled (EventBridge)"
    else:
        trigger_type = "Manual Trigger"

    logger.info(f"Lambda triggered by: {trigger_type}")
    logger.info(f"Event: {json.dumps(event)[:500]}")  

    run_idle_audit(output_file=output_file)

    # Upload to S3
    s3 = boto3.client('s3')
    s3.upload_file(
        Filename=output_file,
        Bucket=os.environ['BUCKET_NAME'],
        Key=os.environ['S3_REPORT_KEY']
    )
    logger.info(f"Uploaded report to s3://{os.environ['BUCKET_NAME']}/{os.environ['S3_REPORT_KEY']}")

    # Generate a presigned URL (valid for 24 hours)
    presigned_url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': os.environ['BUCKET_NAME'],
            'Key': os.environ['S3_REPORT_KEY']
        },
        ExpiresIn=86400  
    )
    logger.info(f"Presigned download URL: {presigned_url}")


    sns = boto3.client('sns')
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject='AWS Resource Reporting Audit is  Ready',
        Message=(
            f"The AWS Resource Reporting Audit has completed successfully.\n\n"
            f"You can download the report using the secure link below (valid for 24 hours):\n\n"
            f"{presigned_url}\n\n"
            f"--\nAWS Resource Reporting Audit Automation"
        )
    )
    logger.info("SNS notification sent")