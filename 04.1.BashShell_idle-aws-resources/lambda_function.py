import json
import boto3
import datetime
import os
import tempfile
from botocore.exceptions import ClientError

print('Loading function')

def lambda_handler(event, context):
    """
    Main handler function for AWS Lambda.
    Generates an AWS resource audit report and sends it via SNS.
    """
    try:
        print("Starting AWS resource audit...")
        
        # Generate a unique timestamp for the report
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        report_name = f"aws_audit_report_{timestamp}.html"
        
        # Create temporary directory to store report
        tmp_dir = tempfile.mkdtemp()
        report_path = os.path.join(tmp_dir, report_name)
        
        # Initialize AWS clients
        s3 = boto3.client('s3')
        sns = boto3.client('sns')
        
        # Get environment variables
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        if not bucket_name:
            raise ValueError("S3_BUCKET_NAME environment variable is not set")
            
        bucket_prefix = os.environ.get('S3_BUCKET_PREFIX', 'reports/')
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            raise ValueError("SNS_TOPIC_ARN environment variable is not set")
            
        regions = os.environ.get('AWS_REGIONS', 'us-east-1').split(',')
        
        # Generate HTML report
        generate_html_report(report_path, regions)
        
        # Upload report to S3
        s3_key = f"{bucket_prefix.rstrip('/')}/{report_name}"
        print(f"Uploading report to S3 bucket {bucket_name}, key: {s3_key}")
        s3.upload_file(report_path, bucket_name, s3_key)
        
        # Generate a pre-signed URL (valid for 7 days)
        s3_url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': s3_key},
            ExpiresIn=604800  # 7 days in seconds
        )
        
        # Send email notification with the S3 link
        message = f"""
        AWS Resource Audit Report - {timestamp}
        
        Your weekly AWS resource audit has been completed. The report is available at:
        {s3_url}
        
        This link will expire in 7 days.
        """
        
        print(f"Publishing notification to SNS topic: {sns_topic_arn}")
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"AWS Audit Report - {timestamp}",
            Message=message
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('AWS audit completed successfully'),
            'reportUrl': s3_url
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        # Send failure notification
        if 'sns' in locals() and 'sns_topic_arn' in locals():
            sns.publish(
                TopicArn=sns_topic_arn,
                Subject=f"AWS Audit Report FAILED - {timestamp if 'timestamp' in locals() else datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}",
                Message=f"The AWS resource audit job failed with error: {str(e)}"
            )
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

# Utility functions similar to utils.sh
def log_info(message):
    return f"ℹ️  {message}"

def log_warn(message):
    return f"⚠️  {message}"

def log_success(message):
    return f"✅ {message}"

def log_error(message):
    return f"❌ {message}"

