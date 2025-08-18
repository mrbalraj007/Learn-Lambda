#!/bin/bash

# EC2 CloudTrail Audit Script
# This script audits CloudTrail logs for EC2 instance activities
# in the last 72 hours, focusing on stop and terminate actions.

#Create a CSV file with EC2 instance IDs (one per line)
#Make the script executable: chmod +x ec2_cloudtrail_audit.sh
#Run the script: ./ec2_cloudtrail_audit.sh input.csv output.csv

set -e

# Check if required tools are installed
command -v aws >/dev/null 2>&1 || { echo "Error: AWS CLI is required but not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Aborting."; exit 1; }

# Check for input arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_csv_file> <output_csv_file>"
    echo "  <input_csv_file>: CSV file containing EC2 instance IDs (one per line)"
    echo "  <output_csv_file>: CSV file where results will be written"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_FILE=$2

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE does not exist."
    exit 1
fi

# Calculate timestamp for 72 hours ago (in UTC)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    START_TIME=$(date -u -v-72H "+%Y-%m-%dT%H:%M:%SZ")
    END_TIME=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
else
    # Linux
    START_TIME=$(date -u -d "72 hours ago" "+%Y-%m-%dT%H:%M:%SZ")
    END_TIME=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
fi

echo "Searching CloudTrail events from $START_TIME to $END_TIME"

# Initialize output file with headers
echo "InstanceID,EventTime,EventName,UserName,UserType,SourceIP,UserAgent,EventSource,Region" > "$OUTPUT_FILE"

# Create a temporary directory for our files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Count total instances for progress reporting
TOTAL_INSTANCES=$(grep -v "^$" "$INPUT_FILE" | wc -l)
CURRENT_INSTANCE=0
EVENTS_FOUND=0

echo "Processing $TOTAL_INSTANCES EC2 instances..."

# Process each instance ID in the input file
while IFS=, read -r instance_id || [[ -n "$instance_id" ]]; do
    # Skip empty lines and trim whitespace
    instance_id=$(echo "$instance_id" | tr -d '[:space:]')
    if [ -z "$instance_id" ]; then
        continue
    fi
    
    # Skip header row if present
    if [[ "$instance_id" == "InstanceID" || "$instance_id" == "instance-id" ]]; then
        continue
    fi
    
    CURRENT_INSTANCE=$((CURRENT_INSTANCE + 1))
    echo "[$CURRENT_INSTANCE/$TOTAL_INSTANCES] Processing EC2 instance: $instance_id"
    
    # Query CloudTrail logs for this instance
    echo "  Querying CloudTrail logs..."
    aws cloudtrail lookup-events \
        --lookup-attributes AttributeKey=ResourceName,AttributeValue="$instance_id" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --output json > "$TEMP_DIR/cloudtrail_events_$instance_id.json"
    
    # Check if any events were found
    event_count=$(jq '.Events | length' "$TEMP_DIR/cloudtrail_events_$instance_id.json")
    if [ "$event_count" -eq 0 ]; then
        echo "  No CloudTrail events found for instance $instance_id in the specified time range."
        continue
    fi
    
    echo "  Found $event_count events. Filtering for stop and terminate actions..."
    
    # Process each event and filter for stop and terminate events
    jq -c '.Events[]' "$TEMP_DIR/cloudtrail_events_$instance_id.json" | while read -r event; do
        event_name=$(echo "$event" | jq -r '.EventName')
        
        # Check if this event is a stop or terminate action
        if [[ "$event_name" == *"StopInstances"* || "$event_name" == *"TerminateInstances"* ]]; then
            event_time=$(echo "$event" | jq -r '.EventTime')
            user_name=$(echo "$event" | jq -r '.Username // "NA"')
            
            # Extract the CloudTrail event details
            cloud_trail_event=$(echo "$event" | jq -r '.CloudTrailEvent')
            
            # Extract additional details
            user_type=$(echo "$cloud_trail_event" | jq -r 'try .userIdentity.type catch "NA"')
            source_ip=$(echo "$cloud_trail_event" | jq -r 'try .sourceIPAddress catch "NA"')
            user_agent=$(echo "$cloud_trail_event" | jq -r 'try .userAgent catch "NA"')
            event_source=$(echo "$cloud_trail_event" | jq -r 'try .eventSource catch "NA"')
            region=$(echo "$cloud_trail_event" | jq -r 'try .awsRegion catch "NA"')
            
            # Escape any commas in fields to prevent CSV corruption
            user_name=$(echo "$user_name" | sed 's/,/\\,/g')
            user_agent=$(echo "$user_agent" | sed 's/,/\\,/g')
            
            # Write to output CSV
            echo "$instance_id,$event_time,$event_name,$user_name,$user_type,$source_ip,$user_agent,$event_source,$region" >> "$OUTPUT_FILE"
            
            echo "  ✓ Found $event_name event on $event_time by $user_name"
            EVENTS_FOUND=$((EVENTS_FOUND + 1))
        fi
    done
    
    echo "  Completed processing for $instance_id"
done < "$INPUT_FILE"

# Print summary
echo "========================================================"
echo "Audit completed. Results saved to $OUTPUT_FILE"
echo "Processed $TOTAL_INSTANCES EC2 instances"
echo "Found $EVENTS_FOUND stop/terminate events"
echo "========================================================"

exit 0
