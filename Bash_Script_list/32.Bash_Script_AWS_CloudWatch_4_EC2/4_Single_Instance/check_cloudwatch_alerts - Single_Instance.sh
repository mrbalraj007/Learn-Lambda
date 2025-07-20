#!/bin/bash
# filepath: check_cloudwatch_alerts.sh

# Script to check CloudWatch alert status for EC2 instances
# Author: AWS Engineer
# Version: 1.1 - Enhanced for Windows environment

set -e

# Configuration
CSV_FILE="instance_names.csv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_PATH="${SCRIPT_DIR}/${CSV_FILE}"
LOG_FILE="${SCRIPT_DIR}/cloudwatch_alerts_$(date +%Y%m%d_%H%M%S).log"
RESULTS_CSV="${SCRIPT_DIR}/cloudwatch_results_$(date +%Y%m%d_%H%M%S).csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Enhanced function to check jq installation on Windows
check_jq_installation() {
    print_status $BLUE "Checking jq installation..."
    
    # Try different ways jq might be available on Windows
    if command -v jq &> /dev/null; then
        print_status $GREEN "✓ jq found in PATH"
        return 0
    elif command -v jq.exe &> /dev/null; then
        print_status $GREEN "✓ jq.exe found in PATH"
        # Create alias for jq
        alias jq='jq.exe'
        return 0
    elif [ -f "/usr/bin/jq" ]; then
        print_status $GREEN "✓ jq found at /usr/bin/jq"
        return 0
    elif [ -f "/c/Program Files/jq/jq.exe" ]; then
        print_status $GREEN "✓ jq found at /c/Program Files/jq/jq.exe"
        # Add to PATH for this session
        export PATH="/c/Program Files/jq:$PATH"
        return 0
    else
        print_status $RED "ERROR: jq is not found in PATH"
        print_status $YELLOW "For Windows 11, try one of these installation methods:"
        print_status $YELLOW "1. Using Chocolatey: choco install jq"
        print_status $YELLOW "2. Using Scoop: scoop install jq"
        print_status $YELLOW "3. Download from: https://github.com/jqlang/jq/releases"
        print_status $YELLOW "4. Using WSL: apt-get install jq (if using WSL)"
        print_status $YELLOW "5. Using Git Bash: pacman -S jq (if using MSYS2)"
        print_status $YELLOW ""
        print_status $YELLOW "After installation, restart your terminal or add jq to your PATH"
        print_status $YELLOW "Current PATH: $PATH"
        return 1
    fi
}

# Function to check if AWS CLI is installed and configured
check_aws_prerequisites() {
    print_status $BLUE "Checking AWS CLI prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        print_status $RED "ERROR: AWS CLI is not installed. Please install AWS CLI first."
        print_status $YELLOW "For Windows 11: Download AWS CLI MSI installer from:"
        print_status $YELLOW "https://awscli.amazonaws.com/AWSCLIV2.msi"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status $RED "ERROR: AWS CLI is not configured or credentials are invalid."
        print_status $YELLOW "Run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    print_status $GREEN "✓ AWS CLI is properly configured"
}

# Function to get instance ID from instance name
get_instance_id() {
    local instance_name=$1
    local instance_id
    
    instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${instance_name}" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null)
    
    echo "$instance_id"
}

