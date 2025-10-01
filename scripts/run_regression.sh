#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psqlc(){ psql "$DATABASE_URL" -c "$1"; }

say "Start / check API"
bash /opt/cliplaunch/scripts/start_api_bg.sh

say "Health"
curl -fsS http://127.0.0.1:8080/health | jq .

say "Seed minimal (users/wallet/creator)"
bash /opt/cliplaunch/scripts/test_flow.sh

say "Run demo trade + feed (full flow)"
bash /opt/cliplaunch/scripts/test_all.sh

say "DB summary: recent orders"
psqlc "SELECT id, side, amount_in, amount_out, price, status, created_at
       FROM orders ORDER BY created_at DESC LIMIT 5;"

say "DB summary: recent activities"
psqlc "SELECT verb, object_type, (meta->>'mint') AS mint, (meta->>'payer') AS payer,
              actor, created_at
       FROM activities ORDER BY created_at DESC LIMIT 6;"

echo -e "\n✅ All checks passed"
