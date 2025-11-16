# Creating the FFmpeg + FFprobe Lambda Layer (AL2023 / Python 3.12)

This guide walks through building a Lambda layer containing **FFmpeg and FFprobe** binaries compatible with **Python 3.12 Lambdas on Amazon Linux 2023**. It replaces older AL2-based tutorials that may only include FFmpeg and fail for `ffprobe` or Python 3.12 runtimes.

## Prerequisites

- **Docker** installed on your machine (used to match the Lambda environment)

## Create ZIP

- Run `scripts/ffmpeg_zip_create.sh`.
