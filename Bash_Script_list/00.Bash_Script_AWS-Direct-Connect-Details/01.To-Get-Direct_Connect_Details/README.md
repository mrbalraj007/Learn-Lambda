# AWS Direct Connect Details

A Bash script that retrieves AWS Direct Connect connections from one or more AWS regions and combines the results in a CSV file.

## Requirements

- Bash
- AWS CLI v2, configured with credentials and a default profile (or `AWS_PROFILE`)
- `jq`
- AWS permissions for `directconnect:DescribeConnections`

## Run

Open a Bash-compatible shell (for example, Git Bash, WSL, or a Linux/macOS terminal), change to this directory, and run:

```bash
chmod +x get-direct-connect-details.sh
./get-direct-connect-details.sh
```

The script prompts for one or more AWS regions. Enter regions separated by commas or spaces. For Sydney and Melbourne, enter `ap-southeast-2,ap-southeast-4`. The script combines their results in one CSV, with a `region` column on each row. By default, it writes `direct-connect-ap-southeast-2-ap-southeast-4.csv` in the current working directory. The filename is built from the supplied region names, joined with hyphens.

To choose a different output file, add `-o`:

```bash
./get-direct-connect-details.sh -o direct-connect.csv
```

To provide multiple regions without a prompt, use `-r` with a comma- or space-separated list in quotes:

```bash
./get-direct-connect-details.sh -r "ap-southeast-2,ap-southeast-4" -o direct-connect.csv
```

Use one region the same way: `./get-direct-connect-details.sh -r ap-southeast-2`.

To see the available options, run:

```bash
./get-direct-connect-details.sh -h
```

To use a named AWS CLI profile:

```bash
AWS_PROFILE=my-profile ./get-direct-connect-details.sh
```

## CSV columns

The CSV contains: `ownerAccount`, `connectionId`, `connectionName`, `connectionState`, `region`, `location`, `bandwidth`, `providerName`, `partnerName`, `vlan`, `awsDevice`, `awsDeviceV2`, `jumboFrameCapable`, `hasLogicalRedundancy`, `macSecCapable`, `portEncryptionStatus`, and `encryptionMode`.

If a regional AWS query fails, the script reports that region and error, keeps any results retrieved from the other regions, and exits with a nonzero status. If the output file cannot be written (for example, because it is open in another application), the script reports the error and exits. Check the AWS CLI credentials, region names, and permissions if a query fails.
