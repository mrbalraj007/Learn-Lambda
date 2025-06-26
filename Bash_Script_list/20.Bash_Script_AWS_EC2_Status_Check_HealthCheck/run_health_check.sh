#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\20.Bash_Script_AWS_EC2_Status_Check_HealthCheck\run_health_check.sh

# Wrapper script for EC2 health check with different execution modes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK_SCRIPT="${SCRIPT_DIR}/ec2_health_check.sh"

# Ensure the main script is executable
chmod +x "$HEALTH_CHECK_SCRIPT"

echo "EC2 Health Check Options:"
echo "1. Check current region only"
echo "2. Check all AWS regions"
echo "3. Check specific region"
echo -n "Select option (1-3): "
read -r choice

case $choice in
    1)
        echo "Checking current region..."
        "$HEALTH_CHECK_SCRIPT"
        ;;
    2)
        echo "Checking all regions..."
        CHECK_ALL_REGIONS=true "$HEALTH_CHECK_SCRIPT"
        ;;
    3)
        echo -n "Enter region name (e.g., us-west-2): "
        read -r region
        echo "Checking region: $region"
        AWS_DEFAULT_REGION="$region" "$HEALTH_CHECK_SCRIPT"
        ;;
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac

echo -e "\nHealth check completed. Check the generated CSV file and logs."