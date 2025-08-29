#!/bin/bash

# Output file
output="ec2-list.csv"

# Write CSV header
echo "Name,InstanceId" > "$output"

# Loop through names in file (trim CRLF, skip blanks/comments)
while IFS= read -r name || [[ -n "$name" ]]; do
  name="${name%%[$'\r\n']}"           # strip trailing CR/LF (Windows line endings)
  [[ -z "$name" || "$name" =~ ^# ]] && continue

  # Exact, case-sensitive match against the Name tag
  result=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$name" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], InstanceId]" \
    --output text)

  if [[ -n "$result" ]]; then
    echo "$result" | awk '{print $1","$2}' >> "$output"
  else
    echo "$name,NOT_FOUND" >> "$output"
  fi
done < ec2-names.txt

