#!/bin/bash
set -euo pipefail

ROOT_DIR="$(pwd)/.."
INFRA_DIR="${ROOT_DIR}/infra/aws"
MUSIC_DIR="${ROOT_DIR}/music"

REKOGNITION_ARN="${1:-}" # long one
PROJECT_ARN="${2:-}" # short one
REGION="${3:-us-east-1}"

if [[ -z "$REKOGNITION_ARN" || -z "$PROJECT_ARN" ]]; then
    echo "Usage: $0 <REKOGNITION_ARN> <PROJECT_ARN> [REGION]"
    echo "Both Rekognition ARN and Project ARN are required."
    exit 1
fi

echo "Starting Rekognition model..."
aws rekognition start-project-version \
    --project-version-arn "$REKOGNITION_ARN" \
    --min-inference-units 1 \
    --region "$REGION"

echo "Rekognition starting..."

# Run Terraform in infra dir
cd "$INFRA_DIR"
terraform apply -auto-approve
echo "Terraform apply complete!"
echo "=================="

# Sync music to S3
echo "Adding NCS music to S3..."
S3_BUCKET="s3://$(terraform output -raw upload_bucket)"
aws s3 sync "$MUSIC_DIR" "$S3_BUCKET/music" --exact-timestamps --exclude "README.md"
echo "Added NCS music to S3."
echo "=================="

# Output API Gateway URL
API_BASE_URL="$(terraform output -raw api_gateway_base_url)"
echo "Add this API Gateway URL to GitHub Actions secrets and run the workflow:"
echo "$API_BASE_URL"
echo "=================="

# Output Cognito URLs
COGNITO_DOMAIN_URI="$(terraform output -raw cognito_pool_domain)"
echo "Add these URLs to Google Cloud OAuth:"
echo "Authorized JavaScript origin:  $COGNITO_DOMAIN_URI"
echo "Authorized redirect URI:       ${COGNITO_DOMAIN_URI}/oauth2/idpresponse"
echo "=================="

# Poll Rekognition status
echo "Polling for Rekognition model status..."
MAX_ATTEMPTS=50
CURRENT_ATTEMPTS=0

while [[ $CURRENT_ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    OUTPUT="$(aws rekognition describe-project-versions \
        --project-arn "$PROJECT_ARN" \
        --region "$REGION" 2>/dev/null || true)"

    if echo "$OUTPUT" | grep -q '"Status": "RUNNING"'; then
        echo "Rekognition model is RUNNING!"
        exit 0
    fi

    STATUS="$(echo "$OUTPUT" | grep '"Status":' | head -1 | sed 's/.*"Status": "\([^"]*\)".*/\1/')"
    echo "Status: ${STATUS:-UNKNOWN} (retry in 10s)"

    sleep 10
    CURRENT_ATTEMPTS=$((CURRENT_ATTEMPTS + 1))
done

echo "Rekognition did not start successfully. Last status: ${STATUS:-UNKNOWN}"
exit 1