def generate_html_report(report_path, regions):
    """Generate the HTML report by running the audit checks for each region"""
    print(f"Generating HTML report at: {report_path}")
    with open(report_path, 'w') as f:
        # Write HTML header and styles
        f.write("""<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='UTF-8'>
  <title>AWS Audit Report</title>
  <style>
    header {
        background: #2f80ed;
        color: white;
        padding: 40px 20px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    header h1 {
        margin: 0;
        font-size: 36px;
    }
    .container {
        max-width: 960px;
        margin: 30px auto;
        padding: 0 20px;
    }
    .info {
        background: #ffffff;
        padding: 20px;
        border-radius: 10px;
        margin-bottom: 30px;
        box-shadow: 0 3px 10px rgba(0,0,0,0.05);
    }
    .section {
        background: #ffffff;
        border-left: 6px solid #2f80ed;
        border-radius: 10px;
        padding: 20px;
        margin: 20px 0;
        box-shadow: 0 3px 10px rgba(0,0,0,0.06);
    }
    .section h2 {
        margin-top: 0;
        color: #2c3e50;
        font-size: 20px;
        display: flex;
        align-items: center;
    }
    .section h2 span {
        font-size: 24px;
        margin-right: 10px;
    }
    pre {
        background: #f9fafc;
        padding: 15px;
        border-radius: 6px;
        overflow-x: auto;
        font-size: 14px;
        line-height: 1.5;
        border: 1px solid #e0e6ed;
    }
    .status-ok { color: #27ae60; font-weight: bold; }
    .status-warn { color: #e67e22; font-weight: bold; }
    .status-fail { color: #c0392b; font-weight: bold; }
    footer {
        text-align: center;
        font-size: 13px;
        padding: 30px 10px;
        color: #777;
    }
  </style>
</head>
<body>""")

        # Add header and account info
        current_time = datetime.datetime.now().strftime('%d-%b-%Y %H:%M:%S')
        f.write(f"<header><h1>📊 AWS Cost Audit Report</h1></header>")
        f.write(f"<div class='container'>")
        f.write(f"<div class='info'><p><strong>Date:</strong> {current_time}</p>")
        
        # Get account ID
        sts = boto3.client('sts')
        try:
            account_id = sts.get_caller_identity()["Account"]
            f.write(f"<p><strong>AWS Account ID:</strong> {account_id}</p></div>")
        except:
            f.write("<p><strong>AWS Account ID:</strong> Unknown</p></div>")

        # Process each region
        for region in regions:
            print(f"Processing region: {region}")
            f.write(f"<div class='section'>")
            f.write(f"<h2><span>🌍</span> Region: {region}</h2>")
            
            # Create a boto3 session for the specific region
            session = boto3.Session(region_name=region)
            
            # Run all checks for this region
            run_check(f, "💰 Budget Alerts Check", session, check_budgets)
            run_check(f, "🏷️ Untagged Resources Check", session, check_untagged_resources)
            run_check(f, "🛌 Idle EC2 Resources Check", session, check_idle_ec2)
            run_check(f, "♻️ S3 Lifecycle Policies Check", session, check_s3_lifecycle)
            run_check(f, "📅 Old RDS Snapshots Check", session, check_old_rds_snapshots)
            run_check(f, "🧹 Forgotten EBS Volumes Check", session, check_forgotten_ebs)
            run_check(f, "🌐 Data Transfer Risks Check", session, check_data_transfer_risks)
            run_check(f, "💸 On-Demand EC2 Instances Check", session, check_on_demand_instances)
            run_check(f, "🛑 Idle Load Balancers Check", session, check_idle_load_balancers)
            run_check(f, "🌍 Route 53 Records Check", session, check_route53)
            run_check(f, "☸️ EKS Clusters Check", session, check_eks_clusters)
            run_check(f, "🔐 IAM Usage Check", session, check_iam_usage)
            run_check(f, "🛡️ Security Groups Check", session, check_security_groups)
            
            f.write(f"<h3 class='status-ok'>✅ AWS Audit Completed for region: {region}</h3>")
            f.write("</div>")

        # End HTML document
        f.write("<h2 class='status-ok'>✅ AWS Audit Completed</h2>")
        f.write("</div></body></html>")

def run_check(file_handle, title, session, check_function):
    """Run a specific check and write results to the report file"""
    file_handle.write(f"<div class='section'>")
    file_handle.write(f"<h2><span>{title.split(' ')[0]}</span> {' '.join(title.split(' ')[1:])}</h2><pre>")
    
    try:
        # Call the check function with the boto3 session
        result = check_function(session)
        file_handle.write(result)
    except Exception as e:
        file_handle.write(f"⚠️ Error running check: {str(e)}")
    
    file_handle.write("</pre></div>")

# Actual check implementations
def check_budgets(session):
    """Check AWS Budgets configuration"""
    try:
        budgets_client = session.client('budgets')
        sts_client = session.client('sts')
        account_id = sts_client.get_caller_identity()["Account"]
        
        output = [log_info(f"Checking budgets for AWS Account: {account_id}"),
                  "--------------------------------------------------"]
        
        try:
            response = budgets_client.describe_budgets(AccountId=account_id)
            budgets = response.get('Budgets', [])
            
            if not budgets:
                output.append(log_warn("No budgets found for this account."))
                return "\n".join(output)
            
            for budget in budgets:
                budget_name = budget['BudgetName']
                output.append(log_info(f"Budget: {budget_name}"))
                
                notifications = budgets_client.describe_notifications_for_budget(
                    AccountId=account_id,
                    BudgetName=budget_name
                ).get('Notifications', [])
                
                if not notifications:
                    output.append(log_warn("  No alerts (notifications) configured!"))
                else:
                    output.append(log_success("  Budget alerts are configured."))
            
        except Exception as e:
            output.append(log_error(f"Error retrieving budget information: {str(e)}"))
        
        return "\n".join(output)
    except Exception as e:
        return log_error(f"Error checking budgets: {str(e)}")

