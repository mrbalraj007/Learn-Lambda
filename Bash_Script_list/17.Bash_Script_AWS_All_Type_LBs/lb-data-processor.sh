#!/bin/bash
# Script to process load balancer data exports and generate additional reports

# Check if directory argument is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <export-directory>"
    echo "Example: $0 aws_lb_export_20230501_120000"
    exit 1
fi

export_dir="$1"

# Check if directory exists
if [ ! -d "$export_dir" ]; then
    echo "Error: Directory $export_dir does not exist"
    exit 1
fi

# Create output directory for processed data
processed_dir="${export_dir}/processed"
mkdir -p "$processed_dir"

# Check for Python and required modules
if ! command -v python3 &>/dev/null; then
    echo "Warning: Python 3 not found. Some processing features won't work."
    has_python=false
else
    has_python=true
    
    # Check for pandas
    if ! python3 -c "import pandas" &>/dev/null; then
        echo "Warning: Python pandas module not found. Install with: pip install pandas"
        has_pandas=false
    else
        has_pandas=true
    fi
fi

echo "Processing AWS Load Balancer data from $export_dir"

# Function to count lines in a CSV file (minus header)
count_entries() {
    local file="$1"
    if [ -f "$file" ]; then
        wc -l < "$file" | awk '{print $1-1}'
    else
        echo "0"
    fi
}

# Generate summary statistics
echo "Generating summary report..."
summary_file="${processed_dir}/lb_summary.txt"

echo "AWS LOAD BALANCER SUMMARY" > "$summary_file"
echo "=========================" >> "$summary_file"
echo "Generated: $(date)" >> "$summary_file"
echo "" >> "$summary_file"

# Count load balancers by type
clb_count=$(count_entries "${export_dir}/classic_load_balancers.csv")
alb_count=$(count_entries "${export_dir}/application_load_balancers.csv")
nlb_count=$(count_entries "${export_dir}/network_load_balancers.csv")
glb_count=$(count_entries "${export_dir}/gateway_load_balancers.csv")
total_lbs=$((clb_count + alb_count + nlb_count + glb_count))

# Write summary counts
echo "LOAD BALANCER COUNTS" >> "$summary_file"
echo "--------------------" >> "$summary_file"
echo "Classic Load Balancers: $clb_count" >> "$summary_file"
echo "Application Load Balancers: $alb_count" >> "$summary_file"
echo "Network Load Balancers: $nlb_count" >> "$summary_file"
echo "Gateway Load Balancers: $glb_count" >> "$summary_file"
echo "Total Load Balancers: $total_lbs" >> "$summary_file"
echo "" >> "$summary_file"

# Count target groups if file exists
tg_file="${export_dir}/target_groups_details.csv"
if [ -f "$tg_file" ]; then
    tg_count=$(count_entries "$tg_file")
    echo "TARGET GROUP INFORMATION" >> "$summary_file"
    echo "-----------------------" >> "$summary_file"
    echo "Total Target Groups: $tg_count" >> "$summary_file"
    
    # Extract healthy/unhealthy targets
    if [ "$has_python" = true ] && [ "$has_pandas" = true ]; then
        python3 -c "
import pandas as pd
try:
    df = pd.read_csv('$tg_file')
    total_targets = df['TargetCount'].astype(int).sum()
    healthy = df['HealthyTargets'].astype(int).sum()
    unhealthy = df['UnhealthyTargets'].astype(int).sum()
    print(f'Total Registered Targets: {total_targets}')
    print(f'Healthy Targets: {healthy}')
    print(f'Unhealthy Targets: {unhealthy}')
    if total_targets > 0:
        health_pct = (healthy / total_targets) * 100
        print(f'Target Health Percentage: {health_pct:.2f}%')
except Exception as e:
    print(f'Error processing target data: {e}')
" >> "$summary_file"
    else
        echo "For detailed target health information, install Python with pandas" >> "$summary_file"
    fi
    echo "" >> "$summary_file"
fi

# Extract security group information for ALBs
alb_file="${export_dir}/application_load_balancers.csv"
if [ -f "$alb_file" ]; then
    echo "ALB SECURITY GROUP INFORMATION" >> "$summary_file"
    echo "-----------------------------" >> "$summary_file"
    
    # Use awk to extract and count security groups
    if [ -s "$alb_file" ]; then
        awk -F '",' 'NR > 1 {print $7}' "$alb_file" | sort | uniq -c | sort -nr | 
        while read count sg; do
            echo "$count ALBs use security group(s): $sg" >> "$summary_file"
        done
    else
        echo "No ALB security group data available" >> "$summary_file"
    fi
    echo "" >> "$summary_file"
fi

# Extract routing rule information if available
rules_file="${export_dir}/alb_routing_rules.csv"
if [ -f "$rules_file" ]; then
    rules_count=$(count_entries "$rules_file")
    echo "ALB ROUTING RULES" >> "$summary_file"
    echo "----------------" >> "$summary_file"
    echo "Total Routing Rules: $rules_count" >> "$summary_file"
    
    # Count rule types
    if [ -s "$rules_file" ] && [ "$has_python" = true ] && [ "$has_pandas" = true ]; then
        python3 -c "
