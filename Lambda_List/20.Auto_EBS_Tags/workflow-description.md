# EBS Auto-Tagging Workflow Description

## Architecture Overview

The EBS Auto-Tagging solution is a fully automated AWS serverless architecture that ensures EBS volumes maintain the same tags as their associated EC2 instances. The system runs every 5 minutes and provides comprehensive reporting.

## Detailed Workflow Steps

### 1. 🔥 **Scheduled Trigger** (EventBridge → Lambda)
- **EventBridge Rule** triggers every 5 minutes using cron expression `rate(5 minutes)`
- Rule is configured with the Lambda function as target
- EventBridge has permission to invoke the Lambda function
- **Color**: Orange/Red arrows indicate scheduled automation

### 2. 🔐 **IAM Role Assumption** (IAM → Lambda)
- Lambda function assumes the **EBSAutoTaggerRole**
- Role provides necessary permissions:
  - `ec2:DescribeInstances` - Read EC2 instance details
  - `ec2:DescribeVolumes` - Read EBS volume information
  - `ec2:DescribeTags` - Read existing tags
  - `ec2:CreateTags` - Apply new tags
  - CloudWatch Logs permissions for reporting
- **Color**: Blue arrows indicate security/permission flows

### 3. 🔍 **Instance Discovery** (Lambda → EC2)
- Lambda scans **ALL EC2 instances** in the region
- Filters instances by state: `running` and `stopped`
- Uses `describe_instances()` API call
- Processes each instance individually
- **Color**: Purple arrows indicate resource scanning operations

### 4. 🏷️ **Tag Reading** (Lambda → EC2)
- For each EC2 instance, read all associated tags
- Filter out AWS system tags (starting with `aws:`)
- Store filtered tags for comparison
- Skip instances with no user-defined tags
- **Color**: Purple arrows continue the scanning process

### 5. 💾 **Volume Discovery** (Lambda → EBS)
- For each EC2 instance, identify attached EBS volumes
- Parse `BlockDeviceMappings` to find EBS volumes
- Get volume IDs from the mapping
- **Color**: Gold dashed lines show physical attachments between EC2 and EBS

### 6. 🔍 **Current Tag Analysis** (Lambda → EBS)
- For each EBS volume, read existing tags using `describe_tags()`
- Compare instance tags with current volume tags
- Identify missing tags or tags with different values
- Create a list of tags that need to be applied
- **Color**: Green arrows indicate tag management operations

### 7. 🏷️ **Tag Application** (Lambda → EBS)
- Apply missing or updated tags to EBS volumes
- Use `create_tags()` API call with batch operations
- Update only volumes that need changes (efficiency)
- Handle errors gracefully with detailed error logging
- **Color**: Green arrows show successful tag operations

### 8. 📊 **Report Generation** (Lambda Internal)
- Generate comprehensive report for each execution:
  ```json
  {
    "timestamp": "2024-01-15T10:30:00.000Z",
    "total_instances_processed": 5,
    "total_volumes_tagged": 3,
    "errors": [],
    "details": [...]
  }
  ```
- Include instance-level and volume-level details
- Track success/failure status for each operation

### 9. 📊 **Logging to CloudWatch** (Lambda → CloudWatch Logs)
- Send detailed reports to CloudWatch Logs
- Log group: `/aws/lambda/ebs-auto-tagger`
- Retention period: 14 days (configurable)
- Include both summary and detailed information
- **Color**: Pink arrows indicate logging operations

### 10. 👤 **Human Monitoring** (Admin → CloudWatch)
- AWS Administrators can view execution reports
- Access logs through CloudWatch Console or CLI
- Monitor success rates and identify issues
- Set up CloudWatch Alarms for failures (optional)
- **Color**: Teal arrows show human interaction

## Error Handling and Resilience

### Instance-Level Error Handling
- If an instance fails to process, log error but continue with other instances
- Track failed instances in the report
- Don't let one failure stop the entire process

### Volume-Level Error Handling
- If a volume fails to tag, log specific error
- Continue processing other volumes for the same instance
- Provide detailed error information in reports

### API Rate Limiting
- Built-in AWS SDK retry logic
- Lambda timeout set to 5 minutes (300 seconds)
- Process instances sequentially to avoid rate limits

## Performance Characteristics

### Execution Time
- Typically 30-60 seconds for 50-100 instances
- Scales linearly with number of instances and volumes
- Average processing: ~1-2 instances per second

### Resource Usage
- Memory: 256 MB (configurable)
- CPU: Variable based on workload
- Cost: ~$0.20/month for typical usage

### Scalability Limits
- Lambda timeout: 15 minutes maximum
- Memory: Up to 10,240 MB if needed
- Concurrent executions: Default 1000 (regional limit)

## Security Best Practices

### Least Privilege IAM
- Role has minimal required permissions
- No wildcard permissions where possible
- Separate policy for EBS tagging operations

### Resource-Based Security
- Lambda function in private subnet (if VPC configured)
- CloudWatch Logs encrypted at rest
- Tags don't contain sensitive information

### Monitoring and Auditing
- All actions logged to CloudWatch
- AWS CloudTrail captures API calls
- Regular access review of IAM roles

## Customization Options

### Schedule Modification
```yaml
ScheduleExpression: 'rate(10 minutes)'  # Every 10 minutes
ScheduleExpression: 'cron(0 */2 * * ? *)'  # Every 2 hours
ScheduleExpression: 'cron(0 8 * * ? *)'   # Daily at 8 AM
```

### Tag Filtering
```python
# Skip certain tags
filtered_tags = {k: v for k, v in instance_tags.items() 
                if not k.startswith('aws:') and k not in ['DoNotCopy', 'Temporary']}

# Only copy specific tags
allowed_tags = ['Environment', 'Project', 'Owner', 'CostCenter']
filtered_tags = {k: v for k, v in instance_tags.items() if k in allowed_tags}
```

### Multi-Region Support
- Deploy same stack in multiple regions
- Each region processes its own resources
- Aggregate reports across regions if needed

## Troubleshooting Guide

### Common Issues
1. **No tags being applied**: Check IAM permissions
2. **Function timeout**: Increase timeout or reduce batch size
3. **High error rate**: Check EC2/EBS API limits
4. **Missing reports**: Verify CloudWatch Logs permissions

### Debug Steps
1. Check CloudWatch Logs for detailed error messages
2. Test Lambda function manually with empty payload
3. Verify IAM role has required permissions
4. Check EventBridge rule is enabled and correctly configured

## Cost Optimization

### Current Costs
- Lambda execution: $0.0000166667 per GB-second
- CloudWatch Logs: $0.50 per GB ingested
- EventBridge: $1.00 per million requests

### Optimization Strategies
- Reduce execution frequency if acceptable
- Implement smart filtering to skip unchanged resources
- Use CloudWatch Logs Insights for analysis instead of detailed logging
- Archive old logs to S3 for long-term retention

This architecture provides a robust, scalable, and cost-effective solution for automated EBS volume tagging with comprehensive monitoring and reporting capabilities.
