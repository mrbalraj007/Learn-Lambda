#!/bin/bash
# filepath: c:\Users\BalraSin\OneDrive - Jetstar Airways Pty Ltd\Balraj_D_Laptop_Drive\DevOps_Master\Learn-Lambda\Lambda_List\24.budget_alert\To_Get-All-Existing_budget_configuration\get_budget_config.sh

# AWS Budget Configuration Extractor
# This script retrieves all existing budget configurations and saves them to a CSV file

# Remove set -e to prevent script from exiting on errors
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

debug() {
    echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    error "jq is not installed. Please install it first."
    exit 1
fi

# Get AWS Account ID
log "Retrieving AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    error "Failed to retrieve AWS Account ID. Please check your AWS credentials."
    exit 1
fi

log "Account ID: $ACCOUNT_ID"

# Set output file with account ID
OUTPUT_FILE="budget_config_${ACCOUNT_ID}_$(date +%Y%m%d_%H%M%S).csv"

# Create CSV header
echo "Budget Name,Budget Type,Period,Start Date,Budget Amount,Currency,Budget Plan,Action Type,Action Threshold,Action Threshold Type,Notification Email,Cost Filter,Time Unit" > "$OUTPUT_FILE"

log "Retrieving budget list..."

# Get all budget names with better error handling
BUDGET_NAMES=$(aws budgets describe-budgets --account-id "$ACCOUNT_ID" --query "Budgets[].BudgetName" --output text 2>/dev/null)
BUDGET_STATUS=$?

if [ $BUDGET_STATUS -ne 0 ]; then
    error "Failed to retrieve budget list. Exit code: $BUDGET_STATUS"
    exit 1
fi

if [ -z "$BUDGET_NAMES" ]; then
    warn "No budgets found in the account."
    log "CSV file created with headers only: $OUTPUT_FILE"
    exit 0
fi

log "Found budgets: $BUDGET_NAMES"

# Process each budget
for BUDGET_NAME in $BUDGET_NAMES; do
    log "Processing budget: $BUDGET_NAME"
    
    # Get budget details with explicit error handling
    BUDGET_DETAILS=$(aws budgets describe-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" --output json 2>/dev/null)
    BUDGET_DETAIL_STATUS=$?
    
    if [ $BUDGET_DETAIL_STATUS -ne 0 ] || [ -z "$BUDGET_DETAILS" ]; then
        error "Failed to retrieve details for budget: $BUDGET_NAME (Exit code: $BUDGET_DETAIL_STATUS)"
        continue
    fi
    
    debug "Budget details retrieved successfully for: $BUDGET_NAME"
    
    # Extract budget information with explicit checks
    BUDGET_TYPE=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.BudgetType // "N/A"' 2>/dev/null)
    [ -z "$BUDGET_TYPE" ] && BUDGET_TYPE="N/A"
    
    PERIOD=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.TimeUnit // "N/A"' 2>/dev/null)
    [ -z "$PERIOD" ] && PERIOD="N/A"
    
    START_DATE=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.TimePeriod.Start // "N/A"' 2>/dev/null)
    [ -z "$START_DATE" ] && START_DATE="N/A"
    
    BUDGET_AMOUNT=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.BudgetLimit.Amount // "N/A"' 2>/dev/null)
    [ -z "$BUDGET_AMOUNT" ] && BUDGET_AMOUNT="N/A"
    
    CURRENCY=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.BudgetLimit.Unit // "N/A"' 2>/dev/null)
    [ -z "$CURRENCY" ] && CURRENCY="N/A"
    
    # Extract cost filters
    COST_FILTER=$(echo "$BUDGET_DETAILS" | jq -r '.Budget.CostFilters | if . then keys | join(";") else "N/A" end' 2>/dev/null)
    [ -z "$COST_FILTER" ] && COST_FILTER="N/A"
    
    debug "Extracted values - Type: $BUDGET_TYPE, Amount: $BUDGET_AMOUNT, Currency: $CURRENCY"
    
    # Get budget notifications
    NOTIFICATION_EMAILS="N/A"
    NOTIFICATIONS=$(aws budgets describe-budget-notifications --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" --output json 2>/dev/null)
    NOTIFICATION_STATUS=$?
    
    if [ $NOTIFICATION_STATUS -eq 0 ] && [ -n "$NOTIFICATIONS" ]; then
        NOTIFICATION_COUNT=$(echo "$NOTIFICATIONS" | jq '.Notifications | length' 2>/dev/null)
        debug "Found $NOTIFICATION_COUNT notifications for budget: $BUDGET_NAME"
        
        if [ "$NOTIFICATION_COUNT" -gt 0 ]; then
            # Try to get subscribers for the first notification
            FIRST_NOTIFICATION=$(echo "$NOTIFICATIONS" | jq -r '.Notifications[0]' 2>/dev/null)
            if [ -n "$FIRST_NOTIFICATION" ] && [ "$FIRST_NOTIFICATION" != "null" ]; then
                NOTIFICATION_TYPE=$(echo "$FIRST_NOTIFICATION" | jq -r '.NotificationType' 2>/dev/null)
                COMPARISON_OP=$(echo "$FIRST_NOTIFICATION" | jq -r '.ComparisonOperator' 2>/dev/null)
                THRESHOLD=$(echo "$FIRST_NOTIFICATION" | jq -r '.Threshold' 2>/dev/null)
                
                debug "Notification details - Type: $NOTIFICATION_TYPE, Operator: $COMPARISON_OP, Threshold: $THRESHOLD"
                
                SUBSCRIBERS=$(aws budgets describe-subscribers-for-notification --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" --notification "{\"NotificationType\":\"$NOTIFICATION_TYPE\",\"ComparisonOperator\":\"$COMPARISON_OP\",\"Threshold\":$THRESHOLD}" --output json 2>/dev/null)
                SUBSCRIBER_STATUS=$?
                
                if [ $SUBSCRIBER_STATUS -eq 0 ] && [ -n "$SUBSCRIBERS" ]; then
                    EMAILS=$(echo "$SUBSCRIBERS" | jq -r '.Subscribers[]? | select(.SubscriptionType == "EMAIL") | .Address' 2>/dev/null)
                    if [ -n "$EMAILS" ]; then
                        NOTIFICATION_EMAILS=$(echo "$EMAILS" | tr '\n' ';' | sed 's/;$//')
                        debug "Found notification emails: $NOTIFICATION_EMAILS"
                    fi
                fi
            fi
        fi
    fi
    
    # Get budget actions
    ACTIONS=$(aws budgets describe-budget-actions-for-budget --account-id "$ACCOUNT_ID" --budget-name "$BUDGET_NAME" --output json 2>/dev/null)
    ACTION_STATUS=$?
    
    if [ $ACTION_STATUS -ne 0 ]; then
        ACTIONS='{"Actions":[]}'
        debug "No actions found or error retrieving actions for budget: $BUDGET_NAME"
    fi
    
    ACTION_COUNT=$(echo "$ACTIONS" | jq '.Actions | length' 2>/dev/null)
    [ -z "$ACTION_COUNT" ] && ACTION_COUNT=0
    
    debug "Found $ACTION_COUNT actions for budget: $BUDGET_NAME"
    
    # If no actions, create a single row with budget info
    if [ "$ACTION_COUNT" -eq 0 ]; then
        CSV_LINE="\"$BUDGET_NAME\",\"$BUDGET_TYPE\",\"$PERIOD\",\"$START_DATE\",\"$BUDGET_AMOUNT\",\"$CURRENCY\",\"Notification Only\",\"N/A\",\"N/A\",\"N/A\",\"$NOTIFICATION_EMAILS\",\"$COST_FILTER\",\"$PERIOD\""
        echo "$CSV_LINE" >> "$OUTPUT_FILE"
        log "Added budget row for: $BUDGET_NAME"
        debug "CSV line: $CSV_LINE"
    else
        # Process each action
        ACTIONS_ARRAY=$(echo "$ACTIONS" | jq -r '.Actions[] | @json' 2>/dev/null)
        
        ACTION_PROCESSED=0
        while IFS= read -r action; do
            if [ -n "$action" ] && [ "$action" != "null" ]; then
                ACTION_TYPE=$(echo "$action" | jq -r '.ActionType // "N/A"' 2>/dev/null)
                ACTION_THRESHOLD=$(echo "$action" | jq -r '.ActionThreshold.ActionThresholdValue // "N/A"' 2>/dev/null)
                ACTION_THRESHOLD_TYPE=$(echo "$action" | jq -r '.ActionThreshold.ActionThresholdType // "N/A"' 2>/dev/null)
                
                # Extract notification emails from action definition
                ACTION_EMAILS=$(echo "$action" | jq -r '.Definition.IamActionDefinition.Users[]? // .Definition.ScpActionDefinition.TargetIds[]? // .Definition.SsmActionDefinition.TargetIds[]? // empty' 2>/dev/null | tr '\n' ';' | sed 's/;$//')
                
                # Use budget notification emails if action emails are empty
                if [ -z "$ACTION_EMAILS" ]; then
                    ACTION_EMAILS="$NOTIFICATION_EMAILS"
                fi
                
                # Determine budget plan based on action type
                case "$ACTION_TYPE" in
                    "APPLY_IAM_POLICY")
                        BUDGET_PLAN="IAM Policy Action"
                        ;;
                    "APPLY_SCP_POLICY")
                        BUDGET_PLAN="SCP Policy Action"
                        ;;
                    "RUN_SSM_DOCUMENTS")
                        BUDGET_PLAN="SSM Document Action"
                        ;;
                    *)
                        BUDGET_PLAN="Custom Action"
                        ;;
                esac
                
                CSV_LINE="\"$BUDGET_NAME\",\"$BUDGET_TYPE\",\"$PERIOD\",\"$START_DATE\",\"$BUDGET_AMOUNT\",\"$CURRENCY\",\"$BUDGET_PLAN\",\"$ACTION_TYPE\",\"$ACTION_THRESHOLD\",\"$ACTION_THRESHOLD_TYPE\",\"$ACTION_EMAILS\",\"$COST_FILTER\",\"$PERIOD\""
                echo "$CSV_LINE" >> "$OUTPUT_FILE"
                ACTION_PROCESSED=$((ACTION_PROCESSED + 1))
                debug "Added action row: $CSV_LINE"
            fi
        done <<< "$ACTIONS_ARRAY"
        
        log "Added $ACTION_PROCESSED action rows for budget: $BUDGET_NAME"
    fi
done

log "Budget configuration exported successfully to: $OUTPUT_FILE"
log "Total budgets processed: $(echo $BUDGET_NAMES | wc -w)"
log "Account ID: $ACCOUNT_ID (included in filename)"

# Display summary
TOTAL_ROWS=$(($(wc -l < "$OUTPUT_FILE") - 1))
log "Total rows in CSV (excluding header): $TOTAL_ROWS"

# Show first few lines of the CSV for verification
log "First 5 lines of the CSV file:"
head -n 5 "$OUTPUT_FILE"

echo
log "Script completed successfully!"
echo -e "${GREEN}Output file: $OUTPUT_FILE${NC}"
echo -e "${GREEN}Account ID: $ACCOUNT_ID${NC}"