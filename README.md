# Radiant

This project is for my Cloud Computing final at the University of San Francisco.

## Project Overview

This project is a full-fledged AI Single Page Application (SPA) built with serverless architecture and cloud infrastructure. It demonstrates best practices in modern cloud deployment, security, and AI integration.

## What Does It Do

AI-powered Valorant montage maker using AWS services. Takes ~20-second gameplay clips, detects kills using Rekognition, and generates an edited montage with AI commentary.

## Requirements

- **Static Page**: Served via cloud storage (S3) as the frontend SPA.
- **API Backend**: AWS API Gateway routing to Lambda functions to process REST endpoints (no GraphQL used).
- **Authentication**: Implemented with Amazon Cognito, supporting username/password login plus one OAuth provider.
- **Database**: Cloud-hosted RDBMS for persistent storage (no DynamoDB).
- **DNS & CDN**: Custom domain with Cloudflare for DNS, CDN caching, and SSL; HTTPS enforced.
- **Security**: Protection against DDoS attacks and ReCaptcha integration via Cloudflare.
- **AI Integration**: Connects to an external ML API (approved for use in this project).
- **Service Constraints**: No AWS Amplify, Google Firebase, or other automatic SaaS/PaaS deployment tools.

## Local Dev

- The following variables are **required** for local dev. Please view `next-app/app/auth/auth.config.ts` for formatting:

```bash
NEXT_PUBLIC_COGNITO_CLIENT_ID=
NEXT_PUBLIC_COGNITO_ENDPOINT=
NEXT_PUBLIC_COGNITO_DOMAIN=
NEXT_PUBLIC_COGNITO_REDIRECT_URI=
```

- Addtionally, confirm/update any `CORS` policies in `infra/aws/api_gateway.tf`

## Google Auth

Cognito utilizes **Google OAUTH 2.0** for the additional sign-in requirement.

### Setup Steps

1. Create a Google Cloud Platform account (if you don’t have one).
2. Go to APIs & Services → Credentials.
3. Click Create Credentials → OAuth client ID and choose Web application.
4. Configure the Authorised JavaScript origins:

```
https://<your-cognito-domain>.auth.<region>.amazoncognito.com
```

5. Configure the Authorized redirect URIs:

```
https://<your-cognito-domain>.auth.<region>.amazoncognito.com/oauth2/idpresponse
```

> **NOTE**: The main uri for the two previous steps can be found in the `cognito_pool_domain` output of Terraform.

6. Note down the generated `Client ID` and `Client Secret`.

7. In this repository, navigate to `infra/aws` and create a `terraform.tfvars` file containing:

```
google_auth_client_id     = "YOUR CLIENT ID"
google_auth_client_secret = "YOUR CLIENT SECRET"
```

Once done, Google sign-in will be enabled in the Cognito UI.

### Notes

- Run `aws secretsmanager delete-secret --secret-id app-config --force-delete-without-recovery` between `terraform destroy` and `terraform apply` because AWS doesn't want you accidentally deleting your secrets (although in this case it's intentional).

## Infrastructure Setup

### Prerequisites

1. **AWS Account** with appropriate IAM permissions
2. **Terraform** installed locally
3. **AWS CLI** configured with credentials
4. **Docker** for building Lambda layers
5. **Rekognition Custom Labels** model trained on kill detection

### Deployment Steps

1. **Build Lambda Layers:**
   ```bash
   cd scripts/
   ./ffmpeg_zip_create.sh    # Creates ffmpeg-layer.zip on ~/Desktop
   ./psycopg_zip_create.sh   # Creates psycopg-layer.zip on ~/Desktop
   ```
   Upload these layers to AWS Lambda manually or via Terraform.

2. **Configure Terraform Variables:**
   Create `infra/aws/terraform.tfvars`:
   ```hcl
   google_auth_client_id     = "your-google-client-id"
   google_auth_client_secret = "your-google-client-secret"
   db_user_info = {
     db_name  = "your-db-name"
     username = "your-db-username"
     password = "your-db-password"
   }
   s3_bucket_name = "your-static-site-bucket"
   # ... other variables
   ```

