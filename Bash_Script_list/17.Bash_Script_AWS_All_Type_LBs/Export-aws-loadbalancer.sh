#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\31.Bash_Script_AWS_All_Type_LBs\export-aws-loadbalancers.sh

# Script to export AWS Load Balancer information to separate CSV files by load balancer type
# Covers Classic Load Balancers (CLB), Application Load Balancers (ALB),
# Network Load Balancers (NLB), and Gateway Load Balancers (GLB)

set -e

# Parse command line arguments
DEBUG=0
while getopts "r:d" opt; do
  case $opt in
    r) AWS_DEFAULT_REGION="$OPTARG" ;;
    d) DEBUG=1 ;;
    *) echo "Usage: $0 [-r region] [-d]" >&2
       echo "  -r: AWS region (default: ap-southeast-2)" >&2
       echo "  -d: Enable debug mode" >&2
       exit 1 ;;
  esac
done

# Set default region if not provided
: ${AWS_DEFAULT_REGION:="ap-southeast-2"}
export AWS_DEFAULT_REGION

# Debug function
debug() {
    if [ $DEBUG -eq 1 ]; then
        echo "DEBUG: $1" >&2
        if [ ! -z "$2" ]; then
            echo "$2" | jq . >&2
        fi
    fi
}

# Create output directory with timestamp
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="aws_lb_export_$timestamp"
mkdir -p "$output_dir"

# Define output files
clb_file="$output_dir/classic_load_balancers.csv"
alb_file="$output_dir/application_load_balancers.csv"
nlb_file="$output_dir/network_load_balancers.csv"
glb_file="$output_dir/gateway_load_balancers.csv"

# Check for dependencies
for cmd in aws jq; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: $cmd is required but not installed. Please install it first."
        exit 1
    fi
done

echo "Starting AWS Load Balancer export (Region: $AWS_DEFAULT_REGION)"

# Function to handle AWS command errors
run_aws_cmd() {
    local cmd_output
    local cmd_status
    
    debug "Running: aws $*"
    cmd_output=$(aws "$@" 2>/dev/null)
    cmd_status=$?
    
    if [ $cmd_status -ne 0 ]; then
        echo "Warning: Failed to execute: aws $*" >&2
        echo "{}"
    else
        debug "Command output:" "$cmd_output"
        echo "$cmd_output"
    fi
}

# Function to get resource tags
get_tags() {
    local arn=$1
    local tags
    
    if [[ $arn == *"loadbalancer/app"* || $arn == *"loadbalancer/net"* || $arn == *"loadbalancer/gwy"* || $arn == *"targetgroup"* ]]; then
        # ALB, NLB, GLB, or Target Group
        tags=$(run_aws_cmd elbv2 describe-tags --resource-arns "$arn" --query 'TagDescriptions[0].Tags')
    elif [[ $arn == *"loadbalancer"* ]]; then
        # Classic LB - extract name from ARN
        local lb_name=$(echo "$arn" | awk -F: '{print $NF}' | sed 's/loadbalancer\///')
        tags=$(run_aws_cmd elb describe-tags --load-balancer-names "$lb_name" --query 'TagDescriptions[0].Tags')
    else
        tags="[]"
    fi
    
    # Format tags as Key=Value|Key=Value
    if [ -z "$tags" ] || [ "$tags" == "[]" ] || [ "$tags" == "null" ]; then
        echo "N/A"
    else
        echo "$tags" | jq -r 'map("\(.Key)=\(.Value)") | join("|")' 2>/dev/null || echo "N/A"
    fi
}

# Initialize CSV files with headers
echo "LB_Name,DNS_Name,Scheme,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,Protocol,Port,InstancePort,SSLCertificate,HealthCheck_Target,HealthCheck_Interval,HealthCheck_Timeout,HealthCheck_HealthyThreshold,HealthCheck_UnhealthyThreshold,Tags" > "$clb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$alb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$nlb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,Tags" > "$glb_file"

# Test AWS CLI access
echo "Testing AWS CLI connectivity..."
account_id=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Cannot authenticate with AWS. Check your credentials and try again."
    exit 1
else
    echo "Successfully authenticated with AWS (Account ID: $account_id)"
fi

