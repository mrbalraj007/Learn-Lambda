#!/bin/bash
# filepath: get_ec2_drivers.sh

# AWS EC2 ENA and PV Driver Information Script
# Author: AWS Professional Engineer
# Default Region: ap-southeast-2

set -euo pipefail

# Configuration
DEFAULT_REGION="ap-southeast-2"
REGION="${1:-$DEFAULT_REGION}"
LOG_FILE="ec2_drivers_$(date +%Y%m%d_%H%M%S).log"
SSM_TIMEOUT=10  # Timeout for SSM commands in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI is not installed${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq is not installed. Output will be less formatted${NC}"
    fi
    
    # Check AWS credentials non-interactively
    if ! timeout 10 aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured or timeout${NC}"
        exit 1
    fi
    
    log "Prerequisites check completed"
}

# Get EC2 instance information
get_ec2_instances() {
    log "Fetching EC2 instances in region: $REGION"
    
    timeout 30 aws ec2 describe-instances \
        --region "$REGION" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Platform,EnaSupport,SriovNetSupport,VirtualizationType]' \
        --output table || {
        log "Error or timeout fetching EC2 instances"
        echo -e "${RED}Failed to fetch EC2 instances${NC}"
    }
}

# Get detailed driver information for running instances
get_driver_details() {
    log "Getting detailed driver information for running instances..."
    
    # Get running instances with timeout
    RUNNING_INSTANCES=$(timeout 30 aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$RUNNING_INSTANCES" ] || [ "$RUNNING_INSTANCES" = "None" ]; then
        log "No running instances found in region $REGION"
        return
    fi
    
    echo -e "\n${BLUE}=== DETAILED DRIVER INFORMATION ===${NC}"
    echo -e "${BLUE}Instance ID\t\tInstance Type\t\tENA Support\t\tSR-IOV\t\tVirtualization${NC}"
    echo "---------------------------------------------------------------------------------"
    
    for instance_id in $RUNNING_INSTANCES; do
        INSTANCE_INFO=$(timeout 15 aws ec2 describe-instances \
            --region "$REGION" \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,EnaSupport,SriovNetSupport,VirtualizationType,Platform]' \
            --output text 2>/dev/null || echo "")
        
        if [ -z "$INSTANCE_INFO" ]; then
            log "Timeout or error getting info for instance: $instance_id"
            continue
        fi
        
        IFS=$'\t' read -r INST_ID INST_TYPE ENA_SUPPORT SRIOV_SUPPORT VIRT_TYPE PLATFORM <<< "$INSTANCE_INFO"
        
        # Set default values for null responses
        ENA_SUPPORT="${ENA_SUPPORT:-false}"
        SRIOV_SUPPORT="${SRIOV_SUPPORT:-None}"
        PLATFORM="${PLATFORM:-linux}"
        
        # Color coding based on support
        if [ "$ENA_SUPPORT" = "true" ]; then
            ENA_COLOR="${GREEN}"
        else
            ENA_COLOR="${RED}"
        fi
        
        if [ "$SRIOV_SUPPORT" = "simple" ]; then
            SRIOV_COLOR="${GREEN}"
        else
            SRIOV_COLOR="${YELLOW}"
        fi
        
        echo -e "${INST_ID}\t\t${INST_TYPE}\t\t${ENA_COLOR}${ENA_SUPPORT}${NC}\t\t${SRIOV_COLOR}${SRIOV_SUPPORT}${NC}\t\t${VIRT_TYPE}"
    done
}

# Get ENA driver version from instances (requires SSM access)
get_ena_driver_version() {
    log "Attempting to get ENA driver versions via SSM..."
    
    # Check if SSM is available with timeout
    SSM_INSTANCES=$(timeout 20 aws ssm describe-instance-information \
        --region "$REGION" \
        --query 'InstanceInformationList[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$SSM_INSTANCES" ] || [ "$SSM_INSTANCES" = "None" ]; then
        log "No SSM-managed instances found or SSM access not available"
        return
    fi
    
    echo -e "\n${BLUE}=== ENA DRIVER VERSIONS (via SSM) ===${NC}"
    
    for instance_id in $SSM_INSTANCES; do
        echo "Checking ENA driver version for instance: $instance_id"
        
        # Command to check ENA driver version on Linux with timeout
        COMMAND_ID=$(timeout 15 aws ssm send-command \
            --region "$REGION" \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=["timeout 5 modinfo ena 2>/dev/null | grep version || echo \"ENA driver not found or timeout\""]' \
            --query 'Command.CommandId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$COMMAND_ID" ] && [ "$COMMAND_ID" != "None" ]; then
            # Wait with timeout
            sleep $SSM_TIMEOUT
            
            # Get command output with timeout
            OUTPUT=$(timeout 10 aws ssm get-command-invocation \
                --region "$REGION" \
                --command-id "$COMMAND_ID" \
                --instance-id "$instance_id" \
                --query 'StandardOutputContent' \
                --output text 2>/dev/null || echo "Command execution timeout or failed")
            
            if [ -n "$OUTPUT" ]; then
                echo "  Result: $OUTPUT"
            else
                echo "  Result: No output or timeout"
            fi
        else
            echo "  Result: Failed to send SSM command"
        fi
    done
}

# Get AWS PV driver information
get_pv_driver_info() {
    log "Getting AWS PV driver information..."
    
    echo -e "\n${BLUE}=== AWS PV DRIVER INFORMATION ===${NC}"
    echo "Note: PV drivers are primarily used with Windows instances and older Linux instances"
    
    # Get Windows instances with timeout
    WINDOWS_INSTANCES=$(timeout 20 aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=platform,Values=windows" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Platform]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$WINDOWS_INSTANCES" ] && [ "$WINDOWS_INSTANCES" != "None" ]; then
        echo -e "${YELLOW}Windows instances found (may have PV drivers):${NC}"
        echo "$WINDOWS_INSTANCES"
        
        # Try to get PV driver info via SSM for Windows instances
        get_windows_pv_drivers
    else
        echo "No Windows instances found"
    fi
}

# Get Windows PV driver information via SSM
get_windows_pv_drivers() {
    log "Attempting to get Windows PV driver information..."
    
    # Get Windows instances with SSM
    WINDOWS_SSM_INSTANCES=$(timeout 15 aws ssm describe-instance-information \
        --region "$REGION" \
        --filters "Name=PlatformType,Values=Windows" \
        --query 'InstanceInformationList[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$WINDOWS_SSM_INSTANCES" ] || [ "$WINDOWS_SSM_INSTANCES" = "None" ]; then
        log "No Windows SSM-managed instances found"
        return
    fi
    
    echo -e "\n${BLUE}=== WINDOWS PV DRIVER VERSIONS ===${NC}"
    
    for instance_id in $WINDOWS_SSM_INSTANCES; do
        echo "Checking PV drivers for Windows instance: $instance_id"
        
        # PowerShell command to check AWS PV drivers
        COMMAND_ID=$(timeout 15 aws ssm send-command \
            --region "$REGION" \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunPowerShellScript" \
            --parameters 'commands=["Get-WmiObject Win32_PnPEntity | Where-Object {$_.Name -like \"*AWS*\" -or $_.Name -like \"*Amazon*\"} | Select-Object Name, DriverVersion | Format-Table -AutoSize"]' \
            --query 'Command.CommandId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$COMMAND_ID" ] && [ "$COMMAND_ID" != "None" ]; then
            sleep $SSM_TIMEOUT
            
            OUTPUT=$(timeout 10 aws ssm get-command-invocation \
                --region "$REGION" \
                --command-id "$COMMAND_ID" \
                --instance-id "$instance_id" \
                --query 'StandardOutputContent' \
                --output text 2>/dev/null || echo "Command execution timeout or failed")
            
            if [ -n "$OUTPUT" ]; then
                echo "  AWS/Amazon drivers found:"
                echo "$OUTPUT"
            else
                echo "  Result: No output or timeout"
            fi
        else
            echo "  Result: Failed to send SSM command"
        fi
    done
}

# Generate summary report
generate_summary() {
    log "Generating summary report..."
    
    echo -e "\n${BLUE}=== SUMMARY REPORT ===${NC}"
    
    # Count instances by type with timeout
    TOTAL_INSTANCES=$(timeout 15 aws ec2 describe-instances \
        --region "$REGION" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null || echo "0")
    
    RUNNING_INSTANCES=$(timeout 15 aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null || echo "0")
    
    ENA_ENABLED=$(timeout 15 aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=ena-support,Values=true" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null || echo "0")
    
    SRIOV_ENABLED=$(timeout 15 aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=sriov-net-support,Values=simple" \
        --query 'length(Reservations[*].Instances[*])' \
        --output text 2>/dev/null || echo "0")
    
    echo "Total instances: $TOTAL_INSTANCES"
    echo "Running instances: $RUNNING_INSTANCES"
    echo "ENA-enabled instances: $ENA_ENABLED"
    echo "SR-IOV enabled instances: $SRIOV_ENABLED"
    
    # Calculate percentages if we have running instances
    if [ "$RUNNING_INSTANCES" -gt 0 ]; then
        ENA_PERCENTAGE=$(( (ENA_ENABLED * 100) / RUNNING_INSTANCES ))
        SRIOV_PERCENTAGE=$(( (SRIOV_ENABLED * 100) / RUNNING_INSTANCES ))
        echo "ENA adoption rate: ${ENA_PERCENTAGE}%"
        echo "SR-IOV adoption rate: ${SRIOV_PERCENTAGE}%"
    fi
    
    log "Summary report generated"
}

# Main execution
main() {
    echo -e "${GREEN}AWS EC2 ENA and PV Driver Information Script${NC}"
    echo -e "${GREEN}Region: $REGION${NC}"
    echo -e "${GREEN}Log file: $LOG_FILE${NC}"
    echo -e "${GREEN}Mode: Fully Automated (Non-Interactive)${NC}"
    echo "============================================="
    
    # Set non-interactive mode for AWS CLI
    export AWS_PAGER=""
    export AWS_CLI_AUTO_PROMPT=off
    
    check_prerequisites
    get_ec2_instances
    get_driver_details
    get_ena_driver_version
    get_pv_driver_info
    generate_summary
    
    log "Script execution completed"
    echo -e "\n${GREEN}Script execution completed successfully!${NC}"
    echo -e "${GREEN}Check $LOG_FILE for detailed logs.${NC}"
}

# Execute main function
main "$@"