3. **Deploy Infrastructure:**
   ```bash
   cd scripts/
   ./start.sh <REKOGNITION_VERSION_ARN> <PROJECT_ARN> us-east-1
   ```
   
   This will:
   - Start Rekognition model
   - Apply Terraform configuration
   - Upload music files to S3
   - Output API Gateway URL and Cognito domains

4. **Configure Frontend:**
   Update `next-app/.env.local` with Cognito configuration from Terraform outputs.

5. **Deploy Frontend:**
   Build Next.js app and sync to S3 bucket:
   ```bash
   cd next-app/
   npm run build
   aws s3 sync out/ s3://your-static-site-bucket/
   ```

### Teardown

```bash
cd scripts/
./teardown.sh <REKOGNITION_VERSION_ARN> us-east-1
```

## Constraints

- Videos limited to 25MB (~20 seconds) for Lambda compatibility
- Rekognition trained only on kills (submitter POV)
- All processing happens in Lambda `/tmp` (512MB-10GB depending on function)
- Presigned upload URLs expire after 10 minutes
- Presigned video playback URLs expire after 20 minutes (1200s)
- Presigned thumbnail URLs expire after 1 hour (3600s)

## API Endpoints

**Base URL:** `https://{api-id}.execute-api.{region}.amazonaws.com/prod/api/`

### `GET /cognito`
- **Purpose:** Get Cognito configuration for frontend authentication
- **Auth:** None
- **Response:** Cognito client ID, domain, and endpoints

### `POST /get-upload-url`
- **Purpose:** Get presigned S3 URL for video upload
- **Auth:** Required (Cognito token)
- **Body:** `{ "email": string, "filename": string, "contentType": string }`
- **Response:** `{ "url": string, "key": string }`

### `POST /poll`
- **Purpose:** Check Step Functions execution status
- **Auth:** Required (Cognito token)
- **Body:** `{ "executionArn": string }`
- **Response:** `{ "status": string, "output": object }`

### `POST /videos`
- **Purpose:** Database operations for video management
- **Auth:** Required (Cognito token)
- **Operations:**
  - `listVideos`: Get all videos for user
    - Body: `{ "operation": "listVideos", "userEmail": string }`
  - `getVideoURL`: Get presigned URL for video playback
    - Body: `{ "operation": "getVideoURL", "videoId": string }`
  - `deleteVideo`: Delete video and S3 objects
    - Body: `{ "operation": "deleteVideo", "videoId": string }`

**CORS:** All endpoints support CORS with `Access-Control-Allow-Origin: *`

## Architecture Flow

```
S3 Upload → EventBridge → Start Step Function Lambda
                               ↓
                          Step Functions
                               ↓
                          Step 1: Setup
                          (Validate input, extract email)
                               ↓
                          Step 2: Detect Kills
                          (Extract frames, Rekognition Custom Labels)
                               ↓
                          Step 3: Merge Intervals
                          (Merge kill timestamps with buffer)
                               ↓
                          Choice: Check if clips exist
                               ↓
                     Yes ────────────┘  No → Success (No Clips Found)
                     ↓
                Step 4: Generate Clips & Montage
                - Extract video segments (FFmpeg)
                - Generate commentary (Bedrock)
                - TTS audio (Polly)
                - Overlay audio on clips (FFmpeg)
                - Add background music (FFmpeg)
                - Concatenate with transitions (FFmpeg xfade)
                - Generate thumbnail (FFmpeg)
                     ↓
                Add to Database
                (RDS: save video record)
                     ↓
                  Success
```

## Scripts

### `scripts/start.sh`

**Purpose:** Deploy infrastructure and start the Rekognition model

**Usage:**
```bash
./scripts/start.sh <REKOGNITION_ARN> <PROJECT_ARN> [REGION]
```

**Actions:**
1. Starts the Rekognition Custom Labels model
2. Runs `terraform apply` in `infra/aws/`
3. Syncs music files from `music/` to S3 bucket (excluding README.md)
4. Outputs API Gateway URL for GitHub Actions secrets
5. Outputs Cognito URLs for Google OAuth configuration
6. Polls Rekognition model status until RUNNING (max 50 attempts, 10s intervals)

### `scripts/teardown.sh`

**Purpose:** Tear down infrastructure and clean up resources

**Usage:**
```bash
./scripts/teardown.sh [REKOGNITION_ARN] [AWS_REGION]
```

