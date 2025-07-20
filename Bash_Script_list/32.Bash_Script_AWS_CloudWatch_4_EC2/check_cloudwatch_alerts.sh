#!/bin/bash

# Script to check CloudWatch alert status for EC2 instances
# Author: AWS Engineer
# Version: 2.1 - Fixed process_instance function

set -e

# Configuration
CSV_FILE="instance_names.csv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_PATH="${SCRIPT_DIR}/${CSV_FILE}"
LOG_FILE="${SCRIPT_DIR}/cloudwatch_alerts_$(date +%Y%m%d_%H%M%S).log"
RESULTS_CSV="${SCRIPT_DIR}/cloudwatch_results_$(date +%Y%m%d_%H%M%S).csv"
PROGRESS_FILE="${SCRIPT_DIR}/progress_$(date +%Y%m%d_%H%M%S).tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to validate instance ID format
validate_instance_id() {
    local instance_id="$1"
    if [[ "$instance_id" =~ ^i-[0-9a-f]{8}([0-9a-f]{9})?$ ]]; then
        return 0
    else
        return 1
    fi
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
    if [[ -z "$instance_name" ]] || [[ "$instance_name" == "None" ]] || [[ "$instance_name" == "null" ]]; then
        instance_name="$instance_id"
    fi
    
    echo "$instance_name"
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
    print_status "$GREEN" "✓ Results CSV file initialized: $RESULTS_CSV"
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

# Enhanced function to check if instance exists and get its state
check_instance_exists() {
    local instance_id="$1"
    local instance_state
    
    log_message "Checking if instance $instance_id exists..."
    
    instance_state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text 2>/dev/null || echo "")
    
    # Clean up the response
    instance_state=$(echo "$instance_state" | tr -d '\n\r' | xargs)
    
    if [[ -z "$instance_state" ]]; then
        log_message "Instance $instance_id not found or in an unusual state"
        return 1
    fi
    
    log_message "Instance $instance_id state: $instance_state"
    echo "$instance_state"
    return 0
}

