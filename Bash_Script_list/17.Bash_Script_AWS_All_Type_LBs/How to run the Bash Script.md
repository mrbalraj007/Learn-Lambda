# AWS Load Balancer Export & Analysis Tool

This toolset enables comprehensive extraction and analysis of AWS Load Balancer configurations across all types (Classic, Application, Network, and Gateway Load Balancers).

## Overview

The toolkit consists of two scripts:

1. **`export-aws-loadbalancer.sh`**: Exports detailed configuration of all AWS load balancers
2. **`lb-data-processor.sh`**: Post-processes exported data to generate additional insights and reports

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- jq utility installed (`apt-get install jq` or `yum install jq`)
- Bash shell environment
- Optional: Python 3 with pandas and openpyxl libraries for enhanced reporting

## Quick Start Guide
### Step 0:  Create a Virtual Environment first and Run the following script to activate the virtual environment automatically

1. run the bash script.

```bash
./setup_venv.sh
```

2. Activate the virtual environment
```bash
source venv/bin/activate
```


### Step 1: Run the Export Script

First, run the main export script to gather all load balancer information:

```bash
./export-aws-loadbalancer.sh
```

This will:
- Export all load balancer configurations to CSV files
- Create a timestamped output directory (e.g., `aws_lb_export_20230501_120000`)
- Generate seven CSV files with detailed information

### Step 2: Run the Data Processor Script

After the export completes, run the data processor script on the generated directory:

```bash
./lb-data-processor.sh aws_lb_export_20230501_120000
```

Replace `aws_lb_export_20230501_120000` with the actual directory name created by the export script.

This will:
- Generate additional summary reports
- Create cross-references between resources
- Analyze security groups, certificates, and routing rules

### Step 3: Generate Excel Report (Optional)

To combine all CSVs into a single Excel file with multiple sheets:

```bash
cd aws_lb_export_20230501_120000
python3 convert_to_excel.py
```

## Detailed Output Files

### Export Script Output

The export script generates the following files:

| File | Description |
|------|-------------|
| `classic_load_balancers.csv` | Classic Load Balancer configurations |
| `application_load_balancers.csv` | Application Load Balancer configurations |
| `network_load_balancers.csv` | Network Load Balancer configurations |
| `gateway_load_balancers.csv` | Gateway Load Balancer configurations |
| `load_balancer_attributes.csv` | Additional attributes for all load balancers |
| `target_groups_details.csv` | Detailed target group information |
| `alb_routing_rules.csv` | ALB routing rule configurations |

### Data Processor Output

The data processor script creates:

| File | Description |
|------|-------------|
| `processed/lb_summary.txt` | Summary report with counts and statistics |
| `processed/lb_to_targetgroups.csv` | Cross-reference between LBs and target groups |

## AWS Region Selection

By default, the scripts use `ap-southeast-2` region. To use a different region:

```bash
# Option 1: Change the default in the script
# Edit the script and change: export AWS_DEFAULT_REGION="your-region"

# Option 2: Set temporarily for the session
export AWS_DEFAULT_REGION="us-east-1"
./export-aws-loadbalancer.sh
```

## Troubleshooting

### AWS Authentication Issues

If you encounter authentication errors:

### Step-by-step Instructions active the virtual environment(Manually)
1. Create a virtual environment <br>
Choose a name for the virtual environment directory (e.g., venv):
```bash
python3 -m venv venv
```
2. Activate the virtual environment
```bash
source venv/bin/activate
```
You'll know it's activated when your shell prompt is prefixed with `(venv)`.

3. Install pandas in the virtual environment
```bash
pip install pandas
```
4. Run your script using the Python in the virtual environment
```bash
python3 aws_lb_export_20250625_153748/convert_to_excel.py
```
ℹ️ Notes
- To deactivate the virtual environment when you're done:
```bash
deactivate
```
This method avoids modifying the system Python and keeps your environment clean.