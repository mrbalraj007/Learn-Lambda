#!/usr/bin/env bash

set -uo pipefail

# ============================================================
# AWS VPC Inventory
#
# Usage:
#   ./aws-vpc-inventory.sh <region>
#
# Example:
#   ./aws-vpc-inventory.sh ap-southeast-2
#
# Requirements:
#   - AWS CLI v2
#   - jq
#   - Valid AWS CLI profiles / SSO profiles
#
# Output:
#   aws-vpc-inventory-<region>.csv
# ============================================================

# ------------------------------------------------------------
# Check region argument
# ------------------------------------------------------------

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <region>"
    echo
    echo "Examples:"
    echo "  $0 ap-southeast-2"
    echo "  $0 us-east-1"
    echo "  $0 us-west-2"
    exit 1
fi

REGION="$1"

# ------------------------------------------------------------
# Output file
# ------------------------------------------------------------

OUTPUT_FILE="aws-vpc-inventory-${REGION}.csv"

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

command -v aws >/dev/null 2>&1 || {
    echo "ERROR: AWS CLI is not installed."
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq is not installed."
    echo "Install jq before running this script."
    exit 1
}

# ------------------------------------------------------------
# CSV helper
# ------------------------------------------------------------

csv_escape() {
    local value="${1:-}"

    value="${value//\"/\"\"}"

    printf '"%s"' "$value"
}

# ------------------------------------------------------------
# Get account name
# ------------------------------------------------------------

get_account_name() {

    local profile="$1"
    local account_id="$2"

    local account_name=""

    account_name=$(aws organizations describe-account \
        --no-cli-pager \
        --account-id "$account_id" \
        --profile "$profile" \
        --query 'Account.Name' \
        --output text 2>/dev/null || true)

    if [[ -z "$account_name" || "$account_name" == "None" ]]; then
        account_name="$profile"
    fi

    echo "$account_name"
}

# ------------------------------------------------------------
# Create CSV header
# ------------------------------------------------------------

cat > "$OUTPUT_FILE" <<EOF
Account ID,Account Name,VPC ID,VPC CIDR,VPC Name,Region,Range,DNS,NTP,Domain Name,DHCP Option Set ID
EOF

# ------------------------------------------------------------
# Get all AWS CLI profiles
# ------------------------------------------------------------

mapfile -t AWS_PROFILES < <(
    aws configure list-profiles 2>/dev/null | tr -d '\r'
)

