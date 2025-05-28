###################################################################
#  ___  ___  ___    ___  _              _   
# | __|| _ )/ __|  / __|| |_   ___  __ | |__
# | _| | _ \\__ \ | (__ | ' \ / -_)/ _|| / /
# |___||___/|___/  \___||_||_|\___|\__||_\_\
#
# To learn more, see https://maxat-akbanov.com/
###################################################################                                           

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

log_info "Checking for unattached (forgotten) EBS volumes in $REGION"
echo "---------------------------------------------------------------"

# Retrieve details of EBS volumes that are unattached (status=available)
# The 'aws ec2 describe-volumes' command queries EBS volume information
# --filters Name=status,Values=available limits to volumes not attached to any EC2 instance
# --query uses a structured JSON format to extract specific fields:
#   - ID: VolumeId (unique identifier of the volume)
#   - Size: Size (volume size in GiB)
#   - Created: CreateTime (creation timestamp of the volume)
#   - Tags: Tags (volume tags, if any)
volumes=$(aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId,Size:Size,Created:CreateTime,Tags:Tags}' \
  --output json)

# Check if no unattached volumes were found (volumes is empty or an empty array "[]")
if [ -z "$volumes" ] || [ "$volumes" == "[]" ]; then
  log_success "🧹 No unattached EBS volumes found."
  exit 0
fi

# Parse the volumes JSON and format the output using jq
# For each unattached volume, print a warning with details:
# - .ID: VolumeId (unique identifier of the volume)
# - .Size: Size (volume size in GiB)
# - .Created: CreateTime (creation timestamp of the volume)
# - .Tags: Tags (volume tags, or "None" if no tags are present, using // for null handling)
echo "$volumes" | jq -r '.[] | 
  "⚠️  Unattached EBS Volume: \(.ID)\n    ↳ Size: \(.Size) GiB\n    ↳ Created: \(.Created)\n    ↳ Tags: \(.Tags // "None")\n"'