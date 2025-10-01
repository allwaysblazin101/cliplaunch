#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL}"

HANDLE="${1:-alice}"
USER_ID="$(psql "$DATABASE_URL" -At -c "select id from users where handle='${HANDLE}' limit 1;")"
[ -n "$USER_ID" ] || { echo "No such handle: ${HANDLE}"; exit 1; }

curl -s "http://127.0.0.1:8080/v1/feed?userId=${USER_ID}" | jq .
