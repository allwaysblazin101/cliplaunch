#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
export PUB32="${PUB32:-11111111111111111111111111111111}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1" | head -n1 | tr -d '\r'; }

say "Health"; curl -fsS http://127.0.0.1:8080/health | jq .

say "Users"
U_ALICE="$(psql1 "INSERT INTO users (handle,display_name) VALUES ('alice','Alice')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name RETURNING id;")"
U_BOB="$(psql1 "INSERT INTO users (handle,display_name) VALUES ('bob','Bob')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name RETURNING id;")"
echo "ALICE=$U_ALICE BOB=$U_BOB"

say "Bind wallet -> Bob"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  INSERT INTO wallet_owners (owner,user_id) VALUES ('$PUB32','$U_BOB')
  ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id;"

say "Creator upsert (API)"
curl -fsS -X POST http://127.0.0.1:8080/v1/creators/upsert \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_BOB\",\"handle\":\"bob\",\"wallet\":\"$PUB32\",\"bio\":\"Demo creator\"}" | jq .

say "Ensure USDC"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  WITH u AS (
    INSERT INTO users (handle, display_name) VALUES ('system','System')
    ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
    RETURNING id
  ), c AS (
    INSERT INTO creators (user_id, handle, wallet, bio)
    SELECT id, 'system', 'USDC_TREASURY', 'System treasury' FROM u
    ON CONFLICT (user_id) DO UPDATE SET handle=EXCLUDED.handle, wallet=EXCLUDED.wallet, bio=EXCLUDED.bio
    RETURNING id
  )
  INSERT INTO tokens (mint,symbol,decimals,initial_supply,base_token,creator_id,created_at)
  SELECT 'USDC','USDC',6,0,'USDC',c.id,now() FROM c
  ON CONFLICT (mint) DO UPDATE SET symbol='USDC',decimals=6,base_token='USDC',creator_id=EXCLUDED.creator_id;
"

say "Faucet"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

say "Creator token for Bob"
CREATOR_ID="$(psql1 "SELECT id FROM creators WHERE user_id='$U_BOB' LIMIT 1;")"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  INSERT INTO tokens (mint,symbol,decimals,initial_supply,base_token,creator_id,created_at)
  VALUES ('MY2xpcGRlbW86ZGVtbw','CLIP',6,0,'USDC','$CREATOR_ID', now())
  ON CONFLICT (mint) DO UPDATE SET symbol='CLIP', base_token='USDC', creator_id='$CREATOR_ID';
"

MINT_DB="$(psql1 "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
echo "MINT_DB=$MINT_DB"

say "Build"
ORDER="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
  -H 'content-type: application/json' \
  -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}")"
echo "$ORDER" | jq .
OID="$(echo "$ORDER" | jq -r '.orderId // empty')"
[ -n "$OID" ] || { echo "Build failed"; exit 1; }

say "Execute"
curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}" | jq .

say "Follow & Feed"
curl -fsS -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" | jq .
curl -fsS "http://127.0.0.1:8080/v1/feed?userId=$U_ALICE" | jq .

say "DONE"