def check_untagged_resources(session):
    """Check for untagged resources"""
    try:
        ec2 = session.client('ec2')
        s3 = session.client('s3')
        rds = session.client('rds')
        lambda_client = session.client('lambda')
        sts_client = session.client('sts')
        
        account_id = sts_client.get_caller_identity()["Account"]
        region = session.region_name
        
        output = [log_info(f"Checking untagged resources for AWS Account: {account_id} in {region}"),
                 "-------------------------------------------------------------"]
        
        # Check EC2 Instances
        output.append(log_info("🔎 Checking EC2 Instances..."))
        try:
            ec2_response = ec2.describe_instances()
            for reservation in ec2_response.get('Reservations', []):
                for instance in reservation.get('Instances', []):
                    instance_id = instance['InstanceId']
                    tags = instance.get('Tags', [])
                    if not tags:
                        output.append(log_warn(f"  Untagged EC2 Instance: {instance_id}"))
                    else:
                        output.append(log_success(f"  Tagged EC2 Instance: {instance_id}"))
                        output.append("    Tags:")
                        for tag in tags:
                            output.append(f"      - {tag['Key']}: {tag['Value']}")
        except Exception as e:
            output.append(log_error(f"Error checking EC2 instances: {str(e)}"))
        
        # Check EBS Volumes
        output.append(log_info("🔎 Checking EBS Volumes..."))
        try:
            volumes_response = ec2.describe_volumes()
            for volume in volumes_response.get('Volumes', []):
                volume_id = volume['VolumeId']
                tags = volume.get('Tags', [])
                if not tags:
                    output.append(log_warn(f"  Untagged EBS Volume: {volume_id}"))
                else:
                    output.append(log_success(f"  Tagged EBS Volume: {volume_id}"))
                    output.append("    Tags:")
                    for tag in tags:
                        output.append(f"      - {tag['Key']}: {tag['Value']}")
        except Exception as e:
            output.append(log_error(f"Error checking EBS volumes: {str(e)}"))
        
        # Check S3 Buckets
        output.append(log_info("🔎 Checking S3 Buckets..."))
        try:
            buckets_response = s3.list_buckets()
            for bucket in buckets_response.get('Buckets', []):
                bucket_name = bucket['Name']
                try:
                    tags_response = s3.get_bucket_tagging(Bucket=bucket_name)
                    output.append(log_success(f"  Tagged S3 Bucket: {bucket_name}"))
                    output.append("    Tags:")
                    for tag in tags_response.get('TagSet', []):
                        output.append(f"      - {tag['Key']}: {tag['Value']}")
                except ClientError as e:
                    if e.response['Error']['Code'] == 'NoSuchTagSet':
                        output.append(log_warn(f"  Untagged S3 Bucket: {bucket_name}"))
                    else:
                        output.append(log_error(f"  Error checking tags for bucket {bucket_name}: {str(e)}"))
        except Exception as e:
            output.append(log_error(f"Error checking S3 buckets: {str(e)}"))
            
        # More resource checks can be added here
        
        output.append(log_success("Untagged resource check completed."))
        return "\n".join(output)
    except Exception as e:
        return log_error(f"Error checking untagged resources: {str(e)}")

