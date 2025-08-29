#!/bin/bash

# Script to check Schedule tag values for EC2 instances listed in a CSV file
# Usage: ./check_ec2_schedule_tags.sh <csv_file_path> [instance_id_column_number]
# To include instances without Schedule tags: (./check_ec2_schedule_tags.sh sample_instances.csv --all)
# To specify a different column for instance IDs: (./check_ec2_schedule_tags.sh sample_instances.csv 2)

# Function to display usage information
usage() {
    echo "Usage: $0 <csv_file_path> [instance_id_column_number] [--all]"
    echo "  csv_file_path: Path to CSV file containing EC2 instance IDs"
    echo "  instance_id_column_number: Column number containing instance IDs (default: 1)"
    echo "  --all: Optional flag to include instances without Schedule tag (default: only instances with Schedule tag)"
    exit 1
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found. Please install it first."
    exit 1
fi

# Check if input file is provided
if [ $# -lt 1 ]; then
    usage
fi

CSV_FILE="$1"
COLUMN_NUM=1  # Default column number
SHOW_ALL=false

# Parse arguments
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --all)
            SHOW_ALL=true
            ;;
        *)
            COLUMN_NUM="$1"
            ;;
    esac
    shift
done

# Check if file exists and is readable
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: File '$CSV_FILE' not found."
    exit 1
fi

if [ ! -r "$CSV_FILE" ]; then
    echo "Error: Cannot read file '$CSV_FILE'. Check permissions."
    exit 1
fi

# Create output file
OUTPUT_FILE="ec2_schedule_tags_$(date +%Y%m%d_%H%M%S).csv"
echo "Instance ID,Instance Name,Schedule Tag Value" > "$OUTPUT_FILE"

echo "Processing EC2 instances from $CSV_FILE..."

# Process each line in the CSV file
while IFS=, read -r -a columns || [[ -n "$columns" ]]; do
    # Skip empty lines
    if [ ${#columns[@]} -eq 0 ]; then
        continue
    fi
    
    # Check if column number is valid
    if [ $COLUMN_NUM -gt ${#columns[@]} ]; then
        continue
    fi
    
    # Get instance ID from specified column (adjust for 0-based array)
    instance_id="${columns[$((COLUMN_NUM-1))]}"
    
    # Remove any whitespace and quotes from instance_id
    instance_id=$(echo "$instance_id" | tr -d '[:space:]"')
    
    # Skip if instance_id is empty or header
    if [ -z "$instance_id" ] || [ "$instance_id" == "Instance ID" ] || [ "$instance_id" == "InstanceID" ]; then
        continue
    fi
    
    # Check if instance_id follows EC2 instance ID format (i-followed by alphanumeric)
    if [[ ! "$instance_id" =~ ^i-[a-zA-Z0-9]+$ ]]; then
        echo "Warning: '$instance_id' does not appear to be a valid EC2 instance ID. Skipping."
        continue
    fi
    
    echo "Checking instance $instance_id..."
    
    # Get instance Name tag
    instance_name=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name" --query "Tags[0].Value" --output text 2>/dev/null)
    if [ "$instance_name" == "None" ]; then
        instance_name="Unnamed"
    fi
    
    # Get Schedule tag value for the instance
    schedule_tag=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Schedule" --query "Tags[0].Value" --output text 2>/dev/null)
    
    # Check if tag exists
    if [ "$schedule_tag" == "None" ] || [ -z "$schedule_tag" ]; then
        if [ "$SHOW_ALL" = true ]; then
            schedule_tag="No Schedule tag found"
            echo "$instance_id,$instance_name,$schedule_tag" >> "$OUTPUT_FILE"
        fi
    else
        # Only output instances that have a Schedule tag
        echo "$instance_id,$instance_name,$schedule_tag" >> "$OUTPUT_FILE"
    fi
    
done < "$CSV_FILE"

echo "Processing complete. Results saved to $OUTPUT_FILE"

# Summary statistics
total_with_schedule=$(grep -v "^Instance ID" "$OUTPUT_FILE" | wc -l)
echo "Total instances with Schedule tag: $total_with_schedule"
if [ "$SHOW_ALL" = true ]; then
    total_without_schedule=$(grep "No Schedule tag found" "$OUTPUT_FILE" | wc -l)
    echo "Total instances without Schedule tag: $total_without_schedule"
fi
