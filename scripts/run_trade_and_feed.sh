#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1" | sed -n '1{s/\r//g;p;q}'; }

say "Health"
curl -fsS http://127.0.0.1:8080/health | jq .

say "Resolve users"
U_ALICE="$(psql1 "select id from users where handle='alice' limit 1;")"
U_BOB="$(psql1   "select id from users where handle='bob'   limit 1;")"
echo "ALICE=$U_ALICE  BOB=$U_BOB"

say "Ensure Alice follows Bob"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  INSERT INTO follows (follower_id, followee_id)
  VALUES ('$U_ALICE', '$U_BOB')
  ON CONFLICT (follower_id, followee_id) DO NOTHING;
"

say "Top up payer with USDC (faucet)"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

say "Pick a creator mint (not USDC)"
MINT_DB="$(psql1 "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
[ -n "$MINT_DB" ] || { echo "No creator token found — mint one first"; exit 1; }
echo "MINT_DB=$MINT_DB"

say "Build order"
ORDER_JSON="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
  -H 'content-type: application/json' \
  -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}")"
echo "$ORDER_JSON" | jq .

OID="$(echo "$ORDER_JSON" | jq -r '.orderId // empty')"
[ -n "$OID" ] || { echo "Build failed (no orderId)"; exit 1; }
echo "OID=$OID"

say "Execute order"
curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}" | jq .

say "Alice's feed"
curl -fsS "http://127.0.0.1:8080/v1/feed?userId=$U_ALICE" | jq .

say "Recent activities (debug)"
psql "$DATABASE_URL" -c "
  SELECT verb, object_type, meta->>'mint' AS mint, meta->>'payer' AS payer, actor, created_at
  FROM activities ORDER BY created_at DESC LIMIT 10;
"

say "Recent orders (debug)"
psql "$DATABASE_URL" -c "
  SELECT id, side, amount_in, amount_out, price, status, created_at
  FROM orders ORDER BY created_at DESC LIMIT 5;
"
