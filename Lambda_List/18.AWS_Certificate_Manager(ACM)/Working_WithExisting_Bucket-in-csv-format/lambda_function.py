import boto3
import csv
import datetime
import os
from io import StringIO
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

def lambda_handler(event, context):
    # Initialize boto3 clients
    acm_client = boto3.client('acm')
    s3_client = boto3.client('s3')
    sns_client = boto3.client('sns')
    ses_client = boto3.client('ses')
    
    # Get environment variables
    bucket_name = os.environ['S3_BUCKET_NAME']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    email_recipient = os.environ['EMAIL_RECIPIENT']
    
    # Get list of certificates
    certificates = []
    paginator = acm_client.get_paginator('list_certificates')
    for page in paginator.paginate():
        certificates.extend(page['CertificateSummaryList'])
    
    # Prepare CSV data
    csv_data = StringIO()
    csv_writer = csv.writer(csv_data)
    csv_writer.writerow(['Certificate ARN', 'Domain Name', 'Status', 'Type', 'Issued At', 'Not Before', 'Not After', 'Days to Expiry'])
    
    # Current time for calculation
    now = datetime.datetime.now(datetime.timezone.utc)
    
    # Collect certificate details
    for cert in certificates:
        cert_details = acm_client.describe_certificate(CertificateArn=cert['CertificateArn'])
        cert_detail = cert_details['Certificate']
        
        domain_name = cert_detail.get('DomainName', 'N/A')
        status = cert_detail.get('Status', 'N/A')
        cert_type = cert_detail.get('Type', 'N/A')
        issued_at = cert_detail.get('IssuedAt', 'N/A')
        not_before = cert_detail.get('NotBefore', 'N/A')
        not_after = cert_detail.get('NotAfter', 'N/A')
        
        # Calculate days to expiry if NotAfter date exists
        days_to_expiry = 'N/A'
        if not_after != 'N/A':
            days_to_expiry = (not_after - now).days
        
        csv_writer.writerow([
            cert['CertificateArn'],
            domain_name,
            status,
            cert_type,
            issued_at.strftime('%Y-%m-%d') if isinstance(issued_at, datetime.datetime) else issued_at,
            not_before.strftime('%Y-%m-%d') if isinstance(not_before, datetime.datetime) else not_before,
            not_after.strftime('%Y-%m-%d') if isinstance(not_after, datetime.datetime) else not_after,
            days_to_expiry
        ])
    
    # Get the CSV data
    csv_content = csv_data.getvalue()
    
    # Generate filename with date and time
    current_timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    file_name = f"acm_certificates_{current_timestamp}.csv"
    
    # Upload to S3
    s3_client.put_object(
        Bucket=bucket_name,
        Key=file_name,
        Body=csv_content,
        ContentType='text/csv'
    )
    
    # Prepare email with CSV attachment using SES
    try:
        # Create a multipart message
        msg = MIMEMultipart()
        msg['Subject'] = "Weekly ACM Certificate Report"
        msg['From'] = "no-reply@aws.amazon.com"
        msg['To'] = email_recipient
        
        # Add message body
        body = f"ACM Certificate report has been generated and saved to s3://{bucket_name}/{file_name}\n\nPlease find the report attached."
        msg.attach(MIMEText(body, 'plain'))
        
        # Add CSV attachment
        attachment = MIMEApplication(csv_content, Name=file_name)
        attachment['Content-Disposition'] = f'attachment; filename="{file_name}"'
        msg.attach(attachment)
        
        # Send email through SES
        ses_client.send_raw_email(
            Source="no-reply@aws.amazon.com",
            Destinations=[email_recipient],
            RawMessage={'Data': msg.as_string()}
        )
    except Exception as e:
        # Fallback to SNS if SES fails or isn't available
        message = f"ACM Certificate report has been generated and saved to s3://{bucket_name}/{file_name}"
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=message,
            Subject="Weekly ACM Certificate Report"
        )
        print(f"Falling back to SNS due to SES error: {str(e)}")
    
    return {
        'statusCode': 200,
        'body': f"Report generated successfully and saved to {file_name}"
    }