# Function to find ALL CloudWatch alarms for an instance - COMPLETELY REWRITTEN
process_instance() {
    local instance_id=$1
    local alarm_count=0
    
    print_status "$BLUE" "=============================================="
    print_status "$BLUE" "Processing instance: $instance_id"
    print_status "$BLUE" "=============================================="
    
    # Get instance state and name
    local instance_state
    local instance_name
    
    # Get instance details
    instance_state=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].State.Name' \
        --output text 2>/dev/null || echo "")
    
    instance_state=$(echo "$instance_state" | tr -d '\n\r' | xargs)
    
    # Check if instance exists
    if [ -z "$instance_state" ]; then
        print_status "$RED" "Instance $instance_id not found in current region"
        log_error_to_csv "$instance_id" "Instance not found in current region"
        return 0
    fi
    
    print_status "$GREEN" "Instance $instance_id found with state: $instance_state"
    
    # Get instance name
    instance_name=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].Tags[?Key==`Name`].Value' \
        --output text 2>/dev/null || echo "$instance_id")
    
    if [ -z "$instance_name" ]; then
        instance_name="$instance_id"
    fi
    
    print_status "$GREEN" "Instance name: $instance_name"
    
    # =====================================================================
    # APPROACH 1: Get ALL alarms and manually search for this instance
    # =====================================================================
    print_status "$YELLOW" "Fetching ALL CloudWatch alarms (this may take a moment)..."
    
    # First, get a list of ALL alarms
    local all_alarms
    all_alarms=$(aws cloudwatch describe-alarms --output json 2>/dev/null)
    
    # Create a debug file with all alarms
    echo "$all_alarms" > "${SCRIPT_DIR}/debug_all_alarms_raw.json"
    
    # Count total alarms for debugging
    local total_alarm_count
    total_alarm_count=$(echo "$all_alarms" | jq '.MetricAlarms | length')
    print_status "$BLUE" "Total alarms found in account: $total_alarm_count"
    
    # Process each alarm and check if it's for our instance - simplest approach possible
    print_status "$YELLOW" "Scanning all alarms for instance ID: $instance_id"
    
    # Extract all alarm names first (for debugging)
    local all_alarm_names
    all_alarm_names=$(echo "$all_alarms" | jq -r '.MetricAlarms[].AlarmName' 2>/dev/null)
    echo "$all_alarm_names" > "${SCRIPT_DIR}/debug_all_alarm_names.txt"
    
    # Find alarms related to our instance - using three different methods
    
    # 1. Direct search in alarm dimensions
    print_status "$BLUE" "METHOD 1: Searching by dimensions..."
    local found_alarms=()
    
    while read -r alarm_json; do
        # Skip empty lines
        [ -z "$alarm_json" ] && continue
        
        # Extract alarm name for logging
        local alarm_name
        alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName')
        
        # Extract dimensions as plain text for simple grep
        local dimensions_text
        dimensions_text=$(echo "$alarm_json" | jq -r '.Dimensions[]? | "\(.Name)=\(.Value)"' 2>/dev/null)
        
        # Check if instance ID is in dimensions
        if echo "$dimensions_text" | grep -q "$instance_id"; then
            print_status "$GREEN" "✓ Found alarm for instance: $alarm_name"
            found_alarms+=("$alarm_json")
            
            # Log directly to CSV
            process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
            alarm_count=$((alarm_count + 1))
        fi
    done < <(echo "$all_alarms" | jq -c '.MetricAlarms[]')
    
    # 2. Search in alarm name (some conventions include instance ID in name)
    print_status "$BLUE" "METHOD 2: Searching by alarm name..."
    
    while read -r alarm_json; do
        # Skip empty lines
        [ -z "$alarm_json" ] && continue
        
        local alarm_name
        alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName')
        
        # Skip alarms we already found
        local already_found=0
        for found in "${found_alarms[@]}"; do
            if [ "$found" = "$alarm_json" ]; then
                already_found=1
                break
            fi
        done
        
        [ $already_found -eq 1 ] && continue
        
        # Check if instance ID is in alarm name
        if echo "$alarm_name" | grep -q "$instance_id"; then
            print_status "$GREEN" "✓ Found alarm by name matching: $alarm_name"
            found_alarms+=("$alarm_json")
            
            # Log directly to CSV
            process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
            alarm_count=$((alarm_count + 1))
        fi
    done < <(echo "$all_alarms" | jq -c '.MetricAlarms[]')
    
    # 3. Look for EC2 instance alarms with dimensions matching our instance ID pattern
    print_status "$BLUE" "METHOD 3: Examining all EC2 alarms more deeply..."
    
    while read -r alarm_json; do
        # Skip empty lines
        [ -z "$alarm_json" ] && continue
        
        local alarm_name
        local namespace
        alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName')
        namespace=$(echo "$alarm_json" | jq -r '.Namespace')
        
        # Skip alarms we already found
        local already_found=0
        for found in "${found_alarms[@]}"; do
            if [ "$found" = "$alarm_json" ]; then
                already_found=1
                break
            fi
        done
        
        [ $already_found -eq 1 ] && continue
        
        # Only check EC2 alarms
        if [ "$namespace" = "AWS/EC2" ]; then
            # Look at full JSON for any mention of our instance ID
            if echo "$alarm_json" | grep -q "$instance_id"; then
                print_status "$GREEN" "✓ Found EC2 alarm with matching text: $alarm_name"
                found_alarms+=("$alarm_json")
                
                # Log directly to CSV
                process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
                alarm_count=$((alarm_count + 1))
            fi
        fi
    done < <(echo "$all_alarms" | jq -c '.MetricAlarms[]')
    
    # =====================================================================
    # APPROACH 2: Try direct AWS CLI filtering
    # =====================================================================
    print_status "$YELLOW" "Trying AWS CLI direct filtering for instance: $instance_id"
    
    # Use the AWS CLI's built-in filtering capabilities
    local direct_alarms
    direct_alarms=$(aws cloudwatch describe-alarms \
        --query "MetricAlarms[?contains(to_string(Dimensions[?Name=='InstanceId'].Value), '$instance_id')]" \
        --output json 2>/dev/null)
    
    # Save for debugging
    echo "$direct_alarms" > "${SCRIPT_DIR}/debug_${instance_id}_direct_alarms.json"
    
    # Count results
    local direct_count
    direct_count=$(echo "$direct_alarms" | jq 'length')
    
    if [ "$direct_count" -gt 0 ]; then
        print_status "$GREEN" "Found $direct_count alarm(s) with direct AWS query"
        
        while read -r alarm_json; do
            # Skip empty lines
            [ -z "$alarm_json" ] && continue
            
            # Check if we've already found this alarm
            local alarm_name
            alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName')
            
            # Check if we've already logged this alarm
            local already_found=0
            for found in "${found_alarms[@]}"; do
                if echo "$found" | jq -r '.AlarmName' | grep -q "^${alarm_name}$"; then
                    already_found=1
                    break
                fi
            done
            
            if [ $already_found -eq 0 ]; then
                print_status "$GREEN" "✓ Found new alarm via direct AWS query: $alarm_name"
                
                # Log directly to CSV
                process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
                alarm_count=$((alarm_count + 1))
                found_alarms+=("$alarm_json")
            fi
        done < <(echo "$direct_alarms" | jq -c '.[]')
    fi
    
    # =====================================================================
    # APPROACH 3: Query for specific CloudWatch metrics for this instance
    # =====================================================================
    print_status "$YELLOW" "Checking for EC2 metrics for instance: $instance_id"
    
    # Get metrics for this instance ID
    local instance_metrics
    instance_metrics=$(aws cloudwatch list-metrics \
        --namespace AWS/EC2 \
        --dimensions Name=InstanceId,Value="$instance_id" \
        --output json 2>/dev/null)
    
    # Save metrics for debugging
    echo "$instance_metrics" > "${SCRIPT_DIR}/debug_${instance_id}_metrics.json"
    
    # Find any alarms associated with these metrics
    local metric_count
    metric_count=$(echo "$instance_metrics" | jq '.Metrics | length')
    
    if [ "$metric_count" -gt 0 ]; then
        print_status "$BLUE" "Found $metric_count metrics for instance $instance_id"
        
        # For each metric, check if there are alarms
        while read -r metric_json; do
            # Skip empty lines
            [ -z "$metric_json" ] && continue
            
            local metric_name
            metric_name=$(echo "$metric_json" | jq -r '.MetricName')
            
            # Check if any alarms use this metric for this instance
            local metric_alarms
            metric_alarms=$(aws cloudwatch describe-alarms-for-metric \
                --namespace AWS/EC2 \
                --metric-name "$metric_name" \
                --dimensions Name=InstanceId,Value="$instance_id" \
                --output json 2>/dev/null)
            
            local metric_alarm_count
            metric_alarm_count=$(echo "$metric_alarms" | jq '.MetricAlarms | length')
            
            if [ "$metric_alarm_count" -gt 0 ]; then
                print_status "$GREEN" "Found $metric_alarm_count alarm(s) for metric: $metric_name"
                
                while read -r alarm_json; do
                    # Skip empty lines
                    [ -z "$alarm_json" ] && continue
                    
                    # Check if we've already found this alarm
                    local alarm_name
                    alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName')
                    
                    # Check if we've already logged this alarm
                    local already_found=0
                    for found in "${found_alarms[@]}"; do
                        if echo "$found" | jq -r '.AlarmName' | grep -q "^${alarm_name}$"; then
                            already_found=1
                            break
                        fi
                    done
                    
                    if [ $already_found -eq 0 ]; then
                        print_status "$GREEN" "✓ Found new alarm via metric: $alarm_name"
                        
                        # Log directly to CSV
                        process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
                        alarm_count=$((alarm_count + 1))
                        found_alarms+=("$alarm_json")
                    fi
                done < <(echo "$metric_alarms" | jq -c '.MetricAlarms[]')
            fi
        done < <(echo "$instance_metrics" | jq -c '.Metrics[]')
    fi
    
    # Final check - direct CLI call
    print_status "$YELLOW" "Final check - AWS CLI direct search..."
    
    # Use a different pattern with raw CLI
    local raw_alarms
    raw_alarms=$(aws cloudwatch describe-alarms \
        --output text \
        --query 'MetricAlarms[*].[AlarmName]' 2>/dev/null)
    
    echo "$raw_alarms" | while read -r raw_alarm_name; do
        # Skip empty lines
        [ -z "$raw_alarm_name" ] && continue
        
        # Check if we've already found this alarm
        local already_found=0
        for found in "${found_alarms[@]}"; do
            if echo "$found" | jq -r '.AlarmName' | grep -q "^${raw_alarm_name}$"; then
                already_found=1
                break
            fi
        done
        
        if [ $already_found -eq 0 ]; then
            # Get details for this alarm
            local alarm_details
            alarm_details=$(aws cloudwatch describe-alarms \
                --alarm-names "$raw_alarm_name" \
                --output json 2>/dev/null)
            
            # Check if this alarm is for our instance
            if echo "$alarm_details" | grep -q "$instance_id"; then
                print_status "$GREEN" "✓ Found new alarm via name search: $raw_alarm_name"
                
                # Extract alarm JSON
                local alarm_json
                alarm_json=$(echo "$alarm_details" | jq '.MetricAlarms[0]')
                
                # Log directly to CSV
                process_alarm_for_csv "$alarm_json" "$instance_id" "$instance_name" "$instance_state"
                alarm_count=$((alarm_count + 1))
            fi
        fi
    done
    
    # Summary for this instance
    if [ $alarm_count -eq 0 ]; then
        print_status "$YELLOW" "No CloudWatch alarms found for instance $instance_id"
        log_no_alarms_to_csv "$instance_id" "$instance_name" "$instance_state"
    else
        print_status "$GREEN" "Found $alarm_count CloudWatch alarm(s) for instance $instance_id"
    fi
    
    return $alarm_count
}

