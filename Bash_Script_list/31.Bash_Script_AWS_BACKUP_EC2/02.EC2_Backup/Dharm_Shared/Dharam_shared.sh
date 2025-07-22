#!/bin/bash
ACCOUNTID=373160674113 # AWS Account ID
CSV_FILE="ec2_instances.csv" # Path to CSV file containing EC2 instance IDs
REGION=us-east-1 # AWS Region 
BACKUP_VAULT=EC2-Backup  # Backup vault name
ROLE=arn:aws:iam::$ACCOUNTID:role/service-role/AWSBackupDefaultServiceRole # IAM role used for backup
RETENTION=7 # Retention period in days
EC2_ARN=arn:aws:ec2:$REGION:$ACCOUNTID:instance

# Check if CSV file exists
if [[ ! -f "$CSV_FILE" ]]; then
    echo "Error: CSV file $CSV_FILE not found!"
    exit 1
fi

# Read EC2 instance IDs from CSV file (skip header)
tail -n +2 "$CSV_FILE" | while IFS=',' read -r instance_id || [[ -n "$instance_id" ]]; do
    # Skip empty lines
    if [[ -z "$instance_id" ]]; then
        continue
    fi
    
    # Trim whitespace
    instance_id=$(echo "$instance_id" | tr -d '[:space:]')
    
    # Skip if still empty after trimming or if it's a header
    if [[ -z "$instance_id" ]] || [[ "$instance_id" == "instance_id" ]]; then
        continue
    fi
    
    # Validate instance ID format (should start with i-)
    if [[ ! "$instance_id" =~ ^i-[0-9a-f]{8,17}$ ]]; then
        echo "Warning: Skipping invalid instance ID format: $instance_id"
        continue
    fi
    
    echo "Starting backup for instance: $instance_id"
    
    # Execute backup command and capture output
    backup_output=$(aws backup start-backup-job \
        --backup-vault-name "$BACKUP_VAULT" \
        --resource-arn "$EC2_ARN/$instance_id" \
        --iam-role-arn "$ROLE" \
        --lifecycle DeleteAfterDays=$RETENTION 2>&1)
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Backup initiated successfully for $instance_id"
        echo "$backup_output"
    else
        echo "✗ Failed to initiate backup for $instance_id"
        echo "Error: $backup_output"
    fi
    echo "---"
done