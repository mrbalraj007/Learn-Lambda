# AWS VPC Resource Details Script

This script extracts information about VPCs and their associated resources in your AWS account and exports the data to CSV files for easy analysis.

## Features

- Extracts details of all VPCs in a specified region or your default AWS region
- Gathers information about associated resources:
  - Subnets
  - Internet Gateways
  - NAT Gateways
  - Network ACLs (including inbound and outbound rules)
  - Route Tables (including routes and associations)
- Exports all data to CSV files
- Includes debug mode for troubleshooting
- Validates AWS connectivity before execution

## Prerequisites

Before using this script, ensure you have:

1. **AWS CLI** installed and configured
   ```
   # Check if AWS CLI is installed
   aws --version
   
   # Configure AWS CLI with your credentials
   aws configure
   ```

2. **jq** installed for JSON processing
   ```
   # Install jq on Ubuntu/Debian
   sudo apt-get install jq
   
   # Install jq on CentOS/RHEL
   sudo yum install jq
   
   # Install jq on macOS
   brew install jq

   # Verify jq status
   jq --version
   which jq
   echo "$PATH"
   ```

3. **Appropriate IAM permissions** to describe the following resources:
   - VPCs
   - Subnets
   - Internet Gateways
   - NAT Gateways
   - Network ACLs
   - Route Tables

## Usage

### Basic Usage

Run the script with default settings (uses your default AWS CLI region):

```bash
./vpc-details.sh
```

### Specify AWS Region

To extract VPC details from a specific region:

```bash
./vpc-details.sh -r us-east-1

or 

./vpc-details.sh -r ap-southeast-2 -c /path/to/corporate-ca-bundle.pem
```

### Enable Debug Mode

For troubleshooting or to see more detailed information during execution:

```bash
./vpc-details.sh -d
```

### Combined Options

You can combine options as needed:

```bash
./vpc-details.sh -r us-west-2 -d
```

### Custom CA Bundle

If your network uses TLS inspection and AWS CLI reports a certificate verification error, ask your IT team for the trusted corporate CA certificate in PEM format. Pass its path with `-c`:

```bash
./vpc-details.sh -r ap-southeast-2 -c /path/to/corporate-ca-bundle.pem
```

The bundle is used by AWS CLI for its HTTPS requests. Do not disable SSL certificate verification.

## Output Files

The script creates a directory called `vpc-reports` and generates the following CSV files:

1. `vpc-details.csv` - Basic information about each VPC
2. `vpc-subnets.csv` - Details of all subnets in each VPC
3. `vpc-internet-gateways.csv` - Information about Internet Gateways
4. `vpc-nat-gateways.csv` - Information about NAT Gateways
5. `vpc-network-acls.csv` - Network ACL details
6. `vpc-nacl-rules.csv` - Inbound and outbound rules for each Network ACL
7. `vpc-route-tables.csv` - Information about route tables
8. `vpc-routes.csv` - Routes in each route table
9. `vpc-rt-associations.csv` - Route table associations with subnets

## Example Output

Here's what the CSV data looks like:

### vpc-details.csv
```
VPC_ID,CIDR_Block,Name,State,Is_Default
vpc-0123456789abcdef0,10.0.0.0/16,"Production VPC",available,false
vpc-0123456789abcdef1,172.31.0.0/16,"Default VPC",available,true
```

### vpc-subnets.csv
```
VPC_ID,Subnet_ID,CIDR_Block,Availability_Zone,State,Name
vpc-0123456789abcdef0,subnet-0123456789abcdef0,10.0.1.0/24,us-east-1a,available,"Production Public Subnet 1"
vpc-0123456789abcdef0,subnet-0123456789abcdef1,10.0.2.0/24,us-east-1b,available,"Production Public Subnet 2"
```

## Troubleshooting

### No Data in CSV Files

If the script runs without errors but CSV files are empty or contain only headers:

