# Adding Montage Music

This guide explains how to make music available for your montages.

## Prerequisites

- Have some non-copyrighted music available. A popular source (my favorite) is [NCS](https://ncs.io/).

## Usage

- The startup script `scripts/start.sh` automatically uploads this directory to S3, so all you need to do is add your MP3 files.
- The system currently selects a random song from the music directory when processing montages.
- For implementation details, see `infra/aws/lambda/process_upload/step4/main.py`.
