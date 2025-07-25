# AWS RDS Snapshot Report Generator

This bash script generates a comprehensive CSV report of all Amazon RDS database snapshots in your AWS account.

## Description

The script fetches information about all manual and automated RDS database snapshots and outputs the data in CSV format. It provides detailed information about each snapshot including creation times, storage details, encryption status, and more.

## Prerequisites

Before running this script, ensure you have the following installed and configured:

1. **AWS CLI** - Amazon Web Services Command Line Interface
   ```bash
   # Install AWS CLI (if not already installed)
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **jq** - Command-line JSON processor
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install jq
   
   # On CentOS/RHEL
   sudo yum install jq
   
   # On macOS
   brew install jq
   ```

3. **AWS Credentials** - Configure your AWS credentials
   ```bash
   aws configure
   ```

## Usage

1. Make the script executable:
   ```bash
   chmod +x rds_snapshot_report.sh
   ```

2. Run the script:
   ```bash
   ./rds_snapshot_report.sh
   ```

3. Redirect output to a file:
   ```bash
   ./rds_snapshot_report.sh > rds_snapshots_report.csv
   ```

## Output Format

The script generates a CSV file with the following columns:

| Column | Description |
|--------|-------------|
| Snapshot Name | The identifier of the DB snapshot |
| Engine Version | The version of the database engine |
| DB Instance or Cluster | The DB instance identifier |
| Snapshot Creation Time | When the snapshot was created |
| DB Instance Created Time | When the original DB instance was created |
| Status | Current status of the snapshot |
| Progress | Percentage completion (for in-progress snapshots) |
| VPC | VPC ID where the snapshot resides |
| Snapshot Type | Type of snapshot (manual/automated) |
| Allocated Storage (GiB) | Storage allocated to the snapshot |
| Storage Type | Type of storage (gp2, gp3, io1, etc.) |
| AZ | Availability Zone |
| Owner | Master username |
| Port | Database port number |
| Encrypted | Whether the snapshot is encrypted |
| TimeZone | Database timezone |
| Engine | Database engine (MySQL, PostgreSQL, etc.) |
| Snapshot DB Time | Database time when snapshot was taken |

## Example Output

```csv
Snapshot Name,Engine Version,DB Instance or Cluster,Snapshot Creation Time,DB Instance Created Time,Status,Progress,VPC,Snapshot Type,Allocated Storage (GiB),Storage Type,AZ,Owner,Port,Encrypted,TimeZone,Engine,Snapshot DB Time
"mydb-snapshot-2024","8.0.35","mydb-instance","2024-01-15T10:30:00.000Z","2024-01-01T09:00:00.000Z","available","100","vpc-12345678","manual","20","gp2","us-east-1a","admin","3306","true","UTC","mysql","2024-01-15T10:29:45.000Z"
```

## Features

- ✅ Fetches all RDS snapshots (manual and automated)
- ✅ Comprehensive snapshot information
- ✅ CSV format for easy data analysis
- ✅ Error handling for missing dependencies
- ✅ Handles missing/null values gracefully
- ✅ Cross-platform compatibility

## Troubleshooting

### Common Issues

1. **AWS CLI not found**
   ```
   Error: AWS CLI not installed. Aborting.
   ```
   Solution: Install AWS CLI using the prerequisites section above.

2. **jq not found**
   ```
   Error: jq not installed. Aborting.
   ```
   Solution: Install jq using the prerequisites section above.

3. **AWS credentials not configured**
   ```
   Error: Unable to locate credentials
   ```
   Solution: Configure AWS credentials using `aws configure`.

4. **Permission denied**
   ```
   Error: An error occurred (AccessDenied) when calling the DescribeDBSnapshots operation
   ```
   Solution: Ensure your AWS user/role has the necessary RDS read permissions.

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

## Notes

- The script processes all snapshots across all regions configured in your AWS CLI
- Large numbers of snapshots may take some time to process
- The output includes both manual and automated snapshots
- Times are displayed in ISO 8601 format (UTC)
- Fields with no data are marked as "N/A"

## License

This script is provided as-is for educational and operational purposes.
