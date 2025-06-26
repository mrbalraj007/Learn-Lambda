import boto3
import datetime
import os

def lambda_handler(event, context):
    # Get regions or use specific regions from environment variables
    regions = os.environ.get('REGIONS', '').split(',')
    if not regions or regions[0] == '':
        ec2_client = boto3.client('ec2')
        regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]
    
    # Store instances with issues
    instances_with_issues = []
    total_instances = 0
    
    for region in regions:
        print(f"Checking region: {region}")
        
        # Create EC2 client for this region
        ec2 = boto3.client('ec2', region_name=region)
        
        # Get all EC2 instances with status
        instance_statuses = ec2.describe_instance_status(IncludeAllInstances=True)
        
        # Get instance details
        instances_response = ec2.describe_instances()
        
        # Create a mapping of instance IDs to names
        instance_names = {}
        for reservation in instances_response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                instance_type = instance['InstanceType']
                instance_state = instance['State']['Name']
                
                # Get instance name from tags
                instance_name = 'No Name'
                if 'Tags' in instance:
                    for tag in instance['Tags']:
                        if tag['Key'] == 'Name':
                            instance_name = tag['Value']
                
                instance_names[instance_id] = {
                    'Name': instance_name,
                    'Type': instance_type,
                    'State': instance_state
                }
        
        # Process instance statuses
        for status in instance_statuses['InstanceStatuses']:
            instance_id = status['InstanceId']
            system_status = status['SystemStatus']['Status']
            instance_status = status['InstanceStatus']['Status']
            
            total_instances += 1
            
            # Check for issues
            if system_status != 'ok' or instance_status != 'ok':
                instance_info = instance_names.get(instance_id, {'Name': 'Unknown', 'Type': 'Unknown', 'State': 'Unknown'})
                instances_with_issues.append({
                    'InstanceId': instance_id,
                    'Name': instance_info['Name'],
                    'Type': instance_info['Type'],
                    'State': instance_info['State'],
                    'SystemStatus': system_status,
                    'InstanceStatus': instance_status,
                    'Region': region
                })
    
    # If there are instances with issues, send notification
    if instances_with_issues:
        send_notification(instances_with_issues, total_instances)
        
    print(f"EC2 status check completed. Total instances: {total_instances}, Issues: {len(instances_with_issues)}")
    return {
        'instancesChecked': total_instances,
        'instancesWithIssues': len(instances_with_issues)
    }

def send_notification(instances_with_issues, total_instances):
    sns = boto3.client('sns')
    topic_arn = os.environ['SNS_TOPIC_ARN']
    
    # Format message
    message = f"EC2 Status Check Alert - {len(instances_with_issues)} instance(s) with issues detected\n\n"
    message += f"Total instances checked: {total_instances}\n\n"
    message += "Instances with issues:\n"
    
    for instance in instances_with_issues:
        message += f"\nInstance ID: {instance['InstanceId']}\n"
        message += f"Name: {instance['Name']}\n"
        message += f"Type: {instance['Type']}\n"
        message += f"State: {instance['State']}\n"
        message += f"System Status: {instance['SystemStatus']}\n"
        message += f"Instance Status: {instance['InstanceStatus']}\n"
        message += f"Region: {instance['Region']}\n"
        
        # Determine health check ratio (3-part check)
        health_checks_passing = 0
        if instance['SystemStatus'] == 'ok':
            health_checks_passing += 1
        if instance['InstanceStatus'] == 'ok':
            health_checks_passing += 1
        if instance['State'] == 'running':
            health_checks_passing += 1
            
        message += f"Health Check Ratio: {health_checks_passing}/3\n"
    
    # Send SNS notification
    sns.publish(
        TopicArn=topic_arn,
        Subject="EC2 Instance Status Check Alert",
        Message=message
    )
