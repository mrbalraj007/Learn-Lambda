#!/bin/bash
# =====================================================================
# Script Name: get_all_accounts_ec2.sh
# Description: Collects EC2 inventory from all AWS profiles and exports
#              into a consolidated CSV file.
# Author     : AWS Engineer
# =====================================================================

set -euo pipefail

# Require jq
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ Error: 'jq' is required but not installed. Please install jq and retry."
  exit 1
fi

# Improve resiliency against throttling/timeouts
export AWS_RETRY_MODE=adaptive
export AWS_MAX_ATTEMPTS=10
AWS_CLI_FLAGS="--cli-read-timeout 120 --cli-connect-timeout 10"

# Fixed region configuration (override by exporting TARGET_REGIONS="ap-southeast-2 us-east-1", etc.)
DEFAULT_REGION="ap-southeast-2"
TARGET_REGIONS="${TARGET_REGIONS:-$DEFAULT_REGION}"
echo "🌏 Regions to scan: $TARGET_REGIONS"

# Input and output files
CSV_FILE="accounts.csv"
OUTPUT_FILE="ec2_inventory.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ Error: The CSV file '$CSV_FILE' does not exist."
    exit 1
fi

# Build profile list from accounts.csv
declare -a PROFILES
while IFS=, read -r account_id permission_set || [ -n "$account_id" ]; do
    # Strip UTF-8 BOM and CRs, then trim
    account_id=$(printf '%s' "$account_id" | sed $'s/^\xEF\xBB\xBF//' | tr -d '\r' | xargs)
    # Skip header line
    if [ "$account_id" = "account_id" ]; then
        continue
    fi
    
    # Trim whitespace and remove carriage returns
    account_id=$(echo "$account_id" | tr -d '\r' | xargs)
    
    # Skip empty lines
    if [ -z "$account_id" ]; then
        continue
    fi
    
    profile_name="account${account_id}"
    PROFILES+=("$profile_name")
done < "$CSV_FILE"

