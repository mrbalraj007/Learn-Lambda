#!/bin/bash
# IAM Identity Center User Group Lookup Script
# This script retrieves all groups a user belongs to and exports them to a CSV file
# Author: AWS Engineer

set -e

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <username>"
    echo "Example: $0 john.doe@company.com"
    exit 1
}

# Check argument
if [ $# -ne 1 ]; then
    usage
fi

username=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_CSV="${SCRIPT_DIR}/user_groups_$(date +"%Y%m%d%H%M%S").csv"
LOG_FILE="${SCRIPT_DIR}/aws_groups_log_$(date +"%Y%m%d%H%M%S").log"

echo "Script started at $(date)" > "$LOG_FILE"
echo "Username: $username" >> "$LOG_FILE"
echo "CSV file: $OUTPUT_CSV" >> "$LOG_FILE"

# Prerequisite checks
command -v aws >/dev/null || { echo -e "${RED}AWS CLI not found${NC}"; exit 1; }
command -v jq >/dev/null || { echo -e "${RED}jq not found${NC}"; exit 1; }

# CSV Header
echo "Group ID,Group Name" > "$OUTPUT_CSV"

echo -e "${BLUE}=== IAM Identity Center User Group Lookup ===${NC}"
echo -e "User: ${YELLOW}$username${NC}"
echo -e "Output CSV: ${YELLOW}$OUTPUT_CSV${NC}"

# Validate credentials
aws sts get-caller-identity --output json >> "$LOG_FILE" 2>&1 || {
    echo -e "${RED}AWS credentials not configured${NC}"
    exit 1
}

# Identity Store ID
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
if [ -z "$IDENTITY_STORE_ID" ] || [ "$IDENTITY_STORE_ID" == "None" ]; then
    echo -e "${RED}Failed to get Identity Store ID${NC}"
    exit 1
fi

# Get User ID
USER_ID=$(aws identitystore list-users \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --filters "AttributePath=UserName,AttributeValue=$username" \
    --query "Users[0].UserId" --output text)

if [ -z "$USER_ID" ] || [ "$USER_ID" == "None" ]; then
    echo -e "${RED}User not found: $username${NC}"
    exit 1
fi

# Get Group Memberships
GROUP_IDS=$(aws identitystore list-group-memberships-for-member \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --member-id "UserId=$USER_ID" \
    --query "GroupMemberships[].GroupId" --output text)

GROUP_COUNT=$(echo "$GROUP_IDS" | wc -w)
echo -e "${GREEN}Found $GROUP_COUNT group(s)${NC}"

if [ "$GROUP_COUNT" -eq 0 ]; then
    echo "N/A,No groups found" >> "$OUTPUT_CSV"
    echo -e "${YELLOW}No groups found for user${NC}"
    exit 0
fi

# Function to get group name from describe-group
get_group_name() {
    local group_id="$1"
    aws identitystore describe-group \
        --identity-store-id "$IDENTITY_STORE_ID" \
        --group-id "$group_id" \
        --query "DisplayName" \
        --output text 2>> "$LOG_FILE"
}

# Process group IDs
for group_id in $GROUP_IDS; do
    [ -z "$group_id" ] && continue

    group_name=$(get_group_name "$group_id")
    if [[ -z "$group_name" || "$group_name" == "None" ]]; then
        group_name="Unknown Group"
    fi

    # Escape commas in group name
    if [[ "$group_name" == *","* ]]; then
        echo "$group_id,\"$group_name\"" >> "$OUTPUT_CSV"
    else
        echo "$group_id,$group_name" >> "$OUTPUT_CSV"
    fi

    echo -e "${GREEN}✔ $group_id -> $group_name${NC}"
done

# Final status
echo -e "${BLUE}=== CSV File Created ===${NC}"
cat "$OUTPUT_CSV"
echo -e "${GREEN}✅ Script completed. Output saved to:${NC} ${YELLOW}$OUTPUT_CSV${NC}"