# Helper function to process alarm and add to CSV
process_alarm_for_csv() {
    local alarm_json="$1"
    local instance_id="$2"
    local instance_name="$3"
    local instance_state="$4"
    
    # Extract values with defensive coding
    local alarm_name
    local state_value
    local metric_name
    local namespace
    local state_reason
    local state_updated
    local actions_enabled
    
    alarm_name=$(echo "$alarm_json" | jq -r '.AlarmName // "Unknown"')
    state_value=$(echo "$alarm_json" | jq -r '.StateValue // "Unknown"')
    metric_name=$(echo "$alarm_json" | jq -r '.MetricName // "Unknown"')
    namespace=$(echo "$alarm_json" | jq -r '.Namespace // "Unknown"')
    state_reason=$(echo "$alarm_json" | jq -r '.StateReason // "Unknown"')
    state_updated=$(echo "$alarm_json" | jq -r '.StateUpdatedTimestamp // "Unknown"')
    actions_enabled=$(echo "$alarm_json" | jq -r '.ActionsEnabled // false')
    
    # Count actions
    local alarm_actions
    local ok_actions
    local insufficient_data_actions
    
    alarm_actions=$(echo "$alarm_json" | jq '.AlarmActions // []')
    ok_actions=$(echo "$alarm_json" | jq '.OKActions // []')
    insufficient_data_actions=$(echo "$alarm_json" | jq '.InsufficientDataActions // []')
    
    local alarm_actions_count
    local ok_actions_count
    local insufficient_data_actions_count
    
    alarm_actions_count=$(echo "$alarm_actions" | jq 'length')
    ok_actions_count=$(echo "$ok_actions" | jq 'length')
    insufficient_data_actions_count=$(echo "$insufficient_data_actions" | jq 'length')
    
    # Output alarm details to console
    print_status "$GREEN" "  Alarm: $alarm_name"
    print_status "$BLUE" "  Status: $state_value"
    print_status "$BLUE" "  Metric: $metric_name"
    print_status "$BLUE" "  Namespace: $namespace"
    
    # Log to CSV
    log_to_csv "$instance_id" "$instance_name" "$instance_state" \
               "$alarm_name" "$state_value" "$metric_name" "$namespace" \
               "$actions_enabled" "$alarm_actions_count" "$ok_actions_count" \
               "$insufficient_data_actions_count" "$state_reason" "$state_updated"
}

