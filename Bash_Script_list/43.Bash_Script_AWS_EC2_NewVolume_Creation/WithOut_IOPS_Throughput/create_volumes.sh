#!/bin/bash

# Input and output CSV files
INPUT_FILE="volumes.csv"
OUTPUT_FILE="created_volumes.csv"
FIXED_AZ="ap-southeast-2c"

# Write CSV header to output file
echo "VolumeId,AvailabilityZone,Size,VolumeType,Encrypted,State,TagName" > "$OUTPUT_FILE"

# Skip header and loop through each line in the input CSV
tail -n +2 "$INPUT_FILE" | while IFS=',' read -r SIZE VTYPE ENCRYPTED TAGNAME; do
    
    echo "Creating EBS Volume in $FIXED_AZ | Size: ${SIZE}GiB | Type: $VTYPE | Encrypted: $ENCRYPTED | Tag: $TAGNAME"

    # Normalize ENCRYPTED value (lowercase)
    ENC_LOWER=$(echo "$ENCRYPTED" | tr '[:upper:]' '[:lower:]')

    # Build encryption flag
    if [[ "$ENC_LOWER" == "true" ]]; then
        ENC_FLAG="--encrypted"
    else
        ENC_FLAG=""
    fi

    # Create the volume
    VOLUME_JSON=$(aws ec2 create-volume \
        --availability-zone "$FIXED_AZ" \
        --size "$SIZE" \
        --volume-type "$VTYPE" \
        $ENC_FLAG \
        --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=$TAGNAME}]" \
        --output json)

    # Extract details
    VOLUME_ID=$(echo "$VOLUME_JSON" | jq -r '.VolumeId')
    STATE=$(echo "$VOLUME_JSON" | jq -r '.State')

    # Append details to output CSV
    echo "$VOLUME_ID,$FIXED_AZ,$SIZE,$VTYPE,$ENC_LOWER,$STATE,$TAGNAME" >> "$OUTPUT_FILE"

done
echo "Volume creation process completed. Details saved in $OUTPUT_FILE."