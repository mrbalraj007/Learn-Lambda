import boto3
from datetime import datetime, timedelta

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    snapshot_id = event['detail']['responseElements']['snapshotId']
    delete_on = (datetime.utcnow() + timedelta(days=90)).strftime('%Y-%m-%d')
    ec2.create_tags(
        Resources=[snapshot_id],
        Tags=[
            {'Key': 'DeleteOn', 'Value': delete_on},
            {'Key': 'Retention', 'Value': '90days'}
        ]
    )
    return f"Snapshot {snapshot_id} tagged for deletion on {delete_on}"