**Actions:**
1. Stops the Rekognition Custom Labels model (if ARN provided)
2. Force-deletes AWS Secrets Manager secrets (`app-config`, `db-secret`)
3. Runs `terraform destroy` in `infra/aws/`

### `scripts/s3.sh`

**Purpose:** Sync local directory to S3 bucket

**Usage:**
```bash
./scripts/s3.sh <BUCKET_NAME> <SOURCE_DIR>
```

**Actions:**
- Validates bucket exists and is accessible
- Syncs source directory to S3 with `--delete` flag

### `scripts/ffmpeg_zip_create.sh`

**Purpose:** Build FFmpeg Lambda layer for AWS Lambda (AL2023/Python 3.12)

**Actions:**
1. Runs Docker container with `amazonlinux:2023` image
2. Builds x264 library from source
3. Builds FFmpeg with libx264 support
4. Creates `ffmpeg-layer.zip` on `~/Desktop`

### `scripts/psycopg_zip_create.sh`

**Purpose:** Build psycopg2 Lambda layer for AWS Lambda (Python 3.12)

**Actions:**
1. Runs Docker container with AWS Lambda Python 3.12 base image
2. Builds psycopg2 with PostgreSQL development libraries
3. Creates `psycopg-layer.zip` on `~/Desktop`

## Lambda Functions

### Lambda: Start Step Function (`start_step/main.py`)

**Trigger:** EventBridge (S3 PutObject events)

**Purpose:** Filter S3 upload events and start Step Functions execution

- Input: EventBridge S3 event
- Actions:
  - Filters out non-video files (music/, thumbnails/, montages/)
  - Extracts S3 bucket and key from event
  - Starts Step Functions state machine with video metadata
- Output: Step Functions execution ARN

### Step 1: Setup (`process_upload/step1/main.py`)

**Purpose:** Validate input and extract metadata

- Input: S3 bucket, video key, model ARN
- Actions:
  - Validates required fields
  - Extracts email from S3 key path (e.g., `email@domain.com/video.mp4`)
- Output: Validated metadata (bucket, videoKey, email, modelArn)

### Step 2: Detect Kills (`process_upload/step2/main.py`)

**Purpose:** Extract frames and detect kills using Rekognition Custom Labels

**Requirements:** FFmpeg Lambda Layer

- Input: S3 video path, Rekognition model ARN
- Actions:
  - Downloads video from S3
  - Extracts 1 frame per second using FFmpeg
  - Processes each frame with Rekognition Custom Labels (min confidence: 50%)
  - Collects timestamps where kills are detected
- Output: Array of kill timestamps `[{time: 5.2, confidence: 89.1}, ...]`

### Step 3: Merge Intervals (`process_upload/step3/main.py`)

**Purpose:** Merge overlapping kill timestamps with buffer

- Input: Array of kill timestamps
- Actions:
  - Adds 2.5-second buffer before/after each kill
  - Merges overlapping intervals using interval merging algorithm
  - Handles case where no kills are detected
- Output: Array of clip intervals `[{start: 5.2, end: 9.5}, {start: 12.0, end: 15.8}]`

### Step 4: Generate Clips & Montage (`process_upload/step4/main.py`)

**Purpose:** Create final montage with AI commentary and music

**Requirements:** FFmpeg Lambda Layer

- Input: Video path, clip intervals
- Actions for each clip:
  - Generate esports commentary using Amazon Bedrock (Titan Text Express)
  - Convert commentary to speech using Amazon Polly (Stephen voice, generative engine)
  - Extract video segment with FFmpeg
  - Overlay commentary audio on video clip
- Concatenation:
  - For multiple clips: Uses FFmpeg xfade transitions (0.5s crossfade)
  - Adds background music from random NCS track in S3
  - Normalizes audio levels
- Finalization:
  - Generates thumbnail from random frame using FFmpeg
  - Uploads montage and thumbnail to S3
  - Cleans up temporary files
- Output: S3 keys for montage and thumbnail

### Lambda: Database Operations (`db/main.py`)

**Trigger:** API Gateway + Step Functions

**Purpose:** Manage video records in RDS PostgreSQL

**Requirements:** psycopg2 Lambda Layer

