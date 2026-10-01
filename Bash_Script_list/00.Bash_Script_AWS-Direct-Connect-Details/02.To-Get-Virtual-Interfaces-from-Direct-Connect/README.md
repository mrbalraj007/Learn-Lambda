# AWS Direct Connect Virtual Interface Details

A Bash script that retrieves AWS Direct Connect virtual interfaces from one or more AWS regions and combines the results in a CSV file.

## Requirements

- Bash
- AWS CLI v2, configured with credentials and a default profile (or `AWS_PROFILE`)
- `jq`
- AWS permissions for `directconnect:DescribeVirtualInterfaces`

## Run

Open a Bash-compatible shell (for example, Git Bash, WSL, or a Linux/macOS terminal), change to this directory, and run:

```bash
chmod +x get-virtual-interface-direct-connect-details.sh
./get-virtual-interface-direct-connect-details.sh
```

The script prompts for one or more AWS regions. Enter regions separated by commas or spaces. For Sydney and Melbourne, enter `ap-southeast-2,ap-southeast-4`. The script combines their results in one CSV, with a `region` column on each row. By default, it writes `direct-connect-virtual-interfaces-ap-southeast-2-ap-southeast-4.csv` in the current working directory. The filename is built from the supplied region names, joined with hyphens.

To choose a different output file, add `-o`:

```bash
./get-virtual-interface-direct-connect-details.sh -o direct-connect-virtual-interfaces.csv
```

To provide multiple regions without a prompt, use `-r` with a comma- or space-separated list in quotes:

```bash
./get-virtual-interface-direct-connect-details.sh -r "ap-southeast-2,ap-southeast-4" -o direct-connect-virtual-interfaces.csv
```

Use one region the same way: `./get-virtual-interface-direct-connect-details.sh -r ap-southeast-2`.

To see the available options, run:

```bash
./get-virtual-interface-direct-connect-details.sh -h
```

To use a named AWS CLI profile:

```bash
AWS_PROFILE=my-profile ./get-virtual-interface-direct-connect-details.sh
```

## CSV columns

The CSV columns match the virtual-interface fields: `ownerAccount`, `virtualInterfaceId`, `connectionId`, `virtualInterfaceType`, `virtualInterfaceName`, `vlan`, `asn`, `amazonSideAsn`, `amazonAddress`, `customerAddress`, `virtualInterfaceState`, `bgpStatus`, `virtualGatewayId`, `directConnectGatewayId`, `region`, and `siteLinkEnabled`. When an interface has multiple BGP peers, distinct peer statuses are combined with semicolons in the `bgpStatus` column.

If a regional AWS query fails, the script reports that region and error, keeps any results retrieved from the other regions, and exits with a nonzero status. If the output file cannot be written (for example, because it is open in another application), the script reports the error and exits. Check the AWS CLI credentials, region names, and permissions if a query fails.
