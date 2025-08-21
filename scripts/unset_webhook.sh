#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ID="${PROJECT_ID:?}"; REGION="${REGION:?}"; SERVICE="telegram-bot"
TOKEN="$(gcloud secrets versions access latest --secret=telegram-token --project "$PROJECT_ID")"
curl -fsS "https://api.telegram.org/bot${TOKEN}/deleteWebhook?drop_pending_updates=true"
echo
