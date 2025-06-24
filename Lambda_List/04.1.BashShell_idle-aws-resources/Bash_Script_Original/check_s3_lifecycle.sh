########################################################################################
# / __||__ / | |   (_) / _| ___  __  _  _  __ | | ___  | _ \ ___ | |(_) __ (_) ___  ___
# \__ \ |_ \ | |__ | ||  _|/ -_)/ _|| || |/ _|| |/ -_) |  _// _ \| || |/ _|| |/ -_)(_-<
# |___/|___/ |____||_||_|  \___|\__| \_, |\__||_|\___| |_|  \___/|_||_|\__||_|\___|/__/
#                                    |__/                                              
# To learn more, see https://maxat-akbanov.com/                                
########################################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

log_info "Checking S3 buckets for missing lifecycle policies in $REGION"
echo "------------------------------------------------------------------"

# Retrieve a list of all S3 bucket names in the account
buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text)

# Check if no buckets were found (buckets is empty)
if [ -z "$buckets" ]; then
  log_warn "No S3 buckets found in this account."
  exit 0
fi

# Loop through each bucket name retrieved
for bucket in $buckets; do
  # Attempt to retrieve the lifecycle configuration for the current bucket
  # The 'aws s3api get-bucket-lifecycle-configuration' command fetches lifecycle rules
  # 2>/dev/null redirects error messages (e.g., if no lifecycle policy exists) to /dev/null
  lifecycle=$(aws s3api get-bucket-lifecycle-configuration \
    --bucket "$bucket" \
    --query 'Rules' \
    --output json 2>/dev/null)

  # Check if no lifecycle policy was found or if the response is "null"
  if [ -z "$lifecycle" ] || [ "$lifecycle" == "null" ]; then
    log_warn "🗃️  Bucket without lifecycle policy: $bucket"
  else
    log_success "✅ Bucket with lifecycle policy: $bucket"
    # Parse the lifecycle rules using jq to extract and display details
    # For each rule, print the ID, Prefix (or "N/A" if not set), and Status
    echo "$lifecycle" | jq -r '.[] | "    ↳ ID: \(.ID // "N/A"), Prefix: \(.Filter.Prefix // "N/A"), Status: \(.Status)"'
  fi
done

log_success "S3 lifecycle policy check completed."