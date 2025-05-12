import boto3
import csv
import io
import datetime
import os
from datetime import datetime, timezone

def lambda_handler(event, context):
    # Initialize AWS clients
    ec2_client = boto3.client('ec2', region_name='us-east-1')
    s3_client = boto3.client('s3', region_name='us-east-1')
    
    # Get bucket name from environment variable
    bucket_name = os.environ['S3_BUCKET_NAME']
    
    # Get current date for filename
    current_date = datetime.now().strftime('%Y-%m-%d')
    csv_file_name = f"idle-resources-{current_date}.csv"
    
    # Lists to store findings
    idle_resources = []
    
    # Find stopped EC2 instances
    stopped_instances = find_stopped_ec2_instances(ec2_client)
    for instance in stopped_instances:
        idle_resources.append({
            'ResourceType': 'EC2',
            'ResourceId': instance['InstanceId'],
            'Status': 'Stopped',
            'IdleSince': instance.get('StoppedSince', 'Unknown'),
            'AdditionalInfo': f"Name: {instance.get('Name', 'N/A')}"
        })
    
    # Find unattached EBS volumes
    unattached_volumes = find_unattached_volumes(ec2_client)
    for volume in unattached_volumes:
        idle_resources.append({
            'ResourceType': 'EBS Volume',
            'ResourceId': volume['VolumeId'],
            'Status': 'Available (Unattached)',
            'IdleSince': volume.get('CreatedSince', 'Unknown'),
            'AdditionalInfo': f"Size: {volume.get('Size', 'N/A')} GB, Type: {volume.get('VolumeType', 'N/A')}"
        })
    
    # Find idle snapshots (older than 30 days and not associated with AMIs)
    idle_snapshots = find_idle_snapshots(ec2_client)
    for snapshot in idle_snapshots:
        idle_resources.append({
            'ResourceType': 'EBS Snapshot',
            'ResourceId': snapshot['SnapshotId'],
            'Status': 'Idle',
            'IdleSince': snapshot.get('StartTime', 'Unknown'),
            'AdditionalInfo': f"Size: {snapshot.get('Size', 'N/A')} GB, Description: {snapshot.get('Description', 'N/A')}"
        })
    
    # Create CSV in memory
    csv_file = io.StringIO()
    fieldnames = ['ResourceType', 'ResourceId', 'Status', 'IdleSince', 'AdditionalInfo']
    writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
    writer.writeheader()
    
    for resource in idle_resources:
        writer.writerow(resource)
    
    # Upload to S3
    s3_client.put_object(
        Bucket=bucket_name,
        Key=csv_file_name,
        Body=csv_file.getvalue(),
        ContentType='text/csv'
    )
    
    return {
        'statusCode': 200,
        'body': f"Successfully identified {len(idle_resources)} idle resources and saved to s3://{bucket_name}/{csv_file_name}"
    }

def find_stopped_ec2_instances(ec2_client):
    instances = []
    response = ec2_client.describe_instances(
        Filters=[
            {
                'Name': 'instance-state-name',
                'Values': ['stopped']
            }
        ]
    )
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            name = 'N/A'
            for tag in instance.get('Tags', []):
                if tag['Key'] == 'Name':
                    name = tag['Value']
                    break
                    
            instances.append({
                'InstanceId': instance['InstanceId'],
                'Name': name,
                'StoppedSince': instance.get('StateTransitionReason', 'Unknown').replace('User initiated (', '').replace(')', '') if 'User initiated' in instance.get('StateTransitionReason', '') else 'Unknown'
            })
    
    return instances

def find_unattached_volumes(ec2_client):
    volumes = []
    response = ec2_client.describe_volumes(
        Filters=[
            {
                'Name': 'status',
                'Values': ['available']
            }
        ]
    )
    
    for volume in response['Volumes']:
        volumes.append({
            'VolumeId': volume['VolumeId'],
            'Size': volume['Size'],
            'VolumeType': volume['VolumeType'],
            'CreatedSince': volume['CreateTime'].strftime('%Y-%m-%d')
        })
    
    return volumes

def find_idle_snapshots(ec2_client):
    # Get all snapshots owned by this account
    snapshots = []
    response = ec2_client.describe_snapshots(OwnerIds=['self'])
    
    # Get snapshots used by AMIs
    images = ec2_client.describe_images(Owners=['self'])
    used_snapshot_ids = set()
    
    for image in images['Images']:
        for block_device in image.get('BlockDeviceMappings', []):
            if 'Ebs' in block_device and 'SnapshotId' in block_device['Ebs']:
                used_snapshot_ids.add(block_device['Ebs']['SnapshotId'])
    
    # Threshold for idle snapshots (30 days)
    threshold_date = datetime.now(timezone.utc) - datetime.timedelta(days=30)
    
    for snapshot in response['Snapshots']:
        # Skip if used by an AMI
        if snapshot['SnapshotId'] in used_snapshot_ids:
            continue
        
        # Check if older than threshold
        if snapshot['StartTime'] < threshold_date:
            snapshots.append({
                'SnapshotId': snapshot['SnapshotId'],
                'StartTime': snapshot['StartTime'].strftime('%Y-%m-%d'),
                'Size': snapshot.get('VolumeSize', 'N/A'),
                'Description': snapshot.get('Description', 'N/A')
            })
    
    return snapshots
