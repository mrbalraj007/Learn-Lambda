import boto3
from datetime import datetime, timezone

ec2 = boto3.client('ec2')
ec2_resource = boto3.resource('ec2')

def get_instance_snapshot_mapping():
    mapping = {}
    for instance in ec2_resource.instances.all():
        for vol in instance.volumes.all():
            mapping[vol.id] = instance.id
    return mapping

def lambda_handler(event, context):
    snapshots = ec2.describe_snapshots(OwnerIds=['self'])['Snapshots']
    instance_map = get_instance_snapshot_mapping()
    stale_snapshots = []

    for snapshot in snapshots:
        snap_id = snapshot['SnapshotId']
        start_time = snapshot['StartTime'].replace(tzinfo=timezone.utc)
        age_days = (datetime.now(timezone.utc) - start_time).days
        volume_id = snapshot.get('VolumeId', 'N/A')
        delete_on = next((tag['Value'] for tag in snapshot.get('Tags', []) if tag['Key'] == 'DeleteOn'), 'Not Tagged')
        associated_instance = instance_map.get(volume_id, 'N/A')

        if age_days > 90:
            stale_snapshots.append({
                'SnapshotId': snap_id,
                'StartTime': str(start_time),
                'AgeInDays': age_days,
                'VolumeId': volume_id,
                'AssociatedInstance': associated_instance,
                'DeleteOnTag': delete_on
            })

    print("Stale Snapshots (>90 days):", stale_snapshots)
    return stale_snapshots
