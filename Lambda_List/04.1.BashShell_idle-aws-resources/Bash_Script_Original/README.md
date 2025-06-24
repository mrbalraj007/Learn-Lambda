# AWS Cost Optimization Audit Tool

This tool generates comprehensive HTML reports to identify idle or cost-inefficient AWS resources across specified regions. It helps DevOps teams and cloud administrators optimize AWS spending by identifying unused or improperly configured resources.

## Prerequisites

Before running the audit scripts, ensure you have the following:
0. **JQ installed**
   - Install JQ: [JQ Installation Guide](https://jqlang.org/download/)
   
1. **AWS CLI installed and configured**
   - Install AWS CLI: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
   - Configure with credentials: `aws configure`
   - Ensure your configured credentials have sufficient read permissions

2. **Required IAM Permissions**
   - Your IAM user/role must have read-only permissions for all services being audited
   - Recommended to use the AWS managed policy `ReadOnlyAccess` or equivalent custom policy

3. **Bash Shell Environment**
   - Works on Linux, macOS, or Windows with WSL/Git Bash
   - Requires `bash` version 4+
   - Requires standard utilities like `date`, `tee`

4. **Script Dependencies**
   - Ensure all referenced check scripts are in the same directory as `main.sh`
   - Scripts should be executable (`chmod +x *.sh`)

## How to Use

Follow these steps to run the AWS audit:

1. **Clone or download the repository**
   ```bash
   git clone <repository-url>
   cd 04.1.BashShell_idle-aws-resources
   ```

2. **Ensure scripts are executable**
   ```bash
   chmod +x *.sh
   ```

3. **Run the main script**
   ```bash
   ./main.sh
   ```

4. **Region Selection**
   - The script will display a list of available AWS regions
   - Select a specific region by entering its number
   - Enter '0' to scan all regions (warning: this may take a long time)
   - Enter the last option to specify custom regions
   - Press Enter without input to use your default region

5. **View the Results**
   - An HTML report will be generated in the same directory
   - The filename follows the format: `aws_audit_report_YYYYMMDD_HHMMSS.html`
   - Open this file in any web browser to review findings

## What the Tool Checks

The audit performs the following checks across the selected regions:

- **Budget Alerts**: Verifies if AWS budget alerts are configured
- **Resource Tagging**: Identifies untagged resources that might be unaccounted for
- **Idle EC2 Resources**: Finds EC2 instances with low utilization
- **S3 Lifecycle Policies**: Checks if S3 buckets have proper lifecycle policies
- **Old RDS Snapshots**: Identifies old database snapshots that can be removed
- **Forgotten EBS Volumes**: Finds detached EBS volumes incurring charges
- **Data Transfer Risks**: Checks for potential excessive data transfer costs
- **On-Demand Instances**: Identifies instances that could use reserved pricing
- **Idle Load Balancers**: Discovers load balancers with little to no traffic
- **Route 53 Records**: Reviews DNS records for optimization
- **EKS Clusters**: Checks for underutilized Kubernetes clusters
- **IAM Usage**: Reviews IAM permissions for best practices
- **Security Groups**: Identifies unused or misconfigured security groups

## Understanding the Report

The generated HTML report contains:

- Account information and scan timestamp
- Region-by-region analysis of resources
- Color-coded status indicators (green for good, yellow for warnings, red for issues)
- Detailed output from each check script
- Summary of findings at the end

## Resource Scanner

The included `aws_scan_resources.sh` script provides a quick overview of resources across all regions without the detailed analysis. Run it separately if you just need a resource inventory:

```bash
./aws_scan_resources.sh
```

## Utility Functions

Common functions are available in `utils.sh` for logging and AWS operations:

- `get_account_id`: Retrieve current AWS account ID
- `log_info`, `log_warn`, `log_success`, `log_error`: Formatted logging functions

## Troubleshooting

- **Permission Issues**: Ensure your AWS credentials have sufficient read permissions
- **Region Errors**: Verify region names if using custom region input
- **Missing Scripts**: Ensure all check scripts exist in the same directory
- **Performance Issues**: For large AWS accounts, consider running against specific regions

## Contributing

To extend this tool:

1. Create new check scripts following the same output format
2. Add them to the `run_check` calls in `main.sh`
3. Ensure they handle errors gracefully
