#!/bin/bash
set -euo pipefail

ROOT_DIR="$(pwd)/.."
INFRA_DIR="${ROOT_DIR}/infra/aws"

REKOGNITION_ARN="${1:-}"
REGION="${2:-us-east-1}"

if [[ -z "$REKOGNITION_ARN" ]]; then
    echo "Rekognition ARN not provided. Exiting."
    exit 1
fi

echo "Starting Rekognition model..."
aws rekognition start-project-version \
    --project-version-arn "$REKOGNITION_ARN" \
    --min-inference-units 1 \
    --region "$REGION"

echo "Rekognition starting..."

cd "$INFRA_DIR"
terraform apply -auto-approve
echo "Terraform apply complete!"
echo "=================="

API_BASE_URL="$(terraform output -raw api_gateway_base_url)"
echo "Add this API Gateway URL to GitHub Actions secrets and run the workflow:"
echo "$API_BASE_URL"
echo "=================="

COGNITO_DOMAIN_URI="$(terraform output -raw cognito_pool_domain)"
echo "Add these URLs to Google Cloud OAuth:"
echo "Authorized JavaScript origin:  $COGNITO_DOMAIN_URI"
echo "Authorized redirect URI:       ${COGNITO_DOMAIN_URI}/oauth2/idpresponse"
echo "=================="

echo "Polling for Rekognition model status..."
MAX_ATTEMPTS=50
CURRENT_ATTEMPTS=0

while (( CURRENT_ATTEMPTS < MAX_ATTEMPTS )); do
    OUTPUT="$(aws rekognition describe-project-versions \
        --project-arn "$REKOGNITION_ARN" \
        --region "$REGION" 2>/dev/null || true)"

    if echo "$OUTPUT" | grep -q "RUNNING"; then
        echo "Rekognition model is RUNNING!"
        exit 0
    fi

    STATUS="$(echo "$OUTPUT" | grep -o "Status[^,]*" || echo "UNKNOWN")"
    echo "Status: $STATUS (retry in 10s)"

    sleep 10
    ((CURRENT_ATTEMPTS++))
done

echo "Rekognition did not start successfully. Last status: $STATUS"
exit 1
