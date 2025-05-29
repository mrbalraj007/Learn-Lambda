#############################################################################
#   ___          ___                              _   ___  ___  ___ 
#  / _ \  _ _   |   \  ___  _ __   __ _  _ _   __| | | __|/ __||_  )
# | (_) || ' \  | |) |/ -_)| '  \ / _` || ' \ / _` | | _|| (__  / / 
#  \___/ |_||_| |___/ \___||_|_|_|\__,_||_||_|\__,_| |___|\___|/___|
#                                                                   
# To learn more, see https://maxat-akbanov.com/                                
#############################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

log_info "Checking for On-Demand EC2 instances in $REGION"
echo "----------------------------------------------------"

# Retrieve details of running EC2 instances
# The 'aws ec2 describe-instances' command queries instance information
# --filters limits to instances in the "running" state
# --query extracts InstanceId, InstanceType, and InstanceLifecycle for each instance
#   - InstanceLifecycle indicates if the instance is On-Demand (null), Spot, or Scheduled
instances=$(aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,Lifecycle:InstanceLifecycle}' \
  --output json)

# Parse the instances JSON using jq to identify On-Demand instances
# Select instances where Lifecycle is null (indicating On-Demand)
# For each On-Demand instance, print a warning with the instance ID and type, using a money bag emoji
echo "$instances" | jq -r '.[][] | select(.Lifecycle == null) | "💸 On-Demand Instance: \(.ID) (\(.Type))"'

# Count the number of On-Demand instances separately
# jq filters instances where Lifecycle is null, creates an array, and counts its length
count=$(echo "$instances" | jq '[.[][] | select(.Lifecycle == null)] | length')

# Check if no On-Demand instances were found (count is 0)
if [ "$count" -eq 0 ]; then
  log_success "No On-Demand instances detected."
else
  log_warn "Total On-Demand instances: $count"
  log_info "Consider using Reserved Instances or Savings Plans to save costs."
fi