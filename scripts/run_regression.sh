#!/usr/bin/env bash
set -euo pipefail

echo "Smoke: /health"
curl -fsS http://127.0.0.1:8080/health | jq -e '.ok == true' >/dev/null
echo "✓ health ok"

# Add more endpoints here as they exist, e.g.:
# echo "Smoke: /v1/wallets"
# curl -fsS "http://127.0.0.1:8080/v1/wallets" | jq . >/dev/null || exit 1

echo "Smoke: PASS"
