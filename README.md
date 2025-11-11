# Radiant

This project is for my Cloud Computing final with the following requirements:

## Project Overview

This project is a full-fledged AI Single Page Application (SPA) built with serverless architecture and cloud infrastructure. It demonstrates best practices in modern cloud deployment, security, and AI integration.

## Requirements

- **Static Page**: Served via cloud storage (S3) as the frontend SPA.
- **API Backend**: AWS API Gateway routing to Lambda functions to process REST endpoints (no GraphQL used).
- **Authentication**: Implemented with Amazon Cognito, supporting username/password login plus one OAuth provider.
- **Database**: Cloud-hosted RDBMS for persistent storage (no DynamoDB).
- **DNS & CDN**: Custom domain with Cloudflare for DNS, CDN caching, and SSL; HTTPS enforced.
- **Security**: Protection against DDoS attacks and ReCaptcha integration via Cloudflare.
- **AI Integration**: Connects to an external ML API (approved for use in this project).
- **Constraints**: No AWS Amplify, Google Firebase, or other automatic SaaS/PaaS deployment tools.

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

## Project Status & Next Steps

### Completed

- **Static Page**: SPA served via S3.
- **Authentication**: Username/password + Google OAUTH 2.0 login via Amazon Cognito fully implemented.
- **DNS & CDN**: Custom domain set up with Cloudflare, SSL/HTTPS enforced.
- **DDOS Protection**: Just turn on `under attack` mode.

### In Progress / To Do

- [ ] **Database**: Connect and configure cloud-hosted RDBMS for persistent storage.
- [ ] **Backend API**: Implement Lambda functions behind API Gateway to handle REST endpoints.
- [ ] **AI Integration**: Connect SPA/backend to external ML API for approved project functionality.
- [ ] **Security Enhancements**:
  - [ ] Explore Cloudflare Turnstile for bot protection.

### Notes

- Run `aws secretsmanager delete-secret --secret-id cognito-config --force-delete-without-recovery` between `terraform destroy` and `terraform apply` because AWS doesn't want you accidentally deleting your secrets (although in this case it's intentional).

## Proposed API Endpoints & Lambda Flow (AI Comments)

### 1. **POST /upload** → `upload-handler` Lambda

- User uploads video from frontend
- Lambda generates presigned S3 URL for upload
- Returns presigned URL to client
- Client uploads directly to S3 (bypasses API Gateway size limits)
- S3 triggers next step via event notification

### 2. **S3 Event → SQS → `video-processor-orchestrator` Lambda**

- S3 upload completion triggers SQS message
- Lambda receives message with S3 key
- Creates job record in RDS (status: PROCESSING)
- Kicks off Rekognition job
- Returns job_id to track progress

### 3. **Rekognition Completion → SNS → `rekognition-handler` Lambda**

- Rekognition publishes to SNS when done
- Lambda receives labels/timestamps
- Runs merge interval logic to consolidate highlights
- Creates highlight chunks list
- Triggers MediaConvert job #1 (extract highlight clips)
- Updates job status in RDS

### 4. **MediaConvert Completion → EventBridge → `mediaconvert-chunks-handler` Lambda**

- MediaConvert finishes extracting clips
- Lambda gets S3 locations of chunks
- Sends chunks metadata to Bedrock for commentary generation
- Receives AI-generated commentary text
- Triggers Polly to generate audio files
- Stores audio S3 locations

### 5. **Polly Completion → `polly-handler` Lambda**

- Lambda receives Polly audio file locations
- Prepares MediaConvert job #2 (stitch clips + overlay audio)
- Kicks off final video assembly

### 6. **MediaConvert Final → EventBridge → `final-video-handler` Lambda**

- MediaConvert finishes final montage
- Lambda updates RDS with final video S3 URL and thumbnail
- Updates job status to COMPLETED
- Optionally sends notification (could use WebSocket or polling)

### 7. **GET /videos** → `get-videos` Lambda

- Returns list of user's completed videos from RDS
- Includes S3 URLs (presigned for security)
- Returns thumbnails for preview

### 8. **GET /video/:id** → `get-video-detail` Lambda

- Returns specific video details
- Generates presigned URL for video playback
- Returns metadata (created_at, duration, etc.)

