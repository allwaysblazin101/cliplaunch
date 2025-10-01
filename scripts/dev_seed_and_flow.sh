#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL (postgres://…)}"
: "${PUB32:?set PUB32 (payer public key)}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psqlq(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1"; }
jcurl(){ curl -fsS "$@" | jq .; }

# 0) Health
say "API health"
jcurl http://127.0.0.1:8080/health

# 1) Users
say "Ensure users (alice, bob)"
U_ALICE="$(psqlq "INSERT INTO users (handle,display_name)
  VALUES ('alice','Alice')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;" | head -n1 | tr -d '[:space:]')"
U_BOB="$(psqlq "INSERT INTO users (handle,display_name)
  VALUES ('bob','Bob')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;" | head -n1 | tr -d '[:space:]')"
echo "U_ALICE=$U_ALICE"
echo "U_BOB=$U_BOB"

# 2) Bind wallet -> Bob (assumes unique index on wallet_owners.owner)
say "Bind payer wallet to Bob (wallet_owners upsert)"
psqlq "
INSERT INTO wallet_owners (owner, user_id)
VALUES ('$PUB32', '$U_BOB')
ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id;
"

# 3) Ensure creators row for Bob (wallet & handle REQUIRED)
#    Upsert WITHOUT ON CONFLICT (user_id) since it's not unique.
say "Ensure creators row for Bob (wallet & handle REQUIRED)"
CREATOR_BOB="$(psqlq "
WITH upd AS (
  UPDATE creators
     SET handle='bob', wallet='$PUB32', bio='Demo creator'
   WHERE user_id='$U_BOB'
 RETURNING id
)
INSERT INTO creators (user_id, handle, wallet, bio)
SELECT '$U_BOB', 'bob', '$PUB32', 'Demo creator'
WHERE NOT EXISTS (SELECT 1 FROM upd)
RETURNING id;
" | head -n1 | tr -d '[:space:]')"

# If UPDATE fired (no INSERT), fetch id now
if [ -z "$CREATOR_BOB" ]; then
  CREATOR_BOB="$(psqlq "SELECT id FROM creators WHERE user_id='$U_BOB' LIMIT 1;")"
fi
if [ -z "$CREATOR_BOB" ]; then
  echo "Failed to resolve CREATOR_BOB"; exit 1
fi
echo "CREATOR_BOB=$CREATOR_BOB"

# 4) Ensure at least one non-USDC token owned by Bob
say "Ensure a non-USDC token owned by Bob"
DEMO_MINT="MY2xpcGRlbW86ZGVtbw"
psqlq "
INSERT INTO tokens (mint, symbol, decimals, initial_supply, base_token, creator_id, created_at)
VALUES ('$DEMO_MINT','CLIP',6,0,'USDC','$CREATOR_BOB',now())
ON CONFLICT (mint) DO NOTHING;
"

MINT_DB="$(psqlq "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
if [ -z "$MINT_DB" ]; then echo "No creator token available"; exit 1; fi
echo "MINT_DB=$MINT_DB"

# 5) Faucet
say "Top up payer with USDC"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

# 6) Social: Alice follows Bob
say "Make Alice follow Bob"
curl -fsS -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" | jq .

# 7) Build -> Execute order
say "Build order"
ORDER_JSON="$(
  curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
    -H 'content-type: application/json' \
    -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}"
)"
echo "$ORDER_JSON" | jq .

if ! echo "$ORDER_JSON" | jq -e 'select(.ok==true)' >/dev/null; then
  echo "Build failed; skipping execute."; exit 0
fi
OID="$(echo "$ORDER_JSON" | jq -r '.orderId' | tr -d '[:space:]')"
[ -n "$OID" ] && [ "$OID" != "null" ] || { echo "No orderId; skipping execute."; exit 0; }
echo "OID=$OID"

say "Execute order"
curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}" | jq .

# 8) Feed
say "Fetch feed (should include Bob's buy)"
jcurl http://127.0.0.1:8080/v1/feed

say "Done."