# Function to get CloudWatch alarms for an instance
get_instance_alarms() {
    local instance_id=$1
    local alarms
    
    # First, get all alarms and then filter by instance ID
    # This approach is more reliable than using complex JMESPath queries
    alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[].{AlarmName:AlarmName,StateValue:StateValue,MetricName:MetricName,Namespace:Namespace,StateReason:StateReason,StateUpdatedTimestamp:StateUpdatedTimestamp,ActionsEnabled:ActionsEnabled,AlarmActions:AlarmActions,OKActions:OKActions,InsufficientDataActions:InsufficientDataActions,Dimensions:Dimensions}" \
        --output json 2>/dev/null)
    
    # Filter alarms that have this instance ID in their dimensions
    filtered_alarms=$(echo "$alarms" | jq --arg instance_id "$instance_id" '
        [.[] | select(
            .Dimensions != null and 
            (.Dimensions | map(select(.Name == "InstanceId" and .Value == $instance_id)) | length > 0)
        ) | del(.Dimensions)]')
    
    echo "$filtered_alarms"
}

# Enhanced function to get all CloudWatch alarms (for debugging)
get_all_instance_related_alarms() {
    local instance_id=$1
    
    # Get alarms with different approaches
    print_status $YELLOW "Debug: Searching for alarms using multiple methods..."
    
    # Method 1: Direct dimension filter
    local method1_alarms
    method1_alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?Dimensions[?Name=='InstanceId' && Value=='${instance_id}']].AlarmName" \
        --output text 2>/dev/null || echo "")
    
    # Method 2: Get all EC2 related alarms and filter
    local method2_alarms
    method2_alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?Namespace=='AWS/EC2'].{AlarmName:AlarmName,Dimensions:Dimensions}" \
        --output json 2>/dev/null | jq --arg instance_id "$instance_id" -r '
        .[] | select(.Dimensions[]? | select(.Name == "InstanceId" and .Value == $instance_id)) | .AlarmName' || echo "")
    
    # Method 3: Search by alarm name pattern (if alarms follow naming convention)
    local method3_alarms
    method3_alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?contains(AlarmName, '${instance_id}')].AlarmName" \
        --output text 2>/dev/null || echo "")
    
    echo "Method 1 (Direct filter): $method1_alarms"
    echo "Method 2 (EC2 namespace filter): $method2_alarms"
    echo "Method 3 (Name pattern): $method3_alarms"
    
    # Return the most comprehensive result
    get_instance_alarms "$instance_id"
}