import pandas as pd
try:
    df = pd.read_csv('$rules_file')
    default_rules = df[df['IsDefault'] == 'true'].shape[0]
    custom_rules = df[df['IsDefault'] == 'false'].shape[0]
    print(f'Default Rules: {default_rules}')
    print(f'Custom Rules: {custom_rules}')
    
    # Analyze rule conditions
    conditions = df['Conditions'].dropna()
    host_rules = conditions.str.contains('Host=').sum()
    path_rules = conditions.str.contains('Path=').sum()
    header_rules = conditions.str.contains('Header').sum()
    method_rules = conditions.str.contains('Method=').sum()
    query_rules = conditions.str.contains('Query=').sum()
    source_ip_rules = conditions.str.contains('SourceIP=').sum()
    
    print(f'\\nRule Condition Types:')
    print(f'  Host Header Rules: {host_rules}')
    print(f'  Path Pattern Rules: {path_rules}')
    print(f'  HTTP Header Rules: {header_rules}')
    print(f'  Request Method Rules: {method_rules}')
    print(f'  Query String Rules: {query_rules}')
    print(f'  Source IP Rules: {source_ip_rules}')
except Exception as e:
    print(f'Error processing routing rules: {e}')
" >> "$summary_file"
    fi
    echo "" >> "$summary_file"
fi

# Generate certificate usage report
echo "CERTIFICATE USAGE" >> "$summary_file"
echo "----------------" >> "$summary_file"

# Process all LB types to find certificates
for file in "$alb_file" "${export_dir}/network_load_balancers.csv"; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        # Extract certificate ARNs using awk
        awk -F '",' 'NR > 1 && $24 != "\"N/A" {print $24}' "$file" | sort | uniq -c | sort -nr |
        while read count cert; do
            # Clean up the certificate string
            clean_cert=$(echo "$cert" | tr -d '"')
            if [ "$clean_cert" != "N/A" ]; then
                echo "$count load balancers use certificate: $clean_cert" >> "$summary_file"
            fi
        done
    fi
done
echo "" >> "$summary_file"

# Create cross-reference of LBs to target groups if possible
if [ "$has_python" = true ] && [ "$has_pandas" = true ]; then
    echo "Generating load balancer to target group mappings..."
    python3 -c "
import pandas as pd
import os

try:
    # Output file
    output_file = '${processed_dir}/lb_to_targetgroups.csv'
    
    # Initialize empty DataFrame for results
    result_df = pd.DataFrame(columns=['LoadBalancerName', 'LoadBalancerType', 'TargetGroups'])
    
    # Process each LB type
    lb_types = {
        'ALB': '${export_dir}/application_load_balancers.csv',
        'NLB': '${export_dir}/network_load_balancers.csv',
        'GLB': '${export_dir}/gateway_load_balancers.csv'
    }
    
    for lb_type, file_path in lb_types.items():
        if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
            df = pd.read_csv(file_path)
            if not df.empty:
                # Group by LB name and concatenate target groups
                grouped = df.groupby('LB_Name').agg({
                    'TargetGroup_Name': lambda x: '|'.join(sorted(set([i for i in x if i != 'N/A'])))
                }).reset_index()
                
                # Add LB type
                grouped['LoadBalancerType'] = lb_type
                
                # Rename columns
                grouped = grouped.rename(columns={
                    'LB_Name': 'LoadBalancerName',
                    'TargetGroup_Name': 'TargetGroups'
                })
                
                # Append to results
                result_df = pd.concat([result_df, grouped[['LoadBalancerName', 'LoadBalancerType', 'TargetGroups']]])
    
    # Save to CSV
    if not result_df.empty:
        result_df.to_csv(output_file, index=False)
        print(f'Created cross-reference file: {output_file}')
    else:
        print('No data available for cross-reference')
        
except Exception as e:
    print(f'Error creating cross-reference: {e}')
"
fi

echo "Processing completed. Summary report available at: $summary_file"

if [ -d "$processed_dir" ]; then
    echo "Additional processed files are in: $processed_dir"
fi

# Merge with original Excel conversion script if it exists
python_script="${export_dir}/convert_to_excel.py"
if [ -f "$python_script" ]; then
    echo "Updating Excel conversion script to include processed data..."
    # Add processed directory to the script
    sed -i "s|current_dir = os.path.dirname(os.path.abspath(__file__))|current_dir = os.path.dirname(os.path.abspath(__file__))\n    processed_dir = os.path.join(current_dir, 'processed')|" "$python_script"
    sed -i "s|for csv_file in os.listdir(current_dir):|for root_dir in [current_dir, processed_dir]:\n        if os.path.exists(root_dir):\n            for csv_file in os.listdir(root_dir):|" "$python_script"
    sed -i "s|df = pd.read_csv(os.path.join(current_dir, csv_file))|df = pd.read_csv(os.path.join(root_dir, csv_file))|" "$python_script"
    
    echo "Excel conversion script updated to include processed data"
    echo "Run the following to create a complete Excel report:"
    echo "  python3 $python_script"
fi