# Function to display progress
show_progress() {
    local total_instances="$1"
    local current_batch="$2"
    local total_batches="$3"
    
    if [[ -f "$PROGRESS_FILE" ]]; then
        local processed_instances
        processed_instances=$(grep -c "INSTANCE:" "$PROGRESS_FILE" 2>/dev/null || echo "0")
        local progress_percent
        progress_percent=$(( processed_instances * 100 / total_instances ))
        
        printf "\r🔄 Progress: %d%% (%d/%d instances) - Batch %d/%d" \
            "$progress_percent" "$processed_instances" "$total_instances" "$current_batch" "$total_batches"
    fi
}

# Enhanced function to generate summary report with batch statistics
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
        
        # Statistics
        echo ""
        print_status $BLUE "Alarm Status Summary:"
        local ok_count
        local alarm_count
        local insufficient_count
        local no_alarms_count
        local actions_enabled_count
        local actions_disabled_count
        
        ok_count=$(grep -c ',"OK",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        alarm_count=$(grep -c ',"ALARM",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        insufficient_count=$(grep -c ',"INSUFFICIENT_DATA",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        no_alarms_count=$(grep -c ',"No Alarms Found",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        actions_enabled_count=$(grep -c ',"true",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        actions_disabled_count=$(grep -c ',"false",' "$RESULTS_CSV" 2>/dev/null || echo "0")
        
        echo "  ✅ OK Status: $ok_count"
        echo "  🚨 ALARM Status: $alarm_count"
        echo "  ❓ Insufficient Data: $insufficient_count"
        echo "  ❌ No Alarms: $no_alarms_count"
        echo "  🔔 Actions Enabled: $actions_enabled_count"
        echo "  🔕 Actions Disabled: $actions_disabled_count"
    fi
    
    # Clean up progress file
    [[ -f "$PROGRESS_FILE" ]] && rm -f "$PROGRESS_FILE"
    
    log_message "Summary - Instances: $total_instances, Total alarms: $total_alarms"
}

# Simplified function to process a batch of instances (now using individual processing)
process_instance_batch() {
    local batch_num="$1"
    local total_batches="$2"
    shift 2
    local instance_ids=("$@")
    local batch_size=${#instance_ids[@]}
    
    print_status $YELLOW "Processing batch $batch_num of $total_batches (${batch_size} instances)..."
    
    local batch_processed=0
    local batch_alarms=0
    
    # Process each instance individually for better reliability
    for instance_id in "${instance_ids[@]}"; do
        if validate_instance_id "$instance_id"; then
            local alarm_count
            alarm_count=$(process_single_instance "$instance_id")
            batch_alarms=$((batch_alarms + alarm_count))
        else
            print_status $RED "Skipping invalid instance ID: $instance_id"
            log_error_to_csv "$instance_id" "Invalid instance ID format"
        fi
        
        batch_processed=$((batch_processed + 1))
        
        # Update progress
        echo "BATCH:$batch_num:INSTANCE:$batch_processed:$batch_size" >> "$PROGRESS_FILE"
        
        # Small delay to avoid API throttling
        sleep 0.5
    done
    
    print_status $GREEN "Batch $batch_num completed: $batch_processed instances, $batch_alarms alarms"
    echo "BATCH:$batch_num:COMPLETE:$batch_processed:$batch_alarms" >> "$PROGRESS_FILE"
}

# Error handling
trap 'print_status $RED "Script interrupted or failed. Check $LOG_FILE for details."' ERR

# Main function - REWRITTEN FOR RELIABILITY
main() {
    print_status "$BLUE" "CloudWatch Alerts Status Checker for EC2 Instances"
    print_status "$BLUE" "=================================================="
    print_status "$BLUE" "Running on: $OSTYPE"
    print_status "$BLUE" "Checking AWS CloudWatch alerts for EC2 instances"
    echo ""
    
    # Check prerequisites
    if ! command -v aws &>/dev/null; then
        print_status "$RED" "ERROR: AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        print_status "$RED" "ERROR: jq is not installed"
        exit 1
    fi
    
    # Test AWS connectivity
    if ! aws sts get-caller-identity &>/dev/null; then
        print_status "$RED" "ERROR: AWS CLI is not configured properly"
        exit 1
    else
        print_status "$GREEN" "✓ AWS CLI is configured properly"
    fi
    
    # Test jq functionality
    if ! echo '{"test":"value"}' | jq -r .test &>/dev/null; then
        print_status "$RED" "ERROR: jq is not functioning properly"
        exit 1
    else
        print_status "$GREEN" "✓ jq is functioning properly"
    fi
    
    # Check if CSV file exists
    if [[ ! -f "$CSV_PATH" ]]; then
        print_status "$RED" "ERROR: CSV file not found: $CSV_PATH"
        exit 1
    fi
    
    # Initialize CSV results file
    initialize_csv_results
    
    # Display AWS region
    local current_region
    current_region=$(aws configure get region 2>/dev/null || echo "unknown")
    print_status "$BLUE" "Current AWS Region: $current_region"
    
    # Show CSV contents
    print_status "$BLUE" "Input CSV file contents:"
    cat "$CSV_PATH"
    echo ""
    
    # Read instance IDs from CSV
    local all_instance_ids=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Clean the line (remove comments, leading/trailing whitespace)
        line=$(echo "$line" | sed 's/#.*//g' | sed 's/\/\/.*//g' | xargs)
        
        # Skip empty lines and header lines
        if [[ -z "$line" ]] || [[ "$line" =~ ^[Ii]nstance ]]; then
            continue
        fi
        
        # Extract instance ID
        local instance_id
        instance_id=$(echo "$line" | cut -d',' -f1 | tr -d '"' | xargs)
        
        # Validate instance ID format
        if validate_instance_id "$instance_id"; then
            all_instance_ids+=("$instance_id")
            print_status "$GREEN" "✓ Added valid instance ID: $instance_id"
        else
            print_status "$YELLOW" "Skipping invalid instance ID: $instance_id"
        fi
    done < "$CSV_PATH"
    
    # Count valid instance IDs
    local valid_count=${#all_instance_ids[@]}
    
    if [[ $valid_count -eq 0 ]]; then
        print_status "$RED" "No valid instance IDs found in CSV"
        exit 1
    fi
    
    print_status "$GREEN" "Found $valid_count valid instance IDs"
    log_message "Starting CloudWatch alerts check for $valid_count EC2 instances"
    
    # Process each instance
    local total_alarms=0
    local current=0
    
    for instance_id in "${all_instance_ids[@]}"; do
        current=$((current + 1))
        print_status "$YELLOW" "Processing instance $current of $valid_count: $instance_id"
        
        process_instance "$instance_id"
        local result=$?
        total_alarms=$((total_alarms + result))
        
        echo "Progress: $current/$valid_count instances processed"
    done

    # Final summary
    echo ""
    print_status "$BLUE" "=================================================="
    print_status "$BLUE" "SUMMARY"
    print_status "$BLUE" "=================================================="
    print_status "$GREEN" "Total instances processed: $valid_count"
    print_status "$GREEN" "Total alarms found: $total_alarms"
    print_status "$GREEN" "Results saved to: $RESULTS_CSV"
    print_status "$GREEN" "Log saved to: $LOG_FILE"
    
    # Display CSV content
    if [[ -f "$RESULTS_CSV" ]]; then
        echo ""
        print_status "$BLUE" "Results CSV contents:"
        cat "$RESULTS_CSV"
    fi
}

# Run the main function
main "$@"