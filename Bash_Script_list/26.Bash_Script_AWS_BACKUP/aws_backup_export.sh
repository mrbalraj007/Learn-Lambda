#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\26.Bash_Script_AWS_BACKUP\aws_backup_export.sh

# Set default region
AWS_REGION="ap-southeast-2"
export AWS_DEFAULT_REGION=$AWS_REGION

# Get current timestamp and account ID
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve AWS Account ID. Please check your AWS credentials."
    exit 1
fi

echo "Starting AWS Backup export for Account: $ACCOUNT_ID in Region: $AWS_REGION"

# Create output directory if it doesn't exist
OUTPUT_DIR="aws_backup_export_${ACCOUNT_ID}_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# Single CSV file name with account ID and timestamp
BACKUP_SUMMARY_CSV="${OUTPUT_DIR}/backup_summary_${ACCOUNT_ID}_${TIMESTAMP}.csv"

# Create CSV header
echo "BackupPlanName,BackupPlanId,BackupVaultName,ResourceAssignmentName,IamRoleArn,CreationDate" > "$BACKUP_SUMMARY_CSV"

# Function to safely extract JSON values
safe_extract() {
    local value="$1"
    if [ "$value" = "null" ] || [ -z "$value" ]; then
        echo "N/A"
    else
        echo "$value" | sed 's/,/;/g' | tr -d '"'
    fi
}

# Get all backup plans
echo "Fetching backup plans..."
BACKUP_PLANS=$(aws backup list-backup-plans --region "$AWS_REGION" --output json)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve backup plans."
    exit 1
fi

PLAN_COUNT=$(echo "$BACKUP_PLANS" | jq -r '.BackupPlansList | length')
echo "Found $PLAN_COUNT backup plans"

# Process each backup plan
echo "$BACKUP_PLANS" | jq -r '.BackupPlansList[] | @base64' | while IFS= read -r plan_data; do
    PLAN_JSON=$(echo "$plan_data" | base64 --decode)
    
    BACKUP_PLAN_ID=$(echo "$PLAN_JSON" | jq -r '.BackupPlanId')
    BACKUP_PLAN_NAME=$(echo "$PLAN_JSON" | jq -r '.BackupPlanName')
    PLAN_CREATION_DATE=$(echo "$PLAN_JSON" | jq -r '.CreationDate')
    
    echo "Processing backup plan: $BACKUP_PLAN_NAME"
    
    # Get detailed backup plan to find vault names
    DETAILED_PLAN=$(aws backup get-backup-plan --backup-plan-id "$BACKUP_PLAN_ID" --region "$AWS_REGION" --output json)
    
    # Extract vault names from backup rules
    VAULT_NAMES=""
    if [ $? -eq 0 ]; then
        VAULT_NAMES=$(echo "$DETAILED_PLAN" | jq -r '.BackupPlan.Rules[]?.TargetBackupVaultName' | sort -u | tr '\n' ';' | sed 's/;$//')
    fi
    
    # Get resource assignments (backup selections) for this plan
    SELECTIONS=$(aws backup list-backup-selections --backup-plan-id "$BACKUP_PLAN_ID" --region "$AWS_REGION" --output json)
    
    if [ $? -eq 0 ] && [ "$(echo "$SELECTIONS" | jq -r '.BackupSelectionsList | length')" -gt 0 ]; then
        # Process each resource assignment
        echo "$SELECTIONS" | jq -r '.BackupSelectionsList[] | @base64' | while IFS= read -r selection_data; do
            SELECTION_JSON=$(echo "$selection_data" | base64 --decode)
            
            SELECTION_NAME=$(echo "$SELECTION_JSON" | jq -r '.SelectionName')
            IAM_ROLE_ARN=$(echo "$SELECTION_JSON" | jq -r '.IamRoleArn')
            
            echo "  Processing resource assignment: $SELECTION_NAME"
            
            # Add to CSV with all vault names for this plan
            echo "$(safe_extract "$BACKUP_PLAN_NAME"),$(safe_extract "$BACKUP_PLAN_ID"),$(safe_extract "$VAULT_NAMES"),$(safe_extract "$SELECTION_NAME"),$(safe_extract "$IAM_ROLE_ARN"),$(safe_extract "$PLAN_CREATION_DATE")" >> "$BACKUP_SUMMARY_CSV"
        done
    else
        # If no resource assignments, still add the backup plan with vault info
        echo "  No resource assignments found"
        echo "$(safe_extract "$BACKUP_PLAN_NAME"),$(safe_extract "$BACKUP_PLAN_ID"),$(safe_extract "$VAULT_NAMES"),N/A,N/A,$(safe_extract "$PLAN_CREATION_DATE")" >> "$BACKUP_SUMMARY_CSV"
    fi
done

echo ""
echo "AWS Backup export completed successfully!"
echo "Output file: $BACKUP_SUMMARY_CSV"
echo ""
echo "Summary:"
echo "  Total entries: $(( $(wc -l < "$BACKUP_SUMMARY_CSV") - 1 ))"