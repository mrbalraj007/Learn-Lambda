#!/bin/bash
# filepath: c:\MY_DevOps_Journey\Learn-Lambda\Bash_Script_list\21.Bash_Script_AWS_S3_Details\get_s3_bucket_tags.sh

# Script to extract AWS S3 bucket tags and export to CSV
# Default region: ap-southeast-2

# Function to display usage information
usage() {
    echo "Usage: $0 [-b BUCKET_NAME1,BUCKET_NAME2,...] [-a] [-t TAG_KEY1,TAG_KEY2,...] [-r REGION] [-o OUTPUT_DIR]"
    echo ""
    echo "Options:"
    echo "  -b BUCKET_NAMES    Comma-separated list of S3 bucket names"
    echo "  -a                 Process all buckets in the region"
    echo "  -t TAG_KEYS        Comma-separated list of tag keys to filter (optional)"
    echo "  -r REGION          AWS region (default: ap-southeast-2)"
    echo "  -o OUTPUT_DIR      Output directory for CSV files (default: current directory)"
    echo "  -h                 Display this help message"
    echo ""
    echo "Note: Either -b or -a must be specified"
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to get AWS account ID and create display name
get_account_info() {
    local account_id
    account_id=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$account_id" ]; then
        echo "AWS-Account-${account_id}"
    else
        echo "Unknown-Account"
    fi
}

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to properly format CSV values
csv_escape() {
    local value="$1"
    # Replace double quotes with double double quotes
    value="${value//\"/\"\"}"
    # If value contains comma, newline, or double quote, enclose in quotes
    if [[ $value =~ [,\"\n] ]]; then
        value="\"$value\""
    fi
    echo "$value"
}

# Function to process a single bucket
process_bucket() {
    local bucket_name="$1"
    local output_file="$2"
    local account_display_name="$3"
    local timestamp="$4"
    
    echo "Retrieving tags for bucket: $bucket_name in region: $REGION"
    TAGS_RESULT=$(aws s3api get-bucket-tagging --bucket "$bucket_name" --region "$REGION" 2>&1)
    RESULT_CODE=$?

    # Check if the command was successful
    if [ $RESULT_CODE -ne 0 ]; then
        if [[ "$TAGS_RESULT" == *"NoSuchTagSet"* ]]; then
            echo "No tags found for bucket $bucket_name"
            # Add a row with bucket name but no tags
            ESCAPED_BUCKET=$(csv_escape "$bucket_name")
            ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
            ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
            echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},No tags,No tags" >> "$output_file"
            return 0
        else
            echo "Error retrieving tags for bucket $bucket_name: $TAGS_RESULT"
            return 1
        fi
    fi

    # Process tags
    # Process the tags based on available tools
    if $JQ_AVAILABLE; then
        # Using jq for better handling
        if [[ -n "$TAG_KEYS" ]]; then
            # Filter by specific tag keys
            IFS=',' read -ra TAG_KEY_ARRAY <<< "$TAG_KEYS"
            for TAG_KEY in "${TAG_KEY_ARRAY[@]}"; do
                TAG_VALUE=$(echo "$TAGS_RESULT" | jq -r --arg tk "$TAG_KEY" '.TagSet[] | select(.Key == $tk) | .Value' 2>/dev/null)
                if [[ -n "$TAG_VALUE" && "$TAG_VALUE" != "null" ]]; then
                    ESCAPED_BUCKET=$(csv_escape "$bucket_name")
                    ESCAPED_KEY=$(csv_escape "$TAG_KEY")
                    ESCAPED_VALUE=$(csv_escape "$TAG_VALUE")
                    ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
                    ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
                    echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},${ESCAPED_KEY},${ESCAPED_VALUE}" >> "$output_file"
                fi
            done
        else
            # Extract all tags
            TAG_COUNT=$(echo "$TAGS_RESULT" | jq -r '.TagSet | length')
            if [ "$TAG_COUNT" -eq 0 ]; then
                # No tags - add a row indicating that
                ESCAPED_BUCKET=$(csv_escape "$bucket_name")
                ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
                ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
                echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},No tags,No tags" >> "$output_file"
            else
                while read -r pair; do
                    if [[ -n "$pair" ]]; then
                        KEY=$(echo "$pair" | jq -r '.Key')
                        VALUE=$(echo "$pair" | jq -r '.Value')
                        
                        ESCAPED_BUCKET=$(csv_escape "$bucket_name")
                        ESCAPED_KEY=$(csv_escape "$KEY")
                        ESCAPED_VALUE=$(csv_escape "$VALUE")
                        ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
                        ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
                        echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},${ESCAPED_KEY},${ESCAPED_VALUE}" >> "$output_file"
                    fi
                done < <(echo "$TAGS_RESULT" | jq -c '.TagSet[]')
            fi
        fi
    else
        # Fallback to basic processing without jq
        # Extract tags using grep and sed
        TAGS=$(echo "$TAGS_RESULT" | grep -o '"Key": "[^"]*", "Value": "[^"]*"' | sed 's/"Key": "\([^"]*\)", "Value": "\([^"]*\)"/\1,\2/g')
        
        if [[ -z "$TAGS" ]]; then
            # No tags - add a row indicating that
            ESCAPED_BUCKET=$(csv_escape "$bucket_name")
            ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
            ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
            echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},No tags,No tags" >> "$output_file"
        elif [[ -n "$TAG_KEYS" ]]; then
            # Filter by specific tag keys
            IFS=',' read -ra TAG_KEY_ARRAY <<< "$TAG_KEYS"
            
            while IFS=',' read -r KEY VALUE; do
                for TAG_KEY in "${TAG_KEY_ARRAY[@]}"; do
                    if [[ "$KEY" == "$TAG_KEY" ]]; then
                        ESCAPED_BUCKET=$(csv_escape "$bucket_name")
                        ESCAPED_KEY=$(csv_escape "$KEY")
                        ESCAPED_VALUE=$(csv_escape "$VALUE")
                        ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
                        ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
                        echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},${ESCAPED_KEY},${ESCAPED_VALUE}" >> "$output_file"
                        break
                    fi
                done
            done <<< "$TAGS"
        else
            # Process all tags
            while IFS=',' read -r KEY VALUE; do
                ESCAPED_BUCKET=$(csv_escape "$bucket_name")
                ESCAPED_KEY=$(csv_escape "$KEY")
                ESCAPED_VALUE=$(csv_escape "$VALUE")
                ESCAPED_ACCOUNT=$(csv_escape "$account_display_name")
                ESCAPED_TIMESTAMP=$(csv_escape "$timestamp")
                echo "${ESCAPED_ACCOUNT},${ESCAPED_TIMESTAMP},${ESCAPED_BUCKET},${ESCAPED_KEY},${ESCAPED_VALUE}" >> "$output_file"
            done <<< "$TAGS"
        fi
    fi

    echo "Tags for bucket $bucket_name added to $output_file"
    return 0
}