1. **Verify Region**: Make sure you have VPC resources in the specified region
   ```bash
   ./vpc-details.sh -r us-east-1
   ```

2. **Check Permissions**: Ensure your IAM user/role has the necessary permissions
   ```bash
   aws iam get-user
   ```

3. **Run in Debug Mode**: Get more detailed information
   ```bash
   ./vpc-details.sh -d
   ```

4. **Verify AWS CLI Configuration**: Make sure your AWS configuration is correct
   ```bash
   aws configure list
   ```

### Error Messages

If you see errors about missing commands or permissions:

1. **AWS CLI not installed**: Install the AWS CLI
   ```bash
   pip install awscli
   ```

2. **jq not installed**: Install jq
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **Permission Denied**: Make the script executable
   ```bash
   chmod +x vpc-details.sh
   ```

## Additional Information

- The script automatically creates the output directory if it doesn't exist
- For VPCs, subnets, and other resources with tags, the script extracts the "Name" tag
- The debug mode (-d) provides detailed information about each step of the process
- The script validates AWS connectivity before attempting to gather resource information

---

************************************************************
---
# AWS CLI SSL Certificate Fix for Zscaler and VPC Reporting

## Overview

This document describes the working solution for running AWS CLI and the `vpc-details.sh` script from a Windows 11 corporate workstation where HTTPS traffic is inspected by Zscaler.

The original problem occurred because different AWS endpoints were presenting different certificate chains:

```text
EC2
 |
 +--> Zscaler TLS Inspection
        |
        +--> Zscaler Intermediate CA
               |
               +--> Zscaler Root CA

STS
 |
 +--> Amazon RSA 2048 M01
        |
        +--> Amazon Root CA 1
               |
               +--> Public CA Trust
```

Using only the Zscaler Root CA fixed EC2 but caused STS certificate validation to fail.

The final solution is to create a combined CA bundle containing:

```text
Standard AWS/Public CA Bundle
+
Corporate Zscaler Root CA
=
AWS Corporate CA Bundle
```

The resulting bundle can then be used by AWS CLI and `vpc-details.sh`.

---

# Environment

This procedure was tested with:

- Windows 11
- Git Bash
- AWS CLI
- OpenSSL
- jq
- Zscaler TLS inspection
- AWS Region: `ap-southeast-2`

---

# Prerequisites

Verify that the required utilities are available.

## AWS CLI

```bash
aws --version
```

## OpenSSL

```bash
openssl version
```

## jq

```bash
jq --version
```

## Git Bash HOME

```bash
echo "$HOME"
```

Example:

```text
/c/Users/bsingh
```

Note that Bash variables use `$`.

Correct:

```bash
echo "$HOME"
```

Incorrect:

```bash
echo "@HOME"
```

---

# Original Problem

Running:

```bash
./vpc-details.sh -r ap-southeast-2
```

failed with an SSL validation error similar to:

```text
SSL validation failed for
https://ec2.ap-southeast-2.amazonaws.com/

[SSL: CERTIFICATE_VERIFY_FAILED]
certificate verify failed:
unable to get local issuer certificate
```

This indicated that AWS CLI could not validate the certificate chain presented for the EC2 endpoint.

---

# Step 1: Inspect the EC2 Certificate

Run:

```bash
openssl s_client \
  -showcerts \
  -servername ec2.ap-southeast-2.amazonaws.com \
  -connect ec2.ap-southeast-2.amazonaws.com:443 \
  </dev/null
```

The certificate showed:

```text
subject=CN=ec2.ap-southeast-2.amazonaws.com,
O=Zscaler Inc.,
OU=Zscaler Inc.
```

and an issuer similar to:

```text
CN=Zscaler Intermediate Root CA
```

The verification failed:

```text
Verify return code: 20
(unable to get local issuer certificate)
```

This confirmed that EC2 traffic was passing through Zscaler TLS inspection.

A shorter check is:

