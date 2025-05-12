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
zip -r ../idle-resource-reporter.zip .
cd ..
```

### 2. Upload the Deployment Package to S3

Now upload the package to your S3 bucket:

```bash
# Create an S3 bucket if you don't have one
aws s3 mb s3://your-lambda-code-bucket --region your-region

# Upload the deployment package
aws s3 cp idle-resource-reporter.zip s3://your-lambda-code-bucket/lambda-packages/
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
    ParameterKey=LambdaCodeS3Key,ParameterValue=lambda-packages/idle-resource-reporter.zip \
    ParameterKey=OutputS3BucketName,ParameterValue="" \
    ParameterKey=UseExistingBucket,ParameterValue=false
```

### 4. Verify Deployment

Check the stack status:

```bash
aws cloudformation describe-stacks --stack-name idle-resource-detector
```
### 4. Create a layer in lambda
-  Go to Lambda function> additional Resources > Click on Layers > Create Layer.
-  Fill the following details for Layer.
   -  name: `lambda-pickup-layer`
   -  Description (Optional)
   -  upload a .zip file or upload a file from amazon S3.
   -  Compatible architectures - optional
      -  select `x86_64`
   -  Compatible runtimes - optional
      -  select `Python 3.12`


### 5. Attach layer to Lambda
   - Go to Lambda function and select the `code` tab
   - Go to layers and click on `add a layer`
   - Select `custom layers`
   - select the layer which you have created in `step 4`



## Troubleshooting

### "NoSuchKey" Error During Deployment

If you encounter a "NoSuchKey" error, verify that:

1. The Lambda package exists at the specified location:
   ```bash
   aws s3 ls s3://your-lambda-code-bucket/lambda-packages/idle-resource-reporter.zip
   ```

2. You have the correct permissions to read the S3 object
3. The bucket exists in the same region as where you're deploying the CloudFormation stack

### In correct bucket path.
   1.  I using the following path in  `LambdaCodeS3Key` 
   ```sh
   bucketname/lambda-packages/idle-resource-reporter.zip
   ```
   while it should as below. This parameter should contain only the path **within** the bucket, not including the bucket name itself. The bucket name is already specified in the `LambdaCodeS3Bucket` parameter.

   #### ✅ Correct format would be:
   ```
   lambda-packages/idle-resource-reporter.zip
   ```

### Ensure Lambda Code Is Packaged Correctly

Before deployment, make sure your Lambda code is properly packaged:

1. The package should include the `lambda.py` file and all dependencies (especially openpyxl)
2. Upload it to the S3 path: `s3://bucketname/lambda-packages/idle-resource-reporter.zip`
3. Verify the file exists using: `aws s3 ls s3://bucketname/lambda-packages/idle-resource-reporter.zip`

After fixing the S3 key format, your CloudFormation deployment should work correctly!
```

