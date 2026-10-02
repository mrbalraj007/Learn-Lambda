#!/usr/bin/env bash
#
# ec2-volume-report.sh
# One row per EBS volume attached to each EC2 instance, with instance details.
#
# Columns:
#   Instance Name, Instance ID, Power State, Public IP, Private IP,
#   Volume ID, Device Name, Volume Size (GiB), Volume State,
#   Attachment Status, Attachment Time, Encrypted, KMS Key ID
#
# Requires: aws cli (v1 or v2), jq
#
# Usage:
#   ./ec2-volume-report.sh                         # default profile/region
#   ./ec2-volume-report.sh -r ap-southeast-2       # specific region
#   ./ec2-volume-report.sh -p prod -r ap-southeast-2 -o prod_volumes.csv
#   ./ec2-volume-report.sh -r ap-southeast-2 -i i-0abc123,i-0def456

set -euo pipefail

REGION=""
PROFILE=""
INSTANCE_IDS=""
OUTPUT_FILE="ec2_volume_report_$(date +%Y%m%d_%H%M%S).csv"

usage() {
  cat <<EOF
Usage: $0 [-r region] [-p profile] [-i id1,id2,...] [-o output.csv]

  -r  AWS region (defaults to your CLI config / AWS_REGION)
  -p  AWS CLI profile
  -i  Comma-separated instance IDs (defaults to all instances)
  -o  CSV output file (default: $OUTPUT_FILE)
EOF
  exit 1
}

while getopts "r:p:i:o:h" opt; do
  case "$opt" in
    r) REGION="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    i) INSTANCE_IDS="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    *) usage ;;
  esac
done

for cmd in aws jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' is not installed or not in PATH." >&2; exit 1; }
done

AWS_ARGS=(--output json)
[[ -n "$PROFILE" ]] && AWS_ARGS+=(--profile "$PROFILE")
[[ -n "$REGION"  ]] && AWS_ARGS+=(--region "$REGION")

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Fetching EC2 instances..." >&2
INSTANCE_FILTER=()
if [[ -n "$INSTANCE_IDS" ]]; then
  IFS=',' read -r -a ID_ARRAY <<< "$INSTANCE_IDS"
  INSTANCE_FILTER=(--instance-ids "${ID_ARRAY[@]}")
fi

aws ec2 describe-instances "${AWS_ARGS[@]}" "${INSTANCE_FILTER[@]}" \
  --query 'Reservations[].Instances[]' > "$TMP_DIR/instances.json"

echo "Fetching EBS volumes..." >&2
aws ec2 describe-volumes "${AWS_ARGS[@]}" \
  --query 'Volumes[]' > "$TMP_DIR/volumes.json"

# Header row
HEADER='"Instance Name","Instance ID","Power State","Public IP","Private IP","Volume ID","Device Name","Volume Size (GiB)","Volume State","Attachment Status","Attachment Time","Encrypted","KMS Key ID"'

{
  echo "$HEADER"
  jq -r --slurpfile vols "$TMP_DIR/volumes.json" '
    # null -> "", everything else -> string (keeps boolean false intact)
    def s: if . == null then "" else tostring end;

    ($vols[0]) as $V
    | .[] as $i
    | ($i.Tags // [] | map(select(.Key == "Name") | .Value) | .[0] // "") as $name
    | [ $V[] as $vol
        | ($vol.Attachments // [])[]
        | select(.InstanceId == $i.InstanceId)
        | { vol: $vol, att: . } ] as $rows
    # Instances with no EBS volumes still get one row
    | ($rows | if length == 0 then [null] else . end)[]
    | [ $name,
        $i.InstanceId,
        $i.State.Name,
        ($i.PublicIpAddress  | s),
        ($i.PrivateIpAddress | s),
        (.vol.VolumeId   | s),
        (.att.Device     | s),
        (.vol.Size       | s),
        (.vol.State      | s),
        (.att.State      | s),
        (.att.AttachTime | s),
        (.vol.Encrypted  | s),
        (.vol.KmsKeyId   | s | sub("^.*key/"; ""))
      ] | @csv
  ' "$TMP_DIR/instances.json"
} > "$OUTPUT_FILE"

ROWS=$(( $(wc -l < "$OUTPUT_FILE") - 1 ))
echo "Done. $ROWS volume row(s) written to: $OUTPUT_FILE" >&2

# Quick preview in the terminal (comma-separated -> aligned columns)
if command -v column >/dev/null 2>&1; then
  echo >&2
  sed 's/","/"|"/g; s/"//g' "$OUTPUT_FILE" | column -s '|' -t >&2
fi
