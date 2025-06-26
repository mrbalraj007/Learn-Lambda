#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\20.Bash_Script_AWS_EC2_Status_Check_HealthCheck\ec2_health_check.sh

# EC2 Health Status Check Script
# This script checks system status and instance status for all EC2 instances
# and saves the results in a CSV file with timestamp

# Set strict error handling
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${SCRIPT_DIR}/ec2_health_status_${TIMESTAMP}.csv"
LOG_FILE="${SCRIPT_DIR}/ec2_health_check.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if AWS CLI is installed and configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed. Please install AWS CLI first."
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS CLI is not configured or credentials are invalid."
    fi
    
    log "AWS CLI check passed"
}

# Get all regions (optional - you can specify specific regions)
get_regions() {
    aws ec2 describe-regions --query 'Regions[].RegionName' --output text
}

# Main function to check EC2 health status
check_ec2_health() {
    local region=$1
    
    log "Checking EC2 instances in region: $region"
    
    # Get all instances in the region
    local instances=$(aws ec2 describe-instances \
        --region "$region" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$instances" ]]; then
        log "No instances found in region $region"
        return
    fi
    
    # Get instance status for all instances in the region
    local instance_ids=$(echo "$instances" | awk '{print $1}' | tr '\n' ' ')
    
    if [[ -n "$instance_ids" ]]; then
        # Get status checks for all instances at once
        local status_data=$(aws ec2 describe-instance-status \
            --region "$region" \
            --instance-ids $instance_ids \
            --include-all-instances \
            --query 'InstanceStatuses[].[InstanceId,InstanceState.Name,SystemStatus.Status,InstanceStatus.Status,SystemStatus.Details[0].Status,InstanceStatus.Details[0].Status]' \
            --output text 2>/dev/null || echo "")
        
        # Process each instance
        while IFS=$'\t' read -r instance_id instance_type state name_tag; do
            [[ -z "$instance_id" ]] && continue
            
            # Find status info for this instance
            local status_info=$(echo "$status_data" | grep "^$instance_id" || echo "$instance_id	unknown	not-applicable	not-applicable	unknown	unknown")
            
            IFS=$'\t' read -r status_instance_id instance_state system_status instance_status system_detail instance_detail <<< "$status_info"
            
            # Set default values if empty
            name_tag=${name_tag:-"N/A"}
            system_status=${system_status:-"not-applicable"}
            instance_status=${instance_status:-"not-applicable"}
            system_detail=${system_detail:-"unknown"}
            instance_detail=${instance_detail:-"unknown"}
            
            # Determine overall health
            local overall_status="HEALTHY"
            local issues=""
            
            if [[ "$system_status" == "impaired" || "$system_detail" == "failed" ]]; then
                overall_status="UNHEALTHY"
                issues="${issues}System Check Failed; "
            fi
            
            if [[ "$instance_status" == "impaired" || "$instance_detail" == "failed" ]]; then
                overall_status="UNHEALTHY"
                issues="${issues}Instance Check Failed; "
            fi
            
            if [[ "$state" != "running" ]]; then
                overall_status="NOT_RUNNING"
                issues="${issues}Instance Not Running; "
            fi
            
            # Count passed checks
            local passed_checks=0
            local total_checks=2
            
            if [[ "$system_status" == "ok" ]]; then
                ((passed_checks++))
            fi
            
            if [[ "$instance_status" == "ok" ]]; then
                ((passed_checks++))
            fi
            
            local check_ratio="${passed_checks}/${total_checks}"
            
            # Write to CSV
            echo "\"$region\",\"$instance_id\",\"$name_tag\",\"$instance_type\",\"$state\",\"$system_status\",\"$instance_status\",\"$check_ratio\",\"$overall_status\",\"${issues%%; }\",\"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$OUTPUT_FILE"
            
            # Log unhealthy instances
            if [[ "$overall_status" == "UNHEALTHY" ]]; then
                log "ALERT: Instance $instance_id ($name_tag) in $region has health issues: $issues"
            fi
            
        done <<< "$instances"
    fi
}

# Main execution
main() {
    log "Starting EC2 Health Check"
    
    # Check prerequisites
    check_aws_cli
    
    # Create CSV header
    echo "Region,InstanceId,Name,InstanceType,State,SystemStatus,InstanceStatus,StatusCheckRatio,OverallHealth,Issues,CheckTime" > "$OUTPUT_FILE"
    
    # Get current region or all regions
    if [[ "${CHECK_ALL_REGIONS:-false}" == "true" ]]; then
        log "Checking all AWS regions"
        regions=$(get_regions)
    else
        # Use current region or default
        regions=$(aws configure get region 2>/dev/null || echo "us-east-1")
        log "Checking current region: $regions"
    fi
    
    # Check each region
    for region in $regions; do
        check_ec2_health "$region"
    done
    
    # Display summary
    local total_instances=$(tail -n +2 "$OUTPUT_FILE" | wc -l)
    local unhealthy_instances=$(tail -n +2 "$OUTPUT_FILE" | grep -c "UNHEALTHY" || echo "0")
    local not_running=$(tail -n +2 "$OUTPUT_FILE" | grep -c "NOT_RUNNING" || echo "0")
    
    log "Health check completed!"
    log "Total instances checked: $total_instances"
    log "Unhealthy instances: $unhealthy_instances"
    log "Not running instances: $not_running"
    log "Results saved to: $OUTPUT_FILE"
    
    # Display unhealthy instances
    if [[ $unhealthy_instances -gt 0 ]]; then
        echo -e "\n${RED}UNHEALTHY INSTANCES:${NC}"
        tail -n +2 "$OUTPUT_FILE" | grep "UNHEALTHY" | while IFS=',' read -r region instance_id name instance_type state system_status instance_status ratio health issues timestamp; do
            echo -e "${YELLOW}Region:${NC} $region"
            echo -e "${YELLOW}Instance:${NC} $instance_id ($name)"
            echo -e "${YELLOW}Issues:${NC} $issues"
            echo -e "${YELLOW}Status Checks:${NC} $ratio"
            echo "---"
        done
    else
        echo -e "\n${GREEN}All instances are healthy!${NC}"
    fi
}

# Run the script
main "$@"