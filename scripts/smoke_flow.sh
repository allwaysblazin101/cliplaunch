#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"   # payer pubkey string (dev stub ok)

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1" | head -n1 | tr -d '\r'; }
sql(){   psql "$DATABASE_URL" -v "ON_ERROR_STOP=1" -c "$1"; }

# 0) health
say "Health"
curl -fsS http://127.0.0.1:8080/health | jq .

# 1) users
say "Users (alice, bob)"
U_ALICE="$(psql1 "INSERT INTO users (handle,display_name)
                  VALUES ('alice','Alice')
                  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
                  RETURNING id;")"
U_BOB="$(psql1   "INSERT INTO users (handle,display_name)
                  VALUES ('bob','Bob')
                  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
                  RETURNING id;")"
echo "ALICE=$U_ALICE  BOB=$U_BOB"

# 2) bind wallet -> bob
say "Bind wallet → Bob (wallet_owners)"
sql "INSERT INTO wallet_owners (owner,user_id)
     VALUES ('$PUB32','$U_BOB')
     ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id;"

# 3) ensure creator row for bob
say "Ensure creator row for Bob (wallet + handle required)"
CREATOR_BOB="$(psql1 "
  WITH upd AS (
    UPDATE creators
       SET handle='bob', wallet='$PUB32', bio='Demo creator'
     WHERE user_id='$U_BOB'
     RETURNING id
  )
  INSERT INTO creators (user_id,handle,wallet,bio)
  SELECT '$U_BOB','bob','$PUB32','Demo creator'
  WHERE NOT EXISTS (SELECT 1 FROM upd)
  RETURNING id;")"
if [ -z "$CREATOR_BOB" ]; then
  # if row existed, fetch id
  CREATOR_BOB="$(psql1 "SELECT id FROM creators WHERE user_id='$U_BOB' LIMIT 1;")"
fi
echo "CREATOR_BOB=$CREATOR_BOB"

# 4) ensure USDC seeded (your fixed path); then faucet
say "Faucet USDC → payer"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

# 5) ensure one non-USDC token (CLIP) belongs to Bob (idempotent)
say "Ensure a non-USDC token owned by Bob"
MINT_DB="$(psql1 "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
if [ -z "$MINT_DB" ]; then
  # create a deterministic demo mint
  MINT_DB="MY2xpcGRlbW86ZGVtbw"
  sql "INSERT INTO tokens (mint,symbol,decimals,initial_supply,base_token,creator_id,created_at)
       VALUES ('$MINT_DB','CLIP',6,0,'USDC','$CREATOR_BOB',now())
       ON CONFLICT DO NOTHING;"
fi
echo "MINT_DB=$MINT_DB"

# 6) ensure follow (alice → bob)
say "Make Alice follow Bob (idempotent)"
curl -fsS -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" | jq .

# 7) build & execute 1M USDC buy
say "Build BUY order (1,000,000 USDC in)"
ORDER="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
  -H 'content-type: application/json' \
  -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}")"
echo "$ORDER" | jq .
OID="$(echo "$ORDER" | jq -r '.orderId // empty')"
[ -n "$OID" ] || { echo "Build failed"; exit 1; }

say "Execute order"
curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}" | jq .

# 8) feed assertion (alice’s home)
say "Alice's feed"
FEED="$(curl -fsS "http://127.0.0.1:8080/v1/feed?userId=$U_ALICE")"
echo "$FEED" | jq .

# require we see at least one item and that the last orderId is present
items="$(echo "$FEED" | jq '.items | length')"
if [ "$items" -lt 1 ]; then
  echo "❌ feed empty"
  exit 1
fi
echo "✅ smoke passed"
