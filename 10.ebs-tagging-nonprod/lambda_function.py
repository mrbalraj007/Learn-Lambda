import boto3
import re

# Initialize AWS services
ec2 = boto3.resource('ec2')

# Function to get the EC2 instance ID to which the volume is attached
def get_ec2_instance_id(volume):
    attachments = volume.attachments
    if attachments:
        return attachments[0]['InstanceId']
    return None

# Function to get tags of an EC2 instance, considering only "EnterpriseAppID"
def get_ec2_tags(instance_id):
    instance = ec2.Instance(instance_id)
    tags = {}
    for tag in instance.tags or []:
        if tag['Key'] == 'EnterpriseAppID':
            tags['EnterpriseAppID'] = tag['Value']
    return tags

# Function to tag the volume with provided tags
def tag_volume(volume, tags):
    formatted_tags = [{'Key': key, 'Value': value} for key, value in tags.items() if not key.startswith('aws:')]
    volume.create_tags(Tags=formatted_tags)

def process_volume(volume):
    volume_id = volume.id
    print(f"\nProcessing volume: {volume_id}")

    # Get the current tags for the volume
    current_tags = {tag['Key']: tag['Value'] for tag in volume.tags or []}
    tags = {}

    # Check if the volume is attached to an EC2 instance
    instance_id = get_ec2_instance_id(volume)
    if instance_id:
        # Volume is attached to an instance
        instance_tags = get_ec2_tags(instance_id)
        enterprise_app_id = instance_tags.get('EnterpriseAppID', '').strip()[:5]  # Trim whitespace and limit to first 5 characters
        if not enterprise_app_id or not re.match(r'^A\d{4}$', enterprise_app_id, re.IGNORECASE):
            enterprise_app_id = 'EC2-EnterpriseAppID-missing'

        # Set "AttachedTo" tag
        tags['AttachedTo'] = instance_id
        # Set "EnterpriseAppID" tag
        tags['EnterpriseAppID'] = enterprise_app_id

    else:
        # Volume is detached
        # Retrieve the previously assigned EnterpriseAppID from volume tags
        previous_app_id = current_tags.get('EnterpriseAppID', 'A****')

        # Add the "Previously-" prefix only if it's not already present
        if not previous_app_id.startswith('Previously-'):
            tags['EnterpriseAppID'] = 'Previously-' + previous_app_id
        else:
            tags['EnterpriseAppID'] = previous_app_id
        
        tags['AttachedTo'] = 'N/A'

    # Prepare tags for comparison
    new_tags = {key: value for key, value in tags.items() if key in ['EnterpriseAppID', 'AttachedTo']}
    current_tags_filtered = {key: value for key, value in current_tags.items() if key in ['EnterpriseAppID', 'AttachedTo']}
    
    # Print current and new tags 
    print(f"Current tags: {current_tags_filtered}")
    print(f"New tags: {new_tags}")
    
    # Determine if the tags need to be updated
    if new_tags != current_tags_filtered:
        print(f"Tags for volume {volume_id} will be updated. New tags:")
        for key, value in new_tags.items():
            print(f"  {key}: {value}")
        
        # Apply the tags
        tag_volume(volume, tags)
        
        print(f"Tags for volume {volume_id} updated successfully.")
    else:
        print(f"No action required for volume {volume_id}. Current tags match desired tags.")

def main(event=None, context=None):
    try:
        print("Lambda function started")

        if event and 'source' in event and event['source'] == 'aws.events':
            # Process all EBS volumes for scheduled events
            print("Processing scheduled event...")
            volumes = ec2.volumes.all()
            for volume in volumes:
                process_volume(volume)
        
        elif event and 'detail' in event:
            event_name = event['detail'].get('eventName', '')
            if event_name in ['AttachVolume', 'DetachVolume']:
                print(f"Processing API event: {event_name}")
                volume_id = event.get('detail', {}).get('responseElements', {}).get('volumeId', '')
                if volume_id:
                    volume = ec2.Volume(volume_id)
                    process_volume(volume)
        
        else:
            print("Event is not recognized or is missing required details.")
        
    except Exception as e:
        print(f"Error handling event: {e}")

# Lambda function handler
def lambda_handler(event, context):
    return main(event, context)