```bash
openssl s_client \
  -showcerts \
  -servername ec2.ap-southeast-2.amazonaws.com \
  -connect ec2.ap-southeast-2.amazonaws.com:443 \
  </dev/null 2>/dev/null |
openssl x509 -noout -subject -issuer
```

---

# Step 2: Find the Zscaler Root CA in Windows

Open PowerShell.

Check the Local Machine certificate store:

```powershell
Get-ChildItem Cert:\LocalMachine\Root |
Where-Object {
    $_.Subject -like "*Zscaler*" -or
    $_.Issuer -like "*Zscaler*"
} |
Select-Object Subject, Issuer, Thumbprint, NotAfter
```

Also check the Current User store:

```powershell
Get-ChildItem Cert:\CurrentUser\Root |
Where-Object {
    $_.Subject -like "*Zscaler*" -or
    $_.Issuer -like "*Zscaler*"
} |
Select-Object Subject, Issuer, Thumbprint, NotAfter
```

The required certificate was:

```text
CN=Zscaler Root CA
```

The certificate was self-signed because both Subject and Issuer identified:

```text
Zscaler Root CA
```

The certificate thumbprint identified during this troubleshooting was:

```text
0D23EE8F0F0560B9F68F2437C526D3CDF1FAF0C5
```

> Important:
> Do not blindly reuse this thumbprint on another machine.
> Identify and verify the corporate-approved certificate installed in that environment.

---

# Step 3: Export the Zscaler Root Certificate

If exporting from `LocalMachine` gives:

```text
Access is denied
0x80070005
```

use the Current User certificate store if the same approved certificate is available there.

In PowerShell:

```powershell
$thumbprint = "0D23EE8F0F0560B9F68F2437C526D3CDF1FAF0C5"
```

Retrieve it:

```powershell
$cert = Get-ChildItem "Cert:\CurrentUser\Root\$thumbprint"
```

Verify:

```powershell
$cert |
Select-Object Subject, Issuer, Thumbprint, NotAfter
```

Export:

```powershell
Export-Certificate `
    -Cert $cert `
    -FilePath "$env:USERPROFILE\zscaler-root-ca.cer"
```

The resulting file will be similar to:

```text
C:\Users\<username>\zscaler-root-ca.cer
```

---

# Step 4: Convert the Certificate to PEM

Return to Git Bash.

Convert the exported certificate:

```bash
openssl x509 \
  -inform DER \
  -in "$HOME/zscaler-root-ca.cer" \
  -out "$HOME/zscaler-root-ca.pem"
```

The resulting file is:

```text
$HOME/zscaler-root-ca.pem
```

For example:

```text
/c/Users/<username>/zscaler-root-ca.pem
```

---

# Step 5: Verify the Zscaler Root Certificate

Run:

```bash
openssl x509 \
  -in "$HOME/zscaler-root-ca.pem" \
  -noout \
  -subject \
  -issuer \
  -fingerprint \
  -sha1
```

The certificate should identify:

```text
subject=... CN=Zscaler Root CA ...
issuer=... CN=Zscaler Root CA ...
```

In the tested environment, the fingerprint was:

```text
SHA1 Fingerprint=
0D:23:EE:8F:0F:05:60:B9:F6:8F:24:37:C5:26:D3:CD:F1:FA:F0:C5
```

This corresponded with the Windows certificate thumbprint:

```text
0D23EE8F0F0560B9F68F2437C526D3CDF1FAF0C5
```

---

# Step 6: Test EC2 Using the Zscaler Certificate

Run:

```bash
openssl s_client \
  -servername ec2.ap-southeast-2.amazonaws.com \
  -connect ec2.ap-southeast-2.amazonaws.com:443 \
  -CAfile "$HOME/zscaler-root-ca.pem" \
  </dev/null 2>/dev/null |
grep "Verify return code"
```

Before fixing the trust:

```text
Verify return code: 20
(unable to get local issuer certificate)
```

After supplying the correct Zscaler Root CA:

```text
Verify return code: 0 (ok)
```

This confirmed that the Zscaler certificate chain was trusted.