if [[ ${#AWS_PROFILES[@]} -eq 0 ]]; then
    echo "ERROR: No AWS profiles found."
    exit 1
fi

echo
echo "============================================================"
echo "AWS VPC Inventory"
echo "============================================================"
echo "Region : $REGION"
echo "Output : $OUTPUT_FILE"
echo "Profiles: ${#AWS_PROFILES[@]}"
echo "============================================================"
echo

# ------------------------------------------------------------
# Process each AWS profile
# ------------------------------------------------------------

for PROFILE in "${AWS_PROFILES[@]}"; do

    echo "------------------------------------------------------------"
    echo "Profile: $PROFILE"
    echo "------------------------------------------------------------"

    # --------------------------------------------------------
    # Get Account ID
    # --------------------------------------------------------

    ACCOUNT_ID=$(aws sts get-caller-identity \
        --no-cli-pager \
        --profile "$PROFILE" \
        --query 'Account' \
        --output text 2>/dev/null || true)

    if [[ -z "$ACCOUNT_ID" || "$ACCOUNT_ID" == "None" ]]; then
        echo "WARNING: Unable to access profile: $PROFILE"
        echo "         Skipping..."
        echo
        continue
    fi

    echo "Account ID  : $ACCOUNT_ID"

    # --------------------------------------------------------
    # Get Account Name
    # --------------------------------------------------------

    ACCOUNT_NAME=$(get_account_name "$PROFILE" "$ACCOUNT_ID")

    echo "Account Name: $ACCOUNT_NAME"
    echo "Region      : $REGION"

    # --------------------------------------------------------
    # Get VPCs
    # --------------------------------------------------------

    VPC_JSON=$(aws ec2 describe-vpcs \
        --no-cli-pager \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output json 2>/dev/null || true)

    if [[ -z "$VPC_JSON" ]]; then
        echo "WARNING: Unable to query region $REGION"
        echo
        continue
    fi

    VPC_COUNT=$(echo "$VPC_JSON" | jq '.Vpcs | length')

    if [[ "$VPC_COUNT" -eq 0 ]]; then
        echo "No VPCs found."
        echo
        continue
    fi

    echo "VPCs found  : $VPC_COUNT"
    echo

    # --------------------------------------------------------
    # Process each VPC
    # --------------------------------------------------------

    while IFS= read -r VPC; do

        VPC_ID=$(echo "$VPC" | jq -r '.VpcId')

        VPC_CIDR=$(echo "$VPC" | jq -r '.CidrBlock // ""')

        # ----------------------------------------------------
        # VPC Name
        # ----------------------------------------------------

        VPC_NAME=$(echo "$VPC" | jq -r '
            (.Tags // [])
            | map(select(.Key == "Name"))
            | .[0].Value // ""
        ')

        # ----------------------------------------------------
        # Range
        # ----------------------------------------------------

        RANGE="$VPC_CIDR"

        # ----------------------------------------------------
        # DHCP Options Set
        # ----------------------------------------------------

        DHCP_ID=$(echo "$VPC" | jq -r '.DhcpOptionsId // ""')

        DNS=""
        NTP=""
        DOMAIN_NAME=""

        # ----------------------------------------------------
        # Get DHCP Options
        # ----------------------------------------------------

        if [[ -n "$DHCP_ID" ]]; then

            DHCP_JSON=$(aws ec2 describe-dhcp-options \
                --no-cli-pager \
                --dhcp-options-ids "$DHCP_ID" \
                --profile "$PROFILE" \
                --region "$REGION" \
                --output json 2>/dev/null || true)

            if [[ -n "$DHCP_JSON" ]]; then

                DNS=$(echo "$DHCP_JSON" | jq -r '
                    [
                        .DhcpOptions[].DhcpConfigurations[]
                        | select(.Key == "domain-name-servers")
                        | .Values[].Value
                    ] | join("; ")
                ')

                NTP=$(echo "$DHCP_JSON" | jq -r '
                    [
                        .DhcpOptions[].DhcpConfigurations[]
                        | select(.Key == "ntp-servers")
                        | .Values[].Value
                    ] | join("; ")
                ')

                DOMAIN_NAME=$(echo "$DHCP_JSON" | jq -r '
                    [
                        .DhcpOptions[].DhcpConfigurations[]
                        | select(.Key == "domain-name")
                        | .Values[].Value
                    ] | join("; ")
                ')

            fi
        fi

        # ----------------------------------------------------
        # Display information
        # ----------------------------------------------------

        echo "  VPC ID       : $VPC_ID"
        echo "  VPC Name     : $VPC_NAME"
        echo "  VPC CIDR     : $VPC_CIDR"
        echo "  Range        : $RANGE"
        echo "  DNS          : $DNS"
        echo "  NTP          : $NTP"
        echo "  Domain Name  : $DOMAIN_NAME"
        echo "  DHCP Option  : $DHCP_ID"
        echo

        # ----------------------------------------------------
        # Write CSV
        # ----------------------------------------------------

        {
            csv_escape "$ACCOUNT_ID"
            printf ","

            csv_escape "$ACCOUNT_NAME"
            printf ","

            csv_escape "$VPC_ID"
            printf ","

            csv_escape "$VPC_CIDR"
            printf ","

            csv_escape "$VPC_NAME"
            printf ","

            csv_escape "$REGION"
            printf ","

            csv_escape "$RANGE"
            printf ","

            csv_escape "$DNS"
            printf ","

            csv_escape "$NTP"
            printf ","

            csv_escape "$DOMAIN_NAME"
            printf ","

            csv_escape "$DHCP_ID"
            printf "\n"

        } >> "$OUTPUT_FILE"

    done < <(echo "$VPC_JSON" | jq -c '.Vpcs[]')

done

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "============================================================"
echo "VPC inventory completed."
echo "============================================================"
echo "Region : $REGION"
echo "Output : $OUTPUT_FILE"
echo "============================================================"