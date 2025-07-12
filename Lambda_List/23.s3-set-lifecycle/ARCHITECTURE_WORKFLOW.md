# S3 Lifecycle Automation - Architecture & Workflow Documentation

## Overview
This AWS solution provides automated S3 lifecycle policy management with email notifications and a configurable waiting period. The architecture ensures proper governance and stakeholder notification before applying lifecycle policies across multiple S3 buckets.

## Architecture Components

### 1. **Amazon EventBridge (Scheduler)**
- **Purpose**: Triggers the automation process on a weekly schedule
- **Schedule**: Default `cron(0 18 ? * FRI *)` - Every Friday at 6 PM UTC (4 AM AEST Saturday)
- **Configuration**: Fully configurable via CloudFormation parameters

### 2. **AWS Lambda Functions**

#### a) S3 Lifecycle Scan Function
- **Runtime**: Python 3.12
- **Memory**: 512 MB
- **Timeout**: 15 minutes (900 seconds)
- **Responsibilities**:
  - Scans all S3 buckets in the account
  - Checks existing lifecycle policies
  - Identifies buckets requiring policy updates
  - Filters out excluded buckets (based on tags)
  - Initiates Step Functions state machine

#### b) S3 Lifecycle Process Function
- **Runtime**: Python 3.12
- **Memory**: 512 MB
- **Timeout**: 15 minutes (900 seconds)
- **Responsibilities**:
  - Sends notification emails with CSV attachments
  - Applies lifecycle policies after wait period
  - Sends completion notifications
  - Handles cross-account SES communication

### 3. **AWS Step Functions (State Machine)**
- **Purpose**: Orchestrates the workflow with timing controls
- **States**:
  - **SendNotification**: Initial notification to stakeholders
  - **WaitPeriod**: Configurable wait time (default 7 days)
  - **ApplyLifecyclePolicies**: Applies policies and sends completion email

### 4. **Amazon S3 Buckets**
- **Target**: All buckets in the AWS account
- **Exclusion**: Buckets tagged with `LifecycleExclude=true`
- **Lifecycle Policy Applied**:
  - Transition to IA: 90 days (configurable)
  - Object Expiration: 180 days (configurable)
  - Non-current Version Expiration: 180 days

### 5. **Amazon SES (Simple Email Service)**
- **Cross-Account Support**: Uses assumed roles for SES access
- **Email Types**:
  - HTML formatted notifications
  - CSV attachments with bucket details
  - Both initial and completion notifications

### 6. **AWS IAM Roles**

#### a) S3 Lifecycle Role (Lambda Execution)
- **Permissions**:
  - S3: ListAllMyBuckets, GetBucketTagging, GetLifecycleConfiguration, PutLifecycleConfiguration
  - Step Functions: StartExecution
  - STS: AssumeRole (for SES)
  - CloudWatch Logs: Basic execution logs

#### b) Step Functions Execution Role
- **Permissions**:
  - Lambda: InvokeFunction
  - CloudWatch Logs: Comprehensive logging permissions

### 7. **Amazon CloudWatch Logs**
- **Log Groups**:
  - `/aws/lambda/S3LifecycleScanFunction`
  - `/aws/lambda/S3LifecycleProcessFunction`
  - `/aws/stepfunctions/S3LifecycleStateMachine`
- **Retention**: 5 days for cost optimization

## Detailed Workflow

### Phase 1: Initialization & Discovery
1. **EventBridge Trigger**
   - Weekly cron schedule activates the automation
   - Invokes the S3 Lifecycle Scan Lambda function
   - Passes configured parameters (transition days, expiration days, etc.)

2. **S3 Bucket Analysis**
   - Lambda function lists all S3 buckets in the account
   - For each bucket:
     - Retrieves bucket tags
     - Checks for exclusion tag (`LifecycleExclude=true`)
     - Analyzes existing lifecycle policies
     - Determines if policy update is needed

3. **Filtering Logic**
   - Excluded buckets: Those with the exclusion tag
   - Already compliant: Buckets with matching lifecycle policies
   - Target buckets: Those requiring policy updates

### Phase 2: State Machine Initiation
4. **Step Functions Execution**
   - Lambda function starts the state machine with:
     - List of buckets to process
     - Configuration parameters
     - Timestamp for audit trail
   - State machine input includes wait period calculation

### Phase 3: Notification Phase
5. **Email Notification Generation**
   - Process Lambda function generates:
     - HTML formatted email with summary
     - CSV report with detailed bucket information
     - Account and timestamp details

6. **Cross-Account SES Communication**
   - Lambda assumes SES sending role in target account
   - Sends email to configured recipients
   - Includes CSV attachment with bucket details

