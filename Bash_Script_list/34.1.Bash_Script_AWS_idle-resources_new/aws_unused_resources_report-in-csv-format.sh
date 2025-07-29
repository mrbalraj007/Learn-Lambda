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
print_header "Unattached EBS Volumes"
echo "VolumeId,Size,AvailabilityZone,VolumeType,CreateTime" > "$OUTPUT_DIR/ebs-unattached.csv"
if aws ec2 describe-volumes --no-verify-ssl --filters Name=status,Values=available \
  --query "Volumes[*].[VolumeId,Size,AvailabilityZone,VolumeType,CreateTime]" \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/ebs-unattached.csv"; then
  echo "EBS volumes check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/ebs-unattached.csv"
fi

# 2. Stopped EC2 Instances
print_header "Stopped EC2 Instances"
echo "InstanceId,InstanceType,LaunchTime" > "$OUTPUT_DIR/ec2-stopped.csv"
if aws ec2 describe-instances --no-verify-ssl --filters Name=instance-state-name,Values=stopped \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime]' \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/ec2-stopped.csv"; then
  echo "EC2 instances check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/ec2-stopped.csv"
fi

# 3. Unused Elastic IPs
print_header "Unused Elastic IPs"
echo "PublicIp,AllocationId" > "$OUTPUT_DIR/eip-unused.csv"
if aws ec2 describe-addresses --no-verify-ssl --query "Addresses[?AssociationId==null].[PublicIp,AllocationId]" \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/eip-unused.csv"; then
  echo "Elastic IPs check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/eip-unused.csv"
fi

# 4. Unassociated Security Groups
print_header "Unassociated Security Groups"
echo "GroupId,GroupName" > "$OUTPUT_DIR/sg-unused.csv"
echo "Checking security groups..."
if aws ec2 describe-security-groups --no-verify-ssl \
  --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" --output text 2>/dev/null | while read -r sg_id sg_name; do
    if [[ -n "$sg_id" ]]; then
      attached=$(aws ec2 describe-network-interfaces --no-verify-ssl --filters Name=group-id,Values=$sg_id --query 'NetworkInterfaces' --output text 2>/dev/null)
      if [[ -z "$attached" ]]; then
        echo "$sg_id,$sg_name" >> "$OUTPUT_DIR/sg-unused.csv"
      fi
    fi
done; then
  echo "Security groups check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/sg-unused.csv"
fi

# 5. Old AMIs not associated with running instances
print_header "Old Unused AMIs"
echo "ImageId,Name,CreationDate" > "$OUTPUT_DIR/ami-unused.csv"
if aws ec2 describe-images --no-verify-ssl --owners self \
  --query "Images[*].[ImageId,Name,CreationDate]" \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/ami-unused.csv"; then
  echo "AMIs check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/ami-unused.csv"
fi

# 6. Unused Load Balancers (ELBv2 with no registered targets)
print_header "Unused Load Balancers"
echo "LoadBalancerArn,LoadBalancerName,Type" > "$OUTPUT_DIR/elb-unused.csv"
echo "Checking load balancers..."
if elb_list=$(aws elbv2 describe-load-balancers --no-verify-ssl --query 'LoadBalancers[*].LoadBalancerArn' --output text 2>/dev/null); then
  for elb in $elb_list; do
    if [[ -n "$elb" ]]; then
      target_arns=$(aws elbv2 describe-target-groups --no-verify-ssl --load-balancer-arn "$elb" --query 'TargetGroups[*].TargetGroupArn' --output text 2>/dev/null)
      has_targets=false
      for tg in $target_arns; do
        if [[ -n "$tg" ]]; then
          count=$(aws elbv2 describe-target-health --no-verify-ssl --target-group-arn "$tg" --query 'TargetHealthDescriptions' --output text 2>/dev/null | wc -l)
          if [[ "$count" -gt 0 ]]; then
            has_targets=true
            break
          fi
        fi
      done
      if [[ "$has_targets" == false ]]; then
        elb_info=$(aws elbv2 describe-load-balancers --no-verify-ssl --load-balancer-arns "$elb" --query 'LoadBalancers[0].[LoadBalancerArn,LoadBalancerName,Type]' --output text 2>/dev/null | sed 's/\t/,/g')
        if [[ -n "$elb_info" ]]; then
          echo "$elb_info" >> "$OUTPUT_DIR/elb-unused.csv"
        fi
      fi
    fi
  done
  echo "Load balancers check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/elb-unused.csv"
