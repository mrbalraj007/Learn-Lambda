#!/bin/bash

# ---------------- CONFIG ----------------
INPUT_FILE="instance_ids.csv"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="cloudwatch_alarms_${ACCOUNT_ID}_${TIMESTAMP}.csv"
# ----------------------------------------

# Define colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

print_status() {
    echo -e "${1}${2}${NC}"
}

validate_instance_id() {
    local instance_id=$1
    [[ "$instance_id" =~ ^i-[a-z0-9]{8,}$ ]]
}

get_all_alarms_for_instance() {
    local instance_id=$1

    local alarms_json
    alarms_json=$(aws cloudwatch describe-alarms --query 'MetricAlarms' --output json 2>/dev/null)

    if [[ -z "$alarms_json" || "$alarms_json" == "[]" ]]; then
        echo "[]"
        return
    fi

    local filtered_alarms
    filtered_alarms=$(echo "$alarms_json" | jq --arg instance_id "$instance_id" '
        [.[] | select(
            .Dimensions != null and
            (.Dimensions | any(.Name == "InstanceId" and .Value == $instance_id))
        )]')

    echo "$filtered_alarms"
}

format_timestamp() {
    local input=$1
    if [[ -z "$input" || "$input" == "null" ]]; then
        echo ""
    else
        date -d "$input" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$input"
    fi
}

log_to_csv() {
    local instance_id="$1"
    local alarm_name="$2"
    local state="$3"
    local metric="$4"
    local namespace="$5"
    local threshold="$6"
    local comparison="$7"
    local period="$8"
    local evaluation_periods="$9"
    local last_updated="${10}"
    local alarm_actions="${11}"
    local ok_actions="${12}"
    local insufficient_actions="${13}"
    local action_enabled="${14}"

    echo "\"$instance_id\",\"$alarm_name\",\"$state\",\"$metric\",\"$namespace\",\"$threshold\",\"$comparison\",\"$period\",\"$evaluation_periods\",\"$last_updated\",\"$alarm_actions\",\"$ok_actions\",\"$insufficient_actions\",\"$action_enabled\"" >> "$OUTPUT_FILE"
}

write_csv_header() {
    echo "\"Instance ID\",\"Alarm Name\",\"State\",\"Metric\",\"Namespace\",\"Threshold\",\"Comparison Operator\",\"Period\",\"Evaluation Periods\",\"Last Updated\",\"Alarm Actions\",\"OK Actions\",\"Insufficient Data Actions\",\"Actions Enabled\"" > "$OUTPUT_FILE"
}

process_alarms_to_csv() {
    local instance_id="$1"
    local alarms="$2"

    if [[ "$alarms" == "[]" ]]; then
        print_status $YELLOW "No alarms found for $instance_id"
        return
    fi

    local count
    count=$(echo "$alarms" | jq 'length')
    print_status $GREEN "Found $count alarms for $instance_id"

    for ((i = 0; i < count; i++)); do
        local alarm
        alarm=$(echo "$alarms" | jq ".[$i]")

        local name state metric namespace threshold comparison period eval_periods updated
        name=$(echo "$alarm" | jq -r '.AlarmName')
        state=$(echo "$alarm" | jq -r '.StateValue')
        metric=$(echo "$alarm" | jq -r '.MetricName')
        namespace=$(echo "$alarm" | jq -r '.Namespace')
        threshold=$(echo "$alarm" | jq -r '.Threshold')
        comparison=$(echo "$alarm" | jq -r '.ComparisonOperator')
        period=$(echo "$alarm" | jq -r '.Period')
        eval_periods=$(echo "$alarm" | jq -r '.EvaluationPeriods')
        updated=$(format_timestamp "$(echo "$alarm" | jq -r '.StateUpdatedTimestamp')")

        alarm_actions=$(echo "$alarm" | jq -r '.AlarmActions | join(", ")')
        ok_actions=$(echo "$alarm" | jq -r '.OKActions | join(", ")')
        insufficient_actions=$(echo "$alarm" | jq -r '.InsufficientDataActions | join(", ")')
        action_enabled=$(echo "$alarm" | jq -r '.ActionsEnabled')

        log_to_csv "$instance_id" "$name" "$state" "$metric" "$namespace" "$threshold" "$comparison" "$period" "$eval_periods" "$updated" "$alarm_actions" "$ok_actions" "$insufficient_actions" "$action_enabled"
    done
}

main() {
    print_status $CYAN "Starting audit..."
    write_csv_header

    while IFS= read -r line || [[ -n "$line" ]]; do
        line=$(echo "$line" | tr -d '\r\n')

        # Skip blank or commented lines
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi

        instance_id="$line"

        if ! validate_instance_id "$instance_id"; then
            print_status $YELLOW "Skipping invalid instance ID: $instance_id"
            continue
        fi

        print_status $CYAN "🔍 Processing instance: $instance_id"
        alarms=$(get_all_alarms_for_instance "$instance_id")
        process_alarms_to_csv "$instance_id" "$alarms"
    done < "$INPUT_FILE"

    print_status $GREEN "Audit complete! CSV saved to: $OUTPUT_FILE"
}

main
