#!/usr/bin/env bash
# Smoke-test the LiteLLM gateway directly (OpenAI-compatible API).
#
# Reads configuration from a .env file (default: ./.env next to this script).
# Pass an alternate path as the first argument: ./test_gateway.sh /path/to/.env
#
# Required variables (set them in the .env file or the environment):
#   LITELLM_ENDPOINT     Base URL of the LiteLLM gateway
#   LITELLM_MASTER_KEY   Gateway master key
#
# Generate a .env from Terraform outputs:
#   cd ../terraform
#   {
#     echo "LITELLM_ENDPOINT=$(terraform output -raw litellm_endpoint)"
#     echo "LITELLM_MASTER_KEY=$(terraform output -raw litellm_master_key)"
#   } > ../samples/.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/.env}"

if [[ -f "${ENV_FILE}" ]]; then
  echo "==> Loading ${ENV_FILE}"
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
else
  echo "==> No .env file at ${ENV_FILE}; relying on existing environment variables."
fi

: "${LITELLM_ENDPOINT:?set LITELLM_ENDPOINT (in ${ENV_FILE} or the environment)}"
: "${LITELLM_MASTER_KEY:?set LITELLM_MASTER_KEY (in ${ENV_FILE} or the environment)}"

# Trim a trailing slash for clean URLs.
LITELLM_ENDPOINT="${LITELLM_ENDPOINT%/}"

echo "==> GET /v1/models"
curl -sS "${LITELLM_ENDPOINT}/v1/models" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" | jq .

echo
echo "==> POST /v1/chat/completions"
curl -sS "${LITELLM_ENDPOINT}/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.4-mini",
    "messages": [{"role": "user", "content": "Say hello from the LiteLLM gateway."}]
  }' | jq .