# Process Classic Load Balancers
echo "Fetching Classic Load Balancers..."
clbs=$(run_aws_cmd elb describe-load-balancers)
debug "Raw CLB response:" "$clbs"

# Add default fields to avoid errors if they don't exist
clbs=$(echo "$clbs" | jq '. += {"LoadBalancerDescriptions": []} | select(.LoadBalancerDescriptions == null) |= {"LoadBalancerDescriptions": []}')
num_clbs=$(echo "$clbs" | jq -r '.LoadBalancerDescriptions | length')

debug "Number of Classic Load Balancers found: $num_clbs"

if [ "$num_clbs" -gt 0 ]; then
    for lb in $(echo "$clbs" | jq -c '.LoadBalancerDescriptions[]'); do
        lb_name=$(echo "$lb" | jq -r '.LoadBalancerName')
        dns_name=$(echo "$lb" | jq -r '.DNSName')
        scheme=$(echo "$lb" | jq -r '.Scheme // "internet-facing"')
        vpc_id=$(echo "$lb" | jq -r '.VPCId // "N/A"')
        security_groups=$(echo "$lb" | jq -r '.SecurityGroups | join("|") // "N/A"')
        subnets=$(echo "$lb" | jq -r '.Subnets | join("|") // "N/A"')
        azs=$(echo "$lb" | jq -r '.AvailabilityZones | join("|") // "N/A"')
        lb_arn="arn:aws:elasticloadbalancing:$AWS_DEFAULT_REGION:$(aws sts get-caller-identity --query 'Account' --output text):loadbalancer/$lb_name"
        
        # Health check
        hc_target=$(echo "$lb" | jq -r '.HealthCheck.Target')
        hc_interval=$(echo "$lb" | jq -r '.HealthCheck.Interval')
        hc_timeout=$(echo "$lb" | jq -r '.HealthCheck.Timeout')
        hc_healthy=$(echo "$lb" | jq -r '.HealthCheck.HealthyThreshold')
        hc_unhealthy=$(echo "$lb" | jq -r '.HealthCheck.UnhealthyThreshold')
        
        # Tags
        tags=$(get_tags "$lb_arn")
        
        # Process listeners
        listeners=$(echo "$lb" | jq -c '.ListenerDescriptions[]')
        if [ -z "$listeners" ]; then
            # No listeners, output basic info
            echo "\"$lb_name\",\"$dns_name\",\"$scheme\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$hc_target\",\"$hc_interval\",\"$hc_timeout\",\"$hc_healthy\",\"$hc_unhealthy\",\"$tags\"" >> "$clb_file"
        else
            # Output one row per listener
            echo "$listeners" | while read -r listener_data; do
                protocol=$(echo "$listener_data" | jq -r '.Listener.Protocol')
                lb_port=$(echo "$listener_data" | jq -r '.Listener.LoadBalancerPort')
                instance_port=$(echo "$listener_data" | jq -r '.Listener.InstancePort')
                
                # SSL Certificate
                ssl_cert="N/A"
                if [[ "$protocol" == "HTTPS" || "$protocol" == "SSL" ]]; then
                    ssl_cert=$(echo "$listener_data" | jq -r '.Listener.SSLCertificateId // "N/A"')
                fi
                
                echo "\"$lb_name\",\"$dns_name\",\"$scheme\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"$protocol\",\"$lb_port\",\"$instance_port\",\"$ssl_cert\",\"$hc_target\",\"$hc_interval\",\"$hc_timeout\",\"$hc_healthy\",\"$hc_unhealthy\",\"$tags\"" >> "$clb_file"
            done
        fi
    done
    echo "Processed $num_clbs Classic Load Balancer(s)"
else
    echo "No Classic Load Balancers found"
fi

# Process Application, Network, and Gateway Load Balancers
echo "Fetching Application, Network, and Gateway Load Balancers..."
lbs=$(run_aws_cmd elbv2 describe-load-balancers)
debug "Raw ELBv2 response:" "$lbs" 

# Add default fields to avoid errors if they don't exist
lbs=$(echo "$lbs" | jq '. += {"LoadBalancers": []} | select(.LoadBalancers == null) |= {"LoadBalancers": []}')
num_lbs=$(echo "$lbs" | jq -r '.LoadBalancers | length')

