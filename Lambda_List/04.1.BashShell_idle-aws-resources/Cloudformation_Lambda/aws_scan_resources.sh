#!/bin/bash

# Get all AWS regions
regions=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

echo "Checking AWS resources across all regions..."

for region in $regions; do
    echo "Region: $region"
    
    # EC2 Instances (running or stopped)
    echo "EC2 Instances:"
    aws ec2 describe-instances --region $region --query "Reservations[].Instances[].[InstanceId, State.Name, InstanceType]" --output text
    
    # RDS Instances (available or stopped)
    echo "RDS Instances:"
    aws rds describe-db-instances --region $region --query "DBInstances[].[DBInstanceIdentifier, DBInstanceStatus, DBInstanceClass]" --output text
    
    # EBS Volumes (available or in-use)
    echo "EBS Volumes:"
    aws ec2 describe-volumes --region $region --query "Volumes[].[VolumeId, State, Size]" --output text
    
    # Lambda Functions (list all)
    echo "Lambda Functions:"
    aws lambda list-functions --region $region --query "Functions[].[FunctionName, Runtime, LastModified]" --output text
    
    # Elastic Load Balancers (classic & v2)
    echo "Classic Load Balancers:"
    aws elb describe-load-balancers --region $region --query "LoadBalancerDescriptions[].[LoadBalancerName, DNSName]" --output text
    
    echo "Application/Network Load Balancers (v2):"
    aws elbv2 describe-load-balancers --region $region --query "LoadBalancers[].[LoadBalancerName, Type, State.Code]" --output text
    
    # ECS Clusters and running tasks
    echo "ECS Clusters and running tasks:"
    cluster_arns=$(aws ecs list-clusters --region $region --query "clusterArns[]" --output text)
    for cluster_arn in $cluster_arns; do
        echo "Cluster: $cluster_arn"
        aws ecs list-tasks --cluster $cluster_arn --region $region --query "taskArns" --output text
    done
    
    echo "-------------------------------------"
done

echo "Resource scan complete."
