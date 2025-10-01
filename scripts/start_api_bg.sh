#!/usr/bin/env bash
set -euo pipefail

PORT=${PORT:-8080}
HEALTH_URL=${HEALTH_URL:-http://127.0.0.1:${PORT}/health}

is_up() { curl -fsS --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; }

if is_up; then
  echo "API already up on :$PORT"
  exit 0
fi

echo "Starting API on :$PORT ..."
# Best-effort install & start; ignore install errors if deps already present.
if command -v npm >/dev/null 2>&1; then
  npm --prefix /opt/cliplaunch/packages/api ci >/dev/null 2>&1 || true
  # Try common start commands; first that exists will work.
  if npm --prefix /opt/cliplaunch/packages/api run | grep -qE '^  start'; then
    (cd /opt/cliplaunch/packages/api && npm start >/tmp/cliplaunch-api.log 2>&1 &)
  else
    # Fallback to node entrypoints commonly used in this repo
    node /opt/cliplaunch/packages/api/src/index.js  >/tmp/cliplaunch-api.log 2>&1 &
  fi
else
  # Very basic fallback
  node /opt/cliplaunch/packages/api/src/index.js  >/tmp/cliplaunch-api.log 2>&1 &
fi

# Wait for health
for i in {1..60}; do
  if is_up; then
    echo "API is healthy."
    exit 0
  fi
  sleep 1
done

echo "API failed to become healthy; last lines of log:"
tail -n 100 /tmp/cliplaunch-api.log || true
exit 1
