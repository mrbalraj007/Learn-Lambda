#!/bin/bash
# Script to export AWS Load Balancer information to separate CSV files by load balancer type
# Covers Classic Load Balancers (CLB), Application Load Balancers (ALB),
# Network Load Balancers (NLB), and Gateway Load Balancers (GLB)

# Default settings
export AWS_DEFAULT_REGION="ap-southeast-2"
export AWS_PROFILE=""
VERBOSE=false

# Display help information
show_help() {
    echo "Usage: $0 [options]"
    echo "Export AWS Load Balancer information to CSV files"
    echo
    echo "Options:"
    echo "  -r, --region REGION    AWS region (default: ap-southeast-2)"
    echo "  -p, --profile PROFILE  AWS CLI profile to use"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -h, --help             Show this help message"
    echo
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--region)
            export AWS_DEFAULT_REGION="$2"
            shift 2
            ;;
        -p|--profile)
            export AWS_PROFILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

set -e

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

# Validate AWS credentials
validate_aws_credentials() {
    echo "Validating AWS credentials..."
    
    # Prepare AWS CLI command with profile if specified
    aws_cmd="aws"
    if [ -n "$AWS_PROFILE" ]; then
        aws_cmd="aws --profile $AWS_PROFILE"
    fi
    
    # Test credentials
    account_info=$($aws_cmd sts get-caller-identity 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: Unable to validate AWS credentials. Please check your configuration."
        echo "Error details: $account_info"
        echo
        echo "Possible solutions:"
        echo "  1. Run 'aws configure' to set up credentials"
        echo "  2. Use --profile to specify a different AWS profile"
        echo "  3. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
        echo "  4. For EC2 instances, ensure the IAM role has appropriate permissions"
        exit 1
    fi
    
    account_id=$(echo "$account_info" | jq -r .Account 2>/dev/null)
    user_arn=$(echo "$account_info" | jq -r .Arn 2>/dev/null)
    
    echo "AWS credentials validated successfully."
    echo "Account ID: $account_id"
    echo "User/Role: $user_arn"
    
    # Check if the user has permissions to describe load balancers
    echo "Checking permissions for load balancer operations..."
    
    # Test classic load balancer permissions
    $aws_cmd elb describe-load-balancers --max-items 1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Warning: May not have permissions for Classic Load Balancers, but continuing..."
    fi
    
    # Test v2 load balancer permissions
    $aws_cmd elbv2 describe-load-balancers --max-items 1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Warning: May not have permissions for ALB/NLB/GLB Load Balancers, but continuing..."
    fi
}

# Function to handle AWS command errors
run_aws_cmd() {
    local cmd_args=("$@")
    
    # Add profile if specified
    if [ -n "$AWS_PROFILE" ]; then
        cmd_args=(--profile "$AWS_PROFILE" "${cmd_args[@]}")
    fi
    
    if $VERBOSE; then
        echo "Executing: aws ${cmd_args[*]}" >&2
    fi
    
    result=$(aws "${cmd_args[@]}" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to execute: aws ${cmd_args[*]}" >&2
        if $VERBOSE; then
            echo "Error details: $result" >&2
        fi
        echo "{}"  # Return empty object instead of empty array
    else
        echo "$result"
    fi
}

# Function to safely parse JSON with jq
safe_jq() {
    local json="$1"
    local query="$2"
    local default="$3"
    
    # Check if input is valid JSON
    if ! echo "$json" | jq -e . >/dev/null 2>&1; then
        echo "$default"
        return
    fi
    
    # Run the query and return default if it fails
    result=$(echo "$json" | jq -r "$query" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$result" ] || [ "$result" == "null" ]; then
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
        tags=$(run_aws_cmd elbv2 describe-tags --resource-arns "$arn" --query 'TagDescriptions[0].Tags')
    elif [[ $arn == *"loadbalancer"* ]]; then
        # Classic LB - extract name from ARN
        local lb_name=$(echo "$arn" | awk -F: '{print $NF}' | sed 's/loadbalancer\///')
        tags=$(run_aws_cmd elb describe-tags --load-balancer-names "$lb_name" --query 'TagDescriptions[0].Tags')
    else
        tags="{}"
    fi
    
    # Format tags as Key=Value|Key=Value
    if [ -z "$tags" ] || [ "$tags" == "{}" ] || [ "$tags" == "null" ]; then
        echo "N/A"
    else
        echo "$tags" | jq -r 'map("\(.Key)=\(.Value)") | join("|")' 2>/dev/null || echo "N/A"
    fi
}

echo "Starting AWS Load Balancer export (Region: $AWS_DEFAULT_REGION, Profile: ${AWS_PROFILE:-default})"

# Validate AWS credentials
validate_aws_credentials

# Initialize CSV files with headers
echo "LB_Name,DNS_Name,Scheme,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,Protocol,Port,InstancePort,SSLCertificate,HealthCheck_Target,HealthCheck_Interval,HealthCheck_Timeout,HealthCheck_HealthyThreshold,HealthCheck_UnhealthyThreshold,Tags" > "$clb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,SecurityGroups,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$alb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,SSLCertificate,Tags" > "$nlb_file"

echo "LB_Name,LB_ARN,DNS_Name,Scheme,State,VPC_ID,Subnets,AvailabilityZones,TargetGroup_Name,TargetGroup_ARN,TargetType,TG_Protocol,TG_Port,HealthCheckPath,HealthCheckPort,HealthyThreshold,UnhealthyThreshold,HealthCheckTimeout,HealthCheckInterval,Listener_ARN,Listener_Protocol,Listener_Port,Tags" > "$glb_file"

# Process Classic Load Balancers
echo "Fetching Classic Load Balancers..."
clbs=$(run_aws_cmd elb describe-load-balancers)

if [ "$(safe_jq "$clbs" '.LoadBalancerDescriptions | length' 0)" -gt 0 ]; then
    for lb in $(safe_jq "$clbs" '.LoadBalancerDescriptions[]' '{}' | jq -c '.'); do
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
    echo "Processed $(safe_jq "$clbs" '.LoadBalancerDescriptions | length' 0) Classic Load Balancer(s)"
else
    echo "No Classic Load Balancers found"
fi

# Process Application, Network, and Gateway Load Balancers
echo "Fetching Application, Network, and Gateway Load Balancers..."
lbs=$(run_aws_cmd elbv2 describe-load-balancers)

if [ "$(safe_jq "$lbs" '.LoadBalancers | length' 0)" -gt 0 ]; then
    for lb in $(safe_jq "$lbs" '.LoadBalancers[]' '{}' | jq -c '.'); do
        lb_arn=$(safe_jq "$lb" '.LoadBalancerArn' 'N/A')
        lb_name=$(safe_jq "$lb" '.LoadBalancerName' 'N/A')
        lb_type=$(safe_jq "$lb" '.Type' 'unknown')
        
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
        
        dns_name=$(safe_jq "$lb" '.DNSName' 'N/A')
        scheme=$(safe_jq "$lb" '.Scheme // "internet-facing"' 'internet-facing')
        state=$(safe_jq "$lb" '.State.Code' 'N/A')
        vpc_id=$(safe_jq "$lb" '.VpcId' 'N/A')
        
        # Security groups (only for ALB)
        security_groups="N/A"
        if [ "$lb_type" == "application" ]; then
            security_groups=$(safe_jq "$lb" '.SecurityGroups | join("|") // "N/A"' 'N/A')
        fi
        
        # Subnets and AZs
        az_info=$(safe_jq "$lb" '.AvailabilityZones' '[]')
        azs=$(echo "$az_info" | jq -r '.[].ZoneName' 2>/dev/null | paste -sd "|" - || echo "N/A")
        subnets=$(echo "$az_info" | jq -r '.[].SubnetId' 2>/dev/null | paste -sd "|" - || echo "N/A")
        
        # Tags
        tags=$(get_tags "$lb_arn")
        
        # Get target groups
        tgs=$(run_aws_cmd elbv2 describe-target-groups --load-balancer-arn "$lb_arn")
        
        # Get listeners
        listeners=$(run_aws_cmd elbv2 describe-listeners --load-balancer-arn "$lb_arn")
        
        # If no target groups, output basic LB info
        if [ "$(safe_jq "$tgs" '.TargetGroups | length' 0)" -eq 0 ]; then
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
        for tg in $(safe_jq "$tgs" '.TargetGroups[]' '{}' | jq -c '.'); do
            tg_arn=$(safe_jq "$tg" '.TargetGroupArn' 'N/A')
            tg_name=$(safe_jq "$tg" '.TargetGroupName' 'N/A')
            tg_protocol=$(safe_jq "$tg" '.Protocol' 'N/A')
            tg_port=$(safe_jq "$tg" '.Port' 'N/A')
            tg_type=$(safe_jq "$tg" '.TargetType' 'N/A')
            
            # Health check info
            hc_path=$(safe_jq "$tg" '.HealthCheckPath // "N/A"' 'N/A')
            hc_port=$(safe_jq "$tg" '.HealthCheckPort' 'N/A')
            healthy_threshold=$(safe_jq "$tg" '.HealthyThresholdCount' 'N/A')
            unhealthy_threshold=$(safe_jq "$tg" '.UnhealthyThresholdCount' 'N/A')
            timeout=$(safe_jq "$tg" '.HealthCheckTimeoutSeconds' 'N/A')
            interval=$(safe_jq "$tg" '.HealthCheckIntervalSeconds' 'N/A')
            
            # Get target group tags
            tg_tags=$(get_tags "$tg_arn")
            combined_tags="$tags"
            [ "$tg_tags" != "N/A" ] && combined_tags="${tags}|${tg_tags}"
            
            # If no listeners, output with target group info only
            if [ "$(safe_jq "$listeners" '.Listeners | length' 0)" -eq 0 ]; then
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
            
            for listener in $(safe_jq "$listeners" '.Listeners[]' '{}' | jq -c '.'); do
                listener_arn=$(safe_jq "$listener" '.ListenerArn' 'N/A')
                listener_protocol=$(safe_jq "$listener" '.Protocol' 'N/A')
                listener_port=$(safe_jq "$listener" '.Port' 'N/A')
                
                # Check rules to see if they reference this target group
                rules_json=$(run_aws_cmd elbv2 describe-rules --listener-arn "$listener_arn")
                
                # Safely check if rules exist and contain our target group
                tg_used=false
                
                # The key fix: safely process rules
                if echo "$rules_json" | jq -e '.Rules' >/dev/null 2>&1; then
                    for rule in $(safe_jq "$rules_json" '.Rules[]' '{}' | jq -c '.'); do
                        actions=$(safe_jq "$rule" '.Actions' '[]')
                        if [ "$(echo "$actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                            tg_used=true
                            break
                        fi
                    done
                else
                    # If default actions contain this target group
                    default_actions=$(safe_jq "$listener" '.DefaultActions' '[]')
                    if [ "$(echo "$default_actions" | jq -r "[.[] | select(.TargetGroupArn == \"$tg_arn\")] | length")" -gt 0 ]; then
                        tg_used=true
                    fi
                fi
                
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
fi

# Create a helper script to convert CSVs to Excel
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