**Operations:**
- `createVideoRecord`: Insert new video record (called by Step Functions)
- `listVideos`: Get all videos for a user with presigned thumbnail URLs
- `getVideoURL`: Get presigned URL for video playback (20 min expiry)
- `deleteVideo`: Delete video record and S3 objects

**Database Schema:**
```sql
CREATE TABLE videos (
    id UUID PRIMARY KEY,
    user_email TEXT NOT NULL,
    job_id TEXT NOT NULL,
    input_key TEXT,
    output_key TEXT NOT NULL,
    thumbnail_key TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_videos_user_email ON videos(user_email);
```

### Lambda: S3 Signed URL (`s3_signed/main.py`)

**Trigger:** API Gateway POST `/api/get-upload-url`

**Purpose:** Generate presigned S3 upload URL for client

- Input: User email, filename, content type
- Actions:
  - Sanitizes email (replaces `@` with `_at_`)
  - Generates presigned PUT URL (10 min expiry)
  - Sets S3 key as `{email}/{timestamp}-{filename}`
- Output: Presigned URL and S3 key

### Lambda: Polling (`polling/main.py`)

**Trigger:** API Gateway POST `/api/poll`

**Purpose:** Check Step Functions execution status

- Input: Execution ARN
- Actions:
  - Queries Step Functions execution status
  - Returns current state (RUNNING, SUCCEEDED, FAILED, etc.)
- Output: Execution status and details

### Lambda: Cognito Config (`cognito/main.py`)

**Trigger:** API Gateway GET `/api/cognito`

**Purpose:** Provide Cognito configuration to frontend

- Input: None
- Actions:
  - Retrieves Cognito settings from Secrets Manager
  - Returns client ID, domain, and endpoints
- Output: Cognito configuration JSON

## S3 Directory Structure

```
/{sanitized-email}/                        # User upload directory (@ replaced with _at_)
  {timestamp}-{filename}.mp4               # Original uploaded video
  
/music/                                    # NCS background music tracks
  *.mp3                                    # No Copyright Sounds music files

/montages/{sanitized-email}/               # Processed montages
  {timestamp}-montage.mp4                  # Final montage output
  
/thumbnails/{sanitized-email}/             # Video thumbnails  
  {timestamp}-thumbnail.jpg                # Extracted thumbnail frame
```

**Notes:**
- Original uploads and final outputs are kept permanently
- All processing happens in Lambda's `/tmp` directory (no S3 intermediate files)
- User emails are sanitized (e.g., `user@example.com` → `user_at_example.com`)

## AWS Services Used

### Core Infrastructure

- **S3:** Static website hosting (frontend SPA) + video upload bucket with CORS
- **API Gateway:** REST API with endpoints for Cognito config, uploads, polling, and database operations
- **Lambda:** Serverless compute for all backend logic (8 functions total)
- **Cognito:** User authentication with username/password + Google OAuth 2.0
- **RDS (PostgreSQL 17):** Relational database for video metadata (db.t3.micro)
- **RDS Proxy:** Connection pooling for Lambda database access
- **VPC:** Private subnets for RDS + Lambda, public subnets for NAT Gateway
- **Secrets Manager:** Stores database credentials and application config

### Video Processing Pipeline

- **EventBridge:** Event-driven triggers on S3 uploads
- **Step Functions:** Orchestrates 4-step video processing workflow with error retry logic
- **Rekognition Custom Labels:** ML model for kill detection in gameplay frames
- **Bedrock (Titan Text Express):** AI-generated esports commentary
- **Polly (Generative TTS):** Text-to-speech with Stephen voice for commentary narration

### Lambda Layers

- **FFmpeg Layer:** Custom-built with x264 support for video/audio processing
- **psycopg2 Layer:** PostgreSQL adapter for Python Lambda functions

### Additional Components

- **Cloudflare (External):** DNS management, CDN caching, SSL/TLS, DDoS protection, ReCaptcha
- **CloudWatch:** Logging for all Lambda functions and Step Functions

> **NOTE:** This architecture is optimized for demonstration and cost management rather than production scale. For a production deployment serving thousands of concurrent users, the design would incorporate asynchronous processing with SQS, increased Lambda concurrency limits, WebSocket notifications, and additional caching layers.
