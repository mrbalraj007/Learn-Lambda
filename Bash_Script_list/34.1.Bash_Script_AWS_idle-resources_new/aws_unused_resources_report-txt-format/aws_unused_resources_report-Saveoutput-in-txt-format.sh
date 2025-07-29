#!/bin/bash

# Ensure AWS CLI is installed and configured before running
DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="aws-unused-report-$DATE"
mkdir -p "$OUTPUT_DIR"

# Function to write section headers
print_header() {
    echo -e "\n========== $1 ==========\n"
}

# 1. Unattached EBS Volumes
print_header "Unattached EBS Volumes" | tee "$OUTPUT_DIR/ebs-unattached.txt"
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query "Volumes[*].{ID:VolumeId,Size:Size,AZ:AvailabilityZone,Type:VolumeType,CreateTime:CreateTime}" \
  --output table | tee -a "$OUTPUT_DIR/ebs-unattached.txt"

# 2. Stopped EC2 Instances
print_header "Stopped EC2 Instances" | tee "$OUTPUT_DIR/ec2-stopped.txt"
aws ec2 describe-instances --filters Name=instance-state-name,Values=stopped \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,LaunchTime:LaunchTime}' \
  --output table | tee -a "$OUTPUT_DIR/ec2-stopped.txt"

# 3. Unused Elastic IPs
print_header "Unused Elastic IPs" | tee "$OUTPUT_DIR/eip-unused.txt"
aws ec2 describe-addresses --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" --output table | tee -a "$OUTPUT_DIR/eip-unused.txt"

# 4. Unassociated Security Groups
print_header "Unassociated Security Groups" | tee "$OUTPUT_DIR/sg-unused.txt"
aws ec2 describe-security-groups \
  --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" --output text | while read -r sg_id sg_name; do
    attached=$(aws ec2 describe-network-interfaces --filters Name=group-id,Values=$sg_id --query 'NetworkInterfaces' --output text)
    if [[ -z "$attached" ]]; then
      echo -e "$sg_id\t$sg_name" | tee -a "$OUTPUT_DIR/sg-unused.txt"
    fi
done

# 5. Old AMIs not associated with running instances
print_header "Old Unused AMIs" | tee "$OUTPUT_DIR/ami-unused.txt"
aws ec2 describe-images --owners self \
  --query "Images[*].{ID:ImageId,Name:Name,CreationDate:CreationDate}" --output table | tee -a "$OUTPUT_DIR/ami-unused.txt"

# 6. Unused Load Balancers (ELBv2 with no registered targets)
print_header "Unused Load Balancers" | tee "$OUTPUT_DIR/elb-unused.txt"
for elb in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text); do
  target_arns=$(aws elbv2 describe-target-groups --load-balancer-arn "$elb" --query 'TargetGroups[*].TargetGroupArn' --output text)
  for tg in $target_arns; do
    count=$(aws elbv2 describe-target-health --target-group-arn "$tg" --query 'TargetHealthDescriptions' --output text | wc -l)
    if [[ "$count" -eq 0 ]]; then
      echo "Unused Load Balancer ARN: $elb" | tee -a "$OUTPUT_DIR/elb-unused.txt"
    fi
  done
done

# 7. Empty S3 Buckets
print_header "Empty S3 Buckets" | tee "$OUTPUT_DIR/s3-empty.txt"
for bucket in $(aws s3api list-buckets --query 'Buckets[*].Name' --output text); do
  count=$(aws s3api list-objects --bucket "$bucket" --query 'Contents' --output text 2>/dev/null | wc -l)
  if [[ "$count" -eq 0 ]]; then
    echo "$bucket" | tee -a "$OUTPUT_DIR/s3-empty.txt"
  fi
done

# 8. IAM Users without activity (last 90 days)
print_header "Inactive IAM Users (90 days)" | tee "$OUTPUT_DIR/iam-inactive-users.txt"
echo "Checking IAM users..." | tee -a "$OUTPUT_DIR/iam-inactive-users.txt"
if ! aws iam list-users --no-verify-ssl --query 'Users[*].UserName' --output text 2>/dev/null | while read user; do
  if [[ -n "$user" ]]; then
    last_used=$(aws iam get-user --no-verify-ssl --user-name "$user" --query 'User.PasswordLastUsed' --output text 2>/dev/null)
    if [[ "$last_used" == "None" ]] || [[ "$last_used" < $(date -d '-90 days' +%Y-%m-%d) ]]; then
      echo "$user - Last Used: $last_used" | tee -a "$OUTPUT_DIR/iam-inactive-users.txt"
    fi
  fi
