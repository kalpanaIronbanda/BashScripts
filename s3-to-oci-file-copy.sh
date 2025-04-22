#!/bin/bash


export PATH=$PATH:/home/ubuntu/bin  #optional



# AWS S3 source bucket
SRC_BUCKET="source_bucket"

# OCI bucket details
OCI_NAMESPACE="Namespace"  # Replace with your OCI namespace
DEST_BUCKET="Dest_bucket"

# Get current timestamp and calculate 4 hours ago
CURRENT_TIMESTAMP=$(date '+%s')
CURRENT_DATE=$(date '+%Y_%m/%d')
N_HOURS_AGO=$(date -d "1 hours ago" '+%s')

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to process file transfer from S3 to OCI
process_transfer() {
    local source_path="$1"
    local target_path="$2"
    local file_pattern="$3"

    log "Searching files in s3://$SRC_BUCKET/$source_path matching pattern: $file_pattern."

    # Get list of files modified in the last 4 hours
    matching_files=$(aws s3 ls "s3://$SRC_BUCKET/$source_path/" --recursive |
        while read -r line; do
            file_date=$(echo "$line" | awk '{print $1 " " $2}')
            file_timestamp=$(date -d "$file_date" '+%s')
            file_path=$(echo "$line" | awk '{$1=$2=$3=""; print substr($0,4)}')
            if [[ "$file_timestamp" -ge "$N_HOURS_AGO" && "$file_timestamp" -le "$CURRENT_TIMESTAMP" ]]; then
                echo "$file_path"
            fi
        done | grep "$file_pattern" || true)

    if [[ -z "$matching_files" ]]; then
        log "No files matched pattern '$file_pattern' in s3://$SRC_BUCKET/$source_path in the last 1 hours."
        return
    fi

    IFS=$'\n'  # Set IFS to handle filenames with spaces
    for file in $matching_files; do
        local file_name=$(basename "$file")
        local dest_file_path="$target_path/$file_name"

        log "#### Copying: "$file" to OCI bucket $DEST_BUCKET at path "$dest_file_path" #####"

        # Download the file from S3
        aws s3 cp "s3://$SRC_BUCKET/$file" "/tmp/$file_name"

        if [[ $? -eq 0 ]]; then
            # Upload to OCI
            oci os object put --namespace "$OCI_NAMESPACE" --bucket-name "$DEST_BUCKET" --auth instance_principal --file "/tmp/$file_name" --name "$dest_file_path" --force

            if [[ $? -eq 0 ]]; then
                log "Successfully copied: "$file" to OCI."
                rm -f "/tmp/$file_name"  # Clean up local copy
            else
                log "Error uploading: "$file" to OCI."
            fi
        else
            log "Error downloading: "$file" from S3."
        fi
    done
    unset IFS  # Reset IFS to default
}

# Define file mappings for different patterns
declare -A FILE_MAPPINGS=(
    ["CCMS_transaction"]="pipeline-unprocessed-files/DATA/ccms_transaction"
    ["Presentment_Report"]="pipeline-unprocessed-files/DATA/presentment_report"
    ["DSRSummaryReport"]="pipeline-unprocessed-files/DATA/dsr_report"
    ["864UNBA"]="pipeline-unprocessed-files/DATA/NPCI_CREDIT_CARD"
    ["All_Disputes"]="ipeline-unprocessed-files/DATA/all_dispute_credit_card"
)

# Define the source folder using yesterday's date
SOURCE_FOLDER="OsFin/$CURRENT_DATE/incoming"
#SOURCE_FOLDER="OsFin/2025_03/16/incoming"
# Check if the folder exists in S3 before processing
folder_exists=$(aws s3 ls "s3://$SRC_BUCKET/$SOURCE_FOLDER/" --recursive | wc -l)

if [[ "$folder_exists" -eq 0 ]]; then
    log "No folder found in S3 bucket for today's date. Exiting."
    exit 0
fi

# Process file transfers based on defined patterns
for pattern in "${!FILE_MAPPINGS[@]}"; do
    target_path="${FILE_MAPPINGS[$pattern]}"
    process_transfer "$SOURCE_FOLDER" "$target_path" "$pattern"
done

log "File transfer script execution completed."
