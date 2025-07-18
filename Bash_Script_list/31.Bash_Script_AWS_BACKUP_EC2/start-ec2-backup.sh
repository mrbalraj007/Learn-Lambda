#!/bin/bash

# -------- CONFIGURATION --------
CSV_FILE="ec2_instances.csv"            # CSV file with instance_id column
BACKUP_VAULT_NAME="EC2-Backup"          # Change to your vault name
IAM_ROLE_ARN="arn:aws:iam::373160674113:role/service-role/AWSBackupDefaultServiceRole"  # IAM role used for backup
LOG_FILE="backup_log_$(date +%F_%T).log"
REGION=$(aws configure get region)      # Get current AWS region

# -------- FUNCTIONS --------
log() {
  echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

validate_instance() {
  local INSTANCE_ID=$1
  
  # Check if instance exists and get its state
  INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null)
  
  if [[ $? -ne 0 ]] || [[ "$INSTANCE_STATE" == "None" ]]; then
    log "❌ Instance $INSTANCE_ID not found or invalid"
    return 1
  fi
  
  log "ℹ️  Instance $INSTANCE_ID is in state: $INSTANCE_STATE"
  return 0
}

start_backup() {
  local INSTANCE_ID=$1
  
  # Validate instance exists
  if ! validate_instance "$INSTANCE_ID"; then
    return 1
  fi
  
  local BACKUP_NAME="EC2-Backup-${INSTANCE_ID}-$(date +%Y%m%d%H%M%S)"
  local RESOURCE_ARN="arn:aws:ec2:${REGION}:$(aws sts get-caller-identity --query Account --output text):instance/$INSTANCE_ID"

  log "Starting backup for instance: $INSTANCE_ID"
  log "Resource ARN: $RESOURCE_ARN"

  # Start backup job without lifecycle management (EC2 doesn't support cold storage)
  ERROR_OUTPUT=$(mktemp)
  BACKUP_JOB_ID=$(aws backup start-backup-job \
    --backup-vault-name "$BACKUP_VAULT_NAME" \
    --resource-arn "$RESOURCE_ARN" \
    --iam-role-arn "$IAM_ROLE_ARN" \
    --idempotency-token "$INSTANCE_ID-$(date +%s)" \
    --recovery-point-tags "InstanceId=$INSTANCE_ID,BackupType=Automated,CreatedBy=BackupScript" \
    --query 'BackupJobId' --output text 2>"$ERROR_OUTPUT")

  BACKUP_EXIT_CODE=$?
  
  if [[ $BACKUP_EXIT_CODE -eq 0 ]] && [[ -n "$BACKUP_JOB_ID" ]] && [[ "$BACKUP_JOB_ID" != "None" ]]; then
    log "✅ Backup job started successfully for $INSTANCE_ID"
    log "   Job ID: $BACKUP_JOB_ID"
    log "   Backup will include all attached EBS volumes"
    log "   Retention: According to backup vault policy"
    rm -f "$ERROR_OUTPUT"
    return 0
  else
    log "❌ Failed to start backup for $INSTANCE_ID"
    log "   Exit code: $BACKUP_EXIT_CODE"
    if [[ -s "$ERROR_OUTPUT" ]]; then
      log "   Error details: $(cat "$ERROR_OUTPUT")"
    fi
    log "   Check IAM permissions and backup vault configuration"
    rm -f "$ERROR_OUTPUT"
    return 1
  fi
}

check_prerequisites() {
  # Check AWS CLI
  if ! command -v aws &> /dev/null; then
    log "❌ AWS CLI not found. Please install AWS CLI"
    exit 1
  fi
  
  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    log "❌ AWS credentials not configured or invalid"
    exit 1
  fi
  
  # Check if backup vault exists
  if ! aws backup describe-backup-vault --backup-vault-name "$BACKUP_VAULT_NAME" &> /dev/null; then
    log "❌ Backup vault '$BACKUP_VAULT_NAME' not found"
    exit 1
  fi
  
  log "✅ Prerequisites check passed"
}

# -------- MAIN --------
if [[ ! -f $CSV_FILE ]]; then
  echo "CSV file '$CSV_FILE' not found. Please provide the file with a column 'instance_id'."
  exit 1
fi

log "==== Starting EC2 Backup Process ===="
log "Backup Vault: $BACKUP_VAULT_NAME"
log "Region: $REGION"

# Check prerequisites
check_prerequisites

# Initialize counters
TOTAL_INSTANCES=0
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0

# Create temporary files for tracking results
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/results.txt"

# Skip the header and read instance IDs
log "Reading instances from CSV file..."
INSTANCE_COUNT=0

while IFS=',' read -r INSTANCE_ID || [[ -n "$INSTANCE_ID" ]]; do
  # Trim whitespace and remove carriage returns
  INSTANCE_ID=$(echo "$INSTANCE_ID" | tr -d '\r\n' | xargs)
  
  if [[ -n "$INSTANCE_ID" ]]; then
    ((INSTANCE_COUNT++))
    log "Processing instance $INSTANCE_COUNT: $INSTANCE_ID"
    ((TOTAL_INSTANCES++))
    
    if start_backup "$INSTANCE_ID"; then
      echo "SUCCESS" >> "$RESULTS_FILE"
      ((SUCCESSFUL_BACKUPS++))
    else
      echo "FAILED" >> "$RESULTS_FILE"
      ((FAILED_BACKUPS++))
    fi
    log "---"
  else
    log "⚠️ Skipping empty instance ID line"
  fi
done < <(tail -n +2 "$CSV_FILE")

log "Found $INSTANCE_COUNT instances in CSV file"

# Count results from file as backup
if [[ -f "$RESULTS_FILE" ]]; then
  FILE_SUCCESS=$(grep -c "SUCCESS" "$RESULTS_FILE" 2>/dev/null || echo 0)
  FILE_FAILED=$(grep -c "FAILED" "$RESULTS_FILE" 2>/dev/null || echo 0)
  
  # Use file counts if counters didn't work properly
  if [[ $SUCCESSFUL_BACKUPS -eq 0 ]] && [[ $FAILED_BACKUPS -eq 0 ]]; then
    SUCCESSFUL_BACKUPS=$FILE_SUCCESS
    FAILED_BACKUPS=$FILE_FAILED
  fi
fi

# Cleanup
rm -rf "$TEMP_DIR"

log "==== Backup Process Completed ===="
log "Total instances processed: $TOTAL_INSTANCES"
log "Successful backups: $SUCCESSFUL_BACKUPS"
log "Failed backups: $FAILED_BACKUPS"
log "Log file: $LOG_FILE"