# Enhanced function to display comprehensive alarm information
display_comprehensive_alarm_info() {
    local instance_id=$1
    local instance_name=$2
    
    echo ""
    print_status $BLUE "=================================================="
    print_status $BLUE "Instance: $instance_name ($instance_id)"
    print_status $BLUE "=================================================="
    
    # Get instance state
    local instance_state
    instance_state=$(check_instance_exists "$instance_id")
    
    # Get alarms using enhanced method
    local alarms_json
    alarms_json=$(get_instance_alarms "$instance_id")
    
    # If no alarms found, try alternative search methods
    if [ "$alarms_json" == "[]" ] || [ -z "$alarms_json" ]; then
        print_status $YELLOW "No alarms found with standard method. Trying alternative searches..."
        
        # Try searching all EC2 related alarms
        local all_ec2_alarms
        all_ec2_alarms=$(aws cloudwatch describe-alarms \
            --query "MetricAlarms[?Namespace=='AWS/EC2']" \
            --output json 2>/dev/null || echo "[]")
        
        if [ "$all_ec2_alarms" != "[]" ]; then
            print_status $BLUE "Found $(echo "$all_ec2_alarms" | jq length) EC2-related alarms in total"
            
            # Filter for this specific instance
            alarms_json=$(echo "$all_ec2_alarms" | jq --arg instance_id "$instance_id" '
                [.[] | select(
                    .Dimensions != null and 
                    (.Dimensions | map(select(.Name == "InstanceId" and .Value == $instance_id)) | length > 0)
                ) | {AlarmName, StateValue, MetricName, Namespace, StateReason, StateUpdatedTimestamp, ActionsEnabled, AlarmActions, OKActions, InsufficientDataActions}]')
        fi
        
        # If still no alarms, show what alarms exist for debugging and log to CSV
        if [ "$alarms_json" == "[]" ] || [ -z "$alarms_json" ]; then
            print_status $YELLOW "Still no alarms found. Showing all EC2 alarms for debugging:"
            
            if [ "$all_ec2_alarms" != "[]" ]; then
                echo "$all_ec2_alarms" | jq -r '.[] | "Alarm: \(.AlarmName) - Dimensions: \(.Dimensions | map("\(.Name)=\(.Value)") | join(", "))"' | head -10
                if [ $(echo "$all_ec2_alarms" | jq length) -gt 10 ]; then
                    print_status $YELLOW "... and $(( $(echo "$all_ec2_alarms" | jq length) - 10 )) more alarms"
                fi
            else
                print_status $YELLOW "No EC2 alarms found in this region/account"
            fi
            
            print_status $YELLOW "No CloudWatch alarms found for this specific instance"
            log_message "No alarms found for instance $instance_name ($instance_id)"
            
            # Log to CSV that no alarms were found
            log_no_alarms_to_csv "$instance_id" "$instance_name" "$instance_state"
            return 0
        fi
    fi
    
    # Display found alarms
    local alarm_count
    alarm_count=$(echo "$alarms_json" | jq length)
    print_status $GREEN "Found $alarm_count alarm(s) for this instance"
    
    # Parse and display alarm details, and log to CSV
    echo "$alarms_json" | jq -r '.[] | @json' | while read -r alarm; do
        alarm_name=$(echo "$alarm" | jq -r '.AlarmName')
        state_value=$(echo "$alarm" | jq -r '.StateValue')
        metric_name=$(echo "$alarm" | jq -r '.MetricName')
        namespace=$(echo "$alarm" | jq -r '.Namespace')
        state_reason=$(echo "$alarm" | jq -r '.StateReason')
        state_updated=$(echo "$alarm" | jq -r '.StateUpdatedTimestamp')
        actions_enabled=$(echo "$alarm" | jq -r '.ActionsEnabled')
        alarm_actions=$(echo "$alarm" | jq -r '.AlarmActions // []')
        ok_actions=$(echo "$alarm" | jq -r '.OKActions // []')
        insufficient_data_actions=$(echo "$alarm" | jq -r '.InsufficientDataActions // []')
        
        # Count actions
        alarm_actions_count=$(echo "$alarm_actions" | jq -r 'length')
        ok_actions_count=$(echo "$ok_actions" | jq -r 'length')
        insufficient_data_actions_count=$(echo "$insufficient_data_actions" | jq -r 'length')
        total_actions=$((alarm_actions_count + ok_actions_count + insufficient_data_actions_count))
        
        # Format timestamp using enhanced function
        formatted_time=$(format_timestamp "$state_updated")
        
        echo ""
        printf "%-20s: %s\n" "Alarm Name" "$alarm_name"
        printf "%-20s: %s\n" "Metric" "$metric_name"
        printf "%-20s: %s\n" "Namespace" "$namespace"
        
        # Color-code the status
        case $state_value in
            "OK")
                printf "%-20s: " "Status"
                print_status $GREEN "$state_value"
                ;;
            "ALARM")
                printf "%-20s: " "Status"
                print_status $RED "$state_value"
                ;;
            "INSUFFICIENT_DATA")
                printf "%-20s: " "Status"
                print_status $YELLOW "$state_value"
                ;;
            *)
                printf "%-20s: %s\n" "Status" "$state_value"
                ;;
        esac
        
        # Display actions status with color coding
        printf "%-20s: " "Actions Enabled"
        if [ "$actions_enabled" == "true" ]; then
            print_status $GREEN "ENABLED"
        else
            print_status $RED "DISABLED"
        fi
        
        printf "%-20s: %d (Alarm: %d, OK: %d, InsufficientData: %d)\n" "Total Actions" "$total_actions" "$alarm_actions_count" "$ok_actions_count" "$insufficient_data_actions_count"
        
        # Show action details if any exist
        if [ "$total_actions" -gt 0 ]; then
            if [ "$alarm_actions_count" -gt 0 ]; then
                printf "%-20s: %s\n" "Alarm Actions" "$(echo "$alarm_actions" | jq -r 'join(", ")')"
            fi
            if [ "$ok_actions_count" -gt 0 ]; then
                printf "%-20s: %s\n" "OK Actions" "$(echo "$ok_actions" | jq -r 'join(", ")')"
            fi
            if [ "$insufficient_data_actions_count" -gt 0 ]; then
                printf "%-20s: %s\n" "InsufficientData Actions" "$(echo "$insufficient_data_actions" | jq -r 'join(", ")')"
            fi
        fi
        
        printf "%-20s: %s\n" "Reason" "$state_reason"
        printf "%-20s: %s\n" "Last Updated" "$formatted_time"
        echo "----------------------------------------"
        
        # Log alarm details to text log
        log_message "Instance: $instance_name | Alarm: $alarm_name | Status: $state_value | Actions: $actions_enabled | Total Actions: $total_actions"
        
        # Log to CSV
        log_to_csv "$instance_id" "$instance_name" "$instance_state" "$alarm_name" "$state_value" "$metric_name" "$namespace" "$actions_enabled" "$alarm_actions_count" "$ok_actions_count" "$insufficient_data_actions_count" "$state_reason" "$formatted_time"
    done
    
    return $alarm_count
}

# Function to initialize CSV results file
initialize_csv_results() {
    echo "Instance_ID,Instance_Name,Instance_State,Alarm_Name,Alarm_Status,Metric_Name,Namespace,Actions_Enabled,Alarm_Actions_Count,OK_Actions_Count,InsufficientData_Actions_Count,State_Reason,Last_Updated,Check_Timestamp" > "$RESULTS_CSV"
    print_status $GREEN "✓ Results CSV file initialized: $RESULTS_CSV"
}

