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

# CSV file names with account ID and timestamp
VAULTS_CSV="${OUTPUT_DIR}/backup_vaults_${ACCOUNT_ID}_${TIMESTAMP}.csv"
BACKUP_PLANS_CSV="${OUTPUT_DIR}/backup_plans_${ACCOUNT_ID}_${TIMESTAMP}.csv"
BACKUP_RULES_CSV="${OUTPUT_DIR}/backup_rules_${ACCOUNT_ID}_${TIMESTAMP}.csv"
RESOURCE_ASSIGNMENTS_CSV="${OUTPUT_DIR}/resource_assignments_${ACCOUNT_ID}_${TIMESTAMP}.csv"

# Create CSV headers
echo "VaultName,VaultArn,EncryptionKeyArn,CreationDate,CreatorRequestId,NumberOfRecoveryPoints" > "$VAULTS_CSV"
echo "BackupPlanId,BackupPlanName,BackupPlanArn,VersionId,CreationDate,CreatorRequestId,LastExecutionDate,AdvancedBackupSettings" > "$BACKUP_PLANS_CSV"
echo "BackupPlanId,BackupPlanName,RuleName,TargetBackupVaultName,ScheduleExpression,StartWindowMinutes,CompletionWindowMinutes,Lifecycle,RecoveryPointTags,CopyActions,EnableContinuousBackup" > "$BACKUP_RULES_CSV"
echo "BackupPlanId,BackupPlanName,SelectionId,SelectionName,IamRoleArn,CreationDate,CreatorRequestId,Resources,Conditions" > "$RESOURCE_ASSIGNMENTS_CSV"

# Function to safely extract JSON values
safe_extract() {
    local value="$1"
    if [ "$value" = "null" ] || [ -z "$value" ]; then
        echo "N/A"
    else
        echo "$value" | sed 's/,/;/g' | tr -d '"'
    fi
}

# Get all backup vaults
echo "Fetching backup vaults..."
VAULTS=$(aws backup list-backup-vaults --region "$AWS_REGION" --output json)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve backup vaults."
    exit 1
fi

VAULT_COUNT=$(echo "$VAULTS" | jq -r '.BackupVaultList | length')
echo "Found $VAULT_COUNT backup vaults"

