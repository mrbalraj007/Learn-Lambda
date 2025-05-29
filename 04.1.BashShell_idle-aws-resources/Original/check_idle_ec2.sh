####################################################
#  ___     _  _        ___  ___  ___ 
# |_ _| __| || | ___  | __|/ __||_  )
#  | | / _` || |/ -_) | _|| (__  / / 
# |___|\__,_||_|\___| |___|\___|/___|
#
# To learn more, see https://maxat-akbanov.com/
####################################################                                    

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

log_info "Checking for idle or oversized EC2 instances in $REGION"
echo "------------------------------------------------------------"

# Define threshold for CPU utilization (in percent) below which an instance is considered idle
CPU_THRESHOLD=10
# Define the time period (in days) to evaluate CPU utilization
DAYS=3

# Retrieve a list of running EC2 instance IDs
instance_ids=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

# Check if no running instances were found (instance_ids is empty)
if [ -z "$instance_ids" ]; then
  log_warn "No running EC2 instances found."
  exit 0
fi

# Loop through each instance ID retrieved
for id in $instance_ids; do
  # Retrieve the instance type for the current instance
  instance_type=$(aws ec2 describe-instances \
    --instance-ids "$id" \
    --query 'Reservations[0].Instances[0].InstanceType' \
    --output text)

  # Retrieve the average CPU utilization for the instance over the specified period
  # The 'aws cloudwatch get-metric-statistics' command fetches CloudWatch metrics
  # --namespace AWS/EC2 specifies the EC2 metrics namespace
  # --metric-name CPUUtilization specifies the CPU usage metric
  # --dimensions filters metrics for the specific instance ID
  # --statistics Average computes the average value
  # --period 86400 sets the metric granularity to daily (86400 seconds = 1 day)
  # --start-time and --end-time define the time range (last $DAYS days to now)
  # --query extracts the Average values from the Datapoints
  # The output is piped to awk to calculate the overall average across all datapoints
  # If no datapoints exist, awk returns 0
  avg_cpu=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=$id \
    --statistics Average \
    --period 86400 \
    --start-time $(date -u -d "$DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ") \
    --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --query 'Datapoints[*].Average' --output text | awk '{ sum+=$1; count++ } END { if (count > 0) print sum/count; else print 0 }')

  # Check if the average CPU utilization is below the defined threshold
  # The comparison is done using bc (basic calculator) to handle floating-point numbers
  if (( $(echo "$avg_cpu < $CPU_THRESHOLD" | bc -l) )); then
    log_warn "Idle Instance: $id ($instance_type) — Avg CPU: ${avg_cpu}%"
  else
    log_success "Active Instance: $id ($instance_type) — Avg CPU: ${avg_cpu}%"
  fi
done

echo
log_info "👉 Tip: For detailed right-sizing recommendations, check AWS Compute Optimizer:"
log_info "https://console.aws.amazon.com/compute-optimizer/home"