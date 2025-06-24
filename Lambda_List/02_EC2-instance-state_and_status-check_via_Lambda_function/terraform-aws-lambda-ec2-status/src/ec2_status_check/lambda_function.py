def lambda_handler(event, context):
    import boto3

    # Create an EC2 client
    ec2_client = boto3.client('ec2')

    # Describe EC2 instances
    response = ec2_client.describe_instances()

    # Initialize a list to hold instance statuses
    instance_statuses = []

    # Loop through the instances and get their statuses
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            instance_state = instance['State']['Name']
            instance_statuses.append({
                'InstanceId': instance_id,
                'State': instance_state
            })

    # Return the instance statuses
    return {
        'statusCode': 200,
        'body': instance_statuses
    }