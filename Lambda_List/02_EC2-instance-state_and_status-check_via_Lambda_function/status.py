import json
import boto3
from pprint import pprint

def lambda_handler(event, context):
    client = boto3.client('ec2')
    response = client.describe_instance_status(IncludeAllInstances=True)

    for instance in response["InstanceStatuses"]:
        print("AvailabilityZone:", instance["AvailabilityZone"])
        print("InstanceId:", instance["InstanceId"])
        print("Instance State:", instance["InstanceState"]["Name"])
        print("Instance Status:", instance["InstanceStatus"]["Status"])
        print("System Status:", instance["SystemStatus"]["Status"])
        print("\n")
 




    # TODO implement
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }


