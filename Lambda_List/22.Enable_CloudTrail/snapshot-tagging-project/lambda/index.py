import boto3
import os
import json
from datetime import datetime, timedelta

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    retention_days = int(os.environ.get("RETENTION_DAYS", 90))
    delete_on = (datetime.utcnow() + timedelta(days=retention_days)).strftime('%Y-%m-%d')

    snapshot_id = None
    resource_arn = None

    if 'detail' in event:
        detail = event['detail']
        service = detail.get('service')

        # EBS Snapshots
        if detail.get('eventName') == 'CreateSnapshot':
            snapshot_id = detail['responseElements']['snapshotId']
            ec2 = boto3.client('ec2')
            ec2.create_tags(
                Resources=[snapshot_id],
                Tags=[
                    {'Key': 'Retention', 'Value': f'{retention_days}days'},
                    {'Key': 'DeleteOn', 'Value': delete_on}
                ]
            )

        # AWS Backup Resource ARN
        elif detail.get('eventName') == 'StartBackupJob':
            resource_arn = detail['requestParameters'].get('resourceArn')
            backup = boto3.client('backup')
            if resource_arn:
                backup.tag_resource(
                    ResourceArn=resource_arn,
                    Tags={
                        'Retention': f'{retention_days}days',
                        'DeleteOn': delete_on
                    }
                )

    return {
        'statusCode': 200,
        'body': json.dumps('Tagging complete')
    }