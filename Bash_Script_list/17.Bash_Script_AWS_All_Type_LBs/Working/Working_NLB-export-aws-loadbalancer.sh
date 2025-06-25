#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\31.Bash_Script_AWS_All_Type_LBs\export-aws-load-balancers.sh

# Script to export AWS Load Balancer information to separate CSV files by load balancer type
# Covers Classic Load Balancers (CLB), Application Load Balancers (ALB),
# Network Load Balancers (NLB), and Gateway Load Balancers (GLB)

set -e

# Set default region
export AWS_DEFAULT_REGION="ap-southeast-2"

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
    result=$(aws "$@" 2>/dev/null)
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Warning: Failed to execute: aws $*" >&2
        echo "{}"
    else
        echo "$result"
    fi
}

# Function to safely parse JSON with jq
safe_jq() {
    local json=$1
    local query=$2
    local default=$3
    
    if [ -z "$json" ] || [ "$json" = "{}" ] || [ "$json" = "[]" ]; then
        echo "$default"
        return
    fi
    
    result=$(echo "$json" | jq -r "$query" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$result" ] || [ "$result" = "null" ]; then
        echo "$default"
    else
        echo "$result"
    fi
}

# Function to get resource tags
get_tags() {
    local arn=$1
    local tags
    
    if [[ $arn == *"loadbalancer/app"* || $arn == *"loadbalancer/net"* || $arn == *"loadbalancer/gwy"* || $arn == *"targetgroup"* ]]; then
        # ALB, NLB, GLB, or Target Group
        tags=$(run_aws_cmd elbv2 describe-tags --resource-arns "$arn")
    elif [[ $arn == *"loadbalancer"* ]]; then
        # Classic LB - extract name from ARN
        local lb_name=$(echo "$arn" | awk -F: '{print $NF}' | sed 's/loadbalancer\///')
        tags=$(run_aws_cmd elb describe-tags --load-balancer-names "$lb_name")
    else
        tags="{}"
    fi
    
    # Format tags as Key=Value|Key=Value
    tags_list=$(safe_jq "$tags" '.TagDescriptions[0].Tags // []' "[]")
    if [ "$tags_list" = "[]" ]; then
        echo "N/A"
    else
        echo "$tags" | jq -r '.TagDescriptions[0].Tags | map("\(.Key)=\(.Value)") | join("|")' 2>/dev/null || echo "N/A"
    fi
}

# Initialize CSV files with headers
echo "LB_Name,DNS_Name,Scheme,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,Protocol,Port,InstancePort,SSLCertificate,HealthCheck_Target,HealthCheck_Interval,HealthCheck_Timeout,HealthCheck_HealthyThreshold,HealthCheck_UnhealthyThreshold,Tags" > "$clb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$alb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$nlb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,Tags" > "$glb_file"

# Process Classic Load Balancers
echo "Fetching Classic Load Balancers..."
clbs=$(run_aws_cmd elb describe-load-balancers)

clb_count=$(safe_jq "$clbs" '.LoadBalancerDescriptions | length' "0")
if [ "$clb_count" -gt 0 ]; then
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
        hc_target=$(echo "$lb" | jq -r '.HealthCheck.Target // "N/A"')
        hc_interval=$(echo "$lb" | jq -r '.HealthCheck.Interval // "N/A"')
        hc_timeout=$(echo "$lb" | jq -r '.HealthCheck.Timeout // "N/A"')
        hc_healthy=$(echo "$lb" | jq -r '.HealthCheck.HealthyThreshold // "N/A"')
        hc_unhealthy=$(echo "$lb" | jq -r '.HealthCheck.UnhealthyThreshold // "N/A"')
        
        # Tags
        tags=$(get_tags "$lb_arn")
        
        # Process listeners
        listeners=$(echo "$lb" | jq -c '.ListenerDescriptions[]' 2>/dev/null)
        if [ -z "$listeners" ]; then
            # No listeners, output basic info
            echo "\"$lb_name\",\"$dns_name\",\"$scheme\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"N/A\",\"N/A\",\"N/A\",\"N/A\",\"$hc_target\",\"$hc_interval\",\"$hc_timeout\",\"$hc_healthy\",\"$hc_unhealthy\",\"$tags\"" >> "$clb_file"
        else
            # Output one row per listener
            echo "$lb" | jq -c '.ListenerDescriptions[]' | while read -r listener_data; do
                protocol=$(echo "$listener_data" | jq -r '.Listener.Protocol // "N/A"')
                lb_port=$(echo "$listener_data" | jq -r '.Listener.LoadBalancerPort // "N/A"')
                instance_port=$(echo "$listener_data" | jq -r '.Listener.InstancePort // "N/A"')
                
                # SSL Certificate
                ssl_cert="N/A"
                if [[ "$protocol" == "HTTPS" || "$protocol" == "SSL" ]]; then
                    ssl_cert=$(echo "$listener_data" | jq -r '.Listener.SSLCertificateId // "N/A"')
                fi
                
                echo "\"$lb_name\",\"$dns_name\",\"$scheme\",\"$vpc_id\",\"$security_groups\",\"$subnets\",\"$azs\",\"$protocol\",\"$lb_port\",\"$instance_port\",\"$ssl_cert\",\"$hc_target\",\"$hc_interval\",\"$hc_timeout\",\"$hc_healthy\",\"$hc_unhealthy\",\"$tags\"" >> "$clb_file"
            done
        fi
    done
    echo "Processed $clb_count Classic Load Balancer(s)"
else
    echo "No Classic Load Balancers found"
fi

# Process Application, Network, and Gateway Load Balancers
echo "Fetching Application, Network, and Gateway Load Balancers..."
lbs=$(run_aws_cmd elbv2 describe-load-balancers)

lb_count=$(safe_jq "$lbs" '.LoadBalancers | length' "0")
if [ "$lb_count" -gt 0 ]; then
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
        state=$(echo "$lb" | jq -r '.State.Code // "unknown"')
        vpc_id=$(echo "$lb" | jq -r '.VpcId // "N/A"')
        
        # Security groups (only for ALB)
        security_groups="N/A"
        if [ "$lb_type" == "application" ]; then
            security_groups=$(echo "$lb" | jq -r '.SecurityGroups | join("|") // "N/A"')
        fi
        
        # Subnets and AZs
        az_info=$(echo "$lb" | jq -c '.AvailabilityZones // []')
        azs=$(echo "$az_info" | jq -r 'map(.ZoneName) | join("|")' 2>/dev/null || echo "N/A")
        subnets=$(echo "$az_info" | jq -r 'map(.SubnetId) | join("|")' 2>/dev/null || echo "N/A")
        
        # Tags
        tags=$(get_tags "$lb_arn")
        
        # Get target groups
        tgs=$(run_aws_cmd elbv2 describe-target-groups --load-balancer-arn "$lb_arn")
        
        # Get listeners
        listeners=$(run_aws_cmd elbv2 describe-listeners --load-balancer-arn "$lb_arn")
        
        # If no target groups, output basic LB info
        tg_count=$(safe_jq "$tgs" '.TargetGroups | length' "0")
        if [ "$tg_count" -eq 0 ]; then
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
            tg_protocol=$(echo "$tg" | jq -r '.Protocol // "N/A"')
            tg_port=$(echo "$tg" | jq -r '.Port // "N/A"')
            tg_type=$(echo "$tg" | jq -r '.TargetType // "N/A"')
            
            # Health check info
            hc_path=$(echo "$tg" | jq -r '.HealthCheckPath // "N/A"')
            hc_port=$(echo "$tg" | jq -r '.HealthCheckPort // "N/A"')
            healthy_threshold=$(echo "$tg" | jq -r '.HealthyThresholdCount // "N/A"')
            unhealthy_threshold=$(echo "$tg" | jq -r '.UnhealthyThresholdCount // "N/A"')
            timeout=$(echo "$tg" | jq -r '.HealthCheckTimeoutSeconds // "N/A"')
            interval=$(echo "$tg" | jq -r '.HealthCheckIntervalSeconds // "N/A"')
            
            # Get target group tags
            tg_tags=$(get_tags "$tg_arn")
            combined_tags="$tags"
            [ "$tg_tags" != "N/A" ] && combined_tags="${tags}|${tg_tags}"
            
            # If no listeners, output with target group info only
            listener_count=$(safe_jq "$listeners" '.Listeners | length' "0")
            if [ "$listener_count" -eq 0 ]; then
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
                listener_protocol=$(echo "$listener" | jq -r '.Protocol // "N/A"')
                listener_port=$(echo "$listener" | jq -r '.Port // "N/A"')
                
                # Special handling for NLB vs ALB/GLB
                tg_used=false
                if [ "$lb_type" == "network" ]; then
                    # For NLBs, look at DefaultActions directly since they don't support rules like ALBs
                    default_actions=$(echo "$listener" | jq -c '.DefaultActions // []')
                    if [ "$(echo "$default_actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                        tg_used=true
                    fi
                else
                    # ALB and GLB support rules
                    rules=$(run_aws_cmd elbv2 describe-rules --listener-arn "$listener_arn")
                    rules_exist=$(echo "$rules" | jq 'has("Rules")')
                    
                    if [ "$rules_exist" = "true" ]; then
                        for rule in $(echo "$rules" | jq -c '.Rules[]'); do
                            actions=$(echo "$rule" | jq -c '.Actions // []')
                            if [ "$(echo "$actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                                tg_used=true
                                break
                            fi
                        done
                    else
                        # If rules can't be accessed, check default actions
                        default_actions=$(echo "$listener" | jq -c '.DefaultActions // []')
                        if [ "$(echo "$default_actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                            tg_used=true
                        fi
                    fi
                fi
                
                if $tg_used; then
                    listener_found=true
                    # Get SSL certificate if applicable
                    ssl_cert="N/A"
                    if [[ "$listener_protocol" == "HTTPS" || "$listener_protocol" == "TLS" ]]; then
                        certs=$(run_aws_cmd elbv2 describe-listener-certificates --listener-arn "$listener_arn")
                        cert_exists=$(echo "$certs" | jq 'has("Certificates")')
                        
                        if [ "$cert_exists" = "true" ]; then
                            cert_count=$(safe_jq "$certs" '.Certificates | length' "0")
                            if [ "$cert_count" -gt 0 ]; then
                                ssl_cert=$(echo "$certs" | jq -r '.Certificates[0].CertificateArn // "N/A"')
                            fi
                        fi
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
    alb_count=$(grep -c "," "$alb_file" 2>/dev/null || echo 0)
    nlb_count=$(grep -c "," "$nlb_file" 2>/dev/null || echo 0)
    glb_count=$(grep -c "," "$glb_file" 2>/dev/null || echo 0)
    
    if [ "$alb_count" -gt 1 ]; then
        echo "  - $((alb_count-1)) Application Load Balancer entries"
    else
        echo "  - 0 Application Load Balancer entries"
    fi
    
    if [ "$nlb_count" -gt 1 ]; then
        echo "  - $((nlb_count-1)) Network Load Balancer entries"
    else
        echo "  - 0 Network Load Balancer entries"
    fi
    
    if [ "$glb_count" -gt 1 ]; then
        echo "  - $((glb_count-1)) Gateway Load Balancer entries"
    else
        echo "  - 0 Gateway Load Balancer entries"
    fi
else
    echo "No Application, Network, or Gateway Load Balancers found"
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