### 9. **GET /job/:id** → `get-job-status` Lambda

- Frontend polls this to check processing status
- Returns current status and progress percentage if possible

---

## Why SQS?

Yes, you need SQS because:

- **Decoupling**: S3 → SQS → Lambda prevents lost events if Lambda fails
- **Retry logic**: Failed processing jobs automatically retry
- **Rate limiting**: Prevents Lambda from getting overwhelmed with concurrent uploads
- **Visibility timeout**: Ensures jobs don't get processed twice

You might also want:

- **DLQ (Dead Letter Queue)**: For failed jobs after max retries
- **SNS for Rekognition/EventBridge for MediaConvert**: AWS services can publish completion events

---

## Database Schema (PostgreSQL/MySQL on RDS)

### `users` table

```
user_id          UUID PRIMARY KEY
cognito_sub      VARCHAR(255) UNIQUE NOT NULL
email            VARCHAR(255)
created_at       TIMESTAMP DEFAULT NOW()
```

### `videos` table

```
video_id                UUID PRIMARY KEY
user_id                 UUID REFERENCES users(user_id)
original_video_s3_key   VARCHAR(500) NOT NULL
final_video_s3_key      VARCHAR(500)
thumbnail_s3_key        VARCHAR(500)
status                  VARCHAR(50) NOT NULL  -- PROCESSING, COMPLETED, FAILED
created_at              TIMESTAMP DEFAULT NOW()
completed_at            TIMESTAMP
duration_seconds        INTEGER
error_message           TEXT
```

### `processing_jobs` table (optional but useful for debugging)

```
job_id                  UUID PRIMARY KEY
video_id                UUID REFERENCES videos(video_id)
step                    VARCHAR(100)  -- REKOGNITION, MEDIACONVERT_CHUNKS, POLLY, MEDIACONVERT_FINAL
status                  VARCHAR(50)   -- PENDING, IN_PROGRESS, COMPLETED, FAILED
started_at              TIMESTAMP
completed_at            TIMESTAMP
metadata                JSONB         -- Store timestamps, labels, etc.
error_message           TEXT
```

### `highlights` table (optional - for storing individual clips)

```
highlight_id       UUID PRIMARY KEY
video_id           UUID REFERENCES videos(video_id)
start_time         FLOAT NOT NULL    -- seconds
end_time           FLOAT NOT NULL
s3_key             VARCHAR(500)
rekognition_labels JSONB             -- labels detected in this clip
created_at         TIMESTAMP DEFAULT NOW()
```

---

## Alternative: Simpler Schema

If you want to keep it minimal for the demo:

### `videos` table (all-in-one)

```
video_id                UUID PRIMARY KEY
user_id                 VARCHAR(255) NOT NULL  -- cognito sub
original_s3_key         VARCHAR(500) NOT NULL
final_s3_key            VARCHAR(500)
thumbnail_s3_key        VARCHAR(500)
status                  VARCHAR(50) NOT NULL
highlights_metadata     JSONB  -- store all timestamps/labels here
created_at              TIMESTAMP DEFAULT NOW()
completed_at            TIMESTAMP
error_message           TEXT
```

This avoids extra joins and keeps everything in one table. JSONB column handles variable highlight data.

---

## Processing Flow Summary

```
User uploads → S3
  ↓
SQS → orchestrator Lambda (create DB record)
  ↓
Rekognition (analyze video)
  ↓
SNS → rekognition-handler Lambda (merge intervals)
  ↓
MediaConvert #1 (extract clips)
  ↓
EventBridge → chunks-handler Lambda
  ↓
Bedrock (generate commentary) → Polly (text-to-speech)
  ↓
MediaConvert #2 (stitch + audio overlay)
  ↓
EventBridge → final-handler Lambda (update DB, mark COMPLETED)
  ↓
Frontend polls /job/:id → shows completed video
```

---

## Considerations

- **Presigned URLs**: Generate for both upload and download to keep S3 bucket private
- **Polling vs WebSockets**: Polling `/job/:id` every 5s is simpler for demo
- **Error handling**: Make sure every Lambda updates job status on failure
- **Timeouts**: MediaConvert can take minutes - don't let API Gateway timeout
- **Cost**: Rekognition + MediaConvert aren't free - test with short clips first