def check_idle_ec2(session):
    """Check for idle EC2 instances"""
    try:
        ec2 = session.client('ec2')
        cloudwatch = session.client('cloudwatch')
        region = session.region_name
        
        # Constants
        CPU_THRESHOLD = 10
        DAYS = 3
        
        output = [log_info(f"Checking for idle or oversized EC2 instances in {region}"),
                 "------------------------------------------------------------"]
        
        # Get current time and time 3 days ago for CloudWatch metrics
        end_time = datetime.datetime.utcnow()
        start_time = end_time - datetime.timedelta(days=DAYS)
        
        # Get all running instances
        response = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
        
        instances_found = False
        for reservation in response.get('Reservations', []):
            for instance in reservation.get('Instances', []):
                instances_found = True
                instance_id = instance['InstanceId']
                instance_type = instance['InstanceType']
                
                # Get average CPU utilization
                try:
                    metric_response = cloudwatch.get_metric_statistics(
                        Namespace='AWS/EC2',
                        MetricName='CPUUtilization',
                        Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                        StartTime=start_time,
                        EndTime=end_time,
                        Period=86400,  # 1 day in seconds
                        Statistics=['Average']
                    )
                    
                    datapoints = metric_response.get('Datapoints', [])
                    if not datapoints:
                        output.append(log_warn(f"Idle Instance: {instance_id} ({instance_type}) — No CPU data available"))
                        continue
                    
                    # Calculate average across all datapoints
                    avg_cpu = sum(point['Average'] for point in datapoints) / len(datapoints)
                    
                    if avg_cpu < CPU_THRESHOLD:
                        output.append(log_warn(f"Idle Instance: {instance_id} ({instance_type}) — Avg CPU: {avg_cpu:.2f}%"))
                    else:
                        output.append(log_success(f"Active Instance: {instance_id} ({instance_type}) — Avg CPU: {avg_cpu:.2f}%"))
                        
                except Exception as e:
                    output.append(log_error(f"Error checking metrics for instance {instance_id}: {str(e)}"))
        
        if not instances_found:
            output.append(log_warn("No running EC2 instances found."))
            
        output.append("\n" + log_info("👉 Tip: For detailed right-sizing recommendations, check AWS Compute Optimizer."))
        return "\n".join(output)
    except Exception as e:
        return log_error(f"Error checking idle EC2 instances: {str(e)}")

def check_s3_lifecycle(session):
    """Check S3 buckets for lifecycle policies"""
    try:
        s3 = session.client('s3')
        region = session.region_name
        
        output = [log_info(f"Checking S3 buckets for missing lifecycle policies in {region}"),
                 "------------------------------------------------------------------"]
        
        try:
            # Get all buckets
            response = s3.list_buckets()
            
            if not response.get('Buckets'):
                output.append(log_warn("No S3 buckets found in this account."))
                return "\n".join(output)
            
            for bucket in response['Buckets']:
                bucket_name = bucket['Name']
                
                try:
                    # Try to get lifecycle configuration
                    lifecycle = s3.get_bucket_lifecycle_configuration(Bucket=bucket_name)
                    
                    # If it has lifecycle rules
                    output.append(log_success(f"✅ Bucket with lifecycle policy: {bucket_name}"))
                    for rule in lifecycle.get('Rules', []):
                        rule_id = rule.get('ID', 'N/A')
                        prefix = 'N/A'
                        if 'Filter' in rule and 'Prefix' in rule['Filter']:
                            prefix = rule['Filter']['Prefix']
                        status = rule.get('Status', 'N/A')
                        output.append(f"    ↳ ID: {rule_id}, Prefix: {prefix}, Status: {status}")
                
                except ClientError as e:
                    if 'NoSuchLifecycleConfiguration' in str(e):
                        output.append(log_warn(f"🗃️  Bucket without lifecycle policy: {bucket_name}"))
                    else:
                        output.append(log_error(f"Error checking bucket {bucket_name}: {str(e)}"))
            
            output.append(log_success("S3 lifecycle policy check completed."))
            return "\n".join(output)
        except Exception as e:
            output.append(log_error(f"Error listing S3 buckets: {str(e)}"))
            return "\n".join(output)
    except Exception as e:
        return log_error(f"Error in S3 lifecycle check: {str(e)}")

