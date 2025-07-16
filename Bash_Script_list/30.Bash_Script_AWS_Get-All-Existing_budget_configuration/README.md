# AWS Budget Configuration Extractor

This script extracts all existing AWS budget configurations and saves them to a CSV file with the account ID included in the filename.

## Prerequisites

- AWS CLI installed and configured
- `jq` command-line JSON processor installed
- Appropriate AWS permissions to read budgets

## Required AWS Permissions

The script requires the following IAM permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "budgets:ViewBudget",
                "budgets:DescribeBudgets",
                "budgets:DescribeBudgetActionsForBudget",
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

1. Make the script executable:
   ```bash
   chmod +x get_budget_config.sh
   ```

2. Run the script:
   ```bash
   ./get_budget_config.sh
   ```

## Output

The script generates a CSV file with the following naming convention:
`budget_config_{ACCOUNT_ID}_{TIMESTAMP}.csv`

### CSV Columns

- **Budget Name**: Name of the budget
- **Budget Type**: Type of budget (COST, USAGE, etc.)
- **Period**: Budget period (MONTHLY, QUARTERLY, ANNUALLY)
- **Start Date**: Budget start date
- **Budget Amount**: Budget limit amount
- **Currency**: Budget currency (USD, etc.)
- **Budget Plan**: Type of action plan
- **Action Type**: Type of action configured
- **Action Threshold**: Threshold value for action
- **Action Threshold Type**: Type of threshold (PERCENTAGE, ABSOLUTE_VALUE)
- **Notification Email**: Email addresses for notifications
- **Cost Filter**: Applied cost filters
- **Time Unit**: Time unit for the budget

## Features

- Extracts all budget configurations from the AWS account
- Includes account ID in the filename (not in CSV content)
- Handles budgets with multiple actions
- Provides colored console output for better readability
- Error handling and logging
- Timestamp in filename for version control

## Error Handling

The script includes comprehensive error handling for:
- Missing AWS CLI or jq
- Invalid AWS credentials
- Failed API calls
- Empty budget lists

## Example Output

```
[INFO] Retrieving AWS Account ID...
[INFO] Account ID: 123456789012
[INFO] Retrieving budget list...
[INFO] Found budgets: MyBudget1 MyBudget2
[INFO] Processing budget: MyBudget1
[INFO] Processing budget: MyBudget2
[INFO] Budget configuration exported successfully to: budget_config_123456789012_20241201_143022.csv
[INFO] Total budgets processed: 2
[INFO] Account ID: 123456789012 (included in filename)
[INFO] Total rows in CSV (excluding header): 3
[INFO] Script completed successfully!
```
