#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/opt/cliplaunch"
cd "$ROOT_DIR"

# --- env defaults for CI/local ---
export DATABASE_URL="${DATABASE_URL:-postgres://cliplaunch:beams@localhost:5432/cliplaunch}"
export PUB32="${PUB32:-11111111111111111111111111111111}"

say(){ printf "\n\033[1;36m%s\033[0m\n" "$*"; }

# --- start API ---
say "Starting API"
# choose your runner; keep logs quiet but capturable
( node ./packages/api/src/index.js & echo $! > .api.pid ) 2>&1 | sed -u 's/^/[api] /' &
sleep 0.3

# --- wait for health ---
say "Waiting for /health"
for i in {1..60}; do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null; then
    echo "API healthy"; break
  fi
  sleep 0.5
  [ $i -eq 60 ] && { echo "API failed to become healthy"; exit 1; }
done

# --- apply migrations you already have ---
say "Applying migrations (if any)"
# adjust to your migration tool; example assumes sql files in /opt/cliplaunch/sql
# Ensure base schema is already applied in your dev image.

# --- seed system usdc (safe to rerun) ---
say "Seeding system USDC"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/007_seed_system_creator_and_usdc.sql

# --- run the e2e flow ---
say "Running end-to-end flow"
./scripts/test_flow.sh

# --- done ---
say "All checks passed"

# cleanup
if [ -f .api.pid ]; then
  kill "$(cat .api.pid)" || true
  rm -f .api.pid
fi
