#!/bin/bash
ACCOUNTID=828585044836 # AWS Account ID
CSV_FILE="EBS.csv" # Path to CSV file containing EBS volume IDs
REGION=ap-southeast-2 # AWS Region us-east-1
BACKUP_VAULT=SSMPatching  # Backup vault name
ROLE=arn:aws:iam::$ACCOUNTID:role/service-role/AWSBackupDefaultServiceRole # IAM role used for backup

RETENTION=30 # Retention period in days
EBS_ARN=arn:aws:ec2:$REGION:$ACCOUNTID:volume

# Check if CSV file exists
if [[ ! -f "$CSV_FILE" ]]; then
    echo "Error: CSV file $CSV_FILE not found!"
    exit 1
fi

# Read EBS volume IDs from CSV file (skip header)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r volume_id || [[ -n "$volume_id" ]]; do
    # Skip empty lines
    if [[ -z "$volume_id" ]]; then
        continue
    fi
    
    # Trim whitespace
    volume_id=$(echo "$volume_id" | tr -d '[:space:]')
    
    # Skip if still empty after trimming or if it's a header
    if [[ -z "$volume_id" ]] || [[ "$volume_id" == "volume_id" ]]; then
        continue
    fi
    
    # Validate volume ID format (should start with vol-)
    if [[ ! "$volume_id" =~ ^vol-[0-9a-f]{8,17}$ ]]; then
        echo "Warning: Skipping invalid volume ID format: $volume_id"
        continue
    fi
    
    echo "Starting backup for EBS volume: $volume_id"
    
    # Execute backup command and capture output
    backup_output=$(aws backup start-backup-job \
        --backup-vault-name "$BACKUP_VAULT" \
        --resource-arn "$EBS_ARN/$volume_id" \
        --iam-role-arn "$ROLE" \
        --lifecycle DeleteAfterDays=$RETENTION 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Backup initiated successfully for volume $volume_id"
        echo "$backup_output"
    else
        echo "✗ Failed to initiate backup for volume $volume_id"
        echo "Error: $backup_output"
    fi
    echo "---"
done