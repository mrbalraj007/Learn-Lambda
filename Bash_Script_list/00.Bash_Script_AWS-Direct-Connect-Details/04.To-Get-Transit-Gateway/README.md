# AWS Transit Gateway Details

A Bash script that retrieves AWS Transit Gateways from one or more AWS regions and combines the results in a CSV file. Identical Transit Gateway rows returned from multiple regions are included only once.

## Requirements

- Bash
- AWS CLI v2, configured with credentials and a default profile (or `AWS_PROFILE`)
- `jq`
- AWS permissions for `ec2:DescribeTransitGateways`

## Run

Open a Bash-compatible shell (for example, Git Bash, WSL, or a Linux/macOS terminal), change to this directory, and run:

```bash
chmod +x to-get-Transit-gateway-details.sh
./to-get-Transit-gateway-details.sh
```

The script prompts for one or more AWS regions. Enter regions separated by commas or spaces. For Sydney and Melbourne, enter `ap-southeast-2,ap-southeast-4`. By default, it writes `transit-gateways-ap-southeast-2-ap-southeast-4.csv` in the current working directory. The filename is built from the supplied region names, joined with hyphens.

To choose a different output file, add `-o`:

```bash
./to-get-Transit-gateway-details.sh -o transit-gateways.csv
```

To provide multiple regions without a prompt, use `-r` with a comma- or space-separated list in quotes:

```bash
./to-get-Transit-gateway-details.sh -r "ap-southeast-2,ap-southeast-4,ap-northeast-1" -o transit-gateways.csv
```

Use one region the same way: `./to-get-Transit-gateway-details.sh -r ap-southeast-2`.

To see the available options, run:

```bash
./to-get-Transit-gateway-details.sh -h
```

To use a named AWS CLI profile:

```bash
AWS_PROFILE=my-profile ./to-get-Transit-gateway-details.sh
```

## CSV columns

The CSV columns are `OwnerId`, `Region`, `Name`, `TransitGatewayId`, `Description`, `AmazonSideAsn`, `AutoAcceptSharedAttachments`, `DefaultRouteTableAssociation`, `AssociationDefaultRouteTableId`, `DefaultRouteTablePropagation`, `PropagationDefaultRouteTableId`, `VpnEcmpSupport`, and `DnsSupport`.

If a regional AWS query fails, the script reports that region and error, keeps any results retrieved from the other regions, and exits with a nonzero status. If the output file cannot be written (for example, because it is open in another application), the script reports the error and exits. Check the AWS CLI credentials, region names, and permissions if a query fails.
