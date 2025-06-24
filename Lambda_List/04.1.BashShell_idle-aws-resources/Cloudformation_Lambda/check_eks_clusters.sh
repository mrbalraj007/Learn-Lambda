#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking EKS clusters in region $REGION"
echo "---------------------------------------------"

clusters=$(aws eks list-clusters --query 'clusters' --output text)
if [ -z "$clusters" ]; then
  log_warn "No EKS clusters found in region $REGION."
  exit 0
fi

for cluster in $clusters; do
  echo
  log_info "🔍 Cluster: $cluster"

  # Get cluster details
  cluster_info=$(aws eks describe-cluster --name "$cluster" --query 'cluster.{Status:status,Version:version,Endpoint:endpoint,CreatedAt:createdAt}' --output json)

  status=$(echo "$cluster_info" | jq -r '.Status')
  version=$(echo "$cluster_info" | jq -r '.Version')
  endpoint=$(echo "$cluster_info" | jq -r '.Endpoint')
  created_at=$(echo "$cluster_info" | jq -r '.CreatedAt')

  log_success "✅ Status: $status"
  log_success "🔢 Version: $version"
  log_success "🌐 Endpoint: $endpoint"
  log_success "📅 Created At: $created_at"

  # Check nodegroups
  nodegroups=$(aws eks list-nodegroups --cluster-name "$cluster" --query 'nodegroups' --output text)
  if [ -z "$nodegroups" ]; then
    log_warn "⚠️ No nodegroups found for cluster $cluster."
  else
    log_info "🧱 Nodegroups:"
    for ng in $nodegroups; do
      log_success " - $ng"
    done
  fi
done

echo
log_info "👉 Tip: Review unused clusters and upgrade older versions to optimize costs and performance."
log_info "🔗 EKS Console: https://console.aws.amazon.com/eks/home"
