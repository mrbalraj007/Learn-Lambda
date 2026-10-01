#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: get-virtual-interface-direct-connect-details.sh [-o output.csv] [-r "region1,region2"]

Prompts for AWS regions (unless -r is supplied), queries Direct Connect
virtual interfaces in each region, and writes all results to one CSV file.

Options:
  -o, --output FILE   Output file (default: direct-connect-virtual-interfaces-REGION-LIST.csv)
  -r, --region LIST   Comma- or space-separated regions; skips the prompt
  -h, --help          Show this help

Requirements: AWS CLI v2, jq, and AWS credentials with Direct Connect read
access.
USAGE
}

output_file=""
requested_region=""

while (($#)); do
  case "$1" in
    -o|--output)
      if (($# < 2)); then
        echo "Missing value for $1" >&2
        usage >&2
        exit 2
      fi
      output_file="$2"
      shift 2
      ;;
    -r|--region)
      if (($# < 2)); then
        echo "Missing value for $1" >&2
        usage >&2
        exit 2
      fi
      requested_region="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for command_name in aws jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ -z "$requested_region" ]]; then
  read -r -p "Enter AWS region(s), comma- or space-separated (for example, ap-southeast-2,ap-southeast-4): " requested_region
fi

requested_regions="${requested_region//,/ }"
read -r -a regions <<< "$requested_regions"

if ((${#regions[@]} == 0)); then
  echo "At least one AWS region is required." >&2
  exit 1
fi

for region in "${regions[@]}"; do
  if [[ ! "$region" =~ ^[a-z0-9-]+$ ]]; then
    echo "Invalid AWS region name: $region" >&2
    exit 2
  fi
done

if [[ -z "$output_file" ]]; then
  region_suffix=$(IFS=-; printf '%s' "${regions[*]}")
  output_file="direct-connect-virtual-interfaces-${region_suffix}.csv"
fi

temporary_file="${output_file}.tmp.$$"
trap 'rm -f "$temporary_file"' EXIT

printf '%s\n' 'ownerAccount,virtualInterfaceId,connectionId,virtualInterfaceType,virtualInterfaceName,vlan,asn,amazonSideAsn,amazonAddress,customerAddress,virtualInterfaceState,bgpStatus,virtualGatewayId,directConnectGatewayId,region,siteLinkEnabled' > "$temporary_file"

query_failed=0
for region in "${regions[@]}"; do
  if ! response=$(aws directconnect describe-virtual-interfaces --region "$region" --output json 2>&1); then
    echo "Warning: unable to query Direct Connect in $region: $response" >&2
    query_failed=1
    continue
  fi

  if ! printf '%s' "$response" | jq -r --arg region "$region" '
    .virtualInterfaces[]? |
    [
      (.ownerAccount // ""),
      (.virtualInterfaceId // ""),
      (.connectionId // ""),
      (.virtualInterfaceType // ""),
      (.virtualInterfaceName // ""),
      (.vlan // ""),
      (.asn // ""),
      (.amazonSideAsn // ""),
      (.amazonAddress // ""),
      (.customerAddress // ""),
      (.virtualInterfaceState // ""),
      ([.bgpPeers[]?.bgpStatus // empty] | unique | join(";")),
      (.virtualGatewayId // ""),
      (.directConnectGatewayId // ""),
      $region,
      (.siteLinkEnabled // "")
    ] | @csv
  ' >> "$temporary_file"; then
    echo "Warning: could not parse Direct Connect response in $region." >&2
    query_failed=1
  fi
done

if ! mv "$temporary_file" "$output_file"; then
  echo "Unable to write CSV to: $output_file" >&2
  exit 1
fi
trap - EXIT
echo "CSV written to: $output_file"

if ((query_failed)); then
  echo "Some regions could not be queried; the CSV may be incomplete." >&2
  exit 1
fi