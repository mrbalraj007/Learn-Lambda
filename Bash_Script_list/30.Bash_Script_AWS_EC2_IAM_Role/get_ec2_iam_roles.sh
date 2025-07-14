#!/bin/bash
# filepath: get_ec2_iam_roles.sh

# Function to check if AWS CLI is installed and configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS CLI is not configured. Please configure it first."
        exit 1
    fi
}

# Function to get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query 'Account' --output text
}

# Function to get current date and time
get_datetime() {
    date +"%Y%m%d_%H%M%S"
}

# Function to get EC2 instances with IAM roles
get_ec2_iam_roles() {
    local csv_file="$1"
    
    # Write CSV header
    echo "Instance_ID,Instance_Name,Instance_Type,State,IAM_Role,Launch_Time,Availability_Zone,Private_IP,Public_IP" > "$csv_file"
    
    # Get all EC2 instances
    aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,State.Name,IamInstanceProfile.Arn,LaunchTime,Placement.AvailabilityZone,PrivateIpAddress,PublicIpAddress]' \
        --output text | while read -r instance_id name instance_type state iam_arn launch_time az private_ip public_ip; do
        
        # Extract role name from ARN if exists
        if [[ "$iam_arn" != "None" && "$iam_arn" != "" ]]; then
            role_name=$(echo "$iam_arn" | sed 's/.*instance-profile\///')
        else
            role_name="No Role Assigned"
        fi
        
        # Handle empty/null values
        name=${name:-"No Name"}
        private_ip=${private_ip:-"N/A"}
        public_ip=${public_ip:-"N/A"}
        
        # Write to CSV
        echo "$instance_id,$name,$instance_type,$state,$role_name,$launch_time,$az,$private_ip,$public_ip" >> "$csv_file"
    done
}

# Main execution
main() {
    echo "Starting EC2 IAM Role Discovery..."
    
    # Check prerequisites
    check_aws_cli
    
    # Get account ID and current datetime
    account_id=$(get_account_id)
    datetime=$(get_datetime)
    
    # Create output filename
    output_file="EC2_IAM_Roles_${account_id}_${datetime}.csv"
    
    echo "Account ID: $account_id"
    echo "Output file: $output_file"
    echo "Fetching EC2 instances and their IAM roles..."
    
    # Get EC2 instances with IAM roles
    get_ec2_iam_roles "$output_file"
    
    # Check if file was created successfully
    if [[ -f "$output_file" ]]; then
        echo "Success! EC2 IAM role information saved to: $output_file"
        echo "Total instances found: $(( $(wc -l < "$output_file") - 1 ))"
    else
        echo "Error: Failed to create output file"
        exit 1
    fi
}

# Execute main function
main "$@"