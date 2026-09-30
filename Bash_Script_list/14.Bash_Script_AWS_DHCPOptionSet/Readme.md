# AWS VPC and DHCP Inventory

This script exports VPC details and their associated DHCP option settings to a CSV file. It checks every AWS CLI profile configured on the machine for VPCs in the selected region. The script only makes read-only AWS API calls.

## Requirements

- Bash (Git Bash, WSL, macOS, or Linux)
- AWS CLI v2
- `jq`
- One or more configured AWS CLI profiles with valid credentials. For AWS IAM Identity Center (SSO) profiles, sign in before running the script.

The profiles need permission to call `sts:GetCallerIdentity`, `ec2:DescribeVpcs`, and `ec2:DescribeDhcpOptions`. The script also tries `organizations:DescribeAccount` to look up account names; if it cannot, it uses the profile name instead.

## Run

Open a Bash terminal in this folder and provide the AWS region as the only argument:

```bash
bash ./Export-aws-dhcp-aws-vpc-inventory.sh ap-southeast-2
```

Other examples:

```bash
bash ./Export-aws-dhcp-aws-vpc-inventory.sh us-east-1
bash ./Export-aws-dhcp-aws-vpc-inventory.sh us-west-2
```

There is no default region; the script exits with usage instructions if the region argument is omitted. For an SSO profile, sign in first, for example:

```bash
aws sso login --profile my-profile
```

The script processes all profiles returned by `aws configure list-profiles`; it does not accept a profile selector.

## Output

The CSV is created in the current working directory as:

```text
aws-vpc-inventory-<region>.csv
```

For example, the command above creates `aws-vpc-inventory-ap-southeast-2.csv`. Running the script again for the same region replaces that file.

Each row represents one VPC. The columns are:

- Account ID and Account Name
- VPC ID, VPC CIDR, and VPC Name
- Region and Range (Range currently repeats the VPC CIDR)
- DNS, NTP, and Domain Name from the DHCP option set
- DHCP Option Set ID

Multiple values in a DHCP field are separated by semicolons. If an option is not configured, its CSV field is blank. The script prints profile and VPC progress in the terminal; profiles it cannot access and regions with no VPCs are skipped.

## Troubleshooting

- `AWS CLI is not installed` or `jq is not installed`: install the missing dependency and retry.
- `No AWS profiles found`: configure a profile with the AWS CLI, then retry.
- `Unable to access profile`: check the profile credentials or complete SSO login with `aws sso login --profile <profile>`.
- An output file containing only the header can mean that no configured profile was accessible or that no VPCs were found in the selected region. Review the terminal messages and verify the region and permissions.