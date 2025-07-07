import boto3
import datetime
import os
import logging
from botocore.exceptions import ClientError, BotoCoreError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to tag AMIs and Snapshots with retention and delete-on tags
    """
    try:
        # Initialize EC2 client
        ec2 = boto3.client('ec2')
        
        # Get retention days from environment variable
        retention_days = int(os.environ.get('RETENTION_DAYS', '90'))
        
        # Calculate delete date
        today = datetime.date.today()
        delete_on = today + datetime.timedelta(days=retention_days)
        formatted_delete_on = delete_on.strftime('%Y-%m-%d')
        
        logger.info(f"Starting tagging process with {retention_days} days retention")
        logger.info(f"Delete on date: {formatted_delete_on}")
        
        # Tag owned AMIs
        ami_count = tag_amis(ec2, retention_days, formatted_delete_on)
        
        # Tag owned Snapshots
        snapshot_count = tag_snapshots(ec2, retention_days, formatted_delete_on)
        
        result = {
            'statusCode': 200,
            'message': f'Successfully tagged {ami_count} AMIs and {snapshot_count} snapshots',
            'amis_tagged': ami_count,
            'snapshots_tagged': snapshot_count,
            'retention_days': retention_days,
            'delete_on': formatted_delete_on
        }
        
        logger.info(result['message'])
        return result
        
    except Exception as e:
        error_message = f"Error in lambda execution: {str(e)}"
        logger.error(error_message)
        return {
            'statusCode': 500,
            'message': error_message
        }

def tag_amis(ec2, retention_days, formatted_delete_on):
    """Tag owned AMIs with retention information"""
    ami_count = 0
    try:
        images_response = ec2.describe_images(Owners=['self'])
        images = images_response.get('Images', [])
        
        for image in images:
            image_id = image['ImageId']
            try:
                ec2.create_tags(
                    Resources=[image_id],
                    Tags=[
                        {'Key': 'Retention', 'Value': f'{retention_days}days'},
                        {'Key': 'DeleteOn', 'Value': formatted_delete_on}
                    ]
                )
                logger.info(f'Tagged AMI: {image_id}')
                ami_count += 1
            except ClientError as e:
                logger.error(f'Failed to tag AMI {image_id}: {str(e)}')
                
    except ClientError as e:
        logger.error(f'Failed to describe AMIs: {str(e)}')
        raise
    
    return ami_count

def tag_snapshots(ec2, retention_days, formatted_delete_on):
    """Tag owned snapshots with retention information"""
    snapshot_count = 0
    try:
        snapshots_response = ec2.describe_snapshots(OwnerIds=['self'])
        snapshots = snapshots_response.get('Snapshots', [])
        
        for snap in snapshots:
            snapshot_id = snap['SnapshotId']
            try:
                ec2.create_tags(
                    Resources=[snapshot_id],
                    Tags=[
                        {'Key': 'Retention', 'Value': f'{retention_days}days'},
                        {'Key': 'DeleteOn', 'Value': formatted_delete_on}
                    ]
                )
                logger.info(f'Tagged Snapshot: {snapshot_id}')
                snapshot_count += 1
            except ClientError as e:
                logger.error(f'Failed to tag snapshot {snapshot_id}: {str(e)}')
                
    except ClientError as e:
        logger.error(f'Failed to describe snapshots: {str(e)}')
        raise
    
    return snapshot_count
