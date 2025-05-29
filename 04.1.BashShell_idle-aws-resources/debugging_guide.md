# Lambda Deployment Troubleshooting Guide

## Common Error: "Unable to import module 'lambda_function'"

This error occurs when Lambda can't find the Python module specified in your handler configuration.

### Solution Steps

1. **Verify the deployment package**:
   ```bash
   # Use the deployment script to create a proper package
   chmod +x deploy_lambda.sh
   ./deploy_lambda.sh
   ```

2. **Check the Lambda handler configuration**:
   - Go to AWS Lambda console
   - Select your function
   - In the "Runtime settings" section, verify that:
     - Runtime is set to "Python 3.9" (or your chosen version)
     - Handler is set to "lambda_function.lambda_handler"

3. **Verify environment variables**:
   Ensure these environment variables are set in your Lambda configuration:
   - `S3_BUCKET_NAME`: Your S3 bucket name
   - `S3_BUCKET_PREFIX`: Folder path in the bucket (default: reports/)
   - `SNS_TOPIC_ARN`: ARN of the SNS topic
   - `AWS_REGIONS`: Comma-separated list of regions to audit

4. **Permissions check**:
   - Ensure the Lambda execution role has:
     - Read access to AWS services
     - Write access to the S3 bucket
     - Publish permissions to the SNS topic

5. **CloudWatch Logs**:
   - Check CloudWatch Logs for detailed error information
   - Look for Python import errors or permission issues

## Manual Deployment Through Console

If the automated deployment isn't working, try this manual approach:

1. Create a ZIP file:
   ```bash
   cd lambda_deploy
   zip -r ../lambda_manual.zip .
   cd ..
   ```

2. Upload through the console:
   - Go to the Lambda function in the AWS console
   - Select "Upload from" > ".zip file"
   - Upload your ZIP file
   - Save the changes

## Testing the Lambda Function

After deployment, test the function with a simple test event:

```json
{
  "test": "event"
}
```

If the function executes successfully, you should see:
- A new report in your S3 bucket
- An email notification sent to your subscribed address