# Verify profiles were found
if [ ${#PROFILES[@]} -eq 0 ]; then
    echo "❌ Error: No profiles found in $CSV_FILE"
    exit 1
fi

echo "🔍 Found ${#PROFILES[@]} profiles to scan:"
for profile in "${PROFILES[@]}"; do
    echo "  - $profile"
done

# Write base CSV header - Added OS details columns
BASE_HEADER="AccountID,AccountName,InstanceID,Name,State,PrivateIP,PublicIP,InstanceType,VPC,Subnet,AZ,Platform,PlatformDetails,ImageId,OSName,OSVersion"

# Write header to output file
echo "${BASE_HEADER}" > "$OUTPUT_FILE"

# Helper: safe instance fetch -> always returns a JSON array ([] on error)
get_instances_json() {
  local profile="$1" region="$2"
  local raw
  if ! raw=$(aws ec2 describe-instances --profile "$profile" --region "$region" $AWS_CLI_FLAGS --output json 2>/dev/null); then
    echo "[]"
    return 0
  fi
  jq -c '[.Reservations // [] | .[]? | .Instances // [] | .[]?]' <<<"$raw" 2>/dev/null || echo "[]"
}

# Get instance details across selected regions only
for profile in "${PROFILES[@]}"; do
  echo ">>> Fetching EC2s for profile: $profile"

  # Validate or auto-login SSO once, then retry
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    sso_name=$(aws configure get sso_session --profile "$profile" 2>/dev/null || true)
    if [ -n "$sso_name" ]; then
      echo "  Attempting SSO login for $profile (session: $sso_name)..."
      aws sso login --profile "$profile" >/dev/null 2>&1 || true
    fi
  fi
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    echo "  Warning: Profile $profile not valid or accessible. Skipping..."
    continue
  fi

  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$profile")
  REGIONS="$TARGET_REGIONS"

  total_profile_count=0
  for region in $REGIONS; do
    echo "  - Region: $region"

    # Safe fetch that never breaks the script
    INSTANCES_JSON=$(get_instances_json "$profile" "$region")
    inst_count=$(jq 'length' <<<"$INSTANCES_JSON" 2>/dev/null || echo 0)
    echo "    Instances found: $inst_count"
    if [ "${inst_count:-0}" -eq 0 ]; then
      continue
    fi

    # Build unique AMI list for the region (avoid process substitution)
    IDS_RAW=$(jq -r '[.[].ImageId // empty] | unique | .[]' <<<"$INSTANCES_JSON" 2>/dev/null || true)
    mapfile -t IMAGE_IDS <<< "$IDS_RAW"
    AMI_MAP_FILE=$(mktemp)
    : > "$AMI_MAP_FILE"

    # Batch describe-images (limit ~100 per call); guard pipeline with || true
    if [ "${#IMAGE_IDS[@]}" -gt 0 ]; then
      batch=()
      for img in "${IMAGE_IDS[@]}"; do
        batch+=("$img")
        if [ "${#batch[@]}" -ge 95 ]; then
          aws ec2 describe-images --image-ids "${batch[@]}" --profile "$profile" --region "$region" $AWS_CLI_FLAGS --output json 2>/dev/null \
            | jq -r '.Images[] | [.ImageId, (.Name // "N/A"), (.Description // "N/A")] | @tsv' 2>/dev/null >> "$AMI_MAP_FILE" || true
          batch=()
        fi
      done
      if [ "${#batch[@]}" -gt 0 ]; then
        aws ec2 describe-images --image-ids "${batch[@]}" --profile "$profile" --region "$region" $AWS_CLI_FLAGS --output json 2>/dev/null \
          | jq -r '.Images[] | [.ImageId, (.Name // "N/A"), (.Description // "N/A")] | @tsv' 2>/dev/null >> "$AMI_MAP_FILE" || true
      fi
    fi

    # Iterate instances without a pipe (avoid pipefail aborts)
    LINES=$(jq -c '.[]' <<<"$INSTANCES_JSON" 2>/dev/null || true)
    if [ -z "$LINES" ]; then
      echo "    Parsing produced 0 lines for region $region"
      rm -f "$AMI_MAP_FILE"
      continue
    fi
    while IFS= read -r instance; do
      INSTANCE_ID=$(echo "$instance" | jq -r '.InstanceId')
      NAME=$(echo "$instance" | jq -r '((.Tags // []) | map(select(.Key=="Name")) | .[0].Value) // "NoName"')
      STATE=$(echo "$instance" | jq -r '.State.Name')
      PRIVATE_IP=$(echo "$instance" | jq -r '.PrivateIpAddress // "N/A"')
      PUBLIC_IP=$(echo "$instance" | jq -r '.PublicIpAddress // "N/A"')
      INSTANCE_TYPE=$(echo "$instance" | jq -r '.InstanceType')
      VPC=$(echo "$instance" | jq -r '.VpcId // "N/A"')
      SUBNET=$(echo "$instance" | jq -r '.SubnetId // "N/A"')
      AZ=$(echo "$instance" | jq -r '.Placement.AvailabilityZone // "N/A"')

      PLATFORM=$(echo "$instance" | jq -r '.Platform // "linux"')
      PLATFORM_DETAILS=$(echo "$instance" | jq -r '.PlatformDetails // "N/A"')
      IMAGE_ID=$(echo "$instance" | jq -r '.ImageId // "N/A"')

      if [ "$IMAGE_ID" != "N/A" ]; then
        AMI_ROW=$(awk -F'\t' -v id="$IMAGE_ID" '$1==id {print; exit}' "$AMI_MAP_FILE" 2>/dev/null || true)
        if [ -n "$AMI_ROW" ]; then
          OS_NAME=$(printf "%s" "$AMI_ROW" | cut -f2 | sed 's/,/;/g; s/"/\\"/g')
          OS_DESC=$(printf "%s" "$AMI_ROW" | cut -f3 | sed 's/,/;/g; s/"/\\"/g')
          OS_VERSION=$(echo "$OS_DESC" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
          [ -z "${OS_VERSION:-}" ] && OS_VERSION="N/A"
        else
          OS_NAME="Not Found"
          OS_VERSION="N/A"
        fi
      else
        OS_NAME="N/A"
        OS_VERSION="N/A"
      fi

      q_NAME=$(echo "$NAME" | sed 's/,/;/g; s/"/\\"/g')
      q_PLATFORM_DETAILS=$(echo "$PLATFORM_DETAILS" | sed 's/,/;/g; s/"/\\"/g')

      CSV_LINE="$ACCOUNT_ID,$profile,$INSTANCE_ID,\"$q_NAME\",$STATE,$PRIVATE_IP,$PUBLIC_IP,$INSTANCE_TYPE,$VPC,$SUBNET,$AZ,$PLATFORM,\"$q_PLATFORM_DETAILS\",\"$IMAGE_ID\",\"$OS_NAME\",\"$OS_VERSION\""
      printf "%s\n" "$CSV_LINE" >> "$OUTPUT_FILE"
    done <<< "$LINES"

    total_profile_count=$(( total_profile_count + inst_count ))
    rm -f "$AMI_MAP_FILE"
  done

  echo "  => Profile $profile total instances: $total_profile_count"
done

echo "✅ EC2 inventory collection complete. File saved as $OUTPUT_FILE."
echo "📊 Processed ${#PROFILES[@]} profiles from accounts.csv"