debug "Number of ELBv2 Load Balancers found: $num_lbs"

if [ "$num_lbs" -gt 0 ]; then
    for lb in $(echo "$lbs" | jq -c '.LoadBalancers[]'); do
        lb_arn=$(echo "$lb" | jq -r '.LoadBalancerArn')
        lb_name=$(echo "$lb" | jq -r '.LoadBalancerName')
        lb_type=$(echo "$lb" | jq -r '.Type')
        
        # Determine output file based on LB type
        if [ "$lb_type" == "application" ]; then
            output_file="$alb_file"
        elif [ "$lb_type" == "network" ]; then
            output_file="$nlb_file"
        elif [ "$lb_type" == "gateway" ]; then
            output_file="$glb_file"
        else
            echo "Unknown load balancer type: $lb_type, skipping"
            continue
        fi
        
        dns_name=$(echo "$lb" | jq -r '.DNSName')
        scheme=$(echo "$lb" | jq -r '.Scheme // "internet-facing"')
        state=$(echo "$lb" | jq -r '.State.Code')
        vpc_id=$(echo "$lb" | jq -r '.VpcId')
        
        # Security groups (only for ALB)
        security_groups="N/A"
        if [ "$lb_type" == "application" ]; then
            security_groups=$(echo "$lb" | jq -r '.SecurityGroups | join("|") // "N/A"')
        fi
        
        # Subnets and AZs
        az_info=$(echo "$lb" | jq -c '.AvailabilityZones')
        azs=$(echo "$az_info" | jq -r '.[].ZoneName' | paste -sd "|" -)
        subnets=$(echo "$az_info" | jq -r '.[].SubnetId' | paste -sd "|" -)
        
        # Tags
        tags=$(get_tags "$lb_arn")
        
        # Get target groups
        tgs=$(run_aws_cmd elbv2 describe-target-groups --load-balancer-arn "$lb_arn")
        
        # Get listeners
        listeners=$(run_aws_cmd elbv2 describe-listeners --load-balancer-arn "$lb_arn")
        
        # If no target groups, output basic LB info
        if [ "$(echo "$tgs" | jq -r '.TargetGroups | length')" -eq 0 ]; then
            if [ "$lb_type" == "application" ]; then
                echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$tags\"" >> "$output_file"
            elif [ "$lb_type" == "network" ]; then
                echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$tags\"" >> "$output_file"
            else # gateway
                echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$tags\"" >> "$output_file"
            fi
            continue
        fi
        
        # Process target groups
        for tg in $(echo "$tgs" | jq -c '.TargetGroups[]'); do
            tg_arn=$(echo "$tg" | jq -r '.TargetGroupArn')
            tg_name=$(echo "$tg" | jq -r '.TargetGroupName')
            tg_protocol=$(echo "$tg" | jq -r '.Protocol')
            tg_port=$(echo "$tg" | jq -r '.Port')
            tg_type=$(echo "$tg" | jq -r '.TargetType')
            
            # Health check info
            hc_path=$(echo "$tg" | jq -r '.HealthCheckPath // "N/A"')
            hc_port=$(echo "$tg" | jq -r '.HealthCheckPort')
            healthy_threshold=$(echo "$tg" | jq -r '.HealthyThresholdCount')
            unhealthy_threshold=$(echo "$tg" | jq -r '.UnhealthyThresholdCount')
            timeout=$(echo "$tg" | jq -r '.HealthCheckTimeoutSeconds')
            interval=$(echo "$tg" | jq -r '.HealthCheckIntervalSeconds')
            
            # Get target group tags
            tg_tags=$(get_tags "$tg_arn")
            combined_tags="$tags"
            [ "$tg_tags" != "N/A" ] && combined_tags="${tags}|${tg_tags}"
            
            # If no listeners, output with target group info only
            if [ "$(echo "$listeners" | jq -r '.Listeners | length')" -eq 0 ]; then
                if [ "$lb_type" == "application" ]; then
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                elif [ "$lb_type" == "network" ]; then
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                else # gateway
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                fi
                continue
            fi
            
            # Find listeners associated with this target group
            listener_found=false
            
            for listener in $(echo "$listeners" | jq -c '.Listeners[]'); do
                listener_arn=$(echo "$listener" | jq -r '.ListenerArn')
                listener_protocol=$(echo "$listener" | jq -r '.Protocol')
                listener_port=$(echo "$listener" | jq -r '.Port')
                
                # Check rules to see if they reference this target group
                rules=$(run_aws_cmd elbv2 describe-rules --listener-arn "$listener_arn")
                
                tg_used=false
                for rule in $(echo "$rules" | jq -c '.Rules[]'); do
                    actions=$(echo "$rule" | jq -c '.Actions')
                    if [ "$(echo "$actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                        tg_used=true
                        break
                    fi
                done
                
                if $tg_used; then
                    listener_found=true
                    # Get SSL certificate if applicable
                    ssl_cert="N/A"
                    if [[ "$listener_protocol" == "HTTPS" || "$listener_protocol" == "TLS" ]]; then
                        certs=$(run_aws_cmd elbv2 describe-listener-certificates --listener-arn "$listener_arn")
                        ssl_cert=$(echo "$certs" | jq -r '.Certificates[0].CertificateArn // "N/A"')
                    fi
                    
                    if [ "$lb_type" == "application" ]; then
                        echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"$listener_arn\",\"$listener_protocol\",\"$listener_port\",\"$ssl_cert\",\"$combined_tags\"" >> "$output_file"
                    elif [ "$lb_type" == "network" ]; then
                        echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"$listener_arn\",\"$listener_protocol\",\"$listener_port\",\"$ssl_cert\",\"$combined_tags\"" >> "$output_file"
                    else # gateway
                        echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"$listener_arn\",\"$listener_protocol\",\"$listener_port\",\"$combined_tags\"" >> "$output_file"
                    fi
                fi
            done
            
            # If no matching listener was found, output target group with basic info
            if ! $listener_found; then
                if [ "$lb_type" == "application" ]; then
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                elif [ "$lb_type" == "network" ]; then
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                else # gateway
                    echo "\"$lb_name\",\"$lb_arn\",\"$dns_name\",\"$scheme\",\"$state\",\"$vpc_id\",\"$subnets\",\"$azs\",\"$tg_name\",\"$tg_arn\",\"$tg_type\",\"$tg_protocol\",\"$tg_port\",\"$hc_path\",\"$hc_port\",\"$healthy_threshold\",\"$unhealthy_threshold\",\"$timeout\",\"$interval\",\"N/A\",\"N/A\",\"N/A\",\"$combined_tags\"" >> "$output_file"
                fi
            fi
        done
    done
    
    echo "Processed:"
    echo "  - $(grep -c "," "$alb_file" 2>/dev/null | awk '{print $1-1}') Application Load Balancer entries"
    echo "  - $(grep -c "," "$nlb_file" 2>/dev/null | awk '{print $1-1}') Network Load Balancer entries"
    echo "  - $(grep -c "," "$glb_file" 2>/dev/null | awk '{print $1-1}') Gateway Load Balancer entries"
else
    echo "No Application, Network, or Gateway Load Balancers found"
    
    # Check if we should scan other regions
    total_lbs_found=0
    if [ "$num_clbs" -eq 0 ] && [ "$num_lbs" -eq 0 ]; then
        echo ""
        echo "Would you like to scan all AWS regions for load balancers? (y/n)"
        read -r scan_all_regions
        
        if [[ "$scan_all_regions" =~ ^[Yy]$ ]]; then
            echo "Scanning all AWS regions for load balancers..."
            
            # Get list of all AWS regions
            all_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)
            
            echo "Found $(echo "$all_regions" | wc -w) regions to scan"
            echo "This may take a while..."
            
            # Create summary file
            region_summary="$output_dir/region_summary.csv"
            echo "Region,Classic_LB_Count,Application_LB_Count,Network_LB_Count,Gateway_LB_Count,Total_LB_Count" > "$region_summary"
            
            # Check each region
            for region in $all_regions; do
                echo -n "Checking region $region... "
                
                # Check Classic LBs
                clb_count=$(aws elb describe-load-balancers --region "$region" --query 'length(LoadBalancerDescriptions)' --output text 2>/dev/null || echo 0)
                
                # Check ELBv2 (ALB, NLB, GLB)
                elbv2_output=$(aws elbv2 describe-load-balancers --region "$region" 2>/dev/null || echo '{"LoadBalancers":[]}')
                alb_count=$(echo "$elbv2_output" | jq '[.LoadBalancers[] | select(.Type=="application")] | length' 2>/dev/null || echo 0)
                nlb_count=$(echo "$elbv2_output" | jq '[.LoadBalancers[] | select(.Type=="network")] | length' 2>/dev/null || echo 0)
                gwlb_count=$(echo "$elbv2_output" | jq '[.LoadBalancers[] | select(.Type=="gateway")] | length' 2>/dev/null || echo 0)
                
                # Calculate total
                total_count=$((clb_count + alb_count + nlb_count + gwlb_count))
                total_lbs_found=$((total_lbs_found + total_count))
                
                # Add to summary
                echo "$region,$clb_count,$alb_count,$nlb_count,$gwlb_count,$total_count" >> "$region_summary"
                
                # Show result for this region
                if [ "$total_count" -gt 0 ]; then
                    echo "Found $total_count load balancer(s): $clb_count CLB, $alb_count ALB, $nlb_count NLB, $gwlb_count GWLB"
                else
                    echo "None found"
                fi
            done
            
            # Display summary
            if [ "$total_lbs_found" -gt 0 ]; then
                echo ""
                echo "Summary: Found $total_lbs_found load balancers across all regions."
                echo "See detailed breakdown in $region_summary"
                echo ""
                echo "To export load balancers from a specific region, run:"
                echo "  $0 -r <region_name>"
            else
                echo ""
                echo "No load balancers found in any region."
            fi
        fi
    fi