---

# Step 7: Test AWS EC2

Test AWS CLI directly:

```bash
AWS_CA_BUNDLE="$HOME/zscaler-root-ca.pem" \
aws ec2 describe-vpcs \
  --region ap-southeast-2 \
  --output json
```

The command should successfully return VPC information.

Example:

```json
{
    "Vpcs": [
        {
            "InstanceTenancy": "default",
            "IsDefault": false,
            "VpcId": "vpc-xxxxxxxxxxxxxxxxx",
            "State": "available",
            "CidrBlock": "10.x.x.x/24"
        }
    ]
}
```

At this stage EC2 is working.

However, this is not yet the complete solution.

---

# Step 8: Test AWS STS

Test STS:

```bash
aws --region ap-southeast-2 \
  sts get-caller-identity
```

In this environment, STS initially failed after configuring only the Zscaler certificate:

```text
SSL validation failed for
https://sts.ap-southeast-2.amazonaws.com/

CERTIFICATE_VERIFY_FAILED
unable to get local issuer certificate
```

This required further investigation.

---

# Step 9: Inspect the STS Certificate

Run:

```bash
openssl s_client \
  -showcerts \
  -servername sts.ap-southeast-2.amazonaws.com \
  -connect sts.ap-southeast-2.amazonaws.com:443 \
  </dev/null
```

Unlike EC2, STS presented a normal public AWS certificate chain:

```text
sts.ap-southeast-2.amazonaws.com
        |
        v
Amazon RSA 2048 M01
        |
        v
Amazon Root CA 1
        |
        v
Public Certificate Trust
```

The output showed:

```text
subject=CN=sts.ap-southeast-2.amazonaws.com

issuer=C=US,
O=Amazon,
CN=Amazon RSA 2048 M01
```

Without explicitly forcing the Zscaler CA file, OpenSSL successfully validated STS:

```text
Verification: OK
Verify return code: 0 (ok)
```

---

# Step 10: Understand Why STS Failed

The original custom CA file contained only:

```text
Zscaler Root CA
```

That worked for EC2 because EC2 traffic was being TLS-inspected by Zscaler.

However, STS was presenting the Amazon/public certificate chain.

Therefore a CA file containing only the Zscaler root was insufficient for all AWS endpoints.

The solution was to create a combined bundle:

```text
Standard Public/AWS CA certificates
+
Zscaler Root CA
```

---

# Step 11: Locate the AWS CLI CA Bundle

Find the AWS executable:

```bash
which aws
```

On Windows Git Bash:

```bash
where.exe aws
```

Check the AWS CLI version:

```bash
aws --version
```

Search the AWS CLI installation for `cacert.pem`:

```bash
find "/c/Program Files/Amazon/AWSCLIV2" \
  -iname "cacert.pem" \
  2>/dev/null
```

The command should return the actual CA bundle used by the AWS CLI installation.

A typical location may resemble:

```text
/c/Program Files/Amazon/AWSCLIV2/awscli/botocore/cacert.pem
```

Use the path returned by your own machine.

---

# Step 12: Create the Combined Corporate AWS CA Bundle

Copy the standard AWS/public CA bundle.

For example:

```bash
cp "/c/Program Files/Amazon/AWSCLIV2/awscli/botocore/cacert.pem" \
   "$HOME/aws-corporate-ca-bundle.pem"
```

> Use the actual `cacert.pem` path returned by the previous `find` command.

Verify:

```bash
ls -lh "$HOME/aws-corporate-ca-bundle.pem"
```

---

# Step 13: Append the Zscaler Root CA

Add a newline:

```bash
printf '\n' >> "$HOME/aws-corporate-ca-bundle.pem"
```

Append the Zscaler Root certificate:

```bash
cat "$HOME/zscaler-root-ca.pem" \
  >> "$HOME/aws-corporate-ca-bundle.pem"
```

The resulting file is:

```text
$HOME/aws-corporate-ca-bundle.pem
```

