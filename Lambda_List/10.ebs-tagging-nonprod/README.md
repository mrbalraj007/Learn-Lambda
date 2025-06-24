# EBS Tagging Automation

This project implements an automated EBS volume tagging solution that runs on AWS Lambda. It ensures all EBS volumes are properly tagged with the `EnterpriseAppID` from their attached EC2 instances and tracks attachment history.

## Solution Overview

This solution automatically tags EBS volumes based on the following rules:

1. For **attached volumes**:
   - Sets `EnterpriseAppID` tag matching the EC2 instance's tag
   - Sets `AttachedTo` tag with the EC2 instance ID

2. For **detached volumes**:
   - Prefixes the existing `EnterpriseAppID` with "Previously-" (if not already prefixed)
   - Sets `AttachedTo` tag to "N/A"

## Architecture

![EBS Tagging Architecture](architecture-diagram-placeholder.jpg)

The solution consists of:
- **Lambda Function**: Applies tags to EBS volumes
- **EventBridge Rules**:
  - Scheduled rule: Runs daily at the specified time
  - Event-based rule: Triggers when volumes are attached/detached

## Lambda Function Explained

The Lambda function (`lambda_function.py`) is the core component that handles the tagging logic:

### Key Functions

#### `get_ec2_instance_id(volume)`
- Retrieves the instance ID to which a volume is attached
- Returns `None` for detached volumes

#### `get_ec2_tags(instance_id)`
- Retrieves the `EnterpriseAppID` tag from an EC2 instance

#### `process_volume(volume)`
- Core processing logic for each EBS volume
- Determines if the volume is attached or detached
- For attached volumes:
  - Fetches the `EnterpriseAppID` from the attached EC2 instance
  - Validates the format (should be A followed by 4 digits)
  - Truncates to 5 characters (e.g., "A1234")
  - If invalid or missing, uses "EC2-EnterpriseAppID-missing"
- For detached volumes:
  - Updates the tag to have "Previously-" prefix
- Updates tags only if they differ from current values

#### `main(event, context)`
- Entry point for the Lambda function
- Handles two trigger types:
  - Scheduled events: Processes all volumes
  - EventBridge events: Processes the specific volume being attached/detached

### Tagging Logic

1. **For attached volumes**:
   ```
   EnterpriseAppID = [EC2 instance's EnterpriseAppID]
   AttachedTo = [EC2 instance ID]
   ```

2. **For detached volumes**:
   ```
   EnterpriseAppID = "Previously-" + [Last known EnterpriseAppID]
   AttachedTo = "N/A"
   ```

## CloudFormation Template

The `ebs-tagging-nonprod.yaml` template provisions all necessary resources:

### Resources Created

1. **IAM Role (`EBSTaggingRole`)**:
   - Allows Lambda to interact with EC2, CloudWatch Logs, and S3
   - Permissions to describe volumes/instances and create tags

2. **Lambda Function (`EBSTaggingLambda`)**:
   - Executes the Python code for EBS tagging
   - 300 second timeout to handle large environments

3. **EventBridge Rules**:
   - **Daily Schedule Rule**: Runs at a specified time (cron expression parameter)
   - **Volume Attachment Rule**: Triggers on `AttachVolume` and `DetachVolume` API calls

4. **Lambda Permissions**:
   - Allows EventBridge rules to invoke the Lambda function

### Parameters

- `ResourcePrefix`: Prefix for naming resources
- `S3BucketName`: S3 bucket containing the Lambda code
- `S3Key`: Path to the Lambda code ZIP in the S3 bucket
- `CronExpression`: Schedule for the daily run (e.g., `cron(0 13 * * ? *)` for 1 PM UTC)

## Deployment

To deploy this solution:

1. Upload the Lambda code to an S3 bucket
2. Deploy the CloudFormation template
3. Provide the required parameters

## Benefits

- **Consistent tagging**: Ensures EBS volumes maintain proper tagging
- **Application tracking**: Links volumes to business applications via EnterpriseAppID
- **Historical context**: Maintains attachment history for detached volumes
- **Automation**: Eliminates manual tagging and human error
- **Compliance**: Supports tagging policies and cost allocation

## Monitoring

The Lambda function logs its actions to CloudWatch Logs:
- Volume IDs being processed
- Current and new tags
- Tag update actions
- Any errors encountered
