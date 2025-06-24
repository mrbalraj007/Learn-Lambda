#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking Route 53 DNS records and hosted zones"
echo "---------------------------------------------------"

# Get list of hosted zones
hosted_zones=$(aws route53 list-hosted-zones --query 'HostedZones[*].Id' --output text)

if [ -z "$hosted_zones" ]; then
  log_warn "No Route 53 hosted zones found in account $ACCOUNT_ID."
  exit 0
fi

for zone_id_full in $hosted_zones; do
  zone_id=$(basename "$zone_id_full")

  zone_name=$(aws route53 get-hosted-zone --id "$zone_id" --query 'HostedZone.Name' --output text)
  record_count=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --query 'length(ResourceRecordSets)' --output text)

  echo
  log_info "🔍 Checking Hosted Zone: $zone_name (ID: $zone_id)"
  echo "Total Records: $record_count"

  # Check if the zone contains only NS and SOA records
  only_ns_soa=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    --query "ResourceRecordSets[?Type != 'NS' && Type != 'SOA']" --output text)

  if [ -z "$only_ns_soa" ]; then
    log_warn "⚠️  Zone $zone_name contains only NS and SOA records (may be unused)."
  fi

  # Get A and CNAME records and try to resolve them
  records=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
    --query "ResourceRecordSets[?Type=='A' || Type=='CNAME']" --output json)

  echo "$records" | jq -c '.[]' | while read -r record; do
    name=$(echo "$record" | jq -r '.Name')
    type=$(echo "$record" | jq -r '.Type')
    value=$(echo "$record" | jq -r '.ResourceRecords[0].Value')

    # Try resolving the DNS record
    if host "$value" &>/dev/null; then
      log_success "✅ $type Record: $name ➜ $value is resolvable."
    else
      log_warn "❌ $type Record: $name ➜ $value is not resolvable. Potential stale/dangling record."
    fi
  done
done

echo
log_info "👉 Tip: Clean up unused zones and invalid records to reduce confusion and improve security."
log_info "🔗 Route 53 Console: https://console.aws.amazon.com/route53/v2/hostedzones"
