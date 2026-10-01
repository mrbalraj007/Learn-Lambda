#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: get-direct-connect-details.sh [-o output.csv] [-r region]

Prompts for an AWS region (unless -r is supplied), queries its Direct Connect
connections, and writes the results to a CSV file.

Options:
  -o, --output FILE   Output file (default: direct-connect-REGION.csv)
  -r, --region REGION Use this region without prompting
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

if [[ -n "$requested_region" ]]; then
  regions="$requested_region"
else
  read -r -p "Enter AWS region (for example, us-east-1): " requested_region
  regions="$requested_region"
fi

if [[ -z "$regions" ]]; then
  echo "AWS region is required." >&2
  exit 1
fi

if [[ -z "$output_file" ]]; then
  output_file="direct-connect-${requested_region}.csv"
fi

temporary_file="${output_file}.tmp.$$"
trap 'rm -f "$temporary_file"' EXIT

printf '%s\n' 'ownerAccount,connectionId,connectionName,connectionState,region,location,bandwidth,providerName,partnerName,vlan,awsDevice,awsDeviceV2,jumboFrameCapable,hasLogicalRedundancy,macSecCapable,portEncryptionStatus,encryptionMode' > "$temporary_file"

query_failed=0
for region in $regions; do
  if ! response=$(aws directconnect describe-connections --region "$region" --output json 2>&1); then
    echo "Warning: unable to query Direct Connect in $region: $response" >&2
    query_failed=1
    continue
  fi

  if ! printf '%s' "$response" | jq -r --arg region "$region" '
    .connections[]? |
    [
      (.ownerAccount // ""),
      (.connectionId // ""),
      (.connectionName // ""),
      (.connectionState // ""),
      $region,
      (.location // ""),
      (.bandwidth // ""),
      (.providerName // ""),
      (.partnerName // ""),
      (.vlan // ""),
      (.awsDevice // ""),
      (.awsDeviceV2 // ""),
      (.jumboFrameCapable // ""),
      (.hasLogicalRedundancy // ""),
      (.macSecCapable // ""),
      (.portEncryptionStatus // ""),
      (.encryptionMode // "")
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