# Idle Resource Detection Lambda

This project deploys a Lambda function that identifies idle AWS resources and generates a comprehensive Excel report.

## Deployment Instructions

### 1. Package the Lambda Function

First, create the Lambda deployment package with all required dependencies:

```bash
# Create a build directory
mkdir -p build

# Copy the main Lambda function code
cp lambda.py build/lambda.py

# Install dependencies into the build directory
pip install openpyxl -t build/

# Create zip file from the build directory
cd build
zip -r ../idle-resources-lambda.zip .
cd ..
```

### 2. Upload the Deployment Package to S3

Now upload the package to your S3 bucket:

```bash
# Create an S3 bucket if you don't have one
aws s3 mb s3://your-lambda-code-bucket --region your-region

# Upload the deployment package
aws s3 cp idle-resources-lambda.zip s3://your-lambda-code-bucket/lambda-packages/
```

### 3. Deploy the CloudFormation Stack

Deploy the CloudFormation stack, providing the bucket and key where you uploaded the package:

```bash
aws cloudformation create-stack \
  --stack-name idle-resource-detector \
  --template-body file://idle_resouce.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=LambdaCodeS3Bucket,ParameterValue=your-lambda-code-bucket \
    ParameterKey=LambdaCodeS3Key,ParameterValue=lambda-packages/idle-resources-lambda.zip \
    ParameterKey=OutputS3BucketName,ParameterValue="" \
    ParameterKey=UseExistingBucket,ParameterValue=false
```

### 4. Verify Deployment

Check the stack status:

```bash
aws cloudformation describe-stacks --stack-name idle-resource-detector
```

## Troubleshooting

### "NoSuchKey" Error During Deployment

If you encounter a "NoSuchKey" error, verify that:

1. The Lambda package exists at the specified location:
   ```bash
   aws s3 ls s3://your-lambda-code-bucket/lambda-packages/idle-resources-lambda.zip
   ```

2. You have the correct permissions to read the S3 object
3. The bucket exists in the same region as where you're deploying the CloudFormation stack