done; then
  echo "SSL certificate error encountered. Skipping IAM user check." | tee -a "$OUTPUT_DIR/iam-inactive-users.txt"
  echo "To fix: Update AWS CLI, configure certificates, or use --no-verify-ssl flag" | tee -a "$OUTPUT_DIR/iam-inactive-users.txt"
fi

# 9. Route 53 Unused Hosted Zones (manual check advised)
print_header "Route 53 Hosted Zones (manual review needed)" | tee "$OUTPUT_DIR/route53-hostedzones.txt"
echo "Checking Route53 hosted zones..." | tee -a "$OUTPUT_DIR/route53-hostedzones.txt"
if ! aws route53 list-hosted-zones --no-verify-ssl --query 'HostedZones[*].{Name:Name,ID:Id,RecordCount:ResourceRecordSetCount}' --output table 2>/dev/null | tee -a "$OUTPUT_DIR/route53-hostedzones.txt"; then
  echo "SSL certificate error encountered. Skipping Route53 check." | tee -a "$OUTPUT_DIR/route53-hostedzones.txt"
  echo "To fix: Update AWS CLI, configure certificates, or use --no-verify-ssl flag" | tee -a "$OUTPUT_DIR/route53-hostedzones.txt"
fi

# 10. Classic Load Balancers (legacy) with no instances
print_header "Unattached Classic ELBs" | tee "$OUTPUT_DIR/classic-elb-unused.txt"
aws elb describe-load-balancers --query 'LoadBalancerDescriptions[?Instances==`[]`].[LoadBalancerName,DNSName]' --output table | tee -a "$OUTPUT_DIR/classic-elb-unused.txt"

# 11. RDS Instances in 'stopped' state
print_header "Stopped RDS Instances" | tee "$OUTPUT_DIR/rds-stopped.txt"
aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceStatus=='stopped'].{ID:DBInstanceIdentifier,Engine:Engine,Class:DBInstanceClass,AZ:AvailabilityZone,Storage:AllocatedStorage}" \
  --output table | tee -a "$OUTPUT_DIR/rds-stopped.txt"

# 12. RDS Manual Snapshots older than 30 days
print_header "Old RDS Manual Snapshots (>30 days)" | tee "$OUTPUT_DIR/rds-old-snapshots.txt"
aws rds describe-db-snapshots --snapshot-type manual \
  --query "DBSnapshots[?SnapshotCreateTime<'$(date -d '30 days ago' --iso-8601=seconds)'].{ID:DBSnapshotIdentifier,DBInstance:DBInstanceIdentifier,Time:SnapshotCreateTime}" \
  --output table | tee -a "$OUTPUT_DIR/rds-old-snapshots.txt"

# 13. Unused NAT Gateways (existence = cost, manual traffic review advised)
print_header "Active NAT Gateways" | tee "$OUTPUT_DIR/nat-gateways.txt"
aws ec2 describe-nat-gateways --filter Name=state,Values=available \
  --query 'NatGateways[*].{ID:NatGatewayId,Subnet:SubnetId,VPC:VpcId,CreateTime:CreateTime}' \
  --output table | tee -a "$OUTPUT_DIR/nat-gateways.txt"
echo "Note: NAT Gateways always incur hourly cost. Review CloudWatch metrics for idle traffic." | tee -a "$OUTPUT_DIR/nat-gateways.txt"

# 14. CloudWatch Alarms in OK or INSUFFICIENT_DATA for 30+ days (likely unused)
print_header "CloudWatch Alarms (possibly unused)" | tee "$OUTPUT_DIR/cloudwatch-unused-alarms.txt"
aws cloudwatch describe-alarms \
  --query 'MetricAlarms[?StateValue==`INSUFFICIENT_DATA` || StateValue==`OK`].[AlarmName,StateUpdatedTimestamp,StateValue]' \
  --output table | tee -a "$OUTPUT_DIR/cloudwatch-unused-alarms.txt"
echo "Note: Investigate these alarms - they may no longer be connected to active metrics." | tee -a "$OUTPUT_DIR/cloudwatch-unused-alarms.txt"

# echo -e "\n✅ Unused AWS Resource Audit complete. Output saved in '$OUTPUT_DIR'.\n"
