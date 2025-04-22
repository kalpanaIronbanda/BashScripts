#!/bin/bash
export PATH=$PATH:/home/ubuntu/bin   #optional


# Configuration
OCI_NAMESPACE="namespace"
OCI_BUCKET="oci_bucket"
AWS_S3_BUCKET="s3://aws_s3_bucket"  # <-- Replace with your actual S3 bucket
TMP_DIR="/tmp/oci_files"
mkdir -p "$TMP_DIR"

SRC_CURRENT_DATE=$(date -u +"%-d%-m%Y")      # e.g., 2242025
DEST_CURRENT_DATE=$(date -u +"%Y_%m/%d") 

SRC_PREFIX="reports/$SRC_CURRENT_DATE/"
DEST_PREFIX="OsFin/$DEST_CURRENT_DATE/Output/testing"

# Get time 15 minutes ago
PAST=$(date -u -d '-15 minutes' +"%Y-%m-%dT%H:%M:%SZ")


echo "Getting files from $SRC_PREFIX"
# List objects modified in the last 15 minutes
FILES=$(oci os object list \
  --namespace "$OCI_NAMESPACE" \
  --bucket-name "$OCI_BUCKET" \
  --prefix "$SRC_PREFIX" \
  --auth instance_principal \
  --query "data[?\"time-modified\">='$PAST']" \
  --output json | jq -r '.[].name')
echo "Recieved files in last 15min : [$FILES]"
for FILE in $FILES; do
  FILENAME=$(basename "$FILE")
  DEST_PATH="${DEST_PREFIX}/${FILENAME}"

  echo "Downloading file $FILE to the local $TMP_DIR/"

  # Download from OCI
  oci os object get \
    --namespace "$OCI_NAMESPACE" \
    --bucket-name "$OCI_BUCKET" \
    --name "$FILE" \
    --file "$TMP_DIR/$FILENAME" \
    --auth instance_principal
  echo "Uploading to $AWS_S3_BUCKET/$DEST_PATH"
  # Upload to AWS S3
  aws s3 cp "$TMP_DIR/$FILENAME" "$AWS_S3_BUCKET/$DEST_PATH"
done

echo "Clearing local folder $TMP_DIR"

# Cleanup
rm -rf "$TMP_DIR"
