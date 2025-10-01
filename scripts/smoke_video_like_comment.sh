#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL}"

die(){ echo -e "\e[31m$*\e[0m" >&2; exit 1; }
say(){ echo -e "\e[36m$*\e[0m"; }

# Wait for API
for i in {1..30}; do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null; then
    say "API healthy ✅"
    break
  fi
  [[ $i -eq 30 ]] && die "API /health never became ready."
  sleep 0.5
done

U_BOB=$(psql "$DATABASE_URL" -At -c "SELECT id FROM users WHERE handle='bob' LIMIT 1;") || die "could not get bob id"
U_ALICE=$(psql "$DATABASE_URL" -At -c "SELECT id FROM users WHERE handle='alice' LIMIT 1;") || die "could not get alice id"
say "USERS: bob=$U_BOB alice=$U_ALICE"

# Create a video
VID_JSON=$(curl -fsS -X POST http://127.0.0.1:8080/v1/videos \
  -H 'content-type: application/json' \
  -d '{"userId":"'"$U_BOB"'","title":"Smoke Video","description":"demo","hlsUrl":"https://example.com/demo.m3u8","durationSeconds":9}') \
  || die "POST /v1/videos failed"
echo "$VID_JSON" | jq .
VID=$(echo "$VID_JSON" | jq -r '.id // .video.id')
[[ -n "$VID" && "$VID" != "null" ]] || die "no video id in response"

say "VID=$VID"

# Like
curl -fsS -X POST "http://127.0.0.1:8080/v1/videos/$VID/like" \
  -H 'content-type: application/json' \
  -d '{"userId":"'"$U_ALICE"'"}' | jq . || die "like failed"

# Comment
curl -fsS -X POST "http://127.0.0.1:8080/v1/videos/$VID/comment" \
  -H 'content-type: application/json' \
  -d '{"userId":"'"$U_ALICE"'","body":"🔥 nice video!"}' | jq . || die "comment failed"

# Recompute & fetch trending
psql "$DATABASE_URL" -q -c "SELECT refresh_trending_cache(48);" >/dev/null || die "refresh_trending_cache failed"

say "== Plain trending =="
curl -fsS "http://127.0.0.1:8080/v1/trending?window=48h&limit=5" | jq .

say "== Personalized (Alice) =="
curl -fsS "http://127.0.0.1:8080/v1/trending?window=48h&limit=5&userId=$U_ALICE" | jq .