def check_old_rds_snapshots(session):
    """Check for old RDS snapshots"""
    # Implement the RDS snapshot check
    return "RDS Snapshots check - Implementation pending"

def check_forgotten_ebs(session):
    """Check for unattached EBS volumes"""
    try:
        ec2 = session.client('ec2')
        region = session.region_name
        
        output = [log_info(f"Checking for unattached (forgotten) EBS volumes in {region}"),
                 "---------------------------------------------------------------"]
        
        try:
            # Get all volumes with status 'available' (unattached)
            response = ec2.describe_volumes(Filters=[{'Name': 'status', 'Values': ['available']}])
            
            if not response.get('Volumes'):
                output.append(log_success("🧹 No unattached EBS volumes found."))
                return "\n".join(output)
            
            for volume in response['Volumes']:
                volume_id = volume['VolumeId']
                size = volume['Size']
                created = volume['CreateTime'].strftime('%Y-%m-%d %H:%M:%S')
                
                # Get tags if any
                tags = volume.get('Tags', [])
                tags_str = "None"
                if tags:
                    tags_str = ", ".join([f"{t['Key']}: {t['Value']}" for t in tags])
                
                output.append(log_warn(f"⚠️  Unattached EBS Volume: {volume_id}"))
                output.append(f"    ↳ Size: {size} GiB")
                output.append(f"    ↳ Created: {created}")
                output.append(f"    ↳ Tags: {tags_str}")
                output.append("")  # Empty line for readability
            
            return "\n".join(output)
        except Exception as e:
            output.append(log_error(f"Error describing EBS volumes: {str(e)}"))
            return "\n".join(output)
    except Exception as e:
        return log_error(f"Error in forgotten EBS check: {str(e)}")

def check_data_transfer_risks(session):
    """Check for data transfer risks"""
    # Implement the data transfer risk check
    return "Data Transfer Risks check - Implementation pending"

def check_on_demand_instances(session):
    """Check for on-demand instances"""
    try:
        ec2 = session.client('ec2')
        region = session.region_name
        
        output = [log_info(f"Checking for On-Demand EC2 instances in {region}"),
                 "----------------------------------------------------"]
        
        try:
            # Get all running instances
            response = ec2.describe_instances(
                Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
            )
            
            on_demand_count = 0
            for reservation in response.get('Reservations', []):
                for instance in reservation.get('Instances', []):
                    # On-demand instances don't have a 'InstanceLifecycle' field
                    if 'InstanceLifecycle' not in instance:
                        on_demand_count += 1
                        instance_id = instance['InstanceId']
                        instance_type = instance['InstanceType']
                        output.append(f"💸 On-Demand Instance: {instance_id} ({instance_type})")
            
            if on_demand_count == 0:
                output.append(log_success("No On-Demand instances detected."))
            else:
                output.append(log_warn(f"Total On-Demand instances: {on_demand_count}"))
                output.append(log_info("Consider using Reserved Instances or Savings Plans to save costs."))
            
            return "\n".join(output)
        except Exception as e:
            output.append(log_error(f"Error describing EC2 instances: {str(e)}"))
            return "\n".join(output)
    except Exception as e:
        return log_error(f"Error in on-demand instances check: {str(e)}")

def check_idle_load_balancers(session):
    """Check for idle load balancers"""
    # Implement the load balancer check
    return "Idle Load Balancers check - Implementation pending"

def check_route53(session):
    """Check Route 53 records"""
    # Implement the Route 53 check
    return "Route 53 Records check - Implementation pending"

