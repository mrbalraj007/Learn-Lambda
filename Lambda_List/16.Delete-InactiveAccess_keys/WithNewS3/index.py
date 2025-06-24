import boto3
import datetime
import os
import json

def handler(event, context):
    # Initialize AWS clients
    iam_client = boto3.client('iam')
    s3_client = boto3.client('s3')
    
    # Get region from Lambda context
    region = context.invoked_function_arn.split(':')[3]
    
    # Get S3 bucket name from environment variable
    bucket_name = os.environ['REPORT_BUCKET']
    
    # Current timestamp for report filenames
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    
    # Initialize lists to track inactive and deleted keys
    inactive_keys = []
    deleted_keys = []
    
    # Get all IAM users
    paginator = iam_client.get_paginator('list_users')
    for page in paginator.paginate():
        for user in page['Users']:
            username = user['UserName']
            
            # List access keys for the user
            keys_response = iam_client.list_access_keys(UserName=username)
            
            for key in keys_response['AccessKeyMetadata']:
                access_key_id = key['AccessKeyId']
                status = key['Status']
                create_date = key['CreateDate'].strftime('%Y-%m-%d')
                
                # If the key is inactive, add it to our list and delete it
                if status == 'Inactive':
                    # Get last used information
                    last_used_response = iam_client.get_access_key_last_used(AccessKeyId=access_key_id)
                    last_used = last_used_response.get('AccessKeyLastUsed', {})
                    last_used_date = last_used.get('LastUsedDate', 'Never')
                    if last_used_date != 'Never':
                        last_used_date = last_used_date.strftime('%Y-%m-%d')
                    
                    # Record the inactive key
                    key_info = {
                        'UserName': username,
                        'AccessKeyId': access_key_id,
                        'Status': status,
                        'CreateDate': create_date,
                        'LastUsed': last_used_date
                    }
                    inactive_keys.append(key_info)
                    
                    # Delete the inactive key
                    try:
                        iam_client.delete_access_key(
                            UserName=username,
                            AccessKeyId=access_key_id
                        )
                        
                        # Record the deletion with region information
                        deleted_key = key_info.copy()
                        deleted_key['Region'] = region
                        deleted_key['DeletionTime'] = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                        deleted_keys.append(deleted_key)
                        
                    except Exception as e:
                        print(f"Error deleting key {access_key_id} for user {username}: {str(e)}")
    
    # Create the inactive keys report
    if inactive_keys:
        inactive_keys_report = {
            'ReportDate': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'Region': region,
            'InactiveKeys': inactive_keys
        }
        
        inactive_keys_filename = f"inactive_keys_{timestamp}.json"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=inactive_keys_filename,
            Body=json.dumps(inactive_keys_report, indent=4),
            ContentType='application/json'
        )
        
        print(f"Inactive keys report uploaded to s3://{bucket_name}/{inactive_keys_filename}")
    else:
        print("No inactive keys found")
    
    # Create the deleted keys report
    if deleted_keys:
        deleted_keys_report = {
            'ReportDate': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'Region': region,
            'DeletedKeys': deleted_keys
        }
        
        deleted_keys_filename = f"deleted_keys_{timestamp}.json"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=deleted_keys_filename,
            Body=json.dumps(deleted_keys_report, indent=4),
            ContentType='application/json'
        )
        
        print(f"Deleted keys report uploaded to s3://{bucket_name}/{deleted_keys_filename}")
    else:
        print("No keys were deleted")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f"Processed {len(inactive_keys)} inactive keys, deleted {len(deleted_keys)} keys",
            'inactiveKeysCount': len(inactive_keys),
            'deletedKeysCount': len(deleted_keys)
        })
    }
