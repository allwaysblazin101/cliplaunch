#!/usr/bin/env bash
set -euo pipefail

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }

: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

psql1() {
  psql "$DATABASE_URL" -Atq -v "ON_ERROR_STOP=1" -c "$1" | head -n1 | tr -d '\r\n[:space:]'
}

# --- 0) health ---
say "API health"
curl -fsS http://127.0.0.1:8080/health | jq .

# --- 1) users ---
say "Ensure users"
U_ALICE=$(psql1 "INSERT INTO users(handle,display_name)
  VALUES('alice','Alice')
  ON CONFLICT(handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")
U_BOB=$(psql1 "INSERT INTO users(handle,display_name)
  VALUES('bob','Bob')
  ON CONFLICT(handle) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id;")
echo "U_ALICE=$U_ALICE"
echo "U_BOB=$U_BOB"

# --- 2) wallet_owners ---
say "Bind wallet -> Bob"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  INSERT INTO wallet_owners(owner,user_id)
  VALUES('$PUB32','$U_BOB')
  ON CONFLICT(owner) DO UPDATE SET user_id=EXCLUDED.user_id;
"

# --- 3) creators ---
say "Ensure creator row for Bob"
CREATOR_BOB=$(psql1 "
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
")
echo "CREATOR_BOB=$CREATOR_BOB"
