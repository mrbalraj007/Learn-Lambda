#!/bin/bash

COST_PER_GB=0.095

# Check if bc is installed
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' is required but not installed. Install it using your package manager (e.g., sudo apt install bc)."
    exit 1
fi

echo "Fetching all manual RDS snapshots..."
echo ""

SNAPSHOTS=$(aws rds describe-db-snapshots \
  --snapshot-type manual \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier, DBInstanceIdentifier, AllocatedStorage]' \
  --output text)

TOTAL_STORAGE=0
TOTAL_COST=0

printf "%-50s %-30s %-10s %-10s\n" "SnapshotIdentifier" "DBInstanceIdentifier" "Size(GB)" "Monthly($)"

while read -r SNAPSHOT_ID DB_INSTANCE_ID SIZE; do
  if [[ "$SIZE" =~ ^[0-9]+$ ]]; then
    COST=$(echo "$SIZE * $COST_PER_GB" | bc)
    printf "%-50s %-30s %-10s %-10.2f\n" "$SNAPSHOT_ID" "$DB_INSTANCE_ID" "$SIZE" "$COST"
    TOTAL_STORAGE=$((TOTAL_STORAGE + SIZE))
    TOTAL_COST=$(echo "$TOTAL_COST + $COST" | bc)
  fi
done <<< "$SNAPSHOTS"

echo ""
echo "--------------------------------------------------------------"
echo "Total Snapshot Storage: $TOTAL_STORAGE GB"
echo "Estimated Monthly Snapshot Cost: \$${TOTAL_COST}"
