###############################################################################################
#  | | | | _ _ | |_  __ _  __ _  __ _  ___  __| | | _ \ ___  ___ ___  _  _  _ _  __  ___  ___
#  | |_| || ' \|  _|/ _` |/ _` |/ _` |/ -_)/ _` | |   // -_)(_-</ _ \| || || '_|/ _|/ -_)(_-<
#   \___/ |_||_|\__|\__,_|\__, |\__, |\___|\__,_| |_|_\\___|/__/\___/ \_,_||_|  \__|\___|/__/
#                        |___/ |___/                                                        
# 
# To learn more, see https://maxat-akbanov.com/                                
###############################################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
log_info "Checking untagged resources for AWS Account: $ACCOUNT_ID"
echo "-------------------------------------------------------------"

# Helper function
check_tags() {
  local resource_id="$1"
  local tags="$2"
  local type="$3"

  if [ -z "$tags" ] || [ "$tags" == "[]" ] || [ "$tags" == "None" ]; then
    log_warn "  Untagged $type: $resource_id"
  else
    log_success "  Tagged $type: $resource_id"
    echo "    Tags:"
    echo "$tags" | jq -r '.[] | "      - \(.Key): \(.Value)"'
  fi
}

# ✅ EC2 Instances
log_info "🔎 Checking EC2 Instances..."
instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId' --output text)
for id in $instances; do
  tags=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$id" \
    --query 'Tags' --output json)
  check_tags "$id" "$tags" "EC2 Instance"
done

# ✅ EBS Volumes
log_info "🔎 Checking EBS Volumes..."
volumes=$(aws ec2 describe-volumes --query 'Volumes[*].VolumeId' --output text)
for id in $volumes; do
  tags=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$id" \
    --query 'Tags' --output json)
  check_tags "$id" "$tags" "EBS Volume"
done

# ✅ S3 Buckets
log_info "🔎 Checking S3 Buckets..."
buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text)
for bucket in $buckets; do
  tags=$(aws s3api get-bucket-tagging --bucket "$bucket" --query 'TagSet' --output json 2>/dev/null)
  check_tags "$bucket" "$tags" "S3 Bucket"
done

# ✅ RDS Instances
log_info "🔎 Checking RDS Instances..."
rds_instances=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output text)
for id in $rds_instances; do
  arn="arn:aws:rds:$(aws configure get region):$ACCOUNT_ID:db:$id"
  tags=$(aws rds list-tags-for-resource --resource-name "$arn" --query 'TagList' --output json)
  check_tags "$id" "$tags" "RDS Instance"
done

# ✅ Lambda Functions
log_info "🔎 Checking Lambda Functions..."
lambdas=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)
for fn in $lambdas; do
  arn=$(aws lambda get-function --function-name "$fn" --query 'Configuration.FunctionArn' --output text)
  tags=$(aws lambda list-tags --resource "$arn" --query 'Tags' --output json)
  # Convert flat map to array of key-value pairs
  formatted=$(echo "$tags" | jq -r 'to_entries | map({Key: .key, Value: .value})')
  check_tags "$fn" "$formatted" "Lambda Function"
done

log_success "Untagged resource check completed."