# Process each vault
echo "$VAULTS" | jq -r '.BackupVaultList[] | @base64' | while IFS= read -r vault_data; do
    VAULT_JSON=$(echo "$vault_data" | base64 --decode)
    
    VAULT_NAME=$(echo "$VAULT_JSON" | jq -r '.BackupVaultName')
    VAULT_ARN=$(echo "$VAULT_JSON" | jq -r '.BackupVaultArn')
    ENCRYPTION_KEY_ARN=$(echo "$VAULT_JSON" | jq -r '.EncryptionKeyArn')
    CREATION_DATE=$(echo "$VAULT_JSON" | jq -r '.CreationDate')
    CREATOR_REQUEST_ID=$(echo "$VAULT_JSON" | jq -r '.CreatorRequestId')
    NUMBER_OF_RECOVERY_POINTS=$(echo "$VAULT_JSON" | jq -r '.NumberOfRecoveryPoints')
    
    echo "Processing vault: $VAULT_NAME"
    
    # Add vault info to CSV
    echo "$(safe_extract "$VAULT_NAME"),$(safe_extract "$VAULT_ARN"),$(safe_extract "$ENCRYPTION_KEY_ARN"),$(safe_extract "$CREATION_DATE"),$(safe_extract "$CREATOR_REQUEST_ID"),$(safe_extract "$NUMBER_OF_RECOVERY_POINTS")" >> "$VAULTS_CSV"
    
    # Get backup plans for this vault
    echo "  Fetching backup plans..."
    BACKUP_PLANS=$(aws backup list-backup-plans --region "$AWS_REGION" --output json)
    
    if [ $? -eq 0 ]; then
        echo "$BACKUP_PLANS" | jq -r '.BackupPlansList[] | @base64' | while IFS= read -r plan_data; do
            PLAN_JSON=$(echo "$plan_data" | base64 --decode)
            
            BACKUP_PLAN_ID=$(echo "$PLAN_JSON" | jq -r '.BackupPlanId')
            BACKUP_PLAN_NAME=$(echo "$PLAN_JSON" | jq -r '.BackupPlanName')
            BACKUP_PLAN_ARN=$(echo "$PLAN_JSON" | jq -r '.BackupPlanArn')
            VERSION_ID=$(echo "$PLAN_JSON" | jq -r '.VersionId')
            PLAN_CREATION_DATE=$(echo "$PLAN_JSON" | jq -r '.CreationDate')
            PLAN_CREATOR_REQUEST_ID=$(echo "$PLAN_JSON" | jq -r '.CreatorRequestId')
            LAST_EXECUTION_DATE=$(echo "$PLAN_JSON" | jq -r '.LastExecutionDate')
            ADVANCED_BACKUP_SETTINGS=$(echo "$PLAN_JSON" | jq -r '.AdvancedBackupSettings')
            
            echo "    Processing backup plan: $BACKUP_PLAN_NAME"
            
            # Add backup plan info to CSV
            echo "$(safe_extract "$BACKUP_PLAN_ID"),$(safe_extract "$BACKUP_PLAN_NAME"),$(safe_extract "$BACKUP_PLAN_ARN"),$(safe_extract "$VERSION_ID"),$(safe_extract "$PLAN_CREATION_DATE"),$(safe_extract "$PLAN_CREATOR_REQUEST_ID"),$(safe_extract "$LAST_EXECUTION_DATE"),$(safe_extract "$ADVANCED_BACKUP_SETTINGS")" >> "$BACKUP_PLANS_CSV"
            
            # Get detailed backup plan with rules
            DETAILED_PLAN=$(aws backup get-backup-plan --backup-plan-id "$BACKUP_PLAN_ID" --region "$AWS_REGION" --output json)
            
            if [ $? -eq 0 ]; then
                # Process backup rules
                echo "$DETAILED_PLAN" | jq -r '.BackupPlan.Rules[]? | @base64' | while IFS= read -r rule_data; do
                    RULE_JSON=$(echo "$rule_data" | base64 --decode)
                    
                    RULE_NAME=$(echo "$RULE_JSON" | jq -r '.RuleName')
                    TARGET_BACKUP_VAULT_NAME=$(echo "$RULE_JSON" | jq -r '.TargetBackupVaultName')
                    SCHEDULE_EXPRESSION=$(echo "$RULE_JSON" | jq -r '.ScheduleExpression')
                    START_WINDOW_MINUTES=$(echo "$RULE_JSON" | jq -r '.StartWindowMinutes')
                    COMPLETION_WINDOW_MINUTES=$(echo "$RULE_JSON" | jq -r '.CompletionWindowMinutes')
                    LIFECYCLE=$(echo "$RULE_JSON" | jq -r '.Lifecycle')
                    RECOVERY_POINT_TAGS=$(echo "$RULE_JSON" | jq -r '.RecoveryPointTags')
                    COPY_ACTIONS=$(echo "$RULE_JSON" | jq -r '.CopyActions')
                    ENABLE_CONTINUOUS_BACKUP=$(echo "$RULE_JSON" | jq -r '.EnableContinuousBackup')
                    
                    echo "      Processing backup rule: $RULE_NAME"
                    
                    # Add backup rule info to CSV
                    echo "$(safe_extract "$BACKUP_PLAN_ID"),$(safe_extract "$BACKUP_PLAN_NAME"),$(safe_extract "$RULE_NAME"),$(safe_extract "$TARGET_BACKUP_VAULT_NAME"),$(safe_extract "$SCHEDULE_EXPRESSION"),$(safe_extract "$START_WINDOW_MINUTES"),$(safe_extract "$COMPLETION_WINDOW_MINUTES"),$(safe_extract "$LIFECYCLE"),$(safe_extract "$RECOVERY_POINT_TAGS"),$(safe_extract "$COPY_ACTIONS"),$(safe_extract "$ENABLE_CONTINUOUS_BACKUP")" >> "$BACKUP_RULES_CSV"
                done
            fi
            
            # Get resource assignments (backup selections) for this plan
            SELECTIONS=$(aws backup list-backup-selections --backup-plan-id "$BACKUP_PLAN_ID" --region "$AWS_REGION" --output json)
            
            if [ $? -eq 0 ]; then
                echo "$SELECTIONS" | jq -r '.BackupSelectionsList[]? | @base64' | while IFS= read -r selection_data; do
                    SELECTION_JSON=$(echo "$selection_data" | base64 --decode)
                    
                    SELECTION_ID=$(echo "$SELECTION_JSON" | jq -r '.SelectionId')
                    SELECTION_NAME=$(echo "$SELECTION_JSON" | jq -r '.SelectionName')
                    IAM_ROLE_ARN=$(echo "$SELECTION_JSON" | jq -r '.IamRoleArn')
                    SELECTION_CREATION_DATE=$(echo "$SELECTION_JSON" | jq -r '.CreationDate')
                    SELECTION_CREATOR_REQUEST_ID=$(echo "$SELECTION_JSON" | jq -r '.CreatorRequestId')
                    
                    echo "      Processing resource assignment: $SELECTION_NAME"
                    
                    # Get detailed selection info
                    DETAILED_SELECTION=$(aws backup get-backup-selection --backup-plan-id "$BACKUP_PLAN_ID" --selection-id "$SELECTION_ID" --region "$AWS_REGION" --output json)
                    
                    if [ $? -eq 0 ]; then
                        RESOURCES=$(echo "$DETAILED_SELECTION" | jq -r '.BackupSelection.Resources')
                        CONDITIONS=$(echo "$DETAILED_SELECTION" | jq -r '.BackupSelection.Conditions')
                        
                        # Add resource assignment info to CSV
                        echo "$(safe_extract "$BACKUP_PLAN_ID"),$(safe_extract "$BACKUP_PLAN_NAME"),$(safe_extract "$SELECTION_ID"),$(safe_extract "$SELECTION_NAME"),$(safe_extract "$IAM_ROLE_ARN"),$(safe_extract "$SELECTION_CREATION_DATE"),$(safe_extract "$SELECTION_CREATOR_REQUEST_ID"),$(safe_extract "$RESOURCES"),$(safe_extract "$CONDITIONS")" >> "$RESOURCE_ASSIGNMENTS_CSV"
                    fi
                done
            fi
        done
    fi
done

echo ""
echo "AWS Backup export completed successfully!"
echo "Output directory: $OUTPUT_DIR"
echo "Files created:"
echo "  - $VAULTS_CSV"
echo "  - $BACKUP_PLANS_CSV"
echo "  - $BACKUP_RULES_CSV"
echo "  - $RESOURCE_ASSIGNMENTS_CSV"
echo ""
echo "Summary:"
echo "  Vaults: $(( $(wc -l < "$VAULTS_CSV") - 1 ))"
echo "  Backup Plans: $(( $(wc -l < "$BACKUP_PLANS_CSV") - 1 ))"
echo "  Backup Rules: $(( $(wc -l < "$BACKUP_RULES_CSV") - 1 ))"
echo "  Resource Assignments: $(( $(wc -l < "$RESOURCE_ASSIGNMENTS_CSV") - 1 ))"