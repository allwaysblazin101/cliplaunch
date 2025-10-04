#!/bin/bash
set -euo pipefail

echo "==== Cliplaunch System Audit ===="
date
echo

echo "[1/5] 🔍 Checking container health..."
docker-compose ps

echo "[2/5] 🧠 DB Connectivity Check..."
docker-compose exec -T db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT count(*) FROM creators;"' || echo "DB check failed!"

echo "[3/5] 📊 Table Row Counts..."
docker-compose exec -T db bash -lc '
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "
SELECT '\''videos'\'' AS table, count(*) FROM videos
UNION ALL SELECT '\''video_likes'\'', count(*) FROM video_likes
UNION ALL SELECT '\''video_comments'\'', count(*) FROM video_comments
UNION ALL SELECT '\''creators'\'', count(*) FROM creators
UNION ALL SELECT '\''users'\'', count(*) FROM users
UNION ALL SELECT '\''wallets'\'', count(*) FROM wallets;
"'

echo "[4/5] ⚙️ API Health..."
curl -fsS http://127.0.0.1:8080/health | jq . || echo "API health check failed!"

echo "[5/5] 🔁 Trending Cache Summary..."
docker-compose exec -T db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM trending_cache;"'

echo
echo "✅ Audit complete."
