#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL (postgres://…)}"
: "${PUB32:?set PUB32 (payer public key)}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1" | head -n1 | tr -d '\r'; }
sql (){ psql "$DATABASE_URL" -v "ON_ERROR_STOP=1" -c "$1" >/dev/null; }

# ---------- health ----------
say "Health"
curl -fsS http://127.0.0.1:8080/health | jq .

# ---------- users ----------
say "Ensure users (alice, bob)"
U_ALICE="$(psql1 "INSERT INTO users (handle,display_name)
  VALUES ('alice','Alice')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")"
U_BOB="$(psql1 "INSERT INTO users (handle,display_name)
  VALUES ('bob','Bob')
  ON CONFLICT (handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")"
echo "ALICE=$U_ALICE  BOB=$U_BOB"

# ---------- wallet mapping ----------
say "Bind wallet -> Bob (wallet_owners)"
sql "INSERT INTO wallet_owners (owner,user_id)
     VALUES ('$PUB32','$U_BOB')
     ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id;"

# ---------- creator row (wallet + handle required) ----------
say "Ensure creator row for Bob (wallet+handle)"
CREATOR_ID="$(psql1 "
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
if [ -z "$CREATOR_ID" ]; then
  CREATOR_ID="$(psql1 "SELECT id FROM creators WHERE user_id='$U_BOB' LIMIT 1;")"
fi
[ -n "$CREATOR_ID" ] || { echo "ASSERT: missing creators row"; exit 1; }
echo "CREATOR_ID=$CREATOR_ID"

# ---------- ensure USDC (already fixed in your DB, but keep a guard) ----------
say "Faucet USDC to payer (guard)"
curl -fsS -X POST http://127.0.0.1:8080/v1/wallets/faucet \
  -H 'content-type: application/json' \
  -d "{\"owner\":\"$PUB32\",\"mint\":\"USDC\",\"amount\":\"10000000\"}" | jq .

# ---------- ensure a creator mint (non-USDC) ----------
say "Ensure one non-USDC token owned by Bob"
MINT_DB="$(psql1 "SELECT mint FROM tokens WHERE symbol <> 'USDC' ORDER BY created_at DESC LIMIT 1;")"
if [ -z "$MINT_DB" ]; then
  MINT_DB="MY2xpcGRlbW86ZGVtbw"
  sql "INSERT INTO tokens (mint,symbol,decimals,initial_supply,base_token,creator_id,created_at)
       VALUES ('$MINT_DB','CLIP',6,0,'USDC','$CREATOR_ID',now())
       ON CONFLICT (mint) DO NOTHING;"
fi
echo "MINT_DB=$MINT_DB"

# ---------- follow relation ----------
say "Make Alice follow Bob (idempotent)"
curl -fsS -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" | jq .

# ---------- trade: build & execute ----------
say "Build BUY order (1,000,000 USDC in)"
ORDER_JSON="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/build \
  -H 'content-type: application/json' \
  -d "{\"mint\":\"$MINT_DB\",\"side\":\"buy\",\"amountIn\":\"1000000\",\"payer\":\"$PUB32\"}")"
echo "$ORDER_JSON" | jq .
OID="$(echo "$ORDER_JSON" | jq -r '.orderId // empty')"
[ -n "$OID" ] || { echo "ASSERT: build failed (no orderId)"; exit 1; }
echo "OID=$OID"

say "Execute order"
EXEC_JSON="$(curl -fsS -X POST http://127.0.0.1:8080/v1/orders/execute \
  -H 'content-type: application/json' \
  -d "{\"orderId\":\"$OID\"}")"
echo "$EXEC_JSON" | jq .

# ---------- assertions ----------
say "DB assertions"
ROW_ID="$(psql1 "SELECT id FROM orders WHERE id='$OID' AND status='executed' LIMIT 1;")"
[ "$ROW_ID" = "$OID" ] || { echo "ASSERT: order not executed in DB"; exit 1; }

PRICE="$(psql1 "SELECT price FROM orders WHERE id='$OID';")"
[ "$PRICE" = "0.500000" ] || { echo "ASSERT: price mismatch ($PRICE)"; exit 1; }

say "Alice's feed"
FEED_JSON="$(curl -fsS "http://127.0.0.1:8080/v1/feed?userId=$U_ALICE")"
echo "$FEED_JSON" | jq .

# must contain the just-executed order from Bob
HAS="$(echo "$FEED_JSON" | jq -r "[.items[] | select(.object_id==\"$OID\" and .actor_id==\"$U_BOB\")] | length")"
[ "$HAS" -ge 1 ] || { echo "ASSERT: feed missing executed order for follower"; exit 1; }

# sanity on enrichment fields
SYM="$(echo "$FEED_JSON" | jq -r ".items[] | select(.object_id==\"$OID\") | .token_symbol" | head -n1)"
[ "$SYM" = "CLIP" ] || { echo "ASSERT: token_symbol enrichment mismatch ($SYM)"; exit 1; }

echo
echo "✅ All checks passed"
