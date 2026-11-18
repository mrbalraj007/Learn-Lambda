# Monitor all EC2 instances in an AWS account

You can monitor all EC2 instances in an AWS account and region using native CloudWatch metrics and AWS CLI, rather than checking each instance manually.

One important distinction: MetadataNoToken is published as a per-instance metric. You don't need to create a separate CloudWatch metric for every instance; you can discover all instances and retrieve their metrics programmatically.

For your environment, I recommend:
- All EC2 instances in the selected region.
- MetadataNoToken – actual IMDSv1 usage.
- ImdsV1Enabled – whether IMDSv1 is permitted.
- MetadataNoTokenRejected – rejected IMDSv1 attempts after enforcement.
- CloudWatch dashboard for central visibility.


### 1. Check metrics available across all EC2 instances
Run:
```sh
aws cloudwatch list-metrics \
  --profile development \
  --region ap-southeast-2 \
  --namespace AWS/EC2 \
  --metric-name MetadataNoToken \
  --output table
```

This lists instances publishing the metric.

#### Repeat for the other metrics:
```sh
aws cloudwatch list-metrics \
  --profile development \
  --region ap-southeast-2 \
  --namespace AWS/EC2 \
  --metric-name ImdsV1Enabled \
  --output table
```
```sh
aws cloudwatch list-metrics \
  --profile development \
  --region ap-southeast-2 \
  --namespace AWS/EC2 \
  --metric-name MetadataNoTokenRejected \
  --output table
```

> [!IMPORTANT]: 
AWS introduced ImdsV1Enabled on 5 November 2026. This is especially useful because it identifies instances that permit IMDSv1 even if they have made no IMDSv1 requests. 


### 2. Create a CloudWatch dashboard for all EC2 instances
This is what I recommend rather than manually selecting individual instance metrics.
```sh
The dashboard will show:

IMDSv1 – EC2 account monitoring

All
Instances allowing IMDSv1


Per instance
Actual IMDSv1 usage


Per instance
Rejected IMDSv1 requests


Live metrics
Migration visibility

Illustrative dashboard layout, not live account data.
```

#### Step A – Create the dashboard JSON
On your Linux administration machine, create a file:
```sh
nano imds-dashboard.json
```

Paste the following:

```powershell
{
  "widgets": [
    {
      "type": "metric",
      "width": 12,
      "height": 6,
      "properties": {
        "title": "EC2 Instances Allowing IMDSv1",
        "view": "timeSeries",
        "region": "ap-southeast-2",
        "period": 300,
        "stat": "Maximum",
        "metrics": [
          [
            {
              "expression": "SUM(SEARCH('{AWS/EC2,InstanceId} MetricName=\"ImdsV1Enabled\"', 'Maximum', 300))",
              "id": "e1",
              "label": "Instances allowing IMDSv1"
            }
          ]
        ]
      }
    },
    {
      "type": "metric",
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Actual IMDSv1 Usage Per EC2",
        "view": "timeSeries",
        "region": "ap-southeast-2",
        "period": 300,
        "metrics": [
          [
            {
              "expression": "SEARCH('{AWS/EC2,InstanceId} MetricName=\"MetadataNoToken\"', 'Sum', 300)",
              "id": "e2",
              "label": "IMDSv1 requests"
            }
          ]
        ]
      }
    },
    {
      "type": "metric",
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Rejected IMDSv1 Requests Per EC2",
        "view": "timeSeries",
        "region": "ap-southeast-2",
        "period": 300,
        "metrics": [
          [
            {
              "expression": "SEARCH('{AWS/EC2,InstanceId} MetricName=\"MetadataNoTokenRejected\"', 'Sum', 300)",
              "id": "e3",
              "label": "Rejected requests"
            }
          ]
        ]
      }
    }
  ]
}
```

#### Step B – Create the dashboard
Run:
```sh
aws cloudwatch put-dashboard \
  --profile development \
  --region ap-southeast-2 \
  --dashboard-name IMDSv1-EC2-Monitoring \
  --dashboard-body file://imds-dashboard.json
```
- Expected response:
```sh
{
  "DashboardValidationMessages": []
}
```

#### Step C – Open your dashboard
Open:
`IMDSv1 EC2 Monitoring Dashboard – Sydney` 

You now have a dashboard that uses CloudWatch metric search expressions to discover matching EC2 metrics automatically, instead of hardcoding instance IDs.

To use Melbourne, change every ap-southeast-2 reference in the JSON to ap-southeast-4 and create a separate regional dashboard.

### 3. Verify the dashboard using AWS CLI
Check that the dashboard exists:
```sh
aws cloudwatch get-dashboard \
  --profile development \
  --region ap-southeast-2 \
  --dashboard-name IMDSv1-EC2-Monitoring
```

Also verify the number of instances currently configured to permit IMDSv1 directly through EC2:
```sh
aws ec2 describe-instances \
  --profile development \
  --region ap-southeast-2 \
  --filters "Name=metadata-options.http-tokens,Values=optional" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table
```

This is a useful cross-check against the dashboard.

### 4. Important scope limitations
Monitoring scope	Covered?
All matching EC2 instances in Sydney account	Yes
Windows and Linux	Yes
Newly launched instances	Automatically, when metrics are published
Multiple AWS regions	Separate regional dashboard or cross-region design
All 12 AWS accounts	Not automatically with this command
Third-party agents	Not required

The dashboard uses native AWS-published metrics. It does not install anything on EC2 instances.

`One important distinction`: CloudWatch dashboards provide visibility, not automatic notifications. We can add CloudWatch alarms and SNS notifications as a separate step.

### 5. Recommended implementation for your environment
I would implement this in two stages:
1. Create the regional dashboards in your Development and Production accounts.
2. Once validated, extend monitoring to all 12 AWS accounts and both Sydney and Melbourne regions.