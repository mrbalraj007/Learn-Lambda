#!/bin/bash
# IAM Identity Center User Group Lookup Script
# This script retrieves all groups a user belongs to and exports them to a CSV file
# Author: AWS Engineer

# Stop on errors
set -e

# Colors for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 <username>"
    echo "Example: $0 john.doe@company.com"
    exit 1
}

# Check if username is provided
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

# Verify prerequisites
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not installed${NC}"
    echo "AWS CLI not installed" >> "$LOG_FILE"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not installed${NC}"
    echo "jq not installed" >> "$LOG_FILE"
    exit 1
fi

# Create CSV header
echo "Group ID,Group Name" > "$OUTPUT_CSV"
echo "Created CSV file with header" >> "$LOG_FILE"

echo -e "${BLUE}=== IAM Identity Center User Group Details ===${NC}"
echo -e "User: ${YELLOW}$username${NC}"
echo -e "Output CSV: ${YELLOW}$OUTPUT_CSV${NC}"
echo -e "Log file: ${YELLOW}$LOG_FILE${NC}"

# Step 1: Check AWS credentials
echo -e "${GREEN}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity --output json >> "$LOG_FILE" 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured correctly${NC}"
    echo "Failed to validate AWS credentials" >> "$LOG_FILE"
    exit 1
fi

# Step 2: Get Identity Store ID
echo -e "${GREEN}Getting Identity Store ID...${NC}"
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
if [ -z "$IDENTITY_STORE_ID" ] || [ "$IDENTITY_STORE_ID" == "None" ]; then
    echo -e "${RED}Error: Failed to get Identity Store ID${NC}"
    echo "Failed to get Identity Store ID" >> "$LOG_FILE"
    exit 1
fi
echo -e "Identity Store ID: ${YELLOW}$IDENTITY_STORE_ID${NC}"
echo "Identity Store ID: $IDENTITY_STORE_ID" >> "$LOG_FILE"

# Step 3: Find user ID
echo -e "${GREEN}Finding user ID...${NC}"
USER_ID=$(aws identitystore list-users \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --filters "AttributePath=UserName,AttributeValue=$username" \
    --query "Users[0].UserId" \
    --output text)

if [ -z "$USER_ID" ] || [ "$USER_ID" == "None" ]; then
    echo -e "${RED}Error: User not found${NC}"
    echo "User not found: $username" >> "$LOG_FILE"
    exit 1
fi
echo -e "User ID: ${YELLOW}$USER_ID${NC}"
echo "User ID: $USER_ID" >> "$LOG_FILE"

# Step 4: Get group memberships
echo -e "${GREEN}Getting group memberships...${NC}"
GROUP_MEMBERSHIPS=$(aws identitystore list-group-memberships-for-member \
    --identity-store-id "$IDENTITY_STORE_ID" \
    --member-id "UserId=$USER_ID" \
    --output json)

# Check if command succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to get group memberships${NC}"
    echo "Failed to get group memberships" >> "$LOG_FILE"
    exit 1
fi

# Log the raw response
echo "Raw group memberships response:" >> "$LOG_FILE"
echo "$GROUP_MEMBERSHIPS" >> "$LOG_FILE"

# Extract group IDs
GROUP_IDS=$(echo "$GROUP_MEMBERSHIPS" | jq -r '.GroupMemberships[].GroupId')
GROUP_COUNT=$(echo "$GROUP_IDS" | grep -v "^$" | wc -l)

echo -e "Found ${YELLOW}$GROUP_COUNT${NC} groups"
echo "Found $GROUP_COUNT groups" >> "$LOG_FILE"