fi

# 8. IAM Users without activity (last 90 days)
print_header "Inactive IAM Users (90 days)"
echo "UserName,PasswordLastUsed,CreateDate" > "$OUTPUT_DIR/iam-inactive-users.csv"
echo "Checking IAM users..."
if aws iam list-users --no-verify-ssl --query 'Users[*].[UserName,PasswordLastUsed,CreateDate]' --output text 2>/dev/null | while read -r user last_used create_date; do
  if [[ -n "$user" ]]; then
    if [[ "$last_used" == "None" ]] || [[ "$last_used" < $(date -d '-90 days' +%Y-%m-%d) ]]; then
      echo "$user,$last_used,$create_date" >> "$OUTPUT_DIR/iam-inactive-users.csv"
    fi
  fi
done; then
  echo "IAM users check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/iam-inactive-users.csv"
fi

# 9. Route 53 Unused Hosted Zones (manual check advised)
print_header "Route 53 Hosted Zones (manual review needed)"
echo "HostedZoneName,HostedZoneId,ResourceRecordSetCount" > "$OUTPUT_DIR/route53-hostedzones.csv"
echo "Checking Route53 hosted zones..."
if aws route53 list-hosted-zones --no-verify-ssl --query 'HostedZones[*].[Name,Id,ResourceRecordSetCount]' --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/route53-hostedzones.csv"; then
  echo "Route53 hosted zones check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/route53-hostedzones.csv"
fi

# 10. Classic Load Balancers (legacy) with no instances
print_header "Unattached Classic ELBs"
echo "LoadBalancerName,DNSName" > "$OUTPUT_DIR/classic-elb-unused.csv"
if aws elb describe-load-balancers --no-verify-ssl --query 'LoadBalancerDescriptions[?Instances==`[]`].[LoadBalancerName,DNSName]' \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/classic-elb-unused.csv"; then
  echo "Classic ELBs check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/classic-elb-unused.csv"
fi

# 11. RDS Instances in 'stopped' state
print_header "Stopped RDS Instances"
echo "DBInstanceIdentifier,Engine,DBInstanceClass,AvailabilityZone,AllocatedStorage" > "$OUTPUT_DIR/rds-stopped.csv"
if aws rds describe-db-instances --no-verify-ssl \
  --query "DBInstances[?DBInstanceStatus=='stopped'].[DBInstanceIdentifier,Engine,DBInstanceClass,AvailabilityZone,AllocatedStorage]" \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/rds-stopped.csv"; then
  echo "RDS instances check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/rds-stopped.csv"
fi

# 12. RDS Manual Snapshots older than 30 days
print_header "Old RDS Manual Snapshots (>30 days)"
echo "DBSnapshotIdentifier,DBInstanceIdentifier,SnapshotCreateTime" > "$OUTPUT_DIR/rds-old-snapshots.csv"
if aws rds describe-db-snapshots --no-verify-ssl --snapshot-type manual \
  --query "DBSnapshots[?SnapshotCreateTime<'$(date -d '30 days ago' --iso-8601=seconds)'].[DBSnapshotIdentifier,DBInstanceIdentifier,SnapshotCreateTime]" \
  --output text 2>/dev/null | sed 's/\t/,/g' >> "$OUTPUT_DIR/rds-old-snapshots.csv"; then
  echo "RDS snapshots check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/rds-old-snapshots.csv"
fi

# 13. Unused NAT Gateways (existence = cost, manual traffic review advised)
print_header "Active NAT Gateways"
echo "NatGatewayId,SubnetId,VpcId,CreateTime,Note" > "$OUTPUT_DIR/nat-gateways.csv"
if aws ec2 describe-nat-gateways --no-verify-ssl --filter Name=state,Values=available \
  --query 'NatGateways[*].[NatGatewayId,SubnetId,VpcId,CreateTime]' \
  --output text 2>/dev/null | sed 's/\t/,/g' | while read -r line; do
    if [[ -n "$line" ]]; then
      echo "$line,NAT Gateways incur hourly cost - Review CloudWatch metrics for idle traffic" >> "$OUTPUT_DIR/nat-gateways.csv"
    fi
done; then
  echo "NAT Gateways check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/nat-gateways.csv"
fi

# 14. CloudWatch Alarms in OK or INSUFFICIENT_DATA for 30+ days (likely unused)
print_header "CloudWatch Alarms (possibly unused)"
echo "AlarmName,StateUpdatedTimestamp,StateValue,Note" > "$OUTPUT_DIR/cloudwatch-unused-alarms.csv"
if aws cloudwatch describe-alarms --no-verify-ssl \
  --query 'MetricAlarms[?StateValue==`INSUFFICIENT_DATA` || StateValue==`OK`].[AlarmName,StateUpdatedTimestamp,StateValue]' \
  --output text 2>/dev/null | sed 's/\t/,/g' | while read -r line; do
    if [[ -n "$line" ]]; then
      echo "$line,Investigate - may no longer be connected to active metrics" >> "$OUTPUT_DIR/cloudwatch-unused-alarms.csv"
    fi
done; then
  echo "CloudWatch alarms check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/cloudwatch-unused-alarms.csv"
fi

# 7. Empty S3 Buckets
print_header "Empty S3 Buckets"
echo "BucketName,CreationDate" > "$OUTPUT_DIR/s3-empty.csv"
echo "Checking S3 buckets..."
if bucket_list=$(aws s3api list-buckets --no-verify-ssl --query 'Buckets[*].Name' --output text 2>/dev/null); then
  for bucket in $bucket_list; do
    if [[ -n "$bucket" ]]; then
      count=$(aws s3api list-objects --no-verify-ssl --bucket "$bucket" --query 'Contents' --output text 2>/dev/null | wc -l)
      if [[ "$count" -eq 0 ]]; then
        creation_date=$(aws s3api list-buckets --no-verify-ssl --query "Buckets[?Name=='$bucket'].CreationDate" --output text 2>/dev/null)
        echo "$bucket,$creation_date" >> "$OUTPUT_DIR/s3-empty.csv"
      fi
    fi
  done
  echo "S3 buckets check completed successfully."
else
  echo "Error,SSL certificate verification failed,Please update AWS CLI or configure SSL properly" >> "$OUTPUT_DIR/s3-empty.csv"
fi

# 15. Create summary report
print_header "Creating Summary Report"
echo "ResourceType,Count,OutputFile" > "$OUTPUT_DIR/summary-report.csv"
echo "Unattached EBS Volumes,$(tail -n +2 "$OUTPUT_DIR/ebs-unattached.csv" | wc -l),ebs-unattached.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Stopped EC2 Instances,$(tail -n +2 "$OUTPUT_DIR/ec2-stopped.csv" | wc -l),ec2-stopped.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Unused Elastic IPs,$(tail -n +2 "$OUTPUT_DIR/eip-unused.csv" | wc -l),eip-unused.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Unassociated Security Groups,$(tail -n +2 "$OUTPUT_DIR/sg-unused.csv" | wc -l),sg-unused.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Old AMIs,$(tail -n +2 "$OUTPUT_DIR/ami-unused.csv" | wc -l),ami-unused.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Unused Load Balancers,$(tail -n +2 "$OUTPUT_DIR/elb-unused.csv" | wc -l),elb-unused.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Empty S3 Buckets,$(tail -n +2 "$OUTPUT_DIR/s3-empty.csv" | wc -l),s3-empty.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Inactive IAM Users,$(tail -n +2 "$OUTPUT_DIR/iam-inactive-users.csv" | wc -l),iam-inactive-users.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Route53 Hosted Zones,$(tail -n +2 "$OUTPUT_DIR/route53-hostedzones.csv" | wc -l),route53-hostedzones.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Unattached Classic ELBs,$(tail -n +2 "$OUTPUT_DIR/classic-elb-unused.csv" | wc -l),classic-elb-unused.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Stopped RDS Instances,$(tail -n +2 "$OUTPUT_DIR/rds-stopped.csv" | wc -l),rds-stopped.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Old RDS Snapshots,$(tail -n +2 "$OUTPUT_DIR/rds-old-snapshots.csv" | wc -l),rds-old-snapshots.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "Active NAT Gateways,$(tail -n +2 "$OUTPUT_DIR/nat-gateways.csv" | wc -l),nat-gateways.csv" >> "$OUTPUT_DIR/summary-report.csv"
echo "CloudWatch Alarms,$(tail -n +2 "$OUTPUT_DIR/cloudwatch-unused-alarms.csv" | wc -l),cloudwatch-unused-alarms.csv" >> "$OUTPUT_DIR/summary-report.csv"

echo -e "\n✅ Unused AWS Resource Audit complete. CSV outputs saved in '$OUTPUT_DIR'."
echo "📊 Summary report available at: $OUTPUT_DIR/summary-report.csv"
