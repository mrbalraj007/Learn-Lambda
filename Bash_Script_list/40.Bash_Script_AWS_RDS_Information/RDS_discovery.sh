#!/bin/bash
# Script Name: rds_inventory_report.sh
# Description: Fetch RDS instance details and export to CSV
# Author: Your Name
# Date: 2025-08-15

# Ensure AWS CLI doesn't page output
export AWS_PAGER=""

# CSV writer that quotes and escapes fields
csv_write_row() {
  local out=""
  for i in "$@"; do
    local f="${i//\"/\"\"}"   # escape double quotes
    if [[ -n "$out" ]]; then out+=","; fi
    out+="\"$f\""
  done
  printf "%s\n" "$out" >> "$OUTPUT_FILE"
}

# Format memory: if numeric (MiB), convert to GiB with 1 decimal; else keep as-is
format_mem() {
  local m="$1"
  if [[ -z "$m" ]]; then
    echo ""
  elif [[ "$m" =~ ^[0-9]+$ ]]; then
    awk -v m="$m" 'BEGIN{printf "%.1f GiB", m/1024}'
  else
    echo "$m"
  fi
}

# Map RDS class to EC2 type (strip "db." prefix)
dbclass_to_ec2_type() {
  local cls="$1"
  echo "${cls#db.}"
}

# Fetch vCPU and Memory (MiB) from EC2 instance type
get_vcpu_mem_from_ec2() {
  local db_class="$1"
  local ec2_type
  ec2_type="$(dbclass_to_ec2_type "$db_class")"

  # Handle serverless or empty classes gracefully
  if [[ -z "$ec2_type" || "$ec2_type" == "serverless" || "$ec2_type" == aurora* ]]; then
    echo -e "\t"   # returns empty VCPU and MEM_RAW separated by a tab
    return 0
  fi

  aws ec2 describe-instance-types \
    --instance-types "$ec2_type" \
    --query 'InstanceTypes[0].[VCpuInfo.DefaultVCpus, MemoryInfo.SizeInMiB]' \
    --output text 2>/dev/null
}

# NEW: Resolve a human-readable alias for a KMS key ARN (e.g., aws/rds)
kms_alias_from_arn() {
  local arn="$1"
  [[ -z "$arn" || "$arn" == "None" ]] && { echo ""; return; }

  # If this is an alias ARN already (…:alias/alias-name), return the alias name without the 'alias/' prefix
  if [[ "$arn" == *":alias/"* ]]; then
    local alias_part="${arn##*/}"     # e.g., alias/aws/rds or aws/rds (depending on ARN format)
    echo "${alias_part#alias/}"        # normalize to aws/rds
    return
  fi

  # Otherwise, it's a key ARN; find its alias via KMS
  local key_id="${arn##*/}"
  local alias_name
  alias_name=$(aws kms list-aliases --query "Aliases[?TargetKeyId=='$key_id'].AliasName | [0]" --output text 2>/dev/null)
  if [[ -n "$alias_name" && "$alias_name" != "None" ]]; then
    echo "${alias_name#alias/}"
  else
    # Fallback to the key id when alias not found
    echo "$key_id"
  fi
}

# NEW: Determine account context for the CSV filename (alias preferred, else account ID)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
ACCOUNT_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null)
# Sanitize alias for filesystem
SAFE_ALIAS=""
if [[ -n "$ACCOUNT_ALIAS" && "$ACCOUNT_ALIAS" != "None" ]]; then
  SAFE_ALIAS=$(echo "$ACCOUNT_ALIAS" | tr -cd '[:alnum:]._-' )
fi

# Output CSV file (alias > account ID > default)
if [[ -n "$SAFE_ALIAS" ]]; then
  OUTPUT_FILE="rds_inventory_report_${SAFE_ALIAS}.csv"
elif [[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]]; then
  OUTPUT_FILE="rds_inventory_report_${ACCOUNT_ID}.csv"
else
  OUTPUT_FILE="rds_inventory_report.csv"
fi

# Write CSV header (quoted) - split storage into size and type, and add encryption column
csv_write_row "No" "AWS Instance Name" "AWS Shape" "vCPU" "Mem" "Storage (GB)" "Storage Type" "Encryption" "Hosted Oracle/MySQL DB" "Oracle DB Version" "Application Supported by Oracle DB"

# Get all RDS instances
INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output text)

COUNT=1
for INSTANCE in $INSTANCES; do
    # Get instance details incl. StorageEncrypted + KmsKeyId
    DETAILS=$(aws rds describe-db-instances --db-instance-identifier "$INSTANCE" \
        --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceClass,Engine,EngineVersion,AllocatedStorage,StorageType,StorageEncrypted,KmsKeyId]' \
        --output text)

    INSTANCE_NAME=$(printf "%s" "$DETAILS" | cut -f1)
    INSTANCE_CLASS=$(printf "%s" "$DETAILS" | cut -f2)
    ENGINE=$(printf "%s" "$DETAILS" | cut -f3)
    ENGINE_VERSION=$(printf "%s" "$DETAILS" | cut -f4)
    STORAGE_SIZE=$(printf "%s" "$DETAILS" | cut -f5)
    STORAGE_TYPE=$(printf "%s" "$DETAILS" | cut -f6)
    STORAGE_ENC=$(printf "%s" "$DETAILS" | cut -f7)
    KMS_KEY_ARN=$(printf "%s" "$DETAILS" | cut -f8)

    # vCPU and Memory via EC2 instance types
    EC2_INFO=$(get_vcpu_mem_from_ec2 "$INSTANCE_CLASS")
    VCPU=$(printf "%s" "$EC2_INFO" | cut -f1)
    MEM_RAW=$(printf "%s" "$EC2_INFO" | cut -f2)
    [[ "$VCPU" == "None" ]] && VCPU=""
    [[ "$MEM_RAW" == "None" ]] && MEM_RAW=""
    MEM=$(format_mem "$MEM_RAW")

    # Hosted DB Type
    if [[ "$ENGINE" == *"oracle"* ]]; then
        HOSTED_DB="Oracle Enterprise Edition"
    elif [[ "$ENGINE" == *"mysql"* ]]; then
        HOSTED_DB="MySQL DB"
    else
        HOSTED_DB="$ENGINE"
    fi

    # NEW: Encryption display
    ENC_ALIAS="$(kms_alias_from_arn "$KMS_KEY_ARN")"
    if [[ "$STORAGE_ENC" == "True" || "$STORAGE_ENC" == "true" ]]; then
        if [[ -n "$ENC_ALIAS" ]]; then
            ENC_DESC="Enabled (${ENC_ALIAS})"
        else
            ENC_DESC="Enabled"
        fi
    else
        ENC_DESC="Disabled"
    fi

    # Write CSV row (properly quoted; last column left blank for manual input)
    csv_write_row "$COUNT" "$INSTANCE_NAME" "$INSTANCE_CLASS" "$VCPU" "$MEM" "$STORAGE_SIZE" "$STORAGE_TYPE" "$ENC_DESC" "$HOSTED_DB" "$ENGINE_VERSION" ""

    ((COUNT++))
done

# Final message with account context
if [[ -n "$SAFE_ALIAS" ]]; then
  echo "RDS inventory report for account ${SAFE_ALIAS} (${ACCOUNT_ID}) saved to $OUTPUT_FILE"
elif [[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]]; then
  echo "RDS inventory report for account ${ACCOUNT_ID} saved to $OUTPUT_FILE"
else
  echo "RDS inventory report saved to $OUTPUT_FILE"
fi
