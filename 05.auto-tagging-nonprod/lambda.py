import os
import boto3
import logging
from datetime import datetime, timedelta

# Standard logging setup
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configure logging to output to console
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

# Function to get AWS client
def get_aws_client(service, region):
    return boto3.client(service, region_name=region)

# Mock decorator function to replace 'call_aws_api'
def call_aws_api(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            logger.error(f"Error calling AWS API: {str(e)}")
            return None
    return wrapper

@call_aws_api
def create_tags(ec2_conn, **kwargs):
    ec2_conn.create_tags(**kwargs)

@call_aws_api
def get_tags(ec2_conn, **kwargs):
    return ec2_conn.describe_tags(**kwargs)

def is_tag_present(ec2_conn, resource_id, region, tag_name, tag_value=None):
    ''' Check if a particular tag is present with a requested value '''
    tags = get_tags(ec2_conn, Filters=[{'Name': 'resource-id', 'Values': [resource_id]}])['Tags']
    is_present = {True for t in tags if t['Key'] == tag_name and (t['Value'] != "" or t['Value'] == tag_value)}
    return is_present

def is_expiry_date_tag_present(ec2_conn, resource_id, region):
    ''' Check if the ExpiryDate tag is present '''
    return is_tag_present(ec2_conn, resource_id, region, 'ExpiryDate')

def lambda_handler(event, context):
    ids = []
    tag_name = os.environ.get('tag_name')
    tag_value = os.environ.get('tag_value', None)
    retention_period_days = int(os.environ.get('retention_period_days', 30))  # Default to 30 days if not set

    if not tag_name:
        logger.warning('"tag_name" environment variable is not defined')
        return False

    region = event['region']
    detail = event['detail']
    eventname = detail['eventName']
    arn = detail['userIdentity']['arn']  # ARN of the entity that triggered the event
    principal = detail['userIdentity']['principalId']
    userType = detail['userIdentity']['type']

    logger.info(f"Event details: ARN={arn}, PrincipalId={principal}, UserType={userType}")

    # Use STS to get the actual identity of the user if possible
    sts_client = boto3.client('sts')
    user = None

    if userType == 'AssumedRole':
        logger.info(f"Assumed Role ARN: {arn}")
        user = arn.split('/')[-1]
        logger.info(f"Captured Assumed Role User: {user}")
    else:
        try:
            caller_identity = sts_client.get_caller_identity()
            user_arn = caller_identity['Arn']
            user = user_arn.split('/')[-1]  # Extract IAM user's name from ARN
            logger.info(f"Captured IAM User: {user}")
        except Exception as e:
            logger.error(f"Error retrieving caller identity: {str(e)}")
            return False

    if not user:
        logger.error("User information could not be found in the event")
        return False

    logger.info(f"Captured User: {user}")

    if not detail.get('responseElements'):
        logger.warning('No responseElements found in event')
        if detail.get('errorCode'):
            logger.error(f'ErrorCode: {detail["errorCode"]}')
        if detail.get('errorMessage'):
            logger.error(f'ErrorMessage: {detail["errorMessage"]}')
        return False

    ec2 = boto3.resource('ec2')
    ec2_client = get_aws_client('ec2', region)

    # Depending on event type, extract the resource ID
    if eventname == 'CreateVolume':
        resource_id = detail['responseElements']['volumeId']
        logger.info(f"Checking volume ID {resource_id} for tags")
        if not is_tag_present(ec2_client, resource_id, region, tag_name, tag_value):
            ids.append(resource_id)

    elif eventname == 'RunInstances':
        items = detail['responseElements']['instancesSet']['items']
        for item in items:
            resource_id = item['instanceId']
            logger.info(f"Checking instance ID {resource_id} for tags")
            if not is_tag_present(ec2_client, resource_id, region, tag_name, tag_value):
                ids.append(resource_id)

    elif eventname == 'CreateImage':
        resource_id = detail['responseElements']['imageId']
        logger.info(f"Checking image ID {resource_id} for tags")
        if not is_tag_present(ec2_client, resource_id, region, tag_name, tag_value):
            ids.append(resource_id)

    elif eventname == 'CreateSnapshot':
        resource_id = detail['responseElements']['snapshotId']
        logger.info(f"Checking snapshot ID {resource_id} for tags")

        # Check if the ExpiryDate tag is already applied
        if not is_expiry_date_tag_present(ec2_client, resource_id, region):
            # Calculate expiry date based on retention period
            expiry_date = datetime.now() + timedelta(days=retention_period_days)
            expiry_date_str = expiry_date.strftime('%Y-%m-%d')  # Format expiry date

            # Add the ExpiryDate tag
            try:
                create_tags(ec2, Resources=[resource_id], Tags=[{'Key': 'ExpiryDate', 'Value': expiry_date_str}])
                logger.info(f"Successfully tagged snapshot {resource_id} with ExpiryDate: {expiry_date_str}")
            except Exception as e:
                logger.error(f"Error applying ExpiryDate tag to snapshot {resource_id}: {str(e)}")
        else:
            logger.info(f"Snapshot {resource_id} already has an ExpiryDate tag. Skipping tag application.")
        ids.append(resource_id)
    
    elif eventname == 'CreateSnapshots':
        resource_id = detail['responseElements']['CreateSnapshotsResponse']['snapshotSet']['item']['snapshotId']
        logger.info(f"Checking snapshot ID {resource_id} for tags")

        # Check if the ExpiryDate tag is already applied
        if not is_expiry_date_tag_present(ec2_client, resource_id, region):
            # Calculate expiry date based on retention period
            expiry_date = datetime.now() + timedelta(days=retention_period_days)
            expiry_date_str = expiry_date.strftime('%Y-%m-%d')  # Format expiry date

            # Add the ExpiryDate tag
            try:
                create_tags(ec2, Resources=[resource_id], Tags=[{'Key': 'ExpiryDate', 'Value': expiry_date_str}])
                logger.info(f"Successfully tagged snapshot {resource_id} with ExpiryDate: {expiry_date_str}")
            except Exception as e:
                logger.error(f"Error applying ExpiryDate tag to snapshot {resource_id}: {str(e)}")
        else:
            logger.info(f"Snapshot {resource_id} already has an ExpiryDate tag. Skipping tag application.")
        ids.append(resource_id)
   
    elif eventname == 'CreateSecurityGroup':
        resource_id = detail['responseElements']['groupId']
        logger.info(f"Checking security group ID {resource_id} for tags")
        if not is_tag_present(ec2_client, resource_id, region, tag_name, tag_value):
            ids.append(resource_id)

    else:
        logger.warning(f'Unsupported eventName "{eventname}"')

    # Apply tags with 'CreatedBy' as the key and the IAM user's name as the value
    if ids:
        logger.info(f"List of resources to be tagged: {ids}")
        try:
            create_tags(ec2, Resources=ids, Tags=[{'Key': 'CreatedBy', 'Value': user}])  # Tagging with the actual user
            logger.info(f"Successfully tagged resources: {ids}")
        except Exception as e:
            logger.error(f"Error applying tags: {str(e)}")

    else:
        logger.warning("No resources found to apply tags to.")

    logger.info(f'Remaining time (ms): {context.get_remaining_time_in_millis()}')
    return True
