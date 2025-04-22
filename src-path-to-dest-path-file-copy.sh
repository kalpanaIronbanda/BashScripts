#!/bin/bash

# Variables
SRC_FOLDER="/reports/"
DEST_FOLDER="/nfs"
FILE_GREP="R_BRS_CONSOLIDATE_LOADER"

# Ensure destination folder exists
mkdir -p "$DEST_FOLDER"

echo "Starting file copy process at $(date)"

# Find and copy files modified in the last 15 minutes
find "$SRC_FOLDER" -type f -name "*$FILE_GREP*" -mmin -15 | while read file; do
    echo "Copying: $file"
    cp "$file" "$DEST_FOLDER"
done

echo "File copy process completed at $(date)"
