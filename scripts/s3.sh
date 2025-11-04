#!/bin/bash

set -euo pipefail

BUCKET_NAME="$1"
SOURCE_DIR="$2"
DEST_PREFIX="${3:-src}"

if [[ -z "$BUCKET_NAME" ]]; then
  echo "Bucket name is empty!"
  exit 1
fi

if [[ ! "$BUCKET_NAME" =~ ^[a-z0-9]([a-z0-9\-]{1,61}[a-z0-9])?$ ]]; then
  echo "Invalid bucket name! Must be 3-63 chars, lowercase letters/numbers/hyphens, start and end with letter/number."
  exit 1
fi

if ! aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
  echo "Bucket '$BUCKET_NAME' does not exist or you do not have access."
  exit 1
fi

if [[ -z "$SOURCE_DIR" ]]; then
  echo "Source directory is empty!"
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Directory '$SOURCE_DIR' does not exist."
  exit 1
fi

if [[ ! "$DEST_PREFIX" =~ ^[a-zA-Z0-9_\-]+$ ]]; then
  echo "Destination prefix '$DEST_PREFIX' contains invalid characters."
  exit 1
fi

echo "Uploading all files from '$SOURCE_DIR/' to s3://$BUCKET_NAME/$DEST_PREFIX/"

aws s3 sync "$SOURCE_DIR" "s3://$BUCKET_NAME/$DEST_PREFIX/" --delete

echo "Upload complete."