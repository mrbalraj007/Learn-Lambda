#!/bin/bash

# Check AWS CLI and jq
command -v aws >/dev/null 2>&1 || { echo >&2 "AWS CLI not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq not installed. Aborting."; exit 1; }

# Output CSV Header
echo "Snapshot Name,Engine Version,DB Instance or Cluster,Snapshot Creation Time,DB Instance Created Time,Status,Progress,VPC,Snapshot Type,Allocated Storage (GiB),Storage Type,AZ,Owner,Port,Encrypted,TimeZone,Engine,Snapshot DB Time"

# Fetch all manual and automated DB snapshots
snapshots=$(aws rds describe-db-snapshots --query 'DBSnapshots[*]' --output json)

# Loop through each snapshot
echo "$snapshots" | jq -c '.[]' | while read -r snapshot; do
    SnapshotName=$(echo "$snapshot" | jq -r '.DBSnapshotIdentifier')
    EngineVersion=$(echo "$snapshot" | jq -r '.EngineVersion')
    DBInstanceIdentifier=$(echo "$snapshot" | jq -r '.DBInstanceIdentifier')
    SnapshotCreateTime=$(echo "$snapshot" | jq -r '.SnapshotCreateTime')
    DBCreateTime=$(echo "$snapshot" | jq -r '.InstanceCreateTime // "N/A"')
    Status=$(echo "$snapshot" | jq -r '.Status')
    Progress=$(echo "$snapshot" | jq -r '.PercentProgress // "N/A"')
    VPCId=$(echo "$snapshot" | jq -r '.VpcId // "N/A"')
    SnapshotType=$(echo "$snapshot" | jq -r '.SnapshotType')
    AllocatedStorage=$(echo "$snapshot" | jq -r '.AllocatedStorage // "N/A"')
    StorageType=$(echo "$snapshot" | jq -r '.StorageType // "N/A"')
    AvailabilityZone=$(echo "$snapshot" | jq -r '.AvailabilityZone // "N/A"')
    MasterUsername=$(echo "$snapshot" | jq -r '.MasterUsername')
    Port=$(echo "$snapshot" | jq -r '.Port // "N/A"')
    Encrypted=$(echo "$snapshot" | jq -r '.Encrypted')
    TimeZone=$(echo "$snapshot" | jq -r '.TimeZone // "N/A"')
    Engine=$(echo "$snapshot" | jq -r '.Engine')
    SnapshotDBTime=$(echo "$snapshot" | jq -r '.SnapshotDatabaseTime // "N/A"')

    echo "\"$SnapshotName\",\"$EngineVersion\",\"$DBInstanceIdentifier\",\"$SnapshotCreateTime\",\"$DBCreateTime\",\"$Status\",\"$Progress\",\"$VPCId\",\"$SnapshotType\",\"$AllocatedStorage\",\"$StorageType\",\"$AvailabilityZone\",\"$MasterUsername\",\"$Port\",\"$Encrypted\",\"$TimeZone\",\"$Engine\",\"$SnapshotDBTime\""
done
