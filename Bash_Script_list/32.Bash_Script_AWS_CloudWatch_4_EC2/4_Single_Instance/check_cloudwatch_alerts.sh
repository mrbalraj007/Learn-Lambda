#!/bin/bash

# Set output file name with timestamp
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="cloudwatch_alarms_${ACCOUNT_ID}_${TIMESTAMP}.csv"

# Colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# Input CSV file (expected: list of instance IDs, one per line, no header)
INPUT_FILE="instance_ids.csv"

# Check prerequisites
check_prerequisites() {
    for cmd in aws jq; do
        if ! command -v $cmd &>/dev/null; then
            echo "${RED}Error:${RESET} '$cmd' is not installed or not in PATH."
            exit 1
        fi
    done
}

# Validate instance ID format
validate_instance_id() {
    local instance_id=$1
    [[ "$instance_id" =~ ^i-[a-f0-9]+$ ]]
}

# Fetch CloudWatch alarms for a given instance ID
get_instance_alarms() {
    local instance_id=$1
    aws cloudwatch describe-alarms --query "MetricAlarms[?Dimensions[?Name=='InstanceId' && Value=='$instance_id']]" --output json 2>/dev/null
}

# Write header to output CSV
write_csv_header() {
    echo "InstanceID,AlarmName,ActionsEnabled,MetricName,Namespace,StateValue,EvaluationPeriods,Period,Statistic,ComparisonOperator,Threshold,AlarmActionsCount,OKActionsCount,InsufficientDataActionsCount" > "$OUTPUT_FILE"
}

# Append alarm details to CSV
write_alarm_to_csv() {
    local instance_id=$1
    local alarm=$2

    local alarm_name=$(echo "$alarm" | jq -r '.AlarmName')
    local actions_enabled=$(echo "$alarm" | jq -r '.ActionsEnabled')
    local metric_name=$(echo "$alarm" | jq -r '.MetricName')
    local namespace=$(echo "$alarm" | jq -r '.Namespace')
    local state_value=$(echo "$alarm" | jq -r '.StateValue')
    local evaluation_periods=$(echo "$alarm" | jq -r '.EvaluationPeriods')
    local period=$(echo "$alarm" | jq -r '.Period')
    local statistic=$(echo "$alarm" | jq -r '.Statistic // "N/A"')
    local comparison_operator=$(echo "$alarm" | jq -r '.ComparisonOperator')
    local threshold=$(echo "$alarm" | jq -r '.Threshold')
    local alarm_actions_count=$(echo "$alarm" | jq -r '.AlarmActions | length')
    local ok_actions_count=$(echo "$alarm" | jq -r '.OKActions | length')
    local insufficient_actions_count=$(echo "$alarm" | jq -r '.InsufficientDataActions | length')

    echo "$instance_id,\"$alarm_name\",$actions_enabled,$metric_name,$namespace,$state_value,$evaluation_periods,$period,$statistic,$comparison_operator,$threshold,$alarm_actions_count,$ok_actions_count,$insufficient_actions_count" >> "$OUTPUT_FILE"
}

# Main logic
main() {
    check_prerequisites

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "${RED}Error:${RESET} '$INPUT_FILE' not found. Please provide a file with EC2 instance IDs."
        exit 1
    fi

    write_csv_header
    echo "${GREEN}Starting CloudWatch alarm audit...${RESET}"

    while IFS= read -r instance_id || [[ -n "$instance_id" ]]; do
        [[ -z "$instance_id" || "$instance_id" == \#* ]] && continue

        if ! validate_instance_id "$instance_id"; then
            echo "${YELLOW}Warning:${RESET} '$instance_id' is not a valid EC2 instance ID. Skipping..."
            continue
        fi

        echo "Checking alarms for instance: $instance_id"
        alarms_json=$(get_instance_alarms "$instance_id")

        if [[ -z "$alarms_json" || "$alarms_json" == "[]" ]]; then
            echo "${YELLOW}No alarms found${RESET} for $instance_id."
            continue
        fi

        alarm_count=$(echo "$alarms_json" | jq 'length')
        echo "${GREEN}$alarm_count alarms found${RESET} for $instance_id."

        for ((i = 0; i < alarm_count; i++)); do
            alarm=$(echo "$alarms_json" | jq ".[$i]")
            write_alarm_to_csv "$instance_id" "$alarm"
        done
    done < "$INPUT_FILE"

    echo "${GREEN}Audit completed. Results saved to:${RESET} $OUTPUT_FILE"
}

main
