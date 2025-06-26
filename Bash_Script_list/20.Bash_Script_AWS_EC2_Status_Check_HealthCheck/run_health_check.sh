#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\20.Bash_Script_AWS_EC2_Status_Check_HealthCheck\run_health_check.sh

# Wrapper script for EC2 health check with different execution modes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_CHECK_SCRIPT="${SCRIPT_DIR}/ec2_health_check.sh"
LOG_FILE="${SCRIPT_DIR}/ec2_health_check.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Simple logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Ensure the main script is executable
if [[ ! -f "$HEALTH_CHECK_SCRIPT" ]]; then
    log "Error: Script not found: $HEALTH_CHECK_SCRIPT"
    exit 1
fi

chmod +x "$HEALTH_CHECK_SCRIPT"

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    log "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Verify AWS credentials are working
if ! aws sts get-caller-identity &> /dev/null; then
    log "AWS credentials are missing or invalid. Please run 'aws configure' first."
    exit 1
fi

# Display EC2 instance count (to verify connectivity)
echo -e "${YELLOW}Verifying AWS connectivity...${NC}"
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
INSTANCE_COUNT=$(aws ec2 describe-instances --region "$REGION" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "Error")

if [[ "$INSTANCE_COUNT" == "Error" ]]; then
    log "Failed to connect to AWS or retrieve instances. Please check your credentials and permissions."
    exit 1
else
    log "Successfully connected to AWS. Found $INSTANCE_COUNT instances in region $REGION."
fi

echo -e "${GREEN}EC2 Health Check Options:${NC}"
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
        
        # Validate the region
        if ! aws ec2 describe-regions --region-names "$region" &>/dev/null; then
            log "Invalid region: $region"
            exit 1
        fi
        
        echo "Checking region: $region"
        AWS_DEFAULT_REGION="$region" "$HEALTH_CHECK_SCRIPT"
        ;;
    *)
        echo "Invalid option. Exiting."
        exit 1
        ;;
esac

# Check if CSV file was created and has content
LATEST_CSV=$(find "$SCRIPT_DIR" -name "ec2_health_status_*.csv" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)

if [[ -n "$LATEST_CSV" && -f "$LATEST_CSV" ]]; then
    ROW_COUNT=$(wc -l < "$LATEST_CSV")
    
    if [[ "$ROW_COUNT" -gt 1 ]]; then
        echo -e "\n${GREEN}Health check completed successfully!${NC}"
        echo "Found $(($ROW_COUNT - 1)) EC2 instances."
        echo "CSV file: $LATEST_CSV"
    else
        echo -e "\n${YELLOW}Warning: No EC2 instances data was found.${NC}"
        echo "CSV file was created but contains only headers: $LATEST_CSV"
        echo "Check the log file for errors: $LOG_FILE"
    fi
else
    echo -e "\n${YELLOW}Warning: No CSV file was created.${NC}"
    echo "Check the log file for errors: $LOG_FILE"
fi

echo -e "\nHealth check completed. Check the generated CSV file and logs."