Its logical contents are:

```text
-----BEGIN CERTIFICATE-----
Standard public CA certificate
-----END CERTIFICATE-----

...

-----BEGIN CERTIFICATE-----
Other standard CA certificates
-----END CERTIFICATE-----

-----BEGIN CERTIFICATE-----
Zscaler Root CA
-----END CERTIFICATE-----
```

---

# Step 14: Verify the Combined Bundle

Count the certificates:

```bash
grep -c "BEGIN CERTIFICATE" \
  "$HOME/aws-corporate-ca-bundle.pem"
```

The result should show multiple certificates.

Confirm that Zscaler is included:

```bash
openssl crl2pkcs7 \
  -nocrl \
  -certfile "$HOME/aws-corporate-ca-bundle.pem" |
openssl pkcs7 \
  -print_certs \
  -noout |
grep -i zscaler
```

---

# Step 15: Verify STS with the Combined Bundle

Run:

```bash
openssl s_client \
  -servername sts.ap-southeast-2.amazonaws.com \
  -connect sts.ap-southeast-2.amazonaws.com:443 \
  -CAfile "$HOME/aws-corporate-ca-bundle.pem" \
  </dev/null 2>/dev/null |
grep "Verify return code"
```

Expected:

```text
Verify return code: 0 (ok)
```

STS now trusts the public Amazon certificate chain.

---

# Step 16: Verify EC2 with the Same Bundle

Run:

```bash
openssl s_client \
  -servername ec2.ap-southeast-2.amazonaws.com \
  -connect ec2.ap-southeast-2.amazonaws.com:443 \
  -CAfile "$HOME/aws-corporate-ca-bundle.pem" \
  </dev/null 2>/dev/null |
grep "Verify return code"
```

Expected:

```text
Verify return code: 0 (ok)
```

At this point both certificate paths work with the same bundle:

```text
STS:
Verify return code: 0 (ok)

EC2:
Verify return code: 0 (ok)
```

---

# Step 17: Test AWS STS with the Combined Bundle

Run:

```bash
AWS_CA_BUNDLE="$HOME/aws-corporate-ca-bundle.pem" \
aws --region ap-southeast-2 \
  sts get-caller-identity
```

Successful output should resemble:

```json
{
    "UserId": "...",
    "Account": "...",
    "Arn": "arn:aws:sts::..."
}
```

---

# Step 18: Test AWS EC2 with the Combined Bundle

Run:

```bash
AWS_CA_BUNDLE="$HOME/aws-corporate-ca-bundle.pem" \
aws ec2 describe-vpcs \
  --region ap-southeast-2 \
  --output json
```

This should successfully return the VPC information.

At this point both commands should work:

```bash
AWS_CA_BUNDLE="$HOME/aws-corporate-ca-bundle.pem" \
aws sts get-caller-identity \
  --region ap-southeast-2
```

and:

```bash
AWS_CA_BUNDLE="$HOME/aws-corporate-ca-bundle.pem" \
aws ec2 describe-vpcs \
  --region ap-southeast-2
```

---

# Step 19: Configure AWS CLI Permanently

Once the combined bundle has been successfully tested, configure AWS CLI:

```bash
aws configure set ca_bundle \
  "$HOME/aws-corporate-ca-bundle.pem"
```

Verify:

```bash
aws configure get ca_bundle
```

Example:

```text
C:/Users/<username>/aws-corporate-ca-bundle.pem
```

AWS CLI supports configuring a custom PEM certificate bundle through the `ca_bundle` configuration option or the `AWS_CA_BUNDLE` environment variable.

---

# Step 20: Remove Temporary AWS_CA_BUNDLE Variable

If `AWS_CA_BUNDLE` was previously exported:

```bash
unset AWS_CA_BUNDLE
```

Check:

```bash
echo "$AWS_CA_BUNDLE"
```

It should return nothing.

The permanent AWS CLI configuration can be checked with:

