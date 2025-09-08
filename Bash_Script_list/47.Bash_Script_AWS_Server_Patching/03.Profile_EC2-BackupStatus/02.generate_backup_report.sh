#!/bin/bash

# -------- CONFIGURATION --------
CSV_FILE="ec2_instances.csv"            # CSV file with instance_id column
LOG_FILE="backup_status_log_$(date +%F_%T).log"
PROFILES_FILE="profiles.txt"            # Created by script 01; fallback to accounts.csv or default profile
ACCOUNTS_CSV="accounts.csv"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CSV_REPORT_FILE="backup_status_report_${TIMESTAMP}.csv"
LOOKBACK_HOURS=6

# -------- FUNCTIONS --------
log() {
  echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

# CSV helpers
csv_escape() {
  local s="${1//\"/\"\"}"
  echo "\"$s\""
}

write_csv_header() {
  echo "job_id,arn,account_id,name,status,created_at" > "$CSV_REPORT_FILE"
}

write_csv_row() {
  local job_id="$1" arn="$2" account_id="$3" name="$4" status="$5" created_at="$6"
  echo "$(csv_escape "$job_id"),$(csv_escape "$arn"),$(csv_escape "$account_id"),$(csv_escape "$name"),$(csv_escape "$status"),$(csv_escape "$created_at")" >> "$CSV_REPORT_FILE"
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

# Get EC2 instance "Name" tag (fallback to instance ID if missing)
get_instance_name() {
  local PROFILE="$1" REGION="$2" INSTANCE_ID="$3"
  local name
  name=$(aws ec2 describe-instances \
    --profile "$PROFILE" --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value | [0]' \
    --output text 2>/dev/null)
  if [[ -z "$name" || "$name" == "None" ]]; then
    echo "$INSTANCE_ID"
  else
    echo "$name"
  fi
}

# NEW: Resolve which profile/region owns the instance and return context as a pipe-delimited line
# Format: PROFILE|REGION|ACCOUNT_ID|NAME|RESOURCE_ARN
resolve_instance_owner() {
  local INSTANCE_ID="$1"
  for PROFILE in "${PROFILES[@]}"; do
    local REGION; REGION=$(get_region_for_profile "$PROFILE")
    # Check if instance exists in this profile/region
    local STATE
    STATE=$(aws ec2 describe-instances \
      --profile "$PROFILE" --region "$REGION" \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text 2>/dev/null)
    if [[ $? -eq 0 && "$STATE" != "None" ]]; then
      local NAME; NAME=$(get_instance_name "$PROFILE" "$REGION" "$INSTANCE_ID")
      local ACCOUNT_ID; ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text 2>/dev/null)
      local ARN=""; [[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]] && ARN="arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/${INSTANCE_ID}"
      echo "${PROFILE}|${REGION}|${ACCOUNT_ID}|${NAME}|${ARN}"
      return 0
    fi
  done
  return 1
}

# Compute the 6-hour lookback window in UTC ISO8601 (Z)
compute_time_window() {
  CREATED_BEFORE=$(date -u +%FT%TZ)
  if CREATED_AFTER=$(date -u -d "-${LOOKBACK_HOURS} hours" +%FT%TZ 2>/dev/null); then
    :
  else
    # Fallback using Python if BSD date is present
    CREATED_AFTER=$(python - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc)-timedelta(hours=int("$LOOKBACK_HOURS"))).strftime('%Y-%m-%dT%H:%M:%SZ'))
PY
)
  fi
}

