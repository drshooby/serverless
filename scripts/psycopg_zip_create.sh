#!/bin/bash
# Build psycopg2 Lambda layer for AL2023 / Python 3.12
# Uses AWS Lambda Python 3.12 base image for compatibility

set -euo pipefail

# Output path on host
HOST_DESKTOP="$HOME/Desktop"
ZIP_NAME="psycopg-layer.zip"

# Use the official AWS Lambda Python 3.12 base image
IMAGE="public.ecr.aws/lambda/python:3.12"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

echo "Starting build inside AWS Lambda Python 3.12 Docker image..."

# Pull the official Lambda image
docker pull $IMAGE

# Run Docker build using the actual Lambda runtime environment
# Use --entrypoint to override the Lambda entrypoint
docker run --rm --platform linux/amd64 --entrypoint /bin/bash -v "$HOST_DESKTOP":/host -w /tmp $IMAGE -c "\
  set -e; \
  dnf install -y gcc postgresql15-devel tar gzip; \
  mkdir -p python; \
  pip install psycopg2-binary -t python --no-cache-dir; \
  cd python; \
  find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true; \
  find . -type f -name '*.pyc' -delete 2>/dev/null || true; \
  cd /tmp; \
  zip -r9 /host/$ZIP_NAME python; \
  echo 'psycopg2 Lambda layer created successfully'; \
"

if [ $? -eq 0 ]; then
  echo "Removing Docker image..."
  docker image rm $IMAGE || true
  echo "Build completed successfully. Layer at ~/Desktop/$ZIP_NAME"
else
  echo "Build failed. Check the output above for errors."
  exit 1
fi

echo "Build completed. The Lambda layer zip is located on your Desktop as $ZIP_NAME"