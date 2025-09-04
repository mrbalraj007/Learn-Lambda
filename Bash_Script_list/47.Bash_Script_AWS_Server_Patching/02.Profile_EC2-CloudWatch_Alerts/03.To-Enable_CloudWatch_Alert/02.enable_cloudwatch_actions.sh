#!/bin/bash

# Script to check and enable CloudWatch alarm actions for given EC2 instances
# Author: AWS Engineer
# Requirements: AWS CLI, jq

INPUT_CSV="ec2_instance_ids.csv"
OUTPUT_CSV="cloudwatch_alarm_action_status_$(date '+%Y%m%d-%H%M%S').csv"
PROFILES_FILE="profiles.txt"
DEFAULT_REGION="${DEFAULT_REGION:-ap-southeast-2}"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Validate dependencies
if ! command -v aws >/dev/null 2>&1; then
  echo -e "${RED}AWS CLI not installed. Exiting.${NC}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}jq is required. Please install jq and retry.${NC}"
  exit 1
fi

# Check if input CSV exists
if [[ ! -f "$INPUT_CSV" ]]; then
  echo -e "${RED}Input file $INPUT_CSV not found. Exiting.${NC}"
  exit 1
fi

# Check if profiles file exists
if [[ ! -f "$PROFILES_FILE" ]]; then
  echo -e "${RED}Profiles file $PROFILES_FILE not found. Run 01.generate_aws_config.sh first.${NC}"
  exit 1
fi

echo "Starting CloudWatch alarm action status check..."
echo "Output CSV file: $OUTPUT_CSV"
# Expanded header to include profile/account/region for traceability
echo "Profile,Account,Region,InstanceID,AlarmName,ActionsEnabled,Status" > "$OUTPUT_CSV"

# Read instance IDs from the CSV, skipping header if detected
FIRST_LINE=$(head -n 1 "$INPUT_CSV" | tr -d '\r')
if [[ "$FIRST_LINE" == "InstanceId" ]]; then
  DATA_LINES=$(tail -n +2 "$INPUT_CSV")
else
  DATA_LINES=$(cat "$INPUT_CSV")
fi

# Normalize instance IDs, ignore empty lines
INSTANCE_IDS=()
while IFS=, read -r INSTANCE_ID; do
  INSTANCE_ID=$(echo "$INSTANCE_ID" | tr -d '\r\n ' )
  [[ -z "$INSTANCE_ID" ]] && continue
  INSTANCE_IDS+=("$INSTANCE_ID")
done <<< "$DATA_LINES"

# Load profiles from profiles.txt
PROFILES=()
while IFS= read -r profile || [[ -n "$profile" ]]; do
  profile=$(echo "$profile" | tr -d '\r\n ' )
  [[ -z "$profile" ]] && continue
  PROFILES+=("$profile")
done < "$PROFILES_FILE"

echo "Profiles detected: ${#PROFILES[@]}"
# Attempt a single SSO login based on the first profile's sso_session (idempotent)
if [[ ${#PROFILES[@]} -gt 0 ]]; then
  FIRST_PROFILE="${PROFILES[0]}"
  SSO_SESSION_NAME=$(aws configure get sso_session --profile "$FIRST_PROFILE" 2>/dev/null)
  if [[ -n "$SSO_SESSION_NAME" ]]; then
    echo "Performing single SSO login for session: $SSO_SESSION_NAME"
    if ! aws sso login --sso-session "$SSO_SESSION_NAME"; then
      echo -e "${RED}SSO login failed for session $SSO_SESSION_NAME.${NC}"
      exit 1
    fi
  fi
fi

# Process each profile and instance ID
for PROFILE in "${PROFILES[@]}"; do
  echo -e "\n==> Profile: $PROFILE"

  # Determine region for this profile (fallback to DEFAULT_REGION)
  REGION=$(aws configure get region --profile "$PROFILE" 2>/dev/null)
  REGION=${REGION:-$DEFAULT_REGION}

  # Verify credentials and capture account ID
  ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text 2>/dev/null)
  if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "None" ]]; then
    echo -e "${RED}Skipping profile $PROFILE: unable to get caller identity.${NC}"
    for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
      echo "$PROFILE,,${REGION},$INSTANCE_ID,N/A,N/A,Profile auth failed" >> "$OUTPUT_CSV"
    done
    continue
  fi
  echo "Authenticated. Account: $ACCOUNT_ID, Region: $REGION"

  # For each instance ID, check and enable alarm actions
  for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    echo -e "\n🔍 [$PROFILE/$ACCOUNT_ID/$REGION] Checking alarms for instance: $INSTANCE_ID"

    # Fetch alarms for this EC2 instance in this profile/region
    ALARMS_JSON=$(aws cloudwatch describe-alarms \
      --profile "$PROFILE" \
      --region "$REGION" \
      --query "MetricAlarms[?contains(Dimensions[?Name=='InstanceId'].Value, '$INSTANCE_ID')]" \
      --output json 2>/dev/null)

    # Handle errors from describe-alarms
    if [[ $? -ne 0 || -z "$ALARMS_JSON" ]]; then
      echo -e "${RED}Failed to describe alarms for $INSTANCE_ID in $PROFILE/$REGION.${NC}"
      echo "$PROFILE,$ACCOUNT_ID,$REGION,$INSTANCE_ID,N/A,N/A,Describe alarms failed" >> "$OUTPUT_CSV"
      continue
    fi

    ALARM_COUNT=$(echo "$ALARMS_JSON" | jq length)
    if [[ "$ALARM_COUNT" -eq 0 ]]; then
      echo "No alarms found for $INSTANCE_ID."
      echo "$PROFILE,$ACCOUNT_ID,$REGION,$INSTANCE_ID,N/A,N/A,No alarms found" >> "$OUTPUT_CSV"
      continue
    fi

    # Loop through each alarm for the instance
    echo "$ALARMS_JSON" | jq -c '.[]' | while read -r alarm; do
      ALARM_NAME=$(echo "$alarm" | jq -r '.AlarmName')
      ACTIONS_ENABLED=$(echo "$alarm" | jq -r '.ActionsEnabled')

      if [[ "$ACTIONS_ENABLED" == "false" ]]; then
        echo -e "⚠️  Alarm '$ALARM_NAME' actions are DISABLED. Enabling..."
        if aws cloudwatch enable-alarm-actions --profile "$PROFILE" --region "$REGION" --alarm-names "$ALARM_NAME"; then
          echo "$PROFILE,$ACCOUNT_ID,$REGION,$INSTANCE_ID,$ALARM_NAME,false,Enabled Now" >> "$OUTPUT_CSV"
        else
          echo -e "${RED}Failed to enable actions for alarm '$ALARM_NAME'.${NC}"
          echo "$PROFILE,$ACCOUNT_ID,$REGION,$INSTANCE_ID,$ALARM_NAME,false,Enable failed" >> "$OUTPUT_CSV"
        fi
      else
        echo -e "✅ Alarm '$ALARM_NAME' actions are already ENABLED."
        echo "$PROFILE,$ACCOUNT_ID,$REGION,$INSTANCE_ID,$ALARM_NAME,true,Already Enabled" >> "$OUTPUT_CSV"
      fi
    done
  done
done

echo -e "\n✅ Script execution completed."
echo "Detailed output saved to: $OUTPUT_CSV"
