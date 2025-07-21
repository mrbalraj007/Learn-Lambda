#########################################################################
#  ___  ___   _     ___     _    _     ___    __ _  _  _     ___ 
# |_ _||   \ | |   | __|   /_\  | |   | _ )  / /| \| || |   | _ )
#  | | | |) || |__ | _|   / _ \ | |__ | _ \ / / | .` || |__ | _ \
# |___||___/ |____||___| /_/ \_\|____||___//_/  |_|\_||____||___/
#                                
# To learn more, see https://maxat-akbanov.com/                                
#########################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

# Define the time period (in days) to evaluate for load balancer activity
DAYS=3

log_info "Checking ALBs and NLBs for idle state (no traffic in past $DAYS days)"
echo "--------------------------------------------------------------------------"

# Calculate the time range for checking metrics
# START: Convert the date from $DAYS ago to ISO8601 format (YYYY-MM-DDTHH:MM:SSZ) in UTC
START=$(date -u -d "$DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")
# END: Get the current date and time in ISO8601 format (YYYY-MM-DDTHH:MM:SSZ) in UTC
END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ✅ 1. Check Application Load Balancers (ALBs)
log_info "🔍 Checking Application Load Balancers (ALB):"
# Retrieve ARNs (Amazon Resource Names) of all Application Load Balancers
# The 'aws elbv2 describe-load-balancers' command queries load balancer information
# --query filters for ALBs (Type='application') and extracts their ARNs
alb_arns=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`application`].LoadBalancerArn' --output text)

# Loop through each ALB ARN
for arn in $alb_arns; do
  # Extract the load balancer name from the ARN using basename
  lb_name=$(basename "$arn")

  # Retrieve the total request count for the ALB over the past $DAYS days
  # The 'aws cloudwatch get-metric-statistics' command fetches CloudWatch metrics
  # --namespace AWS/ApplicationELB specifies the ALB metrics namespace
  # --metric-name RequestCount measures the number of requests handled by the ALB
  # --dimensions filters metrics for the specific load balancer
  # --statistics Sum computes the total sum of requests
  # --period 86400 sets the metric granularity to daily (86400 seconds = 1 day)
  # --start-time and --end-time define the time range (last $DAYS days to now)
  # --query extracts the Sum values from the Datapoints
  # The output is piped to awk to calculate the total sum across all datapoints
  count=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value=$lb_name \
    --statistics Sum \
    --period 86400 \
    --start-time "$START" \
    --end-time "$END" \
    --query 'Datapoints[*].Sum' --output text | awk '{ sum+=$1 } END { print sum }')

  # Check if the request count is empty or less than 1 (indicating no traffic)
  # The comparison uses bc (basic calculator) to handle floating-point numbers
  if [ -z "$count" ] || (( $(echo "$count < 1" | bc -l) )); then
    # Log a warning if the ALB is idle (no requests in the past $DAYS days)
    log_warn "Idle ALB: $lb_name — RequestCount: 0"
  else
    # Log a success message if the ALB is active, including the total request count
    log_success "Active ALB: $lb_name — Requests in last $DAYS days: $count"
  fi
done

# ✅ 2. Check Network Load Balancers (NLBs)
log_info "🔍 Checking Network Load Balancers (NLB):"
# Retrieve ARNs of all Network Load Balancers
# The 'aws elbv2 describe-load-balancers' command queries load balancer information
# --query filters for NLBs (Type='network') and extracts their ARNs
# --output text formats the output as plain text
nlb_arns=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`network`].LoadBalancerArn' --output text)

# Loop through each NLB ARN
for arn in $nlb_arns; do
  # Extract the load balancer name from the ARN using basename
  lb_name=$(basename "$arn")

  # Retrieve the total active flow count for the NLB over the past $DAYS days
  # The 'aws cloudwatch get-metric-statistics' command fetches CloudWatch metrics
  # --namespace AWS/NetworkELB specifies the NLB metrics namespace
  # --metric-name ActiveFlowCount measures the number of active TCP/UDP flows
  # --dimensions filters metrics for the specific load balancer
  # --statistics Sum computes the total sum of flows
  # --period 86400 sets the metric granularity to daily (86400 seconds = 1 day)
  # --start-time and --end-time define the time range (last $DAYS days to now)
  # --query extracts the Sum values from the Datapoints
  # The output is piped to awk to calculate the total sum across all datapoints
  count=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/NetworkELB \
    --metric-name ActiveFlowCount \
    --dimensions Name=LoadBalancer,Value=$lb_name \
    --statistics Sum \
    --period 86400 \
    --start-time "$START" \
    --end-time "$END" \
    --query 'Datapoints[*].Sum' --output text | awk '{ sum+=$1 } END { print sum }')

  # Check if the flow count is empty or less than 1 (indicating no traffic)
  # The comparison uses bc to handle floating-point numbers
  if [ -z "$count" ] || (( $(echo "$count < 1" | bc -l) )); then
    # Log a warning if the NLB is idle (no active flows in the past $DAYS days)
    log_warn "Idle NLB: $lb_name — ActiveFlowCount: 0"
  else
    # Log a success message if the NLB is active, including the total flow count
    log_success "Active NLB: $lb_name — Flows in last $DAYS days: $count"
  fi
done

log_success "Load balancer traffic audit completed."