# Radiant

This project is for my Cloud Computing final with the following requirements:

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

## Constraints

- Videos limited to 25MB (~20 seconds) for Lambda compatibility
- Rekognition trained only on kills (submitter POV)
- Intermediate files stored temporarily in S3

## Architecture Flow

```
S3 Upload → EventBridge → Orchestrator Lambda
                              ↓
                         Step Functions
                              ↓
                    Start Rekognition Job
                    (Custom Labels: kills)
                              ↓
                    Wait for Completion
                    (Step Functions built-in wait)
                              ↓
                    Get Results + Merge Intervals
                    (Lambda with merge logic)
                              ↓
                    Extract Clips in Parallel
                    (Map state - one Lambda per clip)
                    FFmpeg extracts clip segment
                              ↓
                    For each clip (parallel):
                      - Bedrock: generate commentary
                      - Polly: TTS
                      - FFmpeg: overlay audio on clip
                              ↓
                    Concatenate Final Montage
                    (Single Lambda - FFmpeg concat)
                              ↓
                    Save to S3 + RDS + Cleanup
```

## Lambda Functions

### Lambda 1: Start Rekognition

**Trigger:** EventBridge (S3 PutObject)
**Purpose:** Initiate Rekognition video analysis

- Input: S3 bucket + key from EventBridge event
- Action: Start Rekognition Custom Labels job for kill detection
- Output: JobId for tracking

### Lambda 2: Process Results

**Purpose:** Extract and merge kill timestamps

- Input: Rekognition JobId
- Action:
  - Fetch Rekognition results
  - Merge overlapping timestamps with 2-second buffer (intro/outro context)
  - Apply interval merging algorithm
- Output: Array of clip intervals `[{start: 5.2, end: 9.5}, {start: 12.0, end: 15.8}]`

### Lambda 3: Extract & Enhance Clip (Parallel Execution)

**Purpose:** Process individual clips with AI commentary - **FFmpeg Layer Required**

- Input: Single clip interval + original video S3 path
- Actions:
  - Extract video segment using FFmpeg
  - Generate commentary via Bedrock (e.g., "Great kill!")
  - Convert commentary to speech via Polly
  - Overlay audio on video using FFmpeg
  - Save enhanced clip to S3
- Output: S3 path of enhanced clip

### Lambda 4: Concatenate

**Purpose:** Combine all clips into final montage - **FFmpeg Layer Required**

- Input: List of S3 paths for enhanced clips
- Action: FFmpeg concatenate all clips into single video
- Output: Final montage S3 URL

### Lambda 5: Cleanup

**Purpose:** Remove intermediate files and persist results to RDS

- Input: Job ID, processing paths, final montage S3 URL
- Actions:
  - Delete all intermediate clips and audio files
  - Extract random frame as thumbnail using FFmpeg
  - Save to RDS:
    - User email
    - Original video S3 key
    - Final montage S3 key
    - Thumbnail S3 key
    - Processing timestamp
    - Metadata (kills found, clip count, duration), maybe
- Output: Success status
- Keep: Original video + final montage + thumbnail in S3

## S3 Directory Structure

```
/uploads/[email]/[timestamp]-original.mp4 # Original upload
/processing/[job-id]/clip-1.mp4 # Intermediate clips
/processing/[job-id]/clip-1-audio.mp3 # TTS audio
/processing/[job-id]/clip-1-final.mp4 # Clip with audio overlay
/montages/[email]/[timestamp]-montage.mp4 # Final output
```

Lifecycle Policy: `Delete /processing/*` after 1 day

## AWS Additional Services Used

- **EventBridge:** Event-driven trigger on upload
- **Step Functions:** Workflow orchestration
- **Rekognition Custom Labels:** Kill detection
- **Bedrock:** AI commentary generation
- **Polly:** Text-to-speech for voiceover
- **FFmpeg (Lambda Layer):** Video/audio processing

> **NOTE:** This architecture is optimized for demonstration and cost management rather than production scale. For a production deployment serving thousands of concurrent users, the design would incorporate asynchronous processing with SQS, increased Lambda concurrency limits, WebSocket notifications, and additional caching layers.
