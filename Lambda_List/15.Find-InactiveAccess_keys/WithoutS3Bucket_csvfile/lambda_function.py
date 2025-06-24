
import boto3
import json

def lambda_handler(event, context):
    region = event.get('region', 'us-east-1')  # Default to us-east-1 if not provided
    print(f"Checking inactive access keys in region: {region}")

    # IAM is a global service, but region is kept for logging and consistency
    iam_client = boto3.client('iam', region_name=region)
    inactive_keys_report = []

    try:
        # List all users
        users_response = iam_client.list_users()
        users = users_response['Users']

        for user in users:
            username = user['UserName']
            # List access keys for each user
            keys_response = iam_client.list_access_keys(UserName=username)
            for key in keys_response['AccessKeyMetadata']:
                if key['Status'] == 'Inactive':
                    inactive_keys_report.append({
                        'UserName': username,
                        'AccessKeyId': key['AccessKeyId'],
                        'CreateDate': key['CreateDate'].strftime('%Y-%m-%dT%H:%M:%S'),
                        'RegionChecked': region
                    })

        return {
            'statusCode': 200,
            'inactive_keys': inactive_keys_report
        }

    except Exception as e:
        print(f"Error occurred: {str(e)}")
        return {
            'statusCode': 500,
            'error': str(e)
        }
