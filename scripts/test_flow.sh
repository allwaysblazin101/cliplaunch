#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }
psql1(){ psql "$DATABASE_URL" -qAt -v "ON_ERROR_STOP=1" -c "$1" | sed -n '1{s/\r//g;p;q}'; }
sql(){   psql "$DATABASE_URL" -v "ON_ERROR_STOP=1" -c "$1"; }

say "Health"
curl -fsS http://127.0.0.1:8080/health | jq .

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

say "Bind wallet → Bob (wallet_owners)"
sql "INSERT INTO wallet_owners (owner,user_id)
     VALUES ('$PUB32','$U_BOB')
     ON CONFLICT (owner) DO UPDATE SET user_id=EXCLUDED.user_id;"

say "Ensure creator row for Bob (wallet + handle required)"
CREATOR_BOB="$(psql1 "SELECT id FROM creators WHERE user_id='$U_BOB' ORDER BY created_at DESC LIMIT 1;")"

if [ -z "$CREATOR_BOB" ]; then
  echo "No creator row yet — inserting"
  CREATOR_BOB="$(psql1 "INSERT INTO creators (user_id,handle,wallet,bio)
                        VALUES ('$U_BOB','bob','$PUB32','Demo creator')
                        RETURNING id;")"
else
  echo "Found creator $CREATOR_BOB — updating handle & wallet (idempotent)"
  sql "UPDATE creators
       SET handle='bob', wallet='$PUB32', bio='Demo creator'
       WHERE id='$CREATOR_BOB';"
fi

[ -n "$CREATOR_BOB" ] || { echo "creator row missing"; exit 1; }
echo "CREATOR_BOB=$CREATOR_BOB"

# continue with your next steps here if needed...
