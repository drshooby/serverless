#!/bin/bash

set -euo pipefail

ROOT_DIR="$(pwd)/.."
INFRA_DIR="${ROOT_DIR}/infra/aws"

REKOGNITION_ARN="${1:-}"
SECRETS=("app-config" "db-secret")

delete_secret() {
    local name="$1"
    echo "Deleting secret: $name..."
    aws secretsmanager delete-secret \
        --secret-id "$name" \
        --force-delete-without-recovery \
        || echo "Secret '$name' not found. Skipping."
}

echo "Starting teardown..."

cd "$INFRA_DIR"
terraform destroy -auto-approve

for secret in "${SECRETS[@]}"; do
    delete_secret "$secret"
done

if [[ -n "$REKOGNITION_ARN" ]]; then
    echo "Stopping Rekognition model..."
    aws rekognition stop-project-version \
        --project-version-arn "$REKOGNITION_ARN" \
        --region "${AWS_REGION:-us-east-1}" \
        || echo "Could not stop Rekognition model. Skipping."
else
    echo "No Rekognition ARN provided."
fi

echo "Teardown complete."