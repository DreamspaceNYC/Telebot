#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${PROJECT_ID:-PROJECT_ID_PLACEHOLDER}"
REGION="${REGION:-REGION_PLACEHOLDER}"
SERVICE="telegram-bot"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE}"

[[ "$PROJECT_ID" == "PROJECT_ID_PLACEHOLDER" || "$REGION" == "REGION_PLACEHOLDER" ]] && \
  { echo "Set PROJECT_ID and REGION env vars or replace placeholders."; exit 1; }

echo "Enabling APIs..."
gcloud services enable run.googleapis.com secretmanager.googleapis.com cloudbuild.googleapis.com --project "$PROJECT_ID"

echo "Creating/Updating secret telegram-token..."
if gcloud secrets describe telegram-token --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo -n "${TELEGRAM_TOKEN:?missing TELEGRAM_TOKEN}" | gcloud secrets versions add telegram-token --project "$PROJECT_ID" --data-file=-
else
  echo -n "${TELEGRAM_TOKEN:?missing TELEGRAM_TOKEN}" | gcloud secrets create telegram-token --project "$PROJECT_ID" --data-file=-
fi

echo "Building image ${IMAGE}..."
gcloud builds submit --project "$PROJECT_ID" --tag "$IMAGE"

echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --project "$PROJECT_ID" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --max-instances=2 \
  --set-secrets TELEGRAM_TOKEN=telegram-token:latest

URL=$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --format='value(status.url)')
echo "Service URL: $URL"

echo "Saving APP_URL env var (for future use)..."
gcloud run services update "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --set-env-vars APP_URL="${URL}"

TOKEN="$(gcloud secrets versions access latest --secret=telegram-token --project "$PROJECT_ID")"
echo "Setting Telegram webhook..."
curl -fsS "https://api.telegram.org/bot${TOKEN}/setWebhook?url=${URL}/webhook/${TOKEN}" | sed -E 's/.*/Webhook set: &/'

echo "Webhook info:"
curl -fsS "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"; echo

echo "Health check:"
curl -fsS "${URL}/health"; echo