# UPDATED: Emit ONLY ONE row per instance using the owning account; include account_id
query_backup_jobs_for_instance() {
  local INSTANCE_ID="$1"

  # Resolve owning profile/region/account for the instance
  local CTX
  if ! CTX=$(resolve_instance_owner "$INSTANCE_ID"); then
    local now_utc; now_utc=$(date -u +%FT%TZ)
    write_csv_row "" "" "" "$INSTANCE_ID" "NOT_FOUND" "$now_utc"
    return 0
  fi

  IFS='|' read -r OWNER_PROFILE OWNER_REGION OWNER_ACCOUNT OWNER_NAME OWNER_ARN <<< "$CTX"

  # Query jobs for the owner only, within time window
  mapfile -t JOB_LINES < <(aws backup list-backup-jobs \
    --profile "$OWNER_PROFILE" --region "$OWNER_REGION" \
    --by-resource-arn "$OWNER_ARN" \
    --created-after "$CREATED_AFTER" \
    --created-before "$CREATED_BEFORE" \
    --query 'BackupJobs[].[BackupJobId, RecoveryPointArn, ResourceArn, Status, CreationDate]' \
    --output text 2>/dev/null)

  if [[ ${#JOB_LINES[@]} -eq 0 ]]; then
    local now_utc; now_utc=$(date -u +%FT%TZ)
    write_csv_row "" "$OWNER_ARN" "$OWNER_ACCOUNT" "$OWNER_NAME" "NO_JOBS_LAST_${LOOKBACK_HOURS}H" "$now_utc"
    return 0
  fi

  # Build sortable list by creation time (ISO8601) and pick latest
  local -a JOBS=()
  for line in "${JOB_LINES[@]}"; do
    local job_id rpa rarn status created
    IFS=$'\t' read -r job_id rpa rarn status created <<< "$line"
    [[ -z "$job_id" || "$job_id" == "None" ]] && job_id=""
    [[ -z "$rpa" || "$rpa" == "None" ]] && rpa=""
    [[ -z "$rarn" || "$rarn" == "None" ]] && rarn=""
    local arn="$rpa"; [[ -z "$arn" ]] && arn="$rarn"
    JOBS+=("${created}\t${job_id}\t${arn}\t${status}")
  done

  local latest
  latest=$(printf '%s\n' "${JOBS[@]}" | sort -r | head -n1)
  local created job_id arn status
  IFS=$'\t' read -r created job_id arn status <<< "$latest"
  write_csv_row "$job_id" "$arn" "$OWNER_ACCOUNT" "$OWNER_NAME" "$status" "$created"
}

check_prerequisites() {
  if ! command -v aws &> /dev/null; then
    log "❌ AWS CLI not found. Please install AWS CLI"
    exit 1
  fi
  log "✅ Prerequisites check passed"
}

# -------- MAIN --------
if [[ ! -f $CSV_FILE ]]; then
  echo "CSV file '$CSV_FILE' not found. Please provide the file with a column 'instance_id'."
  exit 1
fi

log "==== EC2 Backup Status Report (last ${LOOKBACK_HOURS} hours) ===="

check_prerequisites
write_csv_header
compute_time_window
get_profiles
log "Profiles to use: ${PROFILES[*]}"

TOTAL_INSTANCES=0

# UPDATED: iterate instances once, resolve owner across profiles to avoid duplicates
INSTANCE_COUNT=0
while IFS=',' read -r INSTANCE_ID || [[ -n "$INSTANCE_ID" ]]; do
  INSTANCE_ID=$(echo "$INSTANCE_ID" | tr -d '\r\n' | xargs)
  # Skip header
  [[ "$INSTANCE_ID" == "instance_id" ]] && continue
  if [[ -n "$INSTANCE_ID" ]]; then
    ((INSTANCE_COUNT++))
    ((TOTAL_INSTANCES++))
    log "Checking backup jobs for instance $INSTANCE_ID (last ${LOOKBACK_HOURS}h)"
    query_backup_jobs_for_instance "$INSTANCE_ID"
  fi
done < "$CSV_FILE"

log "Processed $INSTANCE_COUNT instances from CSV"

log "==== Report Completed ===="
log "Total instances evaluated: $TOTAL_INSTANCES"
log "CSV report: $CSV_REPORT_FILE"
