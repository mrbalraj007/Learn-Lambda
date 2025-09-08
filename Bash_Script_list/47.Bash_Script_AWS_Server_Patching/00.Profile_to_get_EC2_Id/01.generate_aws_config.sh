#!/bin/bash
# =====================================================================
# Script Name : generate_aws_config.sh
# Description : Generate AWS CLI config (~/.aws/config) from a CSV file,
#               perform single SSO login, verify all profiles,
#               and export results to CSV
# Author      : AWS Engineer
# =====================================================================

CSV_FILE="accounts.csv"
CONFIG_FILE="$HOME/.aws/config"
SSO_START_URL="https://d-97677017a0.awsapps.com/start"   # <-- Replace with your SSO URL
SSO_REGION="ap-southeast-2"                           # <-- Replace if different
DEFAULT_REGION="ap-southeast-2"
OUTPUT_FORMAT="json"
SSO_SESSION_NAME="readonly"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_FILE="aws_profiles_verification_${TIMESTAMP}.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "❌ Error: The CSV file '$CSV_FILE' does not exist."
    echo "Creating a template CSV file for you..."
    
    # Create a template CSV file
    cat <<EOF > "$CSV_FILE"
account_id,permission_set
123456789012,ReadOnlyAccess
234567890123,PowerUserAccess
345678901234,AdministratorAccess
EOF
    
    echo "✅ Template CSV file created at '$CSV_FILE'. Please edit it with your actual account details."
    echo "Format: account_id,permission_set (one entry per line)"
    exit 1
fi

# Check if CSV file has content (beyond header) - More robust method
CSV_LINE_COUNT=$(grep -v "^[[:space:]]*$" "$CSV_FILE" | wc -l)
DATA_LINE_COUNT=$(grep -v "^[[:space:]]*$" "$CSV_FILE" | grep -v "^account_id" | wc -l)

echo "📋 CSV file has $CSV_LINE_COUNT total lines and $DATA_LINE_COUNT data lines"

if [ $DATA_LINE_COUNT -lt 1 ]; then
    echo "❌ Error: The CSV file '$CSV_FILE' appears to be empty or contains only headers."
    echo "Please add your AWS accounts in the format: account_id,permission_set (one entry per line)"
    echo "Current file content:"
    cat "$CSV_FILE"
    exit 1
fi

# Delete existing config.bak file if it exists
CONFIG_BAK_FILE="$HOME/.aws/config.bak"
if [ -f "$CONFIG_BAK_FILE" ]; then
    echo "🗑️ Deleting existing backup file: $CONFIG_BAK_FILE"
    rm -f "$CONFIG_BAK_FILE"
fi

# Delete any config.bak.* files (timestamp backups from previous runs)
CONFIG_BAK_PATTERN="$HOME/.aws/config.bak.*"
if ls $CONFIG_BAK_PATTERN 1> /dev/null 2>&1; then
    echo "🗑️ Deleting old timestamp backup files: $CONFIG_BAK_PATTERN"
    rm -f $CONFIG_BAK_PATTERN
fi

# Backup old config if exists
if [ -f "$CONFIG_FILE" ]; then
    BACKUP_FILE="$CONFIG_FILE.bak.$(date +%s)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "📂 Existing config backed up as $BACKUP_FILE"
fi

# Write SSO session header
cat <<EOF > "$CONFIG_FILE"
[sso-session $SSO_SESSION_NAME]
sso_start_url = $SSO_START_URL
sso_region = $SSO_REGION
sso_registration_scopes = sso:account:access

EOF

# Initialize empty array to store profiles
PROFILE_LIST=()

# Count lines in CSV (excluding header) for verification
EXPECTED_ACCOUNT_COUNT=$DATA_LINE_COUNT
echo "📋 Found $EXPECTED_ACCOUNT_COUNT accounts in CSV file"

# Read CSV and generate profiles - handling potential Windows line endings
while IFS=, read -r account_id permission_set || [ -n "$account_id" ]; do
    # Skip header line and empty lines
    if [ "$account_id" = "account_id" ] || [ -z "$account_id" ]; then
        continue
    fi
    
    # Trim whitespace and remove carriage returns
    account_id=$(echo "$account_id" | tr -d '\r' | xargs)
    permission_set=$(echo "$permission_set" | tr -d '\r' | xargs)
    
    # Skip empty lines
    if [ -z "$account_id" ] || [ -z "$permission_set" ]; then
        echo "⚠️ Warning: Skipping invalid line in CSV with empty account_id or permission_set"
        continue
    fi
    
    echo "🔍 Processing line: '$account_id','$permission_set'"
    
    profile_name="account${account_id}"
    # Add to the list of profiles
    PROFILE_LIST+=("$profile_name")
    echo "➕ Adding profile: $profile_name (Account: $account_id, Role: $permission_set)"

    cat <<EOF >> "$CONFIG_FILE"
