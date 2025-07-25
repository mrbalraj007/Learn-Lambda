# AWS RDS Snapshot Cost Estimator

This bash script helps you estimate the monthly cost of your manual AWS RDS snapshots.

## Description

The script fetches all manual RDS snapshots in your AWS account, calculates their storage size, and provides an estimated monthly cost based on a fixed price per GB.

## Prerequisites

Before running this script, ensure you have the following installed and configured:

1. **AWS CLI** - Amazon Web Services Command Line Interface with properly configured credentials
2. **bc** - Basic calculator utility for floating-point arithmetic
   ```bash
   # Install bc on Ubuntu/Debian
   sudo apt install bc
   
   # Install bc on CentOS/RHEL
   sudo yum install bc
   
   # Install bc on macOS
   brew install bc
   ```
3. **bc** If you're using **MobaXterm**:
You can install bc using MobaXterm's built-in package manager:

👉 Steps:
Open MobaXterm

Click on the top menu: Tools → MobaXterm Package Manager (MobApt)

In the terminal, run:
```bash
MobApt install bc
```
3. **Proper AWS IAM permissions** to describe RDS snapshots

## Usage

1. Make the script executable:
   ```bash
   chmod +x estimate_rds_snapshot_cost.sh
   ```

2. Run the script:
   ```bash
   ./estimate_rds_snapshot_cost.sh
   ```

## Price Configuration

The script uses a default price of $0.095 per GB for RDS snapshot storage. You can modify this value by changing the `COST_PER_GB` variable at the beginning of the script:

```bash
COST_PER_GB=0.095  # Set this to the current AWS price for your region
```

**Note:** Actual AWS pricing may vary by region and can change over time. Please refer to the [AWS RDS Pricing documentation](https://aws.amazon.com/rds/pricing/) for the most current pricing information.

## Output Format

The script generates a table with the following columns:

| Column | Description |
|--------|-------------|
| SnapshotIdentifier | The identifier of the DB snapshot |
| DBInstanceIdentifier | The identifier of the source DB instance |
| Size(GB) | Storage size in gigabytes |
| Monthly($) | Estimated monthly cost in US dollars |

At the end of the table, the script provides:
- Total storage size used by all snapshots
- Total estimated monthly cost

## Example Output

```
Fetching all manual RDS snapshots...

SnapshotIdentifier                             DBInstanceIdentifier           Size(GB)   Monthly($)
db-snapshot-20240101                           mydb-prod                      100        9.50      
db-snapshot-20240115                           mydb-prod                      120        11.40     
db-snapshot-20240130                           mydb-test                      50         4.75      

--------------------------------------------------------------
Total Snapshot Storage: 270 GB
Estimated Monthly Snapshot Cost: $25.65
```

## Features

- ✅ Lists all manual RDS snapshots
- ✅ Calculates individual and total storage usage
- ✅ Estimates monthly cost based on configurable price per GB
- ✅ Formats output in an easy-to-read table

## Notes

1. The script only includes manual snapshots. Automated snapshots are not included.
2. The cost estimate is based on a fixed rate and does not account for:
   - Tiered pricing models
   - Reserved instance discounts
   - Regional price differences
   - Free tier benefits
3. The script uses the default AWS region configured in your AWS CLI. To use a different region, set the `AWS_REGION` environment variable or use the `--region` flag with the AWS CLI command.

## Required AWS Permissions

Your AWS user or role needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBSnapshots"
            ],
            "Resource": "*"
        }
    ]
}
```
