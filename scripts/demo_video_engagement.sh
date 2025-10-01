#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL}"

say(){ printf '\n\033[1;36m%s\033[0m\n' "$*"; }

# Resolve IDs
U_ALICE=$(psql "$DATABASE_URL" -At -c "SELECT id FROM users WHERE handle='alice' LIMIT 1;")
U_BOB=$(psql "$DATABASE_URL" -At -c "SELECT id FROM users WHERE handle='bob'   LIMIT 1;")
echo "USERS: ALICE=$U_ALICE BOB=$U_BOB"

# Ensure follow (idempotent)
curl -s -X POST http://127.0.0.1:8080/v1/follow \
  -H 'content-type: application/json' \
  -d "{\"follower\":\"$U_ALICE\",\"followee\":\"$U_BOB\"}" >/dev/null

say "Publish a video as Bob"
VID_JSON=$(
  curl -s -X POST http://127.0.0.1:8080/v1/videos \
    -H 'content-type: application/json' \
    -d "{\"userId\":\"$U_BOB\",\"title\":\"Video Z\",\"description\":\"demo\",\"videoUrl\":\"https://cdn.example.com/demo/videoZ.m3u8\",\"thumbnailUrl\":\"https://cdn.example.com/demo/videoZ.jpg\",\"durationSeconds\":33}"
)
echo "$VID_JSON" | jq .
VID=$(echo "$VID_JSON" | jq -r '.video.id // .id // empty')

if [ -n "${VID:-}" ]; then
  say "Engagement: Alice likes and comments"
  curl -s -X POST "http://127.0.0.1:8080/v1/videos/$VID/like" \
    -H 'content-type: application/json' \
    -d "{\"userId\":\"$U_ALICE\"}" | jq .

  curl -s -X POST "http://127.0.0.1:8080/v1/videos/$VID/comment" \
    -H 'content-type: application/json' \
    -d "{\"userId\":\"$U_ALICE\",\"body\":\"🔥 nice video!\"}" | jq .
fi

say "Recompute trending(48h) and fetch"
psql "$DATABASE_URL" -q -c "SELECT refresh_trending_cache(48);"
curl -s "http://127.0.0.1:8080/v1/trending?window=48h&limit=10" | jq .
