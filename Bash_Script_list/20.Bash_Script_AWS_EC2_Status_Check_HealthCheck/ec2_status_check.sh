#!/bin/bash
#
# AWS EC2 Status Check Script
# Checks EC2 instances for system and instance status check issues

# Create timestamp for filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_FILE="ec2_status_check_${TIMESTAMP}.csv"

# Add CSV header
echo "Instance ID,Instance Name,Instance Type,State,System Status,Instance Status,Issues,Region" > "${OUTPUT_FILE}"

# Determine regions to check
if [ -n "$1" ]; then
  REGIONS="$1"
else
  REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)
fi

echo "Starting EC2 status check..."

for REGION in ${REGIONS}; do
  echo "Checking region: ${REGION}"
  
  # Get all instances with their status in one API call
  aws ec2 describe-instance-status \
    --region "${REGION}" \
    --include-all-instances \
    --output json > "/tmp/ec2_status_${REGION}.json"
  
  # Get instance details for all instances in this region in one API call
  aws ec2 describe-instances \
    --region "${REGION}" \
    --output json > "/tmp/ec2_instances_${REGION}.json"
  
  # Process each instance
  jq -r '.InstanceStatuses[] | [.InstanceId, .SystemStatus.Status, .InstanceStatus.Status] | @csv' "/tmp/ec2_status_${REGION}.json" | \
  while IFS=, read -r INSTANCE_ID SYSTEM_STATUS INSTANCE_STATUS; do
    # Remove quotes
    INSTANCE_ID=$(echo "${INSTANCE_ID}" | tr -d '"')
    SYSTEM_STATUS=$(echo "${SYSTEM_STATUS}" | tr -d '"')
    INSTANCE_STATUS=$(echo "${INSTANCE_STATUS}" | tr -d '"')
    
    # Get instance details from the cached data
    INSTANCE_JSON=$(jq --arg id "${INSTANCE_ID}" '.Reservations[].Instances[] | select(.InstanceId==$id)' "/tmp/ec2_instances_${REGION}.json")
    
    INSTANCE_TYPE=$(echo "${INSTANCE_JSON}" | jq -r '.InstanceType')
    INSTANCE_STATE=$(echo "${INSTANCE_JSON}" | jq -r '.State.Name')
    
    # Try to get the instance name
    INSTANCE_NAME=$(echo "${INSTANCE_JSON}" | jq -r '.Tags[] | select(.Key=="Name") | .Value' 2>/dev/null)
    if [ -z "${INSTANCE_NAME}" ]; then
      INSTANCE_NAME="No Name"
    fi
    
    # Check for issues
    if [[ "${SYSTEM_STATUS}" != "ok" || "${INSTANCE_STATUS}" != "ok" ]]; then
      ISSUES="Yes"
    else
      ISSUES="No"
    fi
    
    # Sanitize the instance name for CSV
    INSTANCE_NAME="${INSTANCE_NAME//,/ }"
    INSTANCE_NAME="${INSTANCE_NAME//\"/\'}"
    
    # Add to CSV file
    echo "${INSTANCE_ID},\"${INSTANCE_NAME}\",${INSTANCE_TYPE},${INSTANCE_STATE},${SYSTEM_STATUS},${INSTANCE_STATUS},${ISSUES},${REGION}" >> "${OUTPUT_FILE}"
  done
  
  # Clean up temp files
  rm -f "/tmp/ec2_status_${REGION}.json" "/tmp/ec2_instances_${REGION}.json"
done

# Count the results
TOTAL_INSTANCES=$(grep -c "," "${OUTPUT_FILE}" | awk '{print $1 - 1}')  # Subtract header line
ISSUE_COUNT=$(grep -c ",Yes," "${OUTPUT_FILE}")

echo "EC2 status check scan completed."
echo "Total instances checked: ${TOTAL_INSTANCES}"
echo "Instances with issues: ${ISSUE_COUNT}"
echo "Results saved to: ${OUTPUT_FILE}"
