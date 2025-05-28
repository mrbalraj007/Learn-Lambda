#####################################################################
#  ___  ___   ___   ___                        _          _       
# | _ \|   \ / __| / __| _ _   __ _  _ __  ___| |_   ___ | |_  ___
# |   /| |) |\__ \ \__ \| ' \ / _` || '_ \(_-<| ' \ / _ \|  _|(_-<
# |_|_\|___/ |___/ |___/|_||_|\__,_|| .__//__/|_||_|\___/ \__|/__/
#                                   |_|                           
#
# To learn more, see https://maxat-akbanov.com/                                
#####################################################################

#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)

REGION=$(aws configure get region)

# Define the threshold (in days) for identifying "old" RDS snapshots
THRESHOLD_DAYS=30

log_info "Checking for old RDS snapshots (older than $THRESHOLD_DAYS days) in $REGION"
echo "--------------------------------------------------------------------------------"

# Convert the threshold (30 days ago) to an ISO8601 formatted date
# The 'date' command with -u ensures UTC time, and -d calculates the date $THRESHOLD_DAYS ago
# The output is formatted as YYYY-MM-DDTHH:MM:SSZ (ISO8601)
cutoff_date=$(date -u -d "$THRESHOLD_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")

# Retrieve details of RDS snapshots older than the cutoff date
# The 'aws rds describe-db-snapshots' command queries RDS snapshot information
# --query filters snapshots where SnapshotCreateTime is earlier than cutoff_date
# The query extracts DBSnapshotIdentifier, DBInstanceIdentifier, SnapshotCreateTime, and SnapshotType
snapshots=$(aws rds describe-db-snapshots \
  --query "DBSnapshots[?SnapshotCreateTime<'$cutoff_date'].[DBSnapshotIdentifier,DBInstanceIdentifier,SnapshotCreateTime,SnapshotType]" \
  --output json)

# Check if no snapshots were found (snapshots is empty or an empty array "[]")
if [ -z "$snapshots" ] || [ "$snapshots" == "[]" ]; then
  log_success "♻️  No RDS snapshots older than $THRESHOLD_DAYS days."
  exit 0
fi

# Parse the snapshots JSON and format the output using jq
# For each snapshot, print a warning with details:
# - .0: DBSnapshotIdentifier (snapshot name)
# - .1: DBInstanceIdentifier (associated RDS instance)
# - .2: SnapshotCreateTime (creation timestamp)
# - .3: SnapshotType (e.g., manual or automated)
echo "$snapshots" | jq -r '.[] | 
  "⚠️  Snapshot: \(.0)\n    Instance: \(.1)\n     Created: \(.2)\n     Type: \(.3)\n"'