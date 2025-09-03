#!/bin/bash
# =====================================================================
# Script Name: get_all_accounts_ec2.sh
# Description: Collects EC2 inventory from all AWS profiles and exports
#              into a consolidated CSV file.
# Author     : AWS Engineer
# =====================================================================

set -euo pipefail

# Input and output files
CSV_FILE="accounts.csv"
OUTPUT_FILE="ec2_inventory.csv"
TEMP_FILE=$(mktemp)
TAG_KEYS_FILE=$(mktemp)

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ Error: The CSV file '$CSV_FILE' does not exist."
    exit 1
fi

# Build profile list from accounts.csv
declare -a PROFILES
while IFS=, read -r account_id permission_set || [ -n "$account_id" ]; do
    # Skip header line
    if [ "$account_id" = "account_id" ]; then
        continue
    fi
    
    # Trim whitespace and remove carriage returns
    account_id=$(echo "$account_id" | tr -d '\r' | xargs)
    
    # Skip empty lines
    if [ -z "$account_id" ]; then
        continue
    fi
    
    profile_name="account${account_id}"
    PROFILES+=("$profile_name")
done < "$CSV_FILE"

# Verify profiles were found
if [ ${#PROFILES[@]} -eq 0 ]; then
    echo "❌ Error: No profiles found in $CSV_FILE"
    exit 1
fi

echo "🔍 Found ${#PROFILES[@]} profiles to scan:"
for profile in "${PROFILES[@]}"; do
    echo "  - $profile"
done

echo "🔍 Scanning for all unique EC2 tag keys across all accounts..."

# First pass: collect all unique tag keys
for profile in "${PROFILES[@]}"; do
  echo ">>> Collecting tag keys from profile: $profile"
  
  # Skip invalid profiles
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    echo "  Warning: Profile $profile not valid or accessible. Skipping..."
    continue
  fi

  # Get all unique tag keys from all instances
  aws ec2 describe-instances --profile "$profile" --region ap-southeast-2 --output json 2>/dev/null | \
  jq -r '.Reservations[].Instances[].Tags[]?.Key' 2>/dev/null | sort -u >> "$TAG_KEYS_FILE"
done

# Get unique tag keys in a predictable order (sort alphabetically)
readarray -t SORTED_TAG_KEYS < <(sort -u "$TAG_KEYS_FILE" | grep -v "^$")

# Prioritize 'Name' tag if it exists (move to beginning of list)
if [[ " ${SORTED_TAG_KEYS[*]} " == *" Name "* ]]; then
  # Remove 'Name' from array since we already handle it in base columns
  SORTED_TAG_KEYS=($(echo "${SORTED_TAG_KEYS[@]}" | tr ' ' '\n' | grep -v "^Name$"))
fi

# Write base CSV header
BASE_HEADER="AccountID,AccountName,InstanceID,Name,State,PrivateIP,PublicIP,InstanceType,VPC,Subnet,AZ"

# Generate the tag headers with Tag: prefix for clarity
TAG_HEADERS=""
for key in "${SORTED_TAG_KEYS[@]}"; do
  TAG_HEADERS="${TAG_HEADERS},\"Tag: ${key}\""
done

# Write full header to output file
echo "${BASE_HEADER}${TAG_HEADERS}" > "$OUTPUT_FILE"

# Second pass: get instance details with tags in separate columns
for profile in "${PROFILES[@]}"; do
  echo ">>> Fetching EC2s for profile: $profile"

  # Verify profile is valid and accessible
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    echo "  Warning: Profile $profile not valid or accessible. Skipping..."
    continue
  fi

  # Get Account ID
  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$profile")

  # Process each instance individually to handle tags properly
  aws ec2 describe-instances --profile "$profile" --region ap-southeast-2 --output json 2>/dev/null | \
  jq -c '.Reservations[].Instances[]' 2>/dev/null | while read -r instance; do
    # Extract basic instance properties
    INSTANCE_ID=$(echo "$instance" | jq -r '.InstanceId')
    NAME=$(echo "$instance" | jq -r '(.Tags[] | select(.Key=="Name") | .Value) // "NoName"')
    STATE=$(echo "$instance" | jq -r '.State.Name')
    PRIVATE_IP=$(echo "$instance" | jq -r '.PrivateIpAddress // "N/A"')
    PUBLIC_IP=$(echo "$instance" | jq -r '.PublicIpAddress // "N/A"')
    INSTANCE_TYPE=$(echo "$instance" | jq -r '.InstanceType')
    VPC=$(echo "$instance" | jq -r '.VpcId')
    SUBNET=$(echo "$instance" | jq -r '.SubnetId')
    AZ=$(echo "$instance" | jq -r '.Placement.AvailabilityZone')

    # Start building the CSV line with basic properties
    CSV_LINE="$ACCOUNT_ID,$profile,$INSTANCE_ID,$NAME,$STATE,$PRIVATE_IP,$PUBLIC_IP,$INSTANCE_TYPE,$VPC,$SUBNET,$AZ"

    # Extract all tags into a temporary associative array (using jq)
    TAG_JSON=$(echo "$instance" | jq -r '.Tags // [] | map({key: .Key, value: .Value}) | from_entries')

    # For each unique tag key in our sorted array, add its value
    for tag_key in "${SORTED_TAG_KEYS[@]}"; do
      # Extract the tag value, escape quotes and commas
      tag_value=$(echo "$TAG_JSON" | jq -r --arg key "$tag_key" '.[$key] // "" | gsub(","; "|") | gsub("\""; "\\\"")' 2>/dev/null)
      
      # Add the tag value to the CSV line (quoted to handle special characters)
      CSV_LINE="$CSV_LINE,\"$tag_value\""
    done

    # Append the CSV line to the output file
    echo "$CSV_LINE" >> "$OUTPUT_FILE"
  done || echo "  No EC2 instances found for profile $profile or error accessing AWS resources"
done

# Clean up temp files
rm -f "$TEMP_FILE" "$TAG_KEYS_FILE"

echo "✅ EC2 inventory collection complete. File saved as $OUTPUT_FILE with sorted tag columns."
echo "🔍 Tags are prefixed with 'Tag:' for easier identification in spreadsheet applications."
echo "📊 Processed ${#PROFILES[@]} profiles from accounts.csv"
