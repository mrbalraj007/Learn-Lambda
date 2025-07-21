#!/bin/bash

VAULT_NAME="SSMPatching"   #"EC2-Backup"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Compose output filename with Account ID and timestamp
OUTPUT_FILE="backup_jobs_${ACCOUNT_ID}_${TIMESTAMP}.csv"

# Write CSV header
echo "JobId,ResourceArn,ResourceName,Status,CreatedAt" > "$OUTPUT_FILE"

# Fetch and parse backup jobs
aws backup list-backup-jobs \
  --by-backup-vault-name "$VAULT_NAME" \
  --output json | jq -c '.BackupJobs[]' | while read -r job; do

  job_id=$(echo "$job" | jq -r '.BackupJobId')
  arn=$(echo "$job" | jq -r '.ResourceArn')
  status=$(echo "$job" | jq -r '.State')
  created_at=$(echo "$job" | jq -r '.CreationDate')

  # Extract EC2 instance ID from ARN
  if [[ "$arn" =~ instance/(i-[a-zA-Z0-9]+)$ ]]; then
    instance_id="${BASH_REMATCH[1]}"

    # Get EC2 Name tag
    name=$(aws ec2 describe-tags \
      --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name" \
      --query "Tags[0].Value" \
      --output text 2>/dev/null)

    [[ "$name" == "None" || -z "$name" ]] && name="N/A"
  else
    instance_id="N/A"
    name="Unknown"
  fi

  # Append row to CSV
  echo "$job_id,$arn,$name,$status,$created_at" >> "$OUTPUT_FILE"
done

echo "✅ Report saved as: $OUTPUT_FILE"
