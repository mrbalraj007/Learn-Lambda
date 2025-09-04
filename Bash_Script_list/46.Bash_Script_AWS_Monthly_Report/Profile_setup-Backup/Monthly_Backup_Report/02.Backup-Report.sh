#!/usr/bin/env bash
# ============================================================================
# Script Name : backup_august_report.sh
# Description : Collect AWS Backup jobs from August 1-30 across multiple
#               AWS accounts (via SSO profiles) for ap-southeast-2 region.
#               Generates detailed + summary CSV reports.
# Author      : AWS Engineer
# ============================================================================

set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_FILE="backup-august-report_${TIMESTAMP}.csv"
SUMMARY_FILE="backup-august-summary_${TIMESTAMP}.csv"
PROFILES_FILE="profiles.txt"
REGION="ap-southeast-2"

# Set fixed date range for Monthly 1-30
CURRENT_YEAR=$(date +"%Y")
START_TIME="${CURRENT_YEAR}-08-01T00:00:00Z"
END_TIME="${CURRENT_YEAR}-08-30T23:59:59Z"
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Helper: paginate list-backup-jobs, emit .BackupJobs as compact JSON arrays per page
fetch_jobs_arrays() {
  local profile="$1" region="$2"; shift 2
  local next_token=""
  while :; do
    local cmd=(aws backup list-backup-jobs --profile "$profile" --region "$region" --max-results 1000 "$@")
    [[ -n "$next_token" ]] && cmd+=(--next-token "$next_token")
    local page
    if ! page=$("${cmd[@]}" --output json 2>/dev/null); then
      echo "WARN: list-backup-jobs failed for profile '$profile' region '$region' args: $*" >&2
      break
    fi
    echo "$page" | jq -c '.BackupJobs'
    next_token=$(echo "$page" | jq -r '.NextToken // empty')
    [[ -z "$next_token" ]] && break
  done
}

# CSV headers (added ResourceName after ResourceArn)
echo '"ReportGeneratedUTC","AccountId","Profile","Region","BackupJobId","ResourceType","ResourceArn","ResourceName","BackupVaultName","State","CreationDate","CompletionDate","RecoveryPointArn","StatusMessage"' > "$OUTPUT_FILE"
echo '"ReportGeneratedUTC","AccountId","Profile","Region","TotalJobs","Completed","Failed","Running","Aborted","Expired","Other"' > "$SUMMARY_FILE"

while read -r PROFILE; do
  # Skip blanks/comments and trim whitespace
  PROFILE="${PROFILE%%#*}"
  PROFILE="$(echo "$PROFILE" | xargs)"
  PROFILE="${PROFILE//$'\r'/}"  # strip Windows CR so profiles like 'name\r' work
  [[ -z "$PROFILE" ]] && continue

  echo "Collecting backup jobs for profile: $PROFILE (August 1-30)"

  # Get account ID for profile (fail gracefully)
  if ! ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text 2>/dev/null); then
    echo "WARN: Unable to get caller identity for profile '$PROFILE'. Skipping." >&2
    continue
  fi

  # Gather all jobs created OR completed within Aug 1-30, paginate both, then union by BackupJobId
  ALL_JOBS_JSON=$(
    {
      fetch_jobs_arrays "$PROFILE" "$REGION" --by-created-after "$START_TIME" --by-created-before "$END_TIME"
      fetch_jobs_arrays "$PROFILE" "$REGION" --by-complete-after "$START_TIME" --by-complete-before "$END_TIME"
    } | jq -cs 'reduce .[]? as $a ([]; . + $a) | unique_by(.BackupJobId)' 2>/dev/null
  )
  ALL_JOBS_JSON=${ALL_JOBS_JSON:-'[]'}

  # Append detailed rows with ResourceName (derive from ARN if missing)
  echo "$ALL_JOBS_JSON" | jq -r --arg acct "$ACCOUNT_ID" --arg prof "$PROFILE" --arg reg "$REGION" --arg now "$NOW_UTC" '
    .[]? as $j
    | ($j.ResourceName // (($j.ResourceArn // "") | ([splits("[/:]")] | last))) as $rname
    | [
        $now,
        $acct,
        $prof,
        $reg,
        $j.BackupJobId,
        $j.ResourceType,
        $j.ResourceArn,
        $rname,
        $j.BackupVaultName,
        $j.State,
        $j.CreationDate,
        $j.CompletionDate,
        $j.RecoveryPointArn,
        ($j.StatusMessage // "")
      ]
    | @csv
  ' >> "$OUTPUT_FILE"

  # Summary counts with safe defaults (avoid unbound vars)
  counts=$(echo "$ALL_JOBS_JSON" | jq -r '
    . as $jobs
    | [
        ($jobs|length),
        ($jobs|map(select(.State=="COMPLETED"))|length),
        ($jobs|map(select(.State=="FAILED"))|length),
        ($jobs|map(select(.State=="RUNNING"))|length),
        ($jobs|map(select(.State=="ABORTED"))|length),
        ($jobs|map(select(.State=="EXPIRED"))|length)
      ] | @tsv
  ' 2>/dev/null || echo $'0\t0\t0\t0\t0\t0')
  IFS=$'\t' read -r TOTAL COMPLETED FAILED RUNNING ABORTED EXPIRED <<< "$counts"
  TOTAL=${TOTAL:-0}; COMPLETED=${COMPLETED:-0}; FAILED=${FAILED:-0}; RUNNING=${RUNNING:-0}; ABORTED=${ABORTED:-0}; EXPIRED=${EXPIRED:-0}

  OTHER=$(( TOTAL - COMPLETED - FAILED - RUNNING - ABORTED - EXPIRED ))
  echo "\"$NOW_UTC\",\"$ACCOUNT_ID\",\"$PROFILE\",\"$REGION\",\"$TOTAL\",\"$COMPLETED\",\"$FAILED\",\"$RUNNING\",\"$ABORTED\",\"$EXPIRED\",\"$OTHER\"" >> "$SUMMARY_FILE"

done < "$PROFILES_FILE"

echo "✅ Detailed report for August 1-30: $OUTPUT_FILE"
echo "✅ Summary report for August 1-30 : $SUMMARY_FILE"
