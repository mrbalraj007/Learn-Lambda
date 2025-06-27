# AWS ECS Cluster Information Export Tool

This Bash script collects comprehensive details about all Amazon ECS (Elastic Container Service) clusters in an AWS environment and exports the information to a CSV file for analysis and documentation purposes.

## Features

- Lists all ECS clusters in the specified AWS region (default: ap-southeast-2)
- Collects detailed information for each cluster including:
  - Cluster name and status
  - Services running in each cluster
  - Task count for each service
  - Container instance count
  - Infrastructure type (EC2 or FARGATE)
  - Service discovery namespaces
  - Task definition details (name, revision)
  - Resource allocations (CPU, memory)
- Processes clusters sequentially for comprehensive and organized output
- Exports all data to a timestamped CSV file for easy analysis

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- jq command-line JSON processor installed
- Bash shell environment

## Installation

1. Download the script to your local machine:
   ```bash
   wget https://path-to-repo/export_aws_ecs_cluster_info.sh
   ```
   or copy the script manually to your desired location.

2. Make the script executable:
   ```bash
   chmod +x export_aws_ecs_cluster_info.sh
   ```

## Usage

Run the script from the command line:

```bash
./export_aws_ecs_cluster_info.sh
```

By default, the script uses the AWS region `ap-southeast-2`. If you need to use a different region, you can modify the `AWS_REGION` variable at the beginning of the script.

## Output

The script generates a CSV file with the following naming convention:
