#!/bin/bash
# Script: export_cloudtrail_csv.sh
# Purpose: Export CloudTrail events to CSV with headers
# Usage: ./export_cloudtrail_csv.sh <EVENT_NAME> <REGION> <START_TIME> <END_TIME> <OUTPUT_FILE>
# Example: ./export_cloudtrail_csv.sh ModifyVolume ap-southeast-2 "2025-07-16T00:00:00Z" "2025-07-17T23:59:59Z" modifyvolume.csv
# ./export_cloudtrail_csv.sh ModifyVolume ap-southeast-2 "2025-07-16T00:00:00Z" "2025-07-17T23:59:59Z" modifyvolume.csv

EVENT_NAME=$1
REGION=$2
START_TIME=$3
END_TIME=$4
OUTPUT_FILE=$5

if [[ -z "$EVENT_NAME" || -z "$REGION" || -z "$START_TIME" || -z "$END_TIME" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: $0 <EVENT_NAME> <REGION> <START_TIME> <END_TIME> <OUTPUT_FILE>"
    exit 1
fi

echo "Exporting CloudTrail events for $EVENT_NAME from $START_TIME to $END_TIME in $REGION..."

# Write CSV headers
echo "EventTime,Username,EventName,ResourceID,SourceIP,OldIOPS,NewIOPS,OldThroughput,NewThroughput" > "$OUTPUT_FILE"

# Create a debug file with the full JSON structure of the first event
echo "Creating debug file with first event details..."
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue="$EVENT_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --region "$REGION" \
    --max-results 1 \
    --output json | jq -r '.Events[0].CloudTrailEvent | fromjson' > debug_cloudtrail_event.json
echo "Debug file created as debug_cloudtrail_event.json"

# Fetch CloudTrail events and parse JSON with the correct paths
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue="$EVENT_NAME" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --region "$REGION" \
    --output json | jq -r '
.Events[] |
  (try (.CloudTrailEvent | fromjson) catch null) as $event |
  [
    .EventTime,
    (.Username // .UserIdentity.ARN // "N/A"),
    .EventName,
    (.Resources[0].ResourceName // "N/A"),
    ($event.sourceIPAddress // "N/A"),
    ($event.responseElements.ModifyVolumeResponse.volumeModification.originalIops // "N/A"),
    ($event.requestParameters.ModifyVolumeRequest.Iops //
     $event.responseElements.ModifyVolumeResponse.volumeModification.targetIops // "N/A"),
    ($event.responseElements.ModifyVolumeResponse.volumeModification.originalThroughput // "N/A"),
    ($event.requestParameters.ModifyVolumeRequest.Throughput //
     $event.responseElements.ModifyVolumeResponse.volumeModification.targetThroughput // "N/A")
  ] | @csv
' >> "$OUTPUT_FILE"

echo "Export completed! CSV saved as $OUTPUT_FILE"
echo "Check debug_cloudtrail_event.json to see the structure of a CloudTrail event"
echo "Check debug_cloudtrail_event.json to see the structure of a CloudTrail event"
     $event.responseElements.modifyVolumeResponse.volumeModification.targetIops //
     $event.requestParameters.ModifyVolumeRequest.Iops // "N/A"),
    ($event.responseElements.volumeModification.originalThroughput // 
     $event.responseElements.modification.originalThroughput // 
     $event.responseElements.modifyVolumeResponse.volumeModification.originalThroughput //
     $event.responseElements.originalThroughput //
     $event.responseElements.originalConfiguration.throughput //
     $event.requestParameters.PreviousThroughput // 
     $event.requestParameters.previousThroughput // "N/A"),
    ($event.requestParameters.Throughput // 
     $event.requestParameters.throughput // 
     $event.responseElements.volumeModification.targetThroughput //
     $event.responseElements.modification.targetThroughput //
     $event.responseElements.modifyVolumeResponse.volumeModification.targetThroughput //
     $event.requestParameters.ModifyVolumeRequest.Throughput // "N/A")
  ] | @csv
' >> $OUTPUT_FILE

echo "Export completed! CSV saved as $OUTPUT_FILE"
echo "Check debug_cloudtrail_event.json to see the structure of a CloudTrail event"
