# Detailed Deployment Steps for Bedrock Permission Set

## 1. CloudFormation Deployment (in Global Express Account)

```bash
# Log in to Global Express account via AWS CLI
aws cloudformation create-stack \
    --stack-name bedrock-access-permission-set \
    --template-body file://bedrock-access-permission-set.yaml \
    --capabilities CAPABILITY_NAMED_IAM
```

## 2. Provisioning to Deployment-Tools Account

After CloudFormation deployment completes:

1. In the IAM Identity Center console:
   - Go to AWS accounts
   - Select the deployment-tools account
   - Click "Assign users or groups"
   - Select "Groups" tab
   - Choose the "AWS-Bedrock-Access-DevTools" group (after AD team creates it)
   - Select the "BedrockAccess" Permission Set
   - Complete the assignment

## 3. AD Group Creation and Mapping (For AD Team)

1. Create the AD group:
   ```
   Group Name: AWS-Bedrock-Access-DevTools
   Description: Group for users requiring Bedrock access in the DevTools account
   ```

2. In AWS IAM Identity Center:
   - Go to Groups
   - Click "Create group"
   - Enter display name: "AWS-Bedrock-Access-DevTools"
   - Link to the AD group of the same name

3. Map users:
   - Add the provided users to the AD group
   - Users will automatically receive the appropriate permissions in AWS
```