```bash
aws configure get ca_bundle
```

---

# Step 21: Final AWS STS Test

Run without manually specifying the CA:

```bash
aws --region ap-southeast-2 \
  sts get-caller-identity
```

This should work successfully.

---

# Step 22: Final AWS EC2 Test

Run:

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-2 \
  --output json
```

This should also work successfully.

---

# Step 23: Run the VPC Reporting Script

Now run:

```bash
./vpc-details.sh -r ap-southeast-2
```

Expected workflow:

```text
Using region: ap-southeast-2

Testing AWS connectivity...

Connected to AWS as:
arn:aws:sts::...

Retrieving VPC details...

Found <number> VPCs in the region.

Processing VPC: vpc-...
  Getting subnets...
  Getting internet gateways...
  Getting NAT gateways...
  Getting network ACLs...
  Getting route tables...

Completed processing for VPC: vpc-...
```

---

# Alternative: Explicitly Pass the Bundle to the Script

The script also supports the `-c` option:

```bash
./vpc-details.sh \
  -r ap-southeast-2 \
  -c "$HOME/aws-corporate-ca-bundle.pem"
```

This causes the script to set:

```bash
AWS_CA_BUNDLE
```

for the AWS CLI commands executed by the script.

This is useful when the AWS CLI configuration should not be changed permanently.

---

# Generated Reports

The script generates:

```text
./vpc-reports/
```

with:

```text
vpc-details.csv
vpc-subnets.csv
vpc-internet-gateways.csv
vpc-nat-gateways.csv
vpc-network-acls.csv
vpc-nacl-rules.csv
vpc-route-tables.csv
vpc-routes.csv
vpc-rt-associations.csv
```

Verify:

```bash
ls -lh ./vpc-reports/
```

View VPC details:

```bash
cat ./vpc-reports/vpc-details.csv
```

---

# Quick Validation Procedure

After everything has been configured, the following tests can be used.

## AWS CLI CA Configuration

```bash
aws configure get ca_bundle
```

Expected:

```text
C:/Users/<username>/aws-corporate-ca-bundle.pem
```

## STS TLS

```bash
openssl s_client \
  -servername sts.ap-southeast-2.amazonaws.com \
  -connect sts.ap-southeast-2.amazonaws.com:443 \
  -CAfile "$HOME/aws-corporate-ca-bundle.pem" \
  </dev/null 2>/dev/null |
grep "Verify return code"
```

Expected:

```text
Verify return code: 0 (ok)
```

## EC2 TLS

```bash
openssl s_client \
  -servername ec2.ap-southeast-2.amazonaws.com \
  -connect ec2.ap-southeast-2.amazonaws.com:443 \
  -CAfile "$HOME/aws-corporate-ca-bundle.pem" \
  </dev/null 2>/dev/null |
grep "Verify return code"
```

Expected:

```text
Verify return code: 0 (ok)
```

## AWS STS

```bash
aws sts get-caller-identity \
  --region ap-southeast-2
```

## AWS EC2

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-2 \
  --output json
```

## VPC Script

```bash
./vpc-details.sh -r ap-southeast-2
```

---

# Final Working Architecture

```text
                  AWS CLI
                     |
                     v
       aws-corporate-ca-bundle.pem
                     |
          +----------+----------+
          |                     |
          v                     v
 Standard Public CAs     Zscaler Root CA
          |                     |
          v                     v
         STS                Zscaler TLS
                                  |
                                  v
                                 EC2
          |                     |
          +----------+----------+
                     |
                     v
              Certificate
               validation
                   works
                     |
                     v
              vpc-details.sh
                     |
                     v
                CSV Reports
```

---

# Why the Combined Bundle Is Required

The important discovery during troubleshooting was that EC2 and STS were not using the same certificate path.

## EC2

EC2 was being TLS-inspected:

```text
EC2
 |
 v
Zscaler certificate
 |
 v
Zscaler Intermediate
 |
 v
Zscaler Root CA
```

Therefore:

