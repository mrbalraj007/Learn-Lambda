# AWS CloudFormation template for AWS EC2 Inventory

## Following are the details:

✅ Creates an IAM role with permissions to:

- Describe EC2 instances

- List volumes

- Upload to a specific S3 bucket/folder

✅ Deploys a Lambda function to export EC2 inventory to the EC2_Inventory/ folder of the specified bucket

✅ Sets up a daily EventBridge rule to trigger the Lambda function

✅ CloudFormation Template (YAML)
Save this as ec2-inventory-export.yaml:

## 🔧 Deployment Steps

### 0. Here is the [Updated file]()

### 0. Create folder in S3 bucket
- Will create the following structure in S3 bucket.
- Bucket_name
    - bucket_name/**lambda-code**/
    - bucket_name/**EC2_Inventory**/
### 1. Prepare Lambda Package
- Package your Lambda function (e.g., lambda_function_payload.py) and zip it:
    ```bash
    zip ec2_inventory_export.zip lambda_function_payload.py
    ```
- Upload it to the S3 bucket you specify, under the path:
    ```bash
    s3://your-bucket-name/lambda-code/ec2_inventory_export.zip
    ```
### 2. Deploy CloudFormation Template
Use AWS CLI or Console:
```bash
aws cloudformation deploy \
  --template-file ec2-inventory-export.yaml \
  --stack-name EC2InventoryExporter \
  --parameter-overrides S3BucketName=your-bucket-name \
  --capabilities CAPABILITY_NAMED_IAM
  ```

