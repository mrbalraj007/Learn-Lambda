#!/usr/bin/env bash

# Usage:
#   ./get_appstream_report.sh [-p aws_profile] [-r aws_region] [-o output.csv]
#
# Examples:
#   ./get_appstream_report.sh
#   ./get_appstream_report.sh -p myprofile -r us-east-1 -o report.csv

set -o pipefail

PROFILE_OPT=()
REGION_OPT=()
OUTFILE="appstream_report.csv"

while getopts "p:r:o:" opt; do
  case "$opt" in
    p) PROFILE_OPT=(--profile "$OPTARG") ;;
    r) REGION_OPT=(--region "$OPTARG") ;;
    o) OUTFILE="$OPTARG" ;;
    *) echo "Usage: $0 [-p profile] [-r region] [-o output.csv]" >&2; exit 1 ;;
  esac
done

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found. Install and configure AWS CLI." >&2
  exit 1
fi

csv_escape() {
  # CSV-escape a single field
  local s="${1-}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

# Write header
echo "Stack name,Fleet,Fleet Status,ImageName" > "$OUTFILE"

# List all stacks
stacks=$(aws appstream describe-stacks "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
  --query "Stacks[].Name" --output text 2>/dev/null) || {
    echo "Failed to list AppStream stacks." >&2
    exit 1
  }

# Iterate stacks (AppStream names are no-space identifiers)
for stack in $stacks; do
  fleets=$(aws appstream list-associated-fleets --stack-name "$stack" "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
    --query "Names[]" --output text 2>/dev/null) || {
      echo "Warning: unable to list fleets for stack $stack" >&2
      continue
    }

  # Skip stacks with no associated fleets
  [ -z "$fleets" ] && continue

  for fleet in $fleets; do
    # Get fleet details
    read -r f_name f_state f_image < <(aws appstream describe-fleets --names "$fleet" "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
      --query "Fleets[0].[Name,State,ImageName]" --output text 2>/dev/null)

    # If describe failed, skip
    [ -z "$f_name" ] && continue

    # Emit CSV row
    echo "$(csv_escape "$stack"),$(csv_escape "$f_name"),$(csv_escape "$f_state"),$(csv_escape "$f_image")" >> "$OUTFILE"
  done
done

echo "Done. Wrote: $OUTFILE"