if [ "$GROUP_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No groups found for user $username${NC}"
    echo "No groups found" >> "$LOG_FILE"
    echo "N/A,No groups found" >> "$OUTPUT_CSV"
    exit 0
fi

# Step 5: Create enhanced functions for group name retrieval
echo -e "${GREEN}Creating enhanced group name retrieval functions...${NC}"

# Function to get group name using describe-group
get_group_name_from_describe() {
    local group_id="$1"
    local identity_store_id="$2"
    local log_file="$3"
    
    echo "Attempting describe-group for $group_id..." >> "$log_file"
    
    # Try with different output formats for maximum compatibility
    for output_format in "json" "text"; do
        echo "Trying with output format: $output_format" >> "$log_file"
        
        if output=$(aws identitystore describe-group \
                --identity-store-id "$identity_store_id" \
                --group-id "$group_id" \
                --output "$output_format" 2>> "$log_file"); then
            
            if [[ "$output_format" == "json" ]]; then
                # Parse JSON output
                if name=$(echo "$output" | jq -r '.DisplayName' 2>/dev/null) && \
                   [[ -n "$name" ]] && [[ "$name" != "null" ]]; then
                    echo "Success with JSON parsing: $name" >> "$log_file"
                    echo "$name"
                    return 0
                fi
            else
                # Parse text output - try to extract DisplayName line
                if name=$(echo "$output" | grep -i "DisplayName" | awk '{print $2}' 2>/dev/null) && \
                   [[ -n "$name" ]]; then
                    echo "Success with text parsing: $name" >> "$log_file"
                    echo "$name"
                    return 0
                fi
            fi
        fi
    done
    
    echo "describe-group failed for $group_id" >> "$log_file"
    return 1
}

# Function to get group name using list-groups with filter
get_group_name_from_list() {
    local group_id="$1"
    local identity_store_id="$2"
    local log_file="$3"
    
    echo "Attempting list-groups with filter for $group_id..." >> "$log_file"
    
    # Try different attribute paths that might contain the ID
    for attr_path in "GroupId" "Id" "ExternalId"; do
        echo "Trying with attribute path: $attr_path" >> "$log_file"
        
        if output=$(aws identitystore list-groups \
                --identity-store-id "$identity_store_id" \
                --filters "AttributePath=$attr_path,AttributeValue=$group_id" \
                --output json 2>> "$log_file"); then
            
            # Check if we got any results
            if group_count=$(echo "$output" | jq '.Groups | length' 2>/dev/null) && \
               [[ "$group_count" -gt 0 ]]; then
                
                name=$(echo "$output" | jq -r '.Groups[0].DisplayName' 2>/dev/null)
                if [[ -n "$name" ]] && [[ "$name" != "null" ]]; then
                    echo "Success with list-groups: $name" >> "$log_file"
                    echo "$name"
                    return 0
                fi
            fi
        fi
    done
    
    echo "list-groups failed for $group_id" >> "$log_file"
    return 1
}

# Function to get permission set name if group ID is a permission set
get_name_from_permission_set() {
    local group_id="$1"
    local identity_store_id="$2"
    local log_file="$3"
    
    echo "Checking if $group_id is a permission set..." >> "$log_file"
    
    # Format the potential permission set ARN
    local instance_arn="arn:aws:sso:::instance/$identity_store_id"
    local potential_ps_arn="arn:aws:sso:::permissionSet/$identity_store_id/ps-$group_id"
    
    echo "Trying with instance ARN: $instance_arn" >> "$log_file"
    echo "Potential permission set ARN: $potential_ps_arn" >> "$log_file"
    
    # First, list available permission sets to avoid errors
    if permission_sets=$(aws sso-admin list-permission-sets \
            --instance-arn "$instance_arn" \
            --output json 2>> "$log_file"); then
        
        echo "Successfully listed permission sets" >> "$log_file"
        
        # Check each permission set
        echo "$permission_sets" | jq -r '.PermissionSets[]' 2>/dev/null | while read -r ps_arn; do
            echo "Checking permission set: $ps_arn" >> "$log_file"
            
            if [[ "$ps_arn" == *"$group_id"* ]]; then
                echo "Found matching permission set: $ps_arn" >> "$log_file"
                
                # Get the name for this permission set
                if ps_details=$(aws sso-admin describe-permission-set \
                        --instance-arn "$instance_arn" \
                        --permission-set-arn "$ps_arn" \
                        --output json 2>> "$log_file"); then
                    
                    name=$(echo "$ps_details" | jq -r '.PermissionSet.Name' 2>/dev/null)
                    if [[ -n "$name" ]] && [[ "$name" != "null" ]]; then
                        echo "Found permission set name: $name" >> "$log_file"
                        echo "$name (Permission Set)"
                        return 0
                    fi
                fi
            fi
        done
    fi
    
    echo "Not a permission set or couldn't retrieve name" >> "$log_file"
    return 1
}

# Step 6: Get details for each group and write to CSV using enhanced logic
echo -e "${GREEN}Retrieving group details and writing to CSV...${NC}"
echo "Retrieving group details:" >> "$LOG_FILE"

PROCESSED_COUNT=0
GROUP_NAME_CACHE=() # Cache for group names to avoid duplicate lookups

echo "$GROUP_IDS" | while read -r GROUP_ID; do
    # Skip empty lines
    [ -z "$GROUP_ID" ] && continue
    
    echo -e "${BLUE}Processing group: ${YELLOW}$GROUP_ID${NC}"
    echo "Processing group: $GROUP_ID" >> "$LOG_FILE"
    
    # Try multiple methods to get the group name
    GROUP_NAME=""
    
    # Method 1: Direct describe-group API call
    if [[ -z "$GROUP_NAME" ]]; then
        echo "Method 1: Trying direct describe-group API call..." | tee -a "$LOG_FILE"
        if GROUP_NAME=$(get_group_name_from_describe "$GROUP_ID" "$IDENTITY_STORE_ID" "$LOG_FILE"); then
            echo -e "${GREEN}Found name using describe-group: ${YELLOW}$GROUP_NAME${NC}"
        fi
    fi
    
    # Method 2: List-groups with filter
    if [[ -z "$GROUP_NAME" ]]; then
        echo "Method 2: Trying list-groups with filter..." | tee -a "$LOG_FILE"
        if GROUP_NAME=$(get_group_name_from_list "$GROUP_ID" "$IDENTITY_STORE_ID" "$LOG_FILE"); then
            echo -e "${GREEN}Found name using list-groups: ${YELLOW}$GROUP_NAME${NC}"
        fi
    fi
    
    # Method 3: Check if it's a permission set
    if [[ -z "$GROUP_NAME" ]]; then
        echo "Method 3: Checking if it's a permission set..." | tee -a "$LOG_FILE"
        if GROUP_NAME=$(get_name_from_permission_set "$GROUP_ID" "$IDENTITY_STORE_ID" "$LOG_FILE"); then
            echo -e "${GREEN}Found name as permission set: ${YELLOW}$GROUP_NAME${NC}"
        fi
    fi
    
    # Fallback method: AWS IAM Groups
    if [[ -z "$GROUP_NAME" ]]; then
        echo "Fallback method: Checking AWS IAM Groups..." | tee -a "$LOG_FILE"
        # Extract a potential group name from the ID if it follows patterns
        if [[ "$GROUP_ID" == *"/"* ]]; then
            POTENTIAL_NAME=$(echo "$GROUP_ID" | awk -F'/' '{print $NF}')
            GROUP_NAME="$POTENTIAL_NAME (IAM Group)"
            echo -e "${YELLOW}Using name from ID pattern: ${GROUP_NAME}${NC}"
        fi
    fi
    
    # Final fallback: Use ID as name
    if [[ -z "$GROUP_NAME" ]]; then
        GROUP_NAME="Unknown Group (ID: ${GROUP_ID:0:8}...)"
        echo -e "${YELLOW}Using fallback name: $GROUP_NAME${NC}"
    fi
    
    echo -e "Final Group Name: ${YELLOW}$GROUP_NAME${NC}"
    echo "Final Group Name: $GROUP_NAME" >> "$LOG_FILE"
    
    # Properly escape CSV output
    if [[ "$GROUP_NAME" == *","* ]]; then
        CSV_LINE="$GROUP_ID,\"$GROUP_NAME\""
    else
        CSV_LINE="$GROUP_ID,$GROUP_NAME"
    fi
    
    # Write to CSV file
    echo "$CSV_LINE" >> "$OUTPUT_CSV"
    echo -e "${GREEN}Added to CSV: $CSV_LINE${NC}"
    
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    echo "----------------------------------------"
done

# Clean up temporary files
rm -f "$ALL_GROUPS_FILE" 2>/dev/null

# Step 7: Verify CSV file
echo -e "${GREEN}Verifying CSV file...${NC}"
if [ -s "$OUTPUT_CSV" ]; then
    LINE_COUNT=$(wc -l < "$OUTPUT_CSV")
    DATA_LINES=$((LINE_COUNT - 1))  # Subtract header line
    
    echo -e "CSV file contains ${YELLOW}$DATA_LINES${NC} data rows"
    echo "CSV file contains $DATA_LINES data rows" >> "$LOG_FILE"
    
    # Display the CSV contents
    echo -e "${BLUE}=== CSV File Contents ===${NC}"
    cat "$OUTPUT_CSV"
    
    echo -e "${GREEN}Success: CSV file created at ${YELLOW}$OUTPUT_CSV${NC}"
else
    echo -e "${RED}Error: CSV file is empty or was not created${NC}"
    echo "CSV file is empty or was not created" >> "$LOG_FILE"
fi

echo "Script completed at $(date)" >> "$LOG_FILE"