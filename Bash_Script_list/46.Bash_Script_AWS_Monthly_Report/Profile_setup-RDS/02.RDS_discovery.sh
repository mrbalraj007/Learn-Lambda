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

# NEW: Read profiles created by 01.generate_aws_config.sh
PROFILES_FILE="profiles.txt"
if [[ ! -f "$PROFILES_FILE" ]]; then
  echo "Error: '$PROFILES_FILE' not found. Run 01.generate_aws_config.sh first."
  exit 1
fi

mapfile -t PROFILE_LIST < <(grep -v '^\s*$' "$PROFILES_FILE")
if [[ ${#PROFILE_LIST[@]} -eq 0 ]]; then
  echo "Error: '$PROFILES_FILE' is empty. Run 01.generate_aws_config.sh and ensure profiles are present."
  exit 1
fi

echo "Found ${#PROFILE_LIST[@]} profiles:"
for p in "${PROFILE_LIST[@]}"; do echo " - $p"; done

# NEW: Create consolidated CSV with header (includes Account Name/ID)
CONSOLIDATED_FILE="rds_inventory_report_consolidated.csv"
: > "$CONSOLIDATED_FILE"
__prev_output_file="$OUTPUT_FILE"
OUTPUT_FILE="$CONSOLIDATED_FILE"
csv_write_row "Account Name" "Account ID" "No" "AWS Instance Name" "AWS Shape" "vCPU" "Mem" "Storage (GB)" "Storage Type" "Encryption" "Hosted Oracle/MySQL DB" "Oracle DB Version" "Application Supported by Oracle DB"
OUTPUT_FILE="$__prev_output_file"

# Iterate per profile and generate a CSV per account
for PROFILE in "${PROFILE_LIST[@]}"; do
  echo "Processing profile: $PROFILE"
  export AWS_PROFILE="$PROFILE"

  # Determine account context for filename
  ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
  ACCOUNT_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null)

  SAFE_ALIAS=""
  if [[ -n "$ACCOUNT_ALIAS" && "$ACCOUNT_ALIAS" != "None" ]]; then
    SAFE_ALIAS=$(echo "$ACCOUNT_ALIAS" | tr -cd '[:alnum:]._-' )
  fi
  # NEW: Friendly account name for consolidated CSV (prefer alias, else blank)
  ACCOUNT_NAME="$ACCOUNT_ALIAS"
  [[ "$ACCOUNT_NAME" == "None" ]] && ACCOUNT_NAME=""

  if [[ -n "$SAFE_ALIAS" ]]; then
    OUTPUT_FILE="rds_inventory_report_${SAFE_ALIAS}.csv"
  elif [[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]]; then
    OUTPUT_FILE="rds_inventory_report_${ACCOUNT_ID}.csv"
  else
    OUTPUT_FILE="rds_inventory_report_${PROFILE}.csv"
  fi

  # Write CSV header (quoted)
  : > "$OUTPUT_FILE"
  csv_write_row "No" "AWS Instance Name" "AWS Shape" "vCPU" "Mem" "Storage (GB)" "Storage Type" "Encryption" "Hosted Oracle/MySQL DB" "Oracle DB Version" "Application Supported by Oracle DB"

  # Get all RDS instances for this profile
  INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output text 2>/dev/null)

  COUNT=1
  for INSTANCE in $INSTANCES; do
      DETAILS=$(aws rds describe-db-instances --db-instance-identifier "$INSTANCE" \
          --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceClass,Engine,EngineVersion,AllocatedStorage,StorageType,StorageEncrypted,KmsKeyId]' \
          --output text 2>/dev/null)

      INSTANCE_NAME=$(printf "%s" "$DETAILS" | cut -f1)
      INSTANCE_CLASS=$(printf "%s" "$DETAILS" | cut -f2)
      ENGINE=$(printf "%s" "$DETAILS" | cut -f3)
      ENGINE_VERSION=$(printf "%s" "$DETAILS" | cut -f4)
      STORAGE_SIZE=$(printf "%s" "$DETAILS" | cut -f5)
      STORAGE_TYPE=$(printf "%s" "$DETAILS" | cut -f6)
      STORAGE_ENC=$(printf "%s" "$DETAILS" | cut -f7)
      KMS_KEY_ARN=$(printf "%s" "$DETAILS" | cut -f8)

      EC2_INFO=$(get_vcpu_mem_from_ec2 "$INSTANCE_CLASS")
      VCPU=$(printf "%s" "$EC2_INFO" | cut -f1)
      MEM_RAW=$(printf "%s" "$EC2_INFO" | cut -f2)
      [[ "$VCPU" == "None" ]] && VCPU=""
      [[ "$MEM_RAW" == "None" ]] && MEM_RAW=""
      MEM=$(format_mem "$MEM_RAW")

      if [[ "$ENGINE" == *"oracle"* ]]; then
          HOSTED_DB="Oracle Enterprise Edition"
      elif [[ "$ENGINE" == *"mysql"* ]]; then
          HOSTED_DB="MySQL DB"
      else
          HOSTED_DB="$ENGINE"
      fi

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

      # Write per-account file row
      csv_write_row "$COUNT" "$INSTANCE_NAME" "$INSTANCE_CLASS" "$VCPU" "$MEM" "$STORAGE_SIZE" "$STORAGE_TYPE" "$ENC_DESC" "$HOSTED_DB" "$ENGINE_VERSION" ""

      # NEW: Also append to consolidated file (prepend Account Name and Account ID)
      __prev_output_file="$OUTPUT_FILE"
      OUTPUT_FILE="$CONSOLIDATED_FILE"
      csv_write_row "$ACCOUNT_NAME" "$ACCOUNT_ID" "$COUNT" "$INSTANCE_NAME" "$INSTANCE_CLASS" "$VCPU" "$MEM" "$STORAGE_SIZE" "$STORAGE_TYPE" "$ENC_DESC" "$HOSTED_DB" "$ENGINE_VERSION" ""
      OUTPUT_FILE="$__prev_output_file"

      ((COUNT++))
  done

  if [[ -n "$SAFE_ALIAS" ]]; then
    echo "RDS inventory report for account ${SAFE_ALIAS} (${ACCOUNT_ID}) saved to $OUTPUT_FILE"
  elif [[ -n "$ACCOUNT_ID" && "$ACCOUNT_ID" != "None" ]]; then
    echo "RDS inventory report for account ${ACCOUNT_ID} saved to $OUTPUT_FILE"
  else
    echo "RDS inventory report saved to $OUTPUT_FILE"
  fi
done

# NEW: Final message for consolidated output
echo "Consolidated RDS inventory report saved to $CONSOLIDATED_FILE"

# Clear AWS_PROFILE after processing
unset AWS_PROFILE