[profile $profile_name]
sso_session = $SSO_SESSION_NAME
sso_account_id = $account_id
sso_role_name = $permission_set
region = $DEFAULT_REGION
output = $OUTPUT_FORMAT

EOF
done < "$CSV_FILE"

# Verify we processed the correct number of profiles
echo "✅ Processed ${#PROFILE_LIST[@]} out of $EXPECTED_ACCOUNT_COUNT accounts"
if [ ${#PROFILE_LIST[@]} -ne $EXPECTED_ACCOUNT_COUNT ]; then
    echo "⚠️ Warning: Number of processed profiles doesn't match CSV file count"
    echo "   Expected: $EXPECTED_ACCOUNT_COUNT, Processed: ${#PROFILE_LIST[@]}"
fi

echo "📋 Profiles to verify:"
for profile in "${PROFILE_LIST[@]}"; do
    echo "  - $profile"
done

echo "✅ AWS CLI config generated at $CONFIG_FILE"

# Save profile names to profiles.txt
PROFILES_FILE="profiles.txt"
echo "📝 Saving profile names to $PROFILES_FILE..."
> "$PROFILES_FILE"  # Clear the file first
for profile in "${PROFILE_LIST[@]}"; do
    echo "$profile" >> "$PROFILES_FILE"
done
echo "✅ Saved ${#PROFILE_LIST[@]} profiles to $PROFILES_FILE"

# Perform a single SSO login for the session
echo "🔑 Running single SSO login for session: $SSO_SESSION_NAME ..."
if ! aws sso login --sso-session "$SSO_SESSION_NAME"; then
    echo "❌ SSO login failed. Please check your credentials and try again."
    exit 1
fi

# Use a temporary file to avoid file locking issues
TEMP_REPORT_FILE="/tmp/aws_profiles_temp_$$.csv"

# Prepare CSV report - using a temporary file first
echo "Profile,Account,Status" > "$TEMP_REPORT_FILE"

# Verify all profiles
echo "🔍 Verifying all profiles (${#PROFILE_LIST[@]} total)..."
for profile in "${PROFILE_LIST[@]}"; do
    echo "➡️  Testing profile: $profile"
    if identity=$(aws sts get-caller-identity --profile "$profile" --query 'Account' --output text 2>/dev/null); then
        echo "   ✅ Profile $profile is valid (Account: $identity)"
        # Append to temp file instead of directly to report file
        echo "$profile,$identity,Success" >> "$TEMP_REPORT_FILE"
    else
        echo "   ❌ Profile $profile FAILED to authenticate"
        # Append to temp file instead of directly to report file
        echo "$profile,,Failed" >> "$TEMP_REPORT_FILE"
    fi
done

# Move the temp file to the final report file location
if ! cp "$TEMP_REPORT_FILE" "$REPORT_FILE" 2>/dev/null; then
    # If direct copy fails, try different approach for Windows/Git Bash environment
    cat "$TEMP_REPORT_FILE" > "$REPORT_FILE"
    if [ $? -ne 0 ]; then
        echo "❌ Error writing to report file. Saving report to current directory instead."
        # Try using current directory if home directory has issues
        REPORT_FILE="./aws_profiles_verification.csv"
        cat "$TEMP_REPORT_FILE" > "$REPORT_FILE"
    fi
fi

# Clean up temp file
rm -f "$TEMP_REPORT_FILE"

# Verify the report file was created correctly
if [ -f "$REPORT_FILE" ]; then
    PROFILE_COUNT=$(grep -c "Success" "$REPORT_FILE" 2>/dev/null || echo "0")
    echo "🎉 Verification complete! Results saved in $REPORT_FILE"
    echo "📊 Summary: Verified ${PROFILE_COUNT} profiles from $EXPECTED_ACCOUNT_COUNT accounts"
    
    # Display the contents of the CSV file for confirmation
    echo "📋 Report file contents:"
    cat "$REPORT_FILE"
else
    echo "❌ Failed to create report file."
fi
