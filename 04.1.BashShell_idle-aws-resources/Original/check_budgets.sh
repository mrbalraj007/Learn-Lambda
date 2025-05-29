###################################################################################################################### 
#    _ __      __ ___   ___           _             _   
#   /_\\ \    / // __| | _ ) _  _  __| | __ _  ___ | |_ 
#  / _ \\ \/\/ / \__ \ | _ \| || |/ _` |/ _` |/ -_)|  _|
# /_/ \_\\_/\_/  |___/ |___/ \_,_|\__,_|\__, |\___| \__|
#                                       |___/           
# This script queries AWS for a list of budget names
# For each budget, checks if notifications are set up and logs appropriate messages.
# To learn more, see https://maxat-akbanov.com/
######################################################################################################################

#!/bin/bash

# Source (import) the utils.sh script from the current directory
# This contains helper functions like get_account_id, log_error, log_info, etc.
source ./utils.sh

# Retrieve AWS Account ID using a function from utils.sh and store it in ACCOUNT_ID
ACCOUNT_ID=$(get_account_id)

# Check if ACCOUNT_ID is empty (i.e., the command failed to retrieve an ID)
if [ -z "$ACCOUNT_ID" ]; then
  log_error "Failed to retrieve AWS Account ID. Is your AWS CLI configured?"
  exit 1
fi

log_info "Checking budgets for AWS Account: $ACCOUNT_ID"
echo "--------------------------------------------------"

# Retrieve a list of budget names from AWS using the AWS CLI
# The output is piped to 'jq' (a JSON processor) to extract just the BudgetName fields
budget_names=$(aws budgets describe-budgets \
  --account-id "$ACCOUNT_ID" \
  --output json | jq -r '.Budgets[].BudgetName')

# Check if no budgets were found (budget_names is empty)
if [ -z "$budget_names" ]; then
  log_warn "No budgets found for this account."
  exit 0
fi

# Loop through each budget name retrieved, using IFS (Internal Field Separator) to read lines
while IFS= read -r budget_name; do
  log_info "Budget: $budget_name"

  # Query AWS for notifications associated with the current budget
  notifications=$(aws budgets describe-notifications-for-budget \
    --account-id "$ACCOUNT_ID" \
    --budget-name "$budget_name" \
    --query 'Notifications' \
    --output text)

  # Check if no notifications were found for this budget
  if [ -z "$notifications" ]; then
    log_warn "  No alerts (notifications) configured!"
  else
    log_success "  Budget alerts are configured."
  fi

done <<< "$budget_names"