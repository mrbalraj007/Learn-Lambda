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

# Write base CSV header - Added OS details columns
BASE_HEADER="AccountID,AccountName,InstanceID,Name,State,PrivateIP,PublicIP,InstanceType,VPC,Subnet,AZ,Platform,PlatformDetails,ImageId,OSName,OSVersion"

# Write header to output file
echo "${BASE_HEADER}" > "$OUTPUT_FILE"

# Get instance details without tags
for profile in "${PROFILES[@]}"; do
  echo ">>> Fetching EC2s for profile: $profile"

  # Verify profile is valid and accessible
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    echo "  Warning: Profile $profile not valid or accessible. Skipping..."
    continue
  fi

  # Get Account ID
  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$profile")

  # Process each instance individually
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
    
    # Extract OS information
    PLATFORM=$(echo "$instance" | jq -r '.Platform // "linux"')
    PLATFORM_DETAILS=$(echo "$instance" | jq -r '.PlatformDetails // "N/A"')
    IMAGE_ID=$(echo "$instance" | jq -r '.ImageId // "N/A"')
    
    # Get detailed OS information from the AMI
    if [ "$IMAGE_ID" != "N/A" ]; then
      AMI_INFO=$(aws ec2 describe-images --image-ids "$IMAGE_ID" --profile "$profile" --region ap-southeast-2 --output json 2>/dev/null)
      if [ $? -eq 0 ]; then
        OS_NAME=$(echo "$AMI_INFO" | jq -r '.Images[0].Name // "N/A"' | sed 's/,/;/g')
        OS_DESC=$(echo "$AMI_INFO" | jq -r '.Images[0].Description // "N/A"' | sed 's/,/;/g')
        # Extract version information from description if available
        OS_VERSION=$(echo "$OS_DESC" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "N/A")
        if [ "$OS_VERSION" = "" ]; then 
          OS_VERSION="N/A"
        fi
      else
        OS_NAME="Access Denied or Not Found"
        OS_VERSION="N/A"
      fi
    else
      OS_NAME="N/A"
      OS_VERSION="N/A"
    fi

    # Build the CSV line with basic properties and OS details
    CSV_LINE="$ACCOUNT_ID,$profile,$INSTANCE_ID,$NAME,$STATE,$PRIVATE_IP,$PUBLIC_IP,$INSTANCE_TYPE,$VPC,$SUBNET,$AZ,$PLATFORM,\"$PLATFORM_DETAILS\",\"$IMAGE_ID\",\"$OS_NAME\",\"$OS_VERSION\""

    # Append the CSV line to the output file
    echo "$CSV_LINE" >> "$OUTPUT_FILE"
  done || echo "  No EC2 instances found for profile $profile or error accessing AWS resources"
done

# Clean up temp file
rm -f "$TEMP_FILE"

echo "✅ EC2 inventory collection complete. File saved as $OUTPUT_FILE."
echo "📊 Processed ${#PROFILES[@]} profiles from accounts.csv"
echo "💻 Added OS details (Platform, PlatformDetails, ImageId, OSName, OSVersion)"
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
