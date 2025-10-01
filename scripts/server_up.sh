#!/usr/bin/env bash
set -euo pipefail

PORT=8080
API_HEALTH="http://127.0.0.1:${PORT}/health"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }

# Already up?
if curl -fsS "$API_HEALTH" >/dev/null 2>&1; then
  say "API already up on :${PORT}"
  exit 0
fi

say "Starting API on :${PORT}"
# Try common start methods; adjust if you use pnpm/yarn etc.
if [ -f /opt/cliplaunch/packages/api/dist/index.js ]; then
  node /opt/cliplaunch/packages/api/dist/index.js > /opt/cliplaunch/api.log 2>&1 &
elif [ -f /opt/cliplaunch/packages/api/src/index.ts ]; then
  # fallback: ts-node if present
  npx ts-node /opt/cliplaunch/packages/api/src/index.ts > /opt/cliplaunch/api.log 2>&1 &
else
  # generic npm script if available
  (cd /opt/cliplaunch && npm run start:api >/opt/cliplaunch/api.log 2>&1 &) || true
fi

# Wait for health
for i in {1..60}; do
  if curl -fsS "$API_HEALTH" >/dev/null 2>&1; then
    say "API is healthy"
    exit 0
  fi
  sleep 1
done

say "API failed to report healthy; tail follows:"
tail -n 200 /opt/cliplaunch/api.log || true
exit 1
