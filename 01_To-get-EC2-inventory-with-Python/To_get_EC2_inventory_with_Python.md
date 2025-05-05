# Different way to confiugre the AWS credentails.

Exposing credentials in code is risky, and there are more secure ways to manage AWS credentials without hardcoding them into your Python scripts. Here are a few recommended approaches:

## 1. Use AWS CLI Configuration (Recommended)<br>
    Boto3 can automatically pick up credentials stored in AWS CLI's configuration files. You just need to configure your credentials using the AWS CLI, and Boto3 will use them by default.

- Steps:
    - Install the AWS CLI (if not already installed):
        ```bash
        pip install awscli
        ```
    - Configure the AWS CLI with your credentials:
        ```bash
        aws configure
        ```
    - This will prompt you to enter:
        ```css
        AWS Access Key ID

        AWS Secret Access Key

        Default region name

        Default output format
        ```
    - Your credentials will be stored in `~/.aws/credentials` (on Linux/macOS) or `C:\Users\<YourUsername>\.aws\credentials` (on Windows).


Boto3 will automatically use the credentials stored in this file, so you can simply remove the aws_access_key_id and aws_secret_access_key from the Python script. The code will now use the credentials from your AWS CLI profile.

Example Code without Hardcoding Credentials:
```python
import boto3
import csv
```
### Initialize session without hardcoding credentials
```txt
session = boto3.Session(region_name='us-east-1')
```

## 2. Use Environment Variables
You can set AWS credentials as environment variables in your system. This method is useful if you want to avoid using the AWS CLI and don't want to store the credentials in your code or config files.

- Steps:
    - Set the following environment variables:
        ```powershell
        AWS_ACCESS_KEY_ID

        AWS_SECRET_ACCESS_KEY

        AWS_DEFAULT_REGION (optional)
        ```
    You can set them manually in your terminal or permanently in your system environment variables.

    - For Linux/macOS (in terminal):
        ```bash
        export AWS_ACCESS_KEY_ID="your-access-key-id"
        export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
        export AWS_DEFAULT_REGION="us-east-1"
        ```
    - For Windows (in Command Prompt or PowerShell):
        ```powershell
        set AWS_ACCESS_KEY_ID=your-access-key-id
        set AWS_SECRET_ACCESS_KEY=your-secret-access-key
        set AWS_DEFAULT_REGION=us-east-1
        ```
Boto3 will automatically pick up these environment variables when you initialize a session.

Example Code:
```python
import boto3
import csv
```
#### Initialize session, credentials are picked from environment variables
session = boto3.Session(region_name='us-east-1')

## 3. Use IAM Roles (For EC2, Lambda, and Other AWS Services)
If you are running your script from an EC2 instance or Lambda function, you can assign an IAM role to the instance or function with the necessary permissions. Boto3 will automatically use the credentials provided by the IAM role.

- Steps:
    - Create an IAM role with the necessary permissions (s3:PutObject in this case).
    - Attach the IAM role to your EC2 instance or Lambda function.
    - Boto3 will automatically use the role's temporary credentials for authentication.

## 4. Use AWS Secrets Manager or Parameter Store (For Secure Credential Management)
If you're working with sensitive credentials, it's a good idea to use AWS Secrets Manager or AWS Systems Manager Parameter Store to store the credentials securely.

- **Secrets Manager**: You can store credentials in Secrets Manager and retrieve them dynamically at runtime.

- **Parameter Store**: Similarly, you can store your AWS credentials in AWS SSM Parameter Store.

These services allow you to securely store and access credentials without exposing them in your script.

## Summary
- **AWS CLI Configuration**: Easiest and most common approach. Run aws configure and let Boto3 automatically use the stored credentials.

- **Environment Variables**: Set credentials as environment variables, which Boto3 will pick up automatically.

- **IAM Roles**: For EC2 and Lambda, IAM roles provide secure access to AWS resources without needing hardcoded credentials.

- **AWS Secrets Manager or Parameter Store**: For highly secure use cases, store credentials in these services and access them programmatically.

**Recommendation**:
The AWS CLI Configuration method is typically the best approach for most use cases. It keeps your credentials secure while simplifying the setup process.


__**Ref_Link**__

- [Download Pycharm](https://www.jetbrains.com/pycharm/)

- [YouTube Link](https://www.youtube.com/watch?v=wNFndcljcJQ)
- [YouTube Link](https://www.youtube.com/watch?v=YagM_FuPLQU)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