# Function to log to CSV
log_to_csv() {
    local instance_id="$1"
    local instance_name="$2"
    local instance_state="$3"
    local alarm_name="$4"
    local alarm_status="$5"
    local metric_name="$6"
    local namespace="$7"
    local actions_enabled="$8"
    local alarm_actions_count="$9"
    local ok_actions_count="${10}"
    local insufficient_data_actions_count="${11}"
    local state_reason="${12}"
    local last_updated="${13}"
    local check_timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Escape commas and quotes in the data
    instance_name=$(echo "$instance_name" | sed 's/,/;/g' | sed 's/"/""/g')
    alarm_name=$(echo "$alarm_name" | sed 's/,/;/g' | sed 's/"/""/g')
    state_reason=$(echo "$state_reason" | sed 's/,/;/g' | sed 's/"/""/g')
    
    echo "\"$instance_id\",\"$instance_name\",\"$instance_state\",\"$alarm_name\",\"$alarm_status\",\"$metric_name\",\"$namespace\",\"$actions_enabled\",\"$alarm_actions_count\",\"$ok_actions_count\",\"$insufficient_data_actions_count\",\"$state_reason\",\"$last_updated\",\"$check_timestamp\"" >> "$RESULTS_CSV"
}

# Function to log instance with no alarms to CSV
log_no_alarms_to_csv() {
    local instance_id="$1"
    local instance_name="$2"
    local instance_state="$3"
    local check_timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    instance_name=$(echo "$instance_name" | sed 's/,/;/g' | sed 's/"/""/g')
    
    echo "\"$instance_id\",\"$instance_name\",\"$instance_state\",\"No Alarms Found\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"0\",\"0\",\"0\",\"No CloudWatch alarms configured\",\"N/A\",\"$check_timestamp\"" >> "$RESULTS_CSV"
}

# Function to log errors to CSV
log_error_to_csv() {
    local instance_id="$1"
    local error_message="$2"
    local check_timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    error_message=$(echo "$error_message" | sed 's/,/;/g' | sed 's/"/""/g')
    
    echo "\"$instance_id\",\"ERROR\",\"UNKNOWN\",\"ERROR\",\"ERROR\",\"N/A\",\"N/A\",\"N/A\",\"0\",\"0\",\"0\",\"$error_message\",\"N/A\",\"$check_timestamp\"" >> "$RESULTS_CSV"
}

# Enhanced function to generate summary report with CSV info
generate_summary() {
    local total_instances=$1
    local total_alarms=$2
    
    echo ""
    print_status $BLUE "=================================================="
    print_status $BLUE "SUMMARY REPORT"
    print_status $BLUE "=================================================="
    echo "Total instances processed: $total_instances"
    echo "Total alarms found: $total_alarms"
    echo "Text log file: $LOG_FILE"
    echo "CSV results file: $RESULTS_CSV"
    echo ""
    
    # Show CSV file preview
    if [[ -f "$RESULTS_CSV" ]]; then
        print_status $BLUE "CSV Results Preview (first 5 rows):"
        head -n 6 "$RESULTS_CSV" | column -t -s ','
        echo ""
        
        local csv_row_count
        csv_row_count=$(tail -n +2 "$RESULTS_CSV" | wc -l)
        print_status $GREEN "✓ CSV file contains $csv_row_count data rows"
    fi
    
    log_message "Summary - Instances: $total_instances, Total alarms: $total_alarms"
}

# Enhanced function to format timestamp for Windows
format_timestamp() {
    local timestamp=$1
    
    # Try different date command formats for Windows compatibility
    if date --version 2>/dev/null | grep -q GNU; then
        # GNU date (Linux/WSL)
        date -d "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows Git Bash / MSYS2
        date -d "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$timestamp"
    else
        # Fallback - just return original timestamp
        echo "$timestamp"
    fi
}