```text
zscaler-root-ca.pem
```

allowed EC2 certificate verification to succeed.

## STS

STS presented the public AWS certificate chain:

```text
STS
 |
 v
Amazon RSA 2048 M01
 |
 v
Amazon Root CA 1
 |
 v
Public trust hierarchy
```

A custom CA file containing only the Zscaler Root CA therefore did not contain the public CA trust required by this path.

The working solution was:

```text
AWS/Public CA Bundle
        +
Zscaler Root CA
        |
        v
aws-corporate-ca-bundle.pem
```

The same CA bundle can therefore validate both endpoint certificate paths.

---

# Do Not Use --no-verify-ssl

Do not permanently solve the issue using:

```bash
--no-verify-ssl
```

For example, avoid:

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-2 \
  --no-verify-ssl
```

The working solution keeps TLS certificate validation enabled by configuring the appropriate CA bundle.

---

# Recommended Security Practices

- Keep SSL/TLS certificate verification enabled.
- Use only the corporate-approved Zscaler Root CA.
- Verify the certificate fingerprint before using it.
- Keep the original AWS/public certificates in the combined bundle.
- Do not replace the public CA bundle with only the Zscaler certificate.
- Do not hard-code the certificate itself into `vpc-details.sh`.
- Prefer passing the certificate path or configuring AWS CLI.
- Do not commit corporate certificates into Git unless explicitly permitted by organizational security policy.
- Keep the Zscaler certificate and combined CA bundle outside the repository when possible.

For example:

```text
Repository
|
+-- vpc-details.sh
+-- README.md
+-- .gitignore
```

Certificate files:

```text
C:\Users\<username>\
|
+-- zscaler-root-ca.cer
+-- zscaler-root-ca.pem
+-- aws-corporate-ca-bundle.pem
```

---

# Suggested .gitignore

To reduce the risk of accidentally committing certificate files:

```gitignore
# Certificate files
*.pem
*.cer
*.crt

# VPC generated *eports
vpc-reports/
```

If your r*pository legitimately contains oth*r PEM/CER files, use more specific*entries instead:

```gitignore
zsc*ler-root-ca.cer
zscaler-root-ca.pe*
aws-corporate-ca-bundle.pem
vpc-r*ports/
```

---

# Troubleshooting*Flow

```text
AWS CLI EC2 fails
  *     |
        v
CERTIFICATE_VERIF*_FAILED
        |
        v
Inspec* EC2 certificate
with OpenSSL
    *   |
        v
Zscaler detected
  *     |
        v
Find Zscaler Root*CA
in Windows certificate store
  *     |
        v
Export certificat*
        |
        v
Convert CER -* PEM
        |
        v
Verify fi*gerprint
        |
        v
Test *C2 with Zscaler CA
        |
     *  v
EC2 works
        |
        v
*est STS
        |
        v
STS fa*ls with Zscaler-only CA
        |
*       v
Inspect STS certificate
 *      |
        v
Amazon/Public CA*chain detected
        |
        v*Find AWS CLI cacert.pem
        |
*       v
Copy standard CA bundle
 *      |
        v
Append Zscaler R*ot CA
        |
        v
aws-corp*rate-ca-bundle.pem
        |
     *  +----------------+
        |    *           |
        v            *   v
      STS OK           EC2 OK*        |                |
       *+--------+-------+
               * |
                 v
       Confi*ure AWS ca_bundle
                *|
                 v
          vpc*details.sh
                 |
    *            v
              SUCCES*
```

---

# Final Working Command*

For quick reference:

```bash
aw* configure get ca_bundle
```

```b*sh
openssl s_client \
  -servernam* sts.ap-southeast-2.amazonaws.com *
  -connect sts.ap-southeast-2.ama*onaws.com:443 \
  -CAfile "$HOME/a*s-corporate-ca-bundle.pem" \
  </d*v/null 2>/dev/null |
grep "Verify *eturn code"
```

```bash
openssl s*