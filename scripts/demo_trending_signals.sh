#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"
API="http://127.0.0.1:8080"

say(){ printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

jqok(){ jq -r "$1" 2>/dev/null || true; }

# --- resolve users ---
U_ALICE=$(psql "$DATABASE_URL" -At -c "SELECT id FROM users WHERE handle='alice' LIMIT 1;")
U_BOB=$(psql "$DATABASE_URL"  -At -c "SELECT id FROM users WHERE handle='bob'   LIMIT 1;")
echo "USERS: ALICE=$U_ALICE BOB=$U_BOB"

# Alice follows Bob (idempotent)
curl -s -X POST "$API/v1/follow" \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" >/dev/null || true

say "health"
curl -fsS "$API/health" | jq .

# --- create two fresh posts for Bob, capture real IDs ---
say "create posts"
P1_JSON=$(curl -s -X POST "$API/v1/posts" \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_BOB\",\"title\":\"Clip A\",\"description\":\"demo\",\"videoUrl\":\"https://example.com/demoA.mp4\"}")
P1=$(echo "$P1_JSON" | jq -r '.id // .object_id // empty')

P2_JSON=$(curl -s -X POST "$API/v1/posts" \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_BOB\",\"title\":\"Clip B\",\"description\":\"demo\",\"videoUrl\":\"https://example.com/demoB.mp4\"}")
P2=$(echo "$P2_JSON" | jq -r '.id // .object_id // empty')

echo "POSTS: P1=$P1 P2=$P2"
[ -n "$P1" ] && [ -n "$P2" ] || { echo "❌ Failed to capture post IDs"; echo "$P1_JSON"; echo "$P2_JSON"; exit 1; }

# --- baseline trending (before signals) ---
say "baseline trending (48h)"
curl -s "$API/v1/trending?window=48h&limit=10" | jq .

# --- apply engagement signals from Alice ---
say "signals: like Clip A; comment on Clip B"
curl -s -X POST "$API/v1/posts/$P1/like" \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_ALICE\"}" | jq -r '.ok? // .message? // .error? // "ok"' >/dev/null

curl -s -X POST "$API/v1/posts/$P2/comment" \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_ALICE\",\"body\":\"🔥 nice!\"}" | jq -r '.ok? // .message? // .error? // "ok"' >/dev/null

# optional: add a second like to Clip B to show weight differences
curl -s -X POST "$API/v1/posts/$P2/like" \
  -H 'content-type: application/json' \
  -d "{\"userId\":\"$U_ALICE\"}" >/dev/null

# --- recompute trending cache for 48h window ---
say "refresh trending_cache(48)"
psql "$DATABASE_URL" -q -c "SELECT refresh_trending_cache(48);"

# --- trending after signals (+personalized for Alice) ---
say "trending after signals"
curl -s "$API/v1/trending?window=48h&limit=10" | jq .

say "personalized for Alice (+10% follow boost)"
curl -s "$API/v1/trending?window=48h&limit=10&userId=$U_ALICE" | jq .

# --- raw cache peek (so you can see counts & scores) ---
say "raw cache (top 10)"
psql "$DATABASE_URL" -c "
  SELECT object_type, title, likes_count, comments_count, follows_count, score
  FROM trending_cache
  WHERE window_hours=48
  ORDER BY score DESC, created_at DESC
  LIMIT 10;
"