# Enhanced function to get instance name from instance ID
get_instance_name() {
    local instance_id=$1
    local instance_name
    
    instance_name=$(aws ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' \
        --output text 2>/dev/null || echo "")
    
    # If no Name tag found, return the instance ID as name
    if [[ -z "$instance_name" ]] || [[ "$instance_name" == "None" ]]; then
        instance_name="$instance_id"
    fi
    
    echo "$instance_name"
}

# Function to validate instance ID format
validate_instance_id() {
    local instance_id=$1
    
    # Check if instance ID matches AWS pattern (i-xxxxxxxxxxxxxxxxx)
    if [[ $instance_id =~ ^i-[0-9a-f]{8}([0-9a-f]{9})?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if instance exists and get its state
check_instance_exists() {
    local instance_id=$1
    local instance_state
    
    instance_state=$(aws ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text 2>/dev/null || echo "")
    
    echo "$instance_state"
}

# Enhanced function to check if instance exists in any state
check_instance_exists_any_state() {
    local instance_id=$1
    local instance_info
    
    print_status $BLUE "Searching for instance in all states..."
    
    # Check if instance exists in any state (including terminated)
    instance_info=$(aws ec2 describe-instances \
        --instance-ids "${instance_id}" \
        --query 'Reservations[*].Instances[*].{State:State.Name,Name:Tags[?Key==`Name`].Value|[0],LaunchTime:LaunchTime,InstanceType:InstanceType}' \
        --output json 2>/dev/null || echo "[]")
    
    if [ "$instance_info" != "[]" ] && [ -n "$instance_info" ]; then
        echo "$instance_info" | jq -r '.[] | "State: \(.State), Name: \(.Name // "No Name"), Type: \(.InstanceType), Launch: \(.LaunchTime)"'
        echo "$instance_info" | jq -r '.[].State'
    else
        echo ""
    fi
}

# Enhanced function to debug CloudWatch alarms
debug_cloudwatch_alarms() {
    local instance_id=$1
    
    print_status $BLUE "=== CloudWatch Debug Information ==="
    
    # Get current AWS account and region
    local account_id
    local current_region
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    current_region=$(aws configure get region 2>/dev/null || echo "default")
    
    print_status $BLUE "Account ID: $account_id"
    print_status $BLUE "Region: $current_region"
    
    # Check total number of CloudWatch alarms
    local total_alarms
    total_alarms=$(aws cloudwatch describe-alarms --query 'length(MetricAlarms)' --output text 2>/dev/null || echo "0")
    print_status $BLUE "Total CloudWatch alarms in region: $total_alarms"
    
    if [ "$total_alarms" -eq 0 ]; then
        print_status $YELLOW "No CloudWatch alarms found in this region at all!"
        return
    fi
    
    # Get all EC2 related alarms
    local ec2_alarms
    ec2_alarms=$(aws cloudwatch describe-alarms \
        --query 'MetricAlarms[?Namespace==`AWS/EC2`]' \
        --output json 2>/dev/null || echo "[]")
    
    local ec2_alarm_count
    ec2_alarm_count=$(echo "$ec2_alarms" | jq length)
    print_status $BLUE "EC2-related alarms: $ec2_alarm_count"
    
    if [ "$ec2_alarm_count" -gt 0 ]; then
        print_status $BLUE "Sample EC2 alarms found:"
        echo "$ec2_alarms" | jq -r '.[:3][] | "- \(.AlarmName) (Dimensions: \(.Dimensions | map("\(.Name)=\(.Value)") | join(", ")))"'
        
        # Check if any alarm has this specific instance ID
        local matching_alarms
        matching_alarms=$(echo "$ec2_alarms" | jq --arg instance_id "$instance_id" '
            [.[] | select(.Dimensions[]? | select(.Name == "InstanceId" and .Value == $instance_id))]')
        
        local matching_count
        matching_count=$(echo "$matching_alarms" | jq length)
        
        if [ "$matching_count" -gt 0 ]; then
            print_status $GREEN "Found $matching_count alarm(s) for instance $instance_id:"
            echo "$matching_alarms" | jq -r '.[] | "- \(.AlarmName) (\(.StateValue))"'
        else
            print_status $YELLOW "No alarms found specifically for instance $instance_id"
            print_status $BLUE "All instance IDs found in EC2 alarms:"
            echo "$ec2_alarms" | jq -r '.[] | .Dimensions[]? | select(.Name == "InstanceId") | .Value' | sort -u | head -10
        fi
    fi
    
    # Check for alarms that might be related by name pattern
    local name_pattern_alarms
    name_pattern_alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?contains(AlarmName, '${instance_id}')]" \
        --output json 2>/dev/null || echo "[]")
    
    local name_pattern_count
    name_pattern_count=$(echo "$name_pattern_alarms" | jq length)
    
    if [ "$name_pattern_count" -gt 0 ]; then
        print_status $GREEN "Found $name_pattern_count alarm(s) with instance ID in name:"
        echo "$name_pattern_alarms" | jq -r '.[] | "- \(.AlarmName) (\(.StateValue))"'
    fi
}

# Enhanced function to search across multiple regions
search_instance_across_regions() {
    local instance_id=$1
    
    print_status $BLUE "=== Multi-Region Instance Search ==="
    
    # Common AWS regions
    local regions=("us-east-1" "us-west-2" "eu-west-1" "ap-southeast-2" "ap-south-1")
    local current_region
    current_region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    
    for region in "${regions[@]}"; do
        if [ "$region" != "$current_region" ]; then
            print_status $YELLOW "Checking region: $region"
            local instance_state
            instance_state=$(aws ec2 describe-instances \
                --region "$region" \
                --instance-ids "${instance_id}" \
                --query 'Reservations[*].Instances[*].State.Name' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$instance_state" ]; then
                print_status $GREEN "Found instance in region $region with state: $instance_state"
                return 0
            fi
        fi
    done
    
    print_status $YELLOW "Instance not found in common regions"
    return 1
}

# Main function
main() {
    print_status $BLUE "CloudWatch Alerts Status Checker for EC2 Instances"
    print_status $BLUE "==================================================="
    print_status $BLUE "Running on: $OSTYPE"
    
    # Check prerequisites
    check_aws_prerequisites
    
    # Check jq installation with enhanced Windows support
    if ! check_jq_installation; then
        exit 1
    fi
    
    # Check if CSV file exists
    if [[ ! -f "$CSV_PATH" ]]; then
        print_status $RED "ERROR: CSV file not found at $CSV_PATH"
        exit 1
    fi
    
    # Initialize CSV results file
    initialize_csv_results
    
    # Display current AWS region
    current_region=$(aws configure get region 2>/dev/null || echo "default")
    print_status $BLUE "Current AWS Region: $current_region"
    
    # Show CSV file contents for debugging
    print_status $BLUE "Input CSV file contents:"
    cat "$CSV_PATH"
    echo ""
    
    log_message "Starting CloudWatch alerts check for EC2 instances"
    
    local total_instances=0
    local total_alarms=0
    local line_number=0
    
    # Read CSV file and process each instance
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        
        # Skip header row (check for both possible headers)
        if [[ "$line" == "instance_id" ]] || [[ "$line" == "instance_name" ]]; then
            print_status $BLUE "Skipping header row: $line"
            continue
        fi
        
        # Skip empty lines and lines with only whitespace
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        instance_id=$(echo "$line" | tr -d '\r\n' | xargs)
        
        if [[ -z "$instance_id" ]]; then
            continue
        fi
        
        print_status $YELLOW "Processing line $line_number: '$instance_id'"
        
        # Validate instance ID format
        if ! validate_instance_id "$instance_id"; then
            print_status $RED "ERROR: Invalid instance ID format: $instance_id"
            log_message "Invalid instance ID format: $instance_id"
            log_error_to_csv "$instance_id" "Invalid instance ID format"
            continue
        fi
        
        print_status $BLUE "Valid instance ID format confirmed"
        
        # Enhanced instance existence check
        instance_state=$(check_instance_exists_any_state "$instance_id")
        
        if [[ -z "$instance_state" ]]; then
            print_status $RED "WARNING: Instance '$instance_id' not found in current region"
            log_message "Instance not found in current region: $instance_id"
            
            # Search in other regions
            if search_instance_across_regions "$instance_id"; then
                print_status $YELLOW "Instance found in another region. Please switch regions or update your AWS CLI configuration."
                log_error_to_csv "$instance_id" "Instance found in different region"
                continue
            else
                print_status $RED "Instance not found in any checked region"
                log_error_to_csv "$instance_id" "Instance not found in any region"
                continue
            fi
        fi
        
        # Get instance name from tags
        instance_name=$(get_instance_name "$instance_id")
        
        print_status $GREEN "Found instance: $instance_name (State: $instance_state)"
        
        # Debug CloudWatch alarms
        debug_cloudwatch_alarms "$instance_id"
        
        # Display comprehensive alarm information and log to CSV
        display_comprehensive_alarm_info "$instance_id" "$instance_name"
        instance_alarm_count=$?
        
        total_alarms=$((total_alarms + instance_alarm_count))
        total_instances=$((total_instances + 1))
        
    done < "$CSV_PATH"
    
    # Generate summary
    generate_summary "$total_instances" "$total_alarms"
    
    print_status $GREEN "CloudWatch alerts check completed successfully!"
    print_status $BLUE "Results saved to: $RESULTS_CSV"
}

# Error handling
trap 'print_status $RED "Script interrupted or failed. Check $LOG_FILE for details."' ERR

# Run main function
main "$@"