fi

# Create a helper script to convert CSVs to Excel with multiple sheets
cat > "$output_dir/convert_to_excel.py" << 'EOL'
#!/usr/bin/env python3
"""
Script to convert multiple CSV files to a single Excel file with multiple sheets.
Requires pandas and openpyxl: pip install pandas openpyxl
"""
import os
import pandas as pd

def convert_csvs_to_excel():
    current_dir = os.path.dirname(os.path.abspath(__file__))
    output_file = os.path.join(current_dir, "aws_load_balancers_report.xlsx")
    
    # Create Excel writer
    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
        # Process each CSV file
        for csv_file in os.listdir(current_dir):
            if csv_file.endswith('.csv'):
                sheet_name = os.path.splitext(csv_file)[0].replace('_', ' ').title()
                # Limit sheet name to 31 chars (Excel limit)
                sheet_name = sheet_name[:31]
                
                # Read CSV and write to Excel sheet
                try:
                    df = pd.read_csv(os.path.join(current_dir, csv_file))
                    df.to_excel(writer, sheet_name=sheet_name, index=False)
                    print(f"Added sheet '{sheet_name}' from {csv_file}")
                except Exception as e:
                    print(f"Error processing {csv_file}: {e}")
    
    print(f"\nExcel file created: {output_file}")

if __name__ == "__main__":
    convert_csvs_to_excel()
EOL

chmod +x "$output_dir/convert_to_excel.py"

echo ""
echo "Export completed successfully!"
echo "CSV files are saved in the directory: $output_dir"
echo ""
echo "Individual CSV files created:"
echo "  - $clb_file (Classic Load Balancers)"
echo "  - $alb_file (Application Load Balancers)"
echo "  - $nlb_file (Network Load Balancers)" 
echo "  - $glb_file (Gateway Load Balancers)"
echo ""
echo "To combine all CSVs into a single Excel file with separate sheets, install Python with pandas and openpyxl:"
echo "  pip install pandas openpyxl"
echo "Then run:"
echo "  python3 $output_dir/convert_to_excel.py"
echo ""
echo "TIP: If no load balancers were found but you expected some, try:"
echo "  1. Check your AWS credentials and permissions (try: aws iam get-user)"
echo "  2. Try a different region: $0 -r us-east-1" 
echo "  3. Run with debug mode: $0 -d"
echo "  4. Verify AWS CLI configuration: aws configure list"
