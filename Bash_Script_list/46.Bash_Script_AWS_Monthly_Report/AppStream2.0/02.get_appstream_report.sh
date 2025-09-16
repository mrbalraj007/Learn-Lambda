#!/usr/bin/env bash

# Usage:
#   ./get_appstream_report.sh [-p aws_profile] [-r aws_region] [-o output.csv] [-P profiles_file] [-i]
#     -p profile        Use a single AWS profile (overrides profiles file)
#     -r region         AWS region (e.g., ap-southeast-2)
#     -o output.csv     Output CSV file
#     -P profiles_file  Path to profiles file (default: profiles.txt)
#     -i                Include Profile column in the CSV
#
# Examples:
#   ./get_appstream_report.sh
#   ./get_appstream_report.sh -r ap-southeast-2 -i
#   ./get_appstream_report.sh -p account613428962328 -o report.csv

set -o pipefail

PROFILE_OPT=()
REGION_OPT=()
OUTFILE="appstream_report.csv"

# New options
PROFILES_FILE="profiles.txt"
INCLUDE_PROFILE=0
SINGLE_PROFILE=""

# Parse options (added -P and -i)
while getopts "p:r:o:P:i" opt; do
  case "$opt" in
    p) SINGLE_PROFILE="$OPTARG" ;;
    r) REGION_OPT=(--region "$OPTARG") ;;
    o) OUTFILE="$OPTARG" ;;
    P) PROFILES_FILE="$OPTARG" ;;
    i) INCLUDE_PROFILE=1 ;;
    *) echo "Usage: $0 [-p profile] [-r region] [-o output.csv] [-P profiles_file] [-i]" >&2; exit 1 ;;
  esac
done

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found. Install and configure AWS CLI." >&2
  exit 1
fi

# Determine profiles to iterate
PROFILES=()
if [ -n "$SINGLE_PROFILE" ]; then
  PROFILES+=("$SINGLE_PROFILE")
elif [ -f "$PROFILES_FILE" ]; then
  while IFS= read -r line; do
    line="$(echo "$line" | tr -d '\r' | xargs)"
    [ -n "$line" ] && PROFILES+=("$line")
  done < "$PROFILES_FILE"
fi
# If no profiles found, use default (no --profile)
if [ ${#PROFILES[@]} -eq 0 ]; then
  PROFILES+=("")
fi

csv_escape() {
  # CSV-escape a single field
  local s="${1-}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

# Write header (optionally include Profile column)
if [ "$INCLUDE_PROFILE" -eq 1 ]; then
  echo "Profile,Stack name,Fleet,Fleet Status,ImageName,ActiveSessions" > "$OUTFILE"
else
  echo "Stack name,Fleet,Fleet Status,ImageName,ActiveSessions" > "$OUTFILE"
fi

# Iterate profiles, then stacks/fleets
for profile in "${PROFILES[@]}"; do
  if [ -n "$profile" ]; then
    PROFILE_OPT=(--profile "$profile")
    echo "Processing profile: $profile" >&2
  else
    PROFILE_OPT=()
    echo "Processing default profile" >&2
  fi

  # List all stacks
  stacks=$(aws appstream describe-stacks "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
    --query "Stacks[].Name" --output text 2>/dev/null) || {
      echo "Failed to list AppStream stacks for profile '${profile:-default}'." >&2
      continue
    }

  # Iterate stacks (AppStream names are no-space identifiers)
  for stack in $stacks; do
    fleets=$(aws appstream list-associated-fleets --stack-name "$stack" "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
      --query "Names[]" --output text 2>/dev/null) || {
        echo "Warning: unable to list fleets for stack $stack (profile '${profile:-default}')" >&2
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

      # Count active user sessions for this stack/fleet
      active_sessions=$(aws appstream describe-sessions \
        --stack-name "$stack" --fleet-name "$fleet" \
        "${PROFILE_OPT[@]}" "${REGION_OPT[@]}" \
        --query 'length(Sessions[?State==`ACTIVE`])' --output text 2>/dev/null) || active_sessions=""
      [ -z "$active_sessions" ] && active_sessions=0

      # Emit CSV row (include profile if requested)
      if [ "$INCLUDE_PROFILE" -eq 1 ]; then
        echo "$(csv_escape "${profile:-default}"),$(csv_escape "$stack"),$(csv_escape "$f_name"),$(csv_escape "$f_state"),$(csv_escape "$f_image"),$active_sessions" >> "$OUTFILE"
      else
        echo "$(csv_escape "$stack"),$(csv_escape "$f_name"),$(csv_escape "$f_state"),$(csv_escape "$f_image"),$active_sessions" >> "$OUTFILE"
      fi
    done
  done
done

echo "Done. Wrote: $OUTFILE"
