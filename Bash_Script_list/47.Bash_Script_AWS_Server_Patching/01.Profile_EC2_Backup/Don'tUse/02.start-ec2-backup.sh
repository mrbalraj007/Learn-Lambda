#!/bin/bash

# -------- CONFIGURATION --------
CSV_FILE="ec2_instances.csv"            # CSV file with instance_id column
# BACKUP_VAULT_NAME is now used as a fallback only; primary selection is dynamic (SSM*)
DEFAULT_BACKUP_VAULT_NAME="Default"
# IAM role is derived dynamically per-account (see start_backup)
RETENTION=7                             # Retention period in days
LOG_FILE="backup_log_$(date +%F_%T).log"
# REGION is resolved per-profile (see get_region_for_profile)
PROFILES_FILE="profiles.txt"            # Created by script 01; fallback to accounts.csv or default profile
ACCOUNTS_CSV="accounts.csv"

# -------- FUNCTIONS --------
log() {
  echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

# Resolve profiles to use:
# 1) profiles.txt (from script 01)
# 2) accounts.csv -> profile names "account<account_id>"
# 3) fallback to single "default"
get_profiles() {
  PROFILES=()
  if [[ -f "$PROFILES_FILE" ]]; then
    while IFS= read -r p || [[ -n "$p" ]]; do
      p=$(echo "$p" | tr -d '\r\n' | xargs)
      [[ -n "$p" ]] && PROFILES+=("$p")
    done < "$PROFILES_FILE"
  elif [[ -f "$ACCOUNTS_CSV" ]]; then
    while IFS=, read -r account_id permission_set || [[ -n "$account_id" ]]; do
      [[ "$account_id" == "account_id" ]] && continue
      account_id=$(echo "$account_id" | tr -d '\r\n' | xargs)
      [[ -n "$account_id" ]] && PROFILES+=("account${account_id}")
    done < "$ACCOUNTS_CSV"
  fi
  if [[ ${#PROFILES[@]} -eq 0 ]]; then
    PROFILES=("default")
  fi
}

# Get region for a profile. Prefer profile.<name>.region, then default region, then env, then ap-southeast-2.
get_region_for_profile() {
  local PROFILE="$1"
  local r=""
  r=$(aws configure get "profile.${PROFILE}.region" 2>/dev/null)
  [[ -z "$r" ]] && r=$(aws configure get region 2>/dev/null)
  [[ -z "$r" ]] && r="${AWS_DEFAULT_REGION}"
  [[ -z "$r" ]] && r="ap-southeast-2"
  echo "$r"
}

# Find backup vault for a profile/region:
# Prefer a vault whose name starts with "SSM", otherwise fallback to DEFAULT_BACKUP_VAULT_NAME.
resolve_backup_vault() {
  local PROFILE="$1"
  local REGION="$2"
  local vault_name=""
  # List vault names and pick the first that starts with "SSM"
  mapfile -t VAULTS < <(aws backup list-backup-vaults --profile "$PROFILE" --region "$REGION" \
    --query 'BackupVaultList[].BackupVaultName' --output text 2>/dev/null | tr '\t' '\n')
  if [[ ${#VAULTS[@]} -gt 0 ]]; then
    for v in "${VAULTS[@]}"; do
      if [[ "$v" == SSM* ]]; then
        vault_name="$v"
        break
      fi
    done
  fi
  # Fallback
  if [[ -z "$vault_name" ]]; then
    vault_name="$DEFAULT_BACKUP_VAULT_NAME"
  fi
  # Verify vault exists
  if ! aws backup describe-backup-vault --profile "$PROFILE" --region "$REGION" \
       --backup-vault-name "$vault_name" &>/dev/null; then
    echo ""  # signal not found
  else
    echo "$vault_name"
  fi
}

validate_instance() {
  local PROFILE="$1"
  local REGION="$2"
  local INSTANCE_ID="$3"
  # Check if instance exists and get its state
  INSTANCE_STATE=$(aws ec2 describe-instances \
    --profile "$PROFILE" --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null)
  
  if [[ $? -ne 0 ]] || [[ "$INSTANCE_STATE" == "None" ]]; then
    log "❌ [$PROFILE/$REGION] Instance $INSTANCE_ID not found or invalid"
    return 1
  fi
  
  log "ℹ️  [$PROFILE/$REGION] Instance $INSTANCE_ID is in state: $INSTANCE_STATE"
  return 0
}

start_backup() {
  local PROFILE="$1"
  local REGION="$2"
  local BACKUP_VAULT_NAME="$3"
  local INSTANCE_ID="$4"

  # Derive account ID and role per account
  local ACCOUNT_ID
  ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text 2>/dev/null)
  if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "None" ]]; then
    log "❌ [$PROFILE/$REGION] Unable to get account ID (STS). Is SSO/profile authenticated?"
    return 1
  fi
  local IAM_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/service-role/AWSBackupDefaultServiceRole"

  # Validate instance exists in this account/region
  if ! validate_instance "$PROFILE" "$REGION" "$INSTANCE_ID"; then
    return 1
  fi

  local BACKUP_NAME="EC2-Backup-${INSTANCE_ID}-$(date +%Y%m%d%H%M%S)"
  local RESOURCE_ARN="arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/${INSTANCE_ID}"

  log "Starting backup for instance: $INSTANCE_ID"
  log "Profile: $PROFILE | Account: $ACCOUNT_ID | Region: $REGION"
  log "Backup Vault: $BACKUP_VAULT_NAME"
  log "Resource ARN: $RESOURCE_ARN"

  # Start backup job with lifecycle management
  ERROR_OUTPUT=$(mktemp)
  BACKUP_JOB_ID=$(aws backup start-backup-job \
    --profile "$PROFILE" --region "$REGION" \
    --backup-vault-name "$BACKUP_VAULT_NAME" \
    --resource-arn "$RESOURCE_ARN" \
    --iam-role-arn "$IAM_ROLE_ARN" \
    --idempotency-token "$INSTANCE_ID-$(date +%s)" \
    --lifecycle DeleteAfterDays=$RETENTION \
    --recovery-point-tags "InstanceId=$INSTANCE_ID,BackupType=Automated,CreatedBy=BackupScript" \
    --query 'BackupJobId' --output text 2>"$ERROR_OUTPUT")

  BACKUP_EXIT_CODE=$?
  
  if [[ $BACKUP_EXIT_CODE -eq 0 ]] && [[ -n "$BACKUP_JOB_ID" ]] && [[ "$BACKUP_JOB_ID" != "None" ]]; then
    log "✅ [$PROFILE/$REGION] Backup job started successfully for $INSTANCE_ID"
    log "   Job ID: $BACKUP_JOB_ID"
    log "   Backup will include all attached EBS volumes"
    log "   Retention: $RETENTION days"
    rm -f "$ERROR_OUTPUT"
    return 0
  else
    log "❌ [$PROFILE/$REGION] Failed to start backup for $INSTANCE_ID"
    log "   Exit code: $BACKUP_EXIT_CODE"
    if [[ -s "$ERROR_OUTPUT" ]]; then
      log "   Error details: $(cat "$ERROR_OUTPUT")"
    fi
    log "   Check IAM role ($IAM_ROLE_ARN), permissions, and backup vault ($BACKUP_VAULT_NAME)"
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
  # Do not validate credentials or vault globally; handled per-profile dynamically
  log "✅ Prerequisites check passed"
}

# -------- MAIN --------
if [[ ! -f $CSV_FILE ]]; then
  echo "CSV file '$CSV_FILE' not found. Please provide the file with a column 'instance_id'."
  exit 1
fi

log "==== Starting EC2 Backup Process (multi-account) ===="

# Check prerequisites
check_prerequisites

# Resolve profiles
get_profiles
log "Profiles to use: ${PROFILES[*]}"

# Initialize global counters
TOTAL_INSTANCES=0
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0

# Create temporary files for tracking results
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/results.txt"

# For each profile, resolve region and vault, then process instances
for PROFILE in "${PROFILES[@]}"; do
  REGION=$(get_region_for_profile "$PROFILE")
  VAULT=$(resolve_backup_vault "$PROFILE" "$REGION")
  if [[ -z "$VAULT" ]]; then
    log "❌ [$PROFILE/$REGION] No usable backup vault found (no 'SSM*' and fallback '$DEFAULT_BACKUP_VAULT_NAME' missing). Skipping profile."
    continue
  fi

  log "---"
  log "Processing profile: $PROFILE (Region: $REGION, Vault: $VAULT)"
  log "Reading instances from CSV file..."

  INSTANCE_COUNT=0

  # Skip header and read instance IDs
  while IFS=',' read -r INSTANCE_ID || [[ -n "$INSTANCE_ID" ]]; do
    INSTANCE_ID=$(echo "$INSTANCE_ID" | tr -d '\r\n' | xargs)
    if [[ -n "$INSTANCE_ID" ]]; then
      ((INSTANCE_COUNT++))
      log "Processing instance $INSTANCE_COUNT: $INSTANCE_ID"
      ((TOTAL_INSTANCES++))
      if start_backup "$PROFILE" "$REGION" "$VAULT" "$INSTANCE_ID"; then
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

  log "[$PROFILE] Found $INSTANCE_COUNT instances in CSV file"
done

# Count results from file as backup
if [[ -f "$RESULTS_FILE" ]]; then
  FILE_SUCCESS=$(grep -c "SUCCESS" "$RESULTS_FILE" 2>/dev/null || echo 0)
  FILE_FAILED=$(grep -c "FAILED" "$RESULTS_FILE" 2>/dev/null || echo 0)
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