# Initialize variables
BUCKET_NAMES=""
ALL_BUCKETS=false
TAG_KEYS=""
REGION="ap-southeast-2"
OUTPUT_DIR="."

# Parse command-line options
while getopts ":b:at:r:o:h" opt; do
    case $opt in
        b) BUCKET_NAMES="$OPTARG" ;;
        a) ALL_BUCKETS=true ;;
        t) TAG_KEYS="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check required parameters
if [[ -z "$BUCKET_NAMES" && "$ALL_BUCKETS" == false ]]; then
    echo "Error: Either bucket names (-b) or all buckets (-a) must be specified"
    usage
fi

# Check AWS CLI is installed
check_command "aws"

# Create output directory if it doesn't exist
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create output directory $OUTPUT_DIR"
        exit 1
    fi
fi

# Detect if jq is available
JQ_AVAILABLE=false
if command -v jq &> /dev/null; then
    JQ_AVAILABLE=true
fi

# Get account information and timestamp
ACCOUNT_DISPLAY_NAME=$(get_account_info)
TIMESTAMP=$(get_timestamp)

# Create a single output file for all buckets
OUTPUT_FILE="$OUTPUT_DIR/s3_buckets_tags.csv"
echo "Account,DateTime,Bucket,Key,Value" > "$OUTPUT_FILE"

# Process buckets
if [ "$ALL_BUCKETS" = true ]; then
    echo "Listing all buckets in region $REGION..."
    BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text --region "$REGION")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to list buckets"
        exit 1
    fi
    
    # Process each bucket and append to single file
    for bucket in $BUCKETS; do
        process_bucket "$bucket" "$OUTPUT_FILE" "$ACCOUNT_DISPLAY_NAME" "$TIMESTAMP"
    done
else
    # Process specified buckets
    IFS=',' read -ra BUCKET_ARRAY <<< "$BUCKET_NAMES"
    for bucket in "${BUCKET_ARRAY[@]}"; do
        process_bucket "$bucket" "$OUTPUT_FILE" "$ACCOUNT_DISPLAY_NAME" "$TIMESTAMP"
    done
fi

echo "Operation completed. All tag data has been exported to $OUTPUT_FILE"