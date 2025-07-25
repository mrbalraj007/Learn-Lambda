#!/bin/bash

# Script to check and enable CloudWatch alarm actions for given EC2 instances
# Author: AWS Engineer
# Requirements: AWS CLI, jq

INPUT_CSV="ec2_instance_ids.csv"
OUTPUT_CSV="cloudwatch_alarm_action_status_$(date '+%Y%m%d-%H%M%S').csv"

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

echo "Starting CloudWatch alarm action status check..."
echo "Output CSV file: $OUTPUT_CSV"
echo "InstanceID,AlarmName,ActionsEnabled,Status" > "$OUTPUT_CSV"

# Read instance IDs from the CSV, skipping header if detected
FIRST_LINE=$(head -n 1 "$INPUT_CSV" | tr -d '\r')
if [[ "$FIRST_LINE" == "InstanceId" ]]; then
  DATA_LINES=$(tail -n +2 "$INPUT_CSV")
else
  DATA_LINES=$(cat "$INPUT_CSV")
fi

# Process each instance ID
echo "$DATA_LINES" | while IFS=, read -r INSTANCE_ID; do
  INSTANCE_ID=$(echo "$INSTANCE_ID" | tr -d '\r\n ')
  if [[ -z "$INSTANCE_ID" ]]; then continue; fi

  echo -e "\n🔍 Checking alarms for instance: $INSTANCE_ID"

  # Fetch all alarms for this EC2 instance
  ALARMS_JSON=$(aws cloudwatch describe-alarms \
    --query "MetricAlarms[?contains(Dimensions[?Name=='InstanceId'].Value, '$INSTANCE_ID')]" \
    --output json)

  ALARM_COUNT=$(echo "$ALARMS_JSON" | jq length)
  if [[ "$ALARM_COUNT" -eq 0 ]]; then
    echo "No alarms found for $INSTANCE_ID."
    echo "$INSTANCE_ID,N/A,N/A,No alarms found" >> "$OUTPUT_CSV"
    continue
  fi

  # Loop through each alarm for the instance
  echo "$ALARMS_JSON" | jq -c '.[]' | while read -r alarm; do
    ALARM_NAME=$(echo "$alarm" | jq -r '.AlarmName')
    ACTIONS_ENABLED=$(echo "$alarm" | jq -r '.ActionsEnabled')

    if [[ "$ACTIONS_ENABLED" == "false" ]]; then
      echo -e "⚠️  Alarm '$ALARM_NAME' actions are DISABLED. Enabling..."
      aws cloudwatch enable-alarm-actions --alarm-names "$ALARM_NAME"
      echo "$INSTANCE_ID,$ALARM_NAME,false,Enabled Now" >> "$OUTPUT_CSV"
    else
      echo -e "✅ Alarm '$ALARM_NAME' actions are already ENABLED."
      echo "$INSTANCE_ID,$ALARM_NAME,true,Already Enabled" >> "$OUTPUT_CSV"
    fi
  done
done

echo -e "\n✅ Script execution completed."
echo "Detailed output saved to: $OUTPUT_CSV"
