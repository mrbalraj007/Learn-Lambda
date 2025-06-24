# Project Overview

This project sets up an AWS Lambda function that checks the status and state of EC2 instances using Terraform. The Lambda function is implemented in Python and is configured with the necessary IAM roles and permissions.

## Project Structure

```
terraform-aws-lambda-ec2-status
├── main.tf                # Main Terraform configuration file
├── iam.tf                 # IAM role definition for Lambda
├── lambda.tf              # Lambda function setup
├── variables.tf           # Input variables for Terraform
├── outputs.tf             # Outputs of the Terraform configuration
├── src
│   └── ec2_status_check
│       └── lambda_function.py  # Python code for the Lambda function
├── .gitignore             # Files to ignore in version control
└── README.md              # Project documentation
```

## Setup Instructions

1. **Prerequisites**
   - Ensure you have Terraform installed on your machine.
   - Configure your AWS credentials using the AWS CLI or environment variables.

2. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd terraform-aws-lambda-ec2-status
   ```

3. **Initialize Terraform**
   Run the following command to initialize the Terraform configuration:
   ```bash
   terraform init
   ```

4. **Plan the Deployment**
   To see what resources will be created, run:
   ```bash
   terraform plan
   ```

5. **Apply the Configuration**
   To create the resources defined in the Terraform files, run:
   ```bash
   terraform apply
   ```

6. **Usage**
   After deployment, the Lambda function `ec2_status_check` will be available in your AWS account. You can invoke this function to check the status and state of your EC2 instances.

## Additional Information

- The IAM role `ec2_status_state_check` grants the necessary permissions for the Lambda function to execute and access EC2 instance information.
- The Lambda function is implemented in Python 3.12 and is designed to run in an x86_64 architecture environment.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.