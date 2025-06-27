#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\24.Bash_Script_AWS_ECS\aws_ecs_cluster_info.sh

#######################################################
# AWS ECS Cluster Details Export Script
# 
# This script collects details about all ECS clusters in
# the ap-southeast-2 region and exports the information
# to a CSV file with a timestamp in the filename.
#######################################################

# Set AWS region
AWS_REGION="ap-southeast-2"
export AWS_DEFAULT_REGION=${AWS_REGION}

# Current date-time for filename
DATETIME=$(date +"%Y%m%d_%H%M%S")
CSV_FILE="ecs_cluster_details_${DATETIME}.csv"

# Function to check if required tools are installed
check_prerequisites() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it to run this script."
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed. Please install it to run this script."
        exit 1
    fi
}

# Function to escape CSV fields
escape_csv() {
    local field="$1"
    if [[ $field == *","* || $field == *"\""* ]]; then
        field="\"${field//\"/\"\"}\""
    fi
    echo "$field"
}

# Main function to collect ECS cluster details
collect_ecs_details() {
    echo "Retrieving ECS clusters in ${AWS_REGION}..."
    
    # Create CSV header
    echo "Cluster Name,Service Name,Task Count,Container Instance Count,Infrastructure Type,Namespace,Status" > ${CSV_FILE}
    
    # Get list of all ECS clusters
    local clusters=$(aws ecs list-clusters --query 'clusterArns[]' --output text)
    
    if [ -z "$clusters" ] || [ "$clusters" = "None" ]; then
        echo "No ECS clusters found in region ${AWS_REGION}"
        exit 0
    fi
    
    # Process each cluster
    for cluster_arn in $clusters; do
        cluster_name=$(basename $cluster_arn)
        echo "Processing cluster: ${cluster_name}"
        
        # Get cluster details
        local cluster_details=$(aws ecs describe-clusters --clusters $cluster_arn --include ATTACHMENTS SETTINGS TAGS STATISTICS)
        local cluster_status=$(echo $cluster_details | jq -r '.clusters[0].status')
        
        # Get container instances
        local container_instances=$(aws ecs list-container-instances --cluster $cluster_arn --query 'containerInstanceArns' --output text)
        if [ -z "$container_instances" ] || [ "$container_instances" = "None" ]; then
            container_instance_count=0
        else
            container_instance_count=$(echo $container_instances | wc -w)
        fi
        
        # Determine infrastructure type
        local infrastructure_type="UNKNOWN"
        # Check cluster capacity providers first
        local capacity_providers=$(echo $cluster_details | jq -r '.clusters[0].capacityProviders[]' 2>/dev/null)
        if [[ $capacity_providers == *"FARGATE"* ]]; then
            infrastructure_type="FARGATE"
        elif [ $container_instance_count -gt 0 ]; then
            infrastructure_type="EC2"
        fi
        
        # Get services with pagination support
        local services=()
        local next_token=""
        
        while true; do
            local token_param=""
            if [ ! -z "$next_token" ]; then
                token_param="--next-token $next_token"
            fi
            
            local service_response=$(aws ecs list-services --cluster $cluster_arn $token_param)
            local service_arns=$(echo $service_response | jq -r '.serviceArns[]' 2>/dev/null)
            
            if [ ! -z "$service_arns" ]; then
                for service_arn in $service_arns; do
                    services+=($service_arn)
                done
            fi
            
            next_token=$(echo $service_response | jq -r '.nextToken' 2>/dev/null)
            if [ -z "$next_token" ] || [ "$next_token" == "null" ]; then
                break
            fi
        done
        
        if [ ${#services[@]} -eq 0 ]; then
            # No services in this cluster
            echo "No services found in cluster ${cluster_name}"
            echo "$(escape_csv "$cluster_name"),No Services,0,${container_instance_count},${infrastructure_type},None,${cluster_status}" >> ${CSV_FILE}
        else
            # Process each service
            for service_arn in "${services[@]}"; do
                service_name=$(basename $service_arn)
                echo "  Processing service: ${service_name}"
                
                # Get service details
                local service_details=$(aws ecs describe-services --cluster $cluster_arn --services $service_arn)
                local service_status=$(echo $service_details | jq -r '.services[0].status')
                
                # Confirm infrastructure type from service
                local service_launch_type=$(echo $service_details | jq -r '.services[0].launchType' 2>/dev/null)
                if [ "$service_launch_type" != "null" ] && [ ! -z "$service_launch_type" ]; then
                    infrastructure_type=$service_launch_type
                fi
                
                # Get tasks for this service
                local tasks=$(aws ecs list-tasks --cluster $cluster_arn --service-name $service_name --query 'taskArns' --output text)
                if [ -z "$tasks" ] || [ "$tasks" = "None" ]; then
                    task_count=0
                else
                    task_count=$(echo $tasks | wc -w)
                fi
                
                # Get namespace if any
                local namespace="None"
                if echo $service_details | jq -e '.services[0].serviceRegistries' > /dev/null 2>&1; then
                    local service_registry=$(echo $service_details | jq -r '.services[0].serviceRegistries[0].registryArn' 2>/dev/null)
                    if [ "$service_registry" != "null" ] && [ ! -z "$service_registry" ]; then
                        # Extract registry ID from ARN
                        local registry_id=$(echo $service_registry | awk -F '/' '{print $NF}')
                        
                        # Get service discovery info
                        local discovery_info=$(aws servicediscovery get-service --id $registry_id 2>/dev/null)
                        if [ $? -eq 0 ]; then
                            local namespace_id=$(echo $discovery_info | jq -r '.Service.NamespaceId')
                            local namespace_info=$(aws servicediscovery get-namespace --id $namespace_id 2>/dev/null)
                            if [ $? -eq 0 ]; then
                                namespace=$(echo $namespace_info | jq -r '.Namespace.Name')
                            fi
                        fi
                    fi
                fi
                
                # Write to CSV - escape commas in fields
                echo "$(escape_csv "$cluster_name"),$(escape_csv "$service_name"),${task_count},${container_instance_count},${infrastructure_type},$(escape_csv "$namespace"),${service_status}" >> ${CSV_FILE}
            done
        fi
        
        echo "Completed processing cluster: ${cluster_name}"
        echo "------------------------------------------"
    done
    
    echo "ECS cluster details exported to ${CSV_FILE}"
    echo "File location: $(pwd)/${CSV_FILE}"
}

# Main execution
check_prerequisites
collect_ecs_details