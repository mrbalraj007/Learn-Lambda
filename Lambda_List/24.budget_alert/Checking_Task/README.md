# Bedrock Access Permission Set for AWS IAM Identity Center

This repository contains CloudFormation templates and instructions for creating a Permission Set in IAM Identity Center to grant access to AWS Bedrock services.

## Implementation Steps

### 1. Deploy CloudFormation Template

1. Submit a pull request with the `bedrock-access-permission-set.yaml` template to the awscfn repository
2. Once approved, deploy the template in the Global Express (master) account
3. This will create a Permission Set named "BedrockAccess" with the required permissions:
   - bedrock:InvokeModel
   - bedrock:Converse
   - bedrock:ListFoundationModels

### 2. Provision Permission Set to Deployment-Tools Account

After the Permission Set is created in the Global Express account:

1. Log in to the AWS Management Console in the Global Express account
2. Navigate to IAM Identity Center
3. Select the "BedrockAccess" Permission Set
4. Click "Assign users or groups"
5. Select the deployment-tools account as the target account
6. (The AD group assignment will be done after AD team creates the group)

### 3. Active Directory Integration (For AD Team)

AD Team needs to:

1. Create a new AD group named "AWS-Bedrock-Access-DevTools"
2. In IAM Identity Center:
   - Navigate to the "Groups" section
   - Click "Create group" and map it to the AD group
   - Assign the group to the BedrockAccess Permission Set in the deployment-tools account

### 4. User Assignment

Once the above steps are completed:
1. The provided list of users will be added to the AD group by the AD team
2. Users will then be able to access AWS Bedrock services in the deployment-tools account via SSO

## Verification

After implementation, users should:
1. Log in through the AWS SSO portal
2. Select the deployment-tools account
3. Select the BedrockAccess role
4. Verify they can access Bedrock services