def check_eks_clusters(session):
    """Check EKS clusters"""
    try:
        eks = session.client('eks')
        region = session.region_name
        
        output = [log_info(f"Checking EKS clusters in region {region}"),
                 "---------------------------------------------"]
        
        try:
            # List all clusters
            response = eks.list_clusters()
            clusters = response.get('clusters', [])
            
            if not clusters:
                output.append(log_warn(f"No EKS clusters found in region {region}."))
                return "\n".join(output)
            
            for cluster_name in clusters:
                output.append("")  # Empty line for readability
                output.append(log_info(f"🔍 Cluster: {cluster_name}"))
                
                # Get cluster details
                cluster_info = eks.describe_cluster(name=cluster_name)['cluster']
                
                status = cluster_info.get('status', 'Unknown')
                version = cluster_info.get('version', 'Unknown')
                endpoint = cluster_info.get('endpoint', 'Unknown')
                created_at = cluster_info.get('createdAt', 'Unknown')
                if isinstance(created_at, datetime.datetime):
                    created_at = created_at.strftime('%Y-%m-%d %H:%M:%S')
                
                output.append(log_success(f"✅ Status: {status}"))
                output.append(log_success(f"🔢 Version: {version}"))
                output.append(log_success(f"🌐 Endpoint: {endpoint}"))
                output.append(log_success(f"📅 Created At: {created_at}"))
                
                # Check nodegroups
                try:
                    nodegroups = eks.list_nodegroups(clusterName=cluster_name).get('nodegroups', [])
                    if not nodegroups:
                        output.append(log_warn(f"⚠️ No nodegroups found for cluster {cluster_name}."))
                    else:
                        output.append(log_info("🧱 Nodegroups:"))
                        for ng in nodegroups:
                            output.append(log_success(f" - {ng}"))
                except Exception as ng_error:
                    output.append(log_error(f"Error checking nodegroups: {str(ng_error)}"))
            
            output.append("")
            output.append(log_info("👉 Tip: Review unused clusters and upgrade older versions to optimize costs and performance."))
            output.append(log_info("🔗 EKS Console: https://console.aws.amazon.com/eks/home"))
            return "\n".join(output)
        except Exception as e:
            output.append(log_error(f"Error listing EKS clusters: {str(e)}"))
            return "\n".join(output)
    except Exception as e:
        return log_error(f"Error in EKS clusters check: {str(e)}")

def check_iam_usage(session):
    """Check IAM usage"""
    # Implement the IAM usage check
    return "IAM Usage check - Implementation pending"

def check_security_groups(session):
    """Check security groups"""
    try:
        ec2 = session.client('ec2')
        region = session.region_name
        
        output = [log_info(f"Scanning Security Groups for overly permissive rules in {region}"),
                 "---------------------------------------------------------"]
        
        try:
            # Get all security groups
            response = ec2.describe_security_groups()
            security_groups = response.get('SecurityGroups', [])
            
            if not security_groups:
                output.append(log_warn("No security groups found."))
                return "\n".join(output)
            
            for sg in security_groups:
                sg_id = sg['GroupId']
                sg_name = sg['GroupName']
                vpc_id = sg.get('VpcId', 'Unknown')
                
                output.append("")  # Empty line for readability
                output.append(log_info(f"🔍 Security Group: {sg_name} ({sg_id}) in VPC: {vpc_id}"))
                
                # Check inbound rules (permissions)
                for rule in sg.get('IpPermissions', []):
                    from_port = rule.get('FromPort', 'All')
                    to_port = rule.get('ToPort', 'All')
                    protocol = rule.get('IpProtocol', 'All')
                    
                    # Check for 0.0.0.0/0 in IP ranges (open to the world)
                    for ip_range in rule.get('IpRanges', []):
                        cidr = ip_range.get('CidrIp', '')
                        if cidr == '0.0.0.0/0':
                            # Check for SSH (22) or RDP (3389)
                            if from_port == 22 or from_port == 3389 or from_port == 'All':
                                output.append(log_warn(f"⚠️ Open to the world on port {from_port} ➜ Protocol: {protocol}, CIDR: {cidr}"))
                            else:
                                output.append(f"🌐 Open port range {from_port}-{to_port} to the world ➜ Protocol: {protocol}, CIDR: {cidr}")
            
            output.append(log_info("✅ Security Group scan complete"))
            return "\n".join(output)
        except Exception as e:
            output.append(log_error(f"Error describing security groups: {str(e)}"))
            return "\n".join(output)
    except Exception as e:
        return log_error(f"Error in security groups check: {str(e)}")

# Simple test to make sure the module can be imported correctly
if __name__ == "__main__":
    print("Module can be imported correctly")
