#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32 (payer wallet)}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v ON_ERROR_STOP=1 -c "$1" | head -n1 | tr -d '\r'; }
psqlx(){ psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "$1" >/dev/null; }

say "Health"; curl -fsS http://127.0.0.1:8080/health | jq .

say "Users (alice, bob)"
U_ALICE="$(psql1 "INSERT INTO users(handle,display_name)
  VALUES('alice','Alice')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")"
U_BOB="$(psql1 "INSERT INTO users(handle,display_name)
  VALUES('bob','Bob')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")"
echo "ALICE=$U_ALICE  BOB=$U_BOB"

say "Bind wallet -> Bob (wallet_owners)"
psqlx "INSERT INTO wallet_owners(owner,user_id)
       VALUES('$PUB32','$U_BOB')
       ON CONFLICT(owner) DO UPDATE SET user_id=EXCLUDED.user_id;"

say "Ensure Bob is a creator (wallet + handle)"
CREATOR_BOB="$(psql1 "
  WITH upd AS (
    UPDATE creators
       SET handle='bob', wallet='$PUB32', bio='Demo creator'
     WHERE user_id='$U_BOB'
     RETURNING id
  ),
  ins AS (
    INSERT INTO creators(user_id,handle,wallet,bio)
    SELECT '$U_BOB','bob','$PUB32','Demo creator'
     WHERE NOT EXISTS (SELECT 1 FROM upd)
    RETURNING id
  )
  SELECT COALESCE((SELECT id FROM upd),(SELECT id FROM ins));
")"
echo "CREATOR_BOB=$CREATOR_BOB"

say "Ensure a non-USDC token owned by Bob"
# Use a fixed demo mint so the faucet/build scripts are deterministic
MINT_DEMO="MY2xpcGRlbW86ZGVtbw"   # "myxpcgrlbw86zgvmbw"
psqlx "
  WITH _ AS (
    SELECT 1 FROM tokens WHERE mint='$MINT_DEMO' LIMIT 1
  )
  INSERT INTO tokens(mint,symbol,decimals,initial_supply,base_token,creator_id,created_at)
  SELECT '$MINT_DEMO','CLIP',6,0,'USDC','$CREATOR_BOB',now()
  WHERE NOT EXISTS (SELECT 1 FROM _);
"

# confirm / get latest non-USDC mint
MINT_DB="$(psql1 "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
echo "MINT_DB=$MINT_DB"

say "Faucet USDC to payer"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

say "Make Alice follow Bob (idempotent)"
curl -fsS -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" | jq .

say "Build order (buy 1,000,000 USDC worth)"
ORDER="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
  -H 'content-type: application/json' \
  -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}")"
echo "$ORDER" | jq .
OID="$(echo "$ORDER" | jq -r '.orderId // empty')"
[ -n "$OID" ] || { echo "Build failed (no orderId)"; exit 1; }
echo "OID=$OID"

say "Execute order"
curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}" | jq .

say "Alice's feed"
curl -fsS "http://127.0.0.1:8080/v1/feed?userId=$U_ALICE" | jq .
