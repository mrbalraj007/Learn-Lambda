# Idle Resource Detection - Architecture

This document describes the architecture and workflow of the Idle Resource Detection system.

## System Components

```mermaid
flowchart TD
    subgraph "Deployment"
        cfn[CloudFormation Stack]
        s3deploy[S3 Deployment Bucket]
        s3deploy -->|stores code| cfn
    end
    
    subgraph "Triggers"
        api[API Gateway]
        event[EventBridge\nScheduled Rule]
    end
    
    subgraph "Core Components"
        lambda[Lambda Function]
        role[IAM Role/Permissions]
        s3out[S3 Output Bucket]
    end
    
    subgraph "AWS Resources Scanned"
        ec2[EC2 Instances]
        ebs[EBS Volumes]
        snap[Snapshots]
        sg[Security Groups]
        iam[IAM Roles]
        lmb[Lambda Functions]
    end
    
    cfn -->|creates| api
    cfn -->|creates| event
    cfn -->|creates| lambda
    cfn -->|creates| role
    cfn -->|creates/uses| s3out
    
    api -->|triggers| lambda
    event -->|triggers monthly| lambda
    
    role -->|grants permissions| lambda
    
    lambda -->|scans| ec2
    lambda -->|scans| ebs
    lambda -->|scans| snap
    lambda -->|scans| sg
    lambda -->|scans| iam
    lambda -->|scans| lmb
    
    lambda -->|generates & uploads report| s3out
    
    classDef deployment fill:#f9f,stroke:#333,stroke-width:2px;
    classDef trigger fill:#bbf,stroke:#333,stroke-width:1px;
    classDef core fill:#bfb,stroke:#333,stroke-width:2px;
    classDef scanned fill:#fbb,stroke:#333,stroke-width:1px;
    
    class cfn,s3deploy deployment;
    class api,event trigger;
    class lambda,role,s3out core;
    class ec2,ebs,snap,sg,iam,lmb scanned;
```

## Execution Flow

```mermaid
sequenceDiagram
    participant User
    participant API as API Gateway
    participant Schedule as EventBridge Scheduler
    participant Lambda
    participant AWS as AWS Services
    participant S3 as S3 Output Bucket
    
    alt Manual Trigger
        User->>API: POST Request
        API->>Lambda: Invoke
    else Scheduled Execution
        Schedule->>Lambda: Invoke (monthly)
    end
    
    activate Lambda
    
    Lambda->>AWS: Query EC2 (stopped instances)
    AWS-->>Lambda: Return data
    
    Lambda->>AWS: Query EBS (unattached volumes)
    AWS-->>Lambda: Return data
    
    Lambda->>AWS: Query EC2 (orphaned snapshots)
    AWS-->>Lambda: Return data
    
    Lambda->>AWS: Query EC2 (unused security groups)
    AWS-->>Lambda: Return data
    
    Lambda->>AWS: Query IAM (roles without policies)
    AWS-->>Lambda: Return data
    
    Lambda->>AWS: Query Lambda (idle functions)
    AWS-->>Lambda: Return data
    
    Lambda->>Lambda: Generate Excel report
    
    Lambda->>S3: Upload report
    S3-->>Lambda: Confirm upload
    
    Lambda->>S3: Generate presigned URL
    S3-->>Lambda: Return URL
    
    deactivate Lambda
    
    Lambda-->>API: Return response with URL
    API-->>User: Return report URL
```

## Architecture Description

The Idle Resource Detection system consists of the following components:

1. **CloudFormation Stack**: Defines and provisions all required AWS resources.

2. **Triggers**:
   - **API Gateway**: Provides an HTTP endpoint for on-demand execution
   - **EventBridge Rule**: Schedules automated monthly executions

3. **Core Components**:
   - **Lambda Function**: The main component that scans AWS resources and generates reports
   - **IAM Role**: Grants the Lambda function necessary permissions
   - **S3 Output Bucket**: Stores the generated Excel reports

4. **Resources Scanned**:
   - **EC2 Instances**: Identifies stopped instances
   - **EBS Volumes**: Identifies unattached volumes
   - **EBS Snapshots**: Identifies orphaned/expired snapshots
   - **Security Groups**: Identifies unused security groups
   - **IAM Roles**: Identifies roles without attached policies
   - **Lambda Functions**: Identifies idle Lambda functions

## Data Flow

1. The system is triggered either manually via API Gateway or on schedule via EventBridge.
2. The Lambda function queries various AWS services to identify idle resources.
3. The function compiles results into an Excel workbook with separate sheets for each resource type.
4. The report is uploaded to the S3 bucket with a timestamped filename.
5. A presigned URL is generated for easy access to the report.
6. The Lambda function returns a response with resource counts and the download URL.

This architecture provides a serverless, cost-effective solution for identifying idle AWS resources that can potentially be eliminated to reduce costs.
