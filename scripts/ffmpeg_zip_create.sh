#!/bin/bash
# Build FFmpeg + FFprobe Lambda layer for AL2023 / Python 3.12
# Runs entirely inside Docker, copies the zip to ~/Desktop,
# explicitly builds for x86_64, and removes the Amazon Linux image afterwards.

set -euo pipefail

# Output path on host
HOST_DESKTOP="$HOME/Desktop"
ZIP_NAME="ffmpeg-layer.zip"
IMAGE="amazonlinux:2023"

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

echo "Starting build inside Docker (x86_64)..."

# Pull the image to ensure it's available
docker pull --platform linux/amd64 $IMAGE

# Run Docker build
docker run --rm --platform linux/amd64 -v "$HOST_DESKTOP":/host -w /tmp $IMAGE /bin/bash -c "\
  set -e; \
  dnf -y update; \
  dnf install -y gcc make autoconf automake bzip2 bzip2-devel cmake git libtool pkgconfig nasm yasm zlib-devel zip wget; \
  mkdir -p /tmp/ffmpeg_build; cd /tmp/ffmpeg_build; \
  git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg_source; cd ffmpeg_source; \
  ./configure --prefix=/opt --disable-shared --enable-static --disable-doc --disable-debug --enable-pic --enable-gpl --enable-nonfree --disable-ffplay; \
  make -j\$(nproc); make install; \
  cd /opt; zip -r9 /host/$ZIP_NAME bin; \
  echo 'FFmpeg + FFprobe layer zip created at ~/Desktop/$ZIP_NAME'; \
"

# Remove the Amazon Linux image to free disk space
echo "Removing the Docker image $IMAGE to free space..."
docker image rm $IMAGE || echo "Could not remove image $IMAGE (it may be in use elsewhere)"

echo "Build completed. The Lambda layer zip is located on your Desktop as $ZIP_NAME"