7. **Email Content Structure**:
   ```
   Subject: S3 Lifecycle Policy Update Notification - [Account Name]
   
   Body:
   - Account information and timestamp
   - Action to be performed (transition/expiration days)
   - Wait period information
   - Instructions for exclusion (tagging)
   - Summary table of buckets affected
   - CSV attachment with detailed bucket information
   ```

### Phase 4: Wait Period
8. **Configurable Wait State**
   - Default: 168 hours (7 days)
   - Test mode: 60 seconds for rapid testing
   - Allows stakeholders time to:
     - Review the bucket list
     - Add exclusion tags if needed
     - Prepare for lifecycle policy changes

### Phase 5: Policy Application
9. **Lifecycle Policy Implementation**
   - After wait period, Lambda function:
     - Re-scans buckets (respects new exclusion tags)
     - Applies lifecycle policies to eligible buckets
     - Logs all actions for audit purposes

10. **Policy Configuration Applied**:
    ```json
    {
      "Rules": [{
        "ID": "TransitionAndExpireObjects",
        "Status": "Enabled",
        "Filter": {},
        "Transitions": [{
          "Days": 90,  // Configurable
          "StorageClass": "STANDARD_IA"
        }],
        "Expiration": {"Days": 180},  // Configurable
        "NoncurrentVersionExpiration": {"NoncurrentDays": 180}
      }]
    }
    ```

### Phase 6: Completion Notification
11. **Final Email Notification**
    - Summary of processed buckets
    - Count of successful vs failed applications
    - Failure details for troubleshooting
    - Audit trail information

## Configuration Parameters

### Lifecycle Settings
- **TransitionToIADays**: 30-3650 days (default: 90)
- **ExpirationDays**: 1-3650 days (default: 180)

### Scheduling
- **ScheduleExpression**: Cron format (default: weekly Friday)

### Email Configuration
- **SenderEmailAddress**: Verified SES email
- **RecipientEmailAddresses**: Comma-separated list
- **SESConfigurationSetName**: SES configuration set
- **SESSendingRoleArn**: Cross-account SES role
- **SESRegion**: SES service region

### Operational Settings
- **DryRun**: true/false (default: false)
- **TestMode**: true/false (default: false)
- **NotificationWaitPeriod**: 1-720 hours (default: 168)
- **TagKey/TagValue**: Exclusion tag configuration

## Security Features

### IAM Principle of Least Privilege
- Specific S3 permissions for bucket operations only
- Cross-account SES access via assumed roles
- No excessive permissions granted

### Audit Trail
- Comprehensive CloudWatch logging
- Step Functions execution history
- Email notifications for transparency

### Safety Mechanisms
- Dry-run mode for testing
- Tag-based exclusion system
- Configurable wait periods
- Re-scanning before policy application

## Monitoring & Troubleshooting

### CloudWatch Metrics
- Lambda function invocations
- Step Functions executions
- Error rates and duration

### Log Analysis
- Function execution logs in CloudWatch
- Step Functions state transitions
- Email delivery status

### Common Issues & Solutions
1. **SES Permission Errors**: Verify cross-account role trust
2. **S3 Access Denied**: Check IAM policies for bucket permissions
3. **Email Delivery Failures**: Validate SES configuration and verified addresses
4. **State Machine Timeouts**: Review wait period configuration

## Cost Optimization

### Resource Efficiency
- Log retention limited to 5 days
- Lambda functions sized appropriately
- Step Functions pay-per-use model
- Weekly scheduling reduces execution frequency

### Email Cost Management
- Single notification per cycle
- CSV attachments replace multiple emails
- Cross-account SES eliminates duplication

## Best Practices

### Implementation
1. Test in non-production environments first
2. Use dry-run mode for initial validation
3. Configure appropriate wait periods
4. Set up proper SES verification
5. Monitor CloudWatch logs during initial runs

### Operational
1. Regular review of excluded buckets
2. Monitor email delivery success
3. Audit lifecycle policy applications
4. Maintain up-to-date recipient lists
5. Review and adjust transition/expiration days based on usage patterns

## Testing Strategy

### Test Mode Features
- Reduced wait period (60 seconds)
- Dry-run capability
- Detailed logging for validation

### Validation Steps
1. Deploy in test environment
2. Enable test mode and dry-run
3. Verify email notifications
4. Check CSV report accuracy
5. Validate policy application logic
6. Test exclusion tag functionality

This architecture provides a robust, scalable, and secure solution for automated S3 lifecycle management with proper governance and stakeholder communication.
