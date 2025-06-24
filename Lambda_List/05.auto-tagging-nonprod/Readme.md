# AWS Auto-Tagging Lambda Function Explanation
This Lambda function automatically tags AWS resources when they're created in a non-production environment. It specifically adds:

1. A CreatedBy tag with the username of who created the resource
2. An ExpiryDate tag for snapshots based on a configurable retention period

## How It Works
Event Triggering
CloudWatch Events monitors specific EC2 API calls:

- CreateVolume
- RunInstances
- CreateImage
- CreateSnapshot/CreateSnapshots
- CreateSecurityGroup

### Processing Flow
1. The Lambda receives the CloudTrail event from CloudWatch Events
2. It identifies the user who created the resource (handling both direct users and assumed roles)
3. Based on the event type, it extracts the relevant resource ID(s)
4. It checks if tags already exist to avoid duplicates
5. It applies the appropriate tags to the resources

### Key Components
- Decorator Pattern: The call_aws_api decorator provides error handling for AWS API calls
- User Identification: Handles both direct IAM users and assumed roles
- Environment Variables:
    - tag_name: Name of the tag (defaults to "CreatedBy")
    - retention_period_days: For snapshot expiration calculation (defaults to 30 days)
### Testing the Function
To test this solution:

1. Deploy the CloudFormation stack:
```sh
aws cloudformation deploy --template-file auto-tagging-nonprod.yaml --stack-name auto-tagging-nonprod --parameter-overrides Description="Auto Tagging Lambda" Handler="lambda.lambda_handler" LambdaS3Bucket="your-code-bucket" LambdaS3Key="auto-tagging-nonprod/lambda.zip" --capabilities CAPABILITY_NAMED_IAM
```
2. Create test resources:

    - Create an EC2 volume: aws ec2 create-volume --availability-zone us-east-1a --size 10
    - Create a snapshot: aws ec2 create-snapshot --volume-id vol-12345678
    - Launch an EC2 instance: aws ec2 run-instances --image-id ami-12345678 --instance-type t2.micro

3. Check CloudWatch Logs:

    - Navigate to CloudWatch Logs in the AWS Console
    - Look for the log group related to your Lambda function
    - Verify execution logs show successful tagging

4. Verify tags on resources:
```sh
aws ec2 describe-tags --filters "Name=resource-id,Values=vol-12345678"
aws ec2 describe-tags --filters "Name=resource-id,Values=snap-12345678"
```
5. Check snapshots for expiry dates:

```sh
aws ec2 describe-tags --filters "Name=key,Values=ExpiryDate" "Name=resource-id,Values=snap-12345678"
```
This solution helps maintain resource governance by tracking resource creators and setting expiration dates on snapshots, which can help with cost management in non-production environments.