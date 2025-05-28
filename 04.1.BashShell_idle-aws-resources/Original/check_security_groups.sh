#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Scanning Security Groups for overly permissive rules"
echo "---------------------------------------------------------"

security_groups=$(aws ec2 describe-security-groups --query 'SecurityGroups[*]' --output json)

echo "$security_groups" | jq -c '.[]' | while read -r sg; do
  sg_id=$(echo "$sg" | jq -r '.GroupId')
  sg_name=$(echo "$sg" | jq -r '.GroupName')
  vpc_id=$(echo "$sg" | jq -r '.VpcId')

  echo
  log_info "🔍 Security Group: $sg_name ($sg_id) in VPC: $vpc_id"

  echo "$sg" | jq -c '.IpPermissions[]?' | while read -r rule; do
    from_port=$(echo "$rule" | jq -r '.FromPort // "All"')
    to_port=$(echo "$rule" | jq -r '.ToPort // "All"')
    protocol=$(echo "$rule" | jq -r '.IpProtocol')

    echo "$rule" | jq -r '.IpRanges[].CidrIp' | while read -r cidr; do
      if [[ "$cidr" == "0.0.0.0/0" ]]; then
        if [[ "$from_port" == "22" || "$from_port" == "3389" || "$from_port" == "All" ]]; then
          log_warn "⚠️ Open to the world on port $from_port ➜ Protocol: $protocol, CIDR: $cidr"
        else
          log_info "🌐 Open port range $from_port-$to_port to the world ➜ Protocol: $protocol, CIDR: $cidr"
        fi
      fi
    done
  done
done

log_info "✅ Security Group scan complete"
