# Cliplaunch — Build Status (Single Source of Truth)

_Last updated: $(date)_

## High-level
- Goal: Video + social + on-chain creator economy.
- Stack: Postgres + Node.js (Fastify API) + Docker, with Solana integration coming.

## Database — Current State ✅
Tables present: `creators, videos, tokens, orders, ledger_entries, wallets, users, trades, comments, tips, posts, trending_cache`.
Key points:
- `tokens` uses `creator_id` as PK (no `id` column).
- Engagement schema complete: `video_likes`, `video_comments`, `video_comment_likes`.
- Trending functions operational.
- `posts` table present but legacy (not blocking).

## Recent Fixes
- Fixed token seeding logic for USDC.
- Added idempotent safety to all migrations (skip if objects exist).
- Created engagement core to unblock 032–033 SQL files.
- Relaxed schema hardening to skip `creators.user_id`.
- Disabled duplicate indexes and redundant triggers.

## What Works Now
- `make migrate` ✅ completes successfully.
- `/health` ✅ returns ok.
- DB audit script runs cleanly.
- Engagement triggers installed (likes/comments bump `videos.last_engaged_at`).

## Pending Work
1. Rename or disable `sql/110_posts.sql` (expects `posts.user_id`, fails).
2. Wire API endpoints:
   - `GET /api/videos`
   - `POST /api/videos`
   - `POST /api/videos/:id/like`
   - `POST /api/videos/:id/comment`
   - `POST /api/videos/:id/tip`
   - `GET /api/creators`
   - `GET /api/wallets/:owner/balances`
3. Add sample seed data for creators, users, videos.
4. Cron/Make job to refresh `trending_cache`.
5. Add Solana RPC wallet sync and transaction verification.

## Guardrails
- All migrations must be idempotent.
- Legacy “posts” schema excluded from new logic.
- Token schema remains stable (no added `id` column).

## Quick Checklist
- [ ] `make migrate` from clean DB succeeds  
- [ ] `/health` returns `{"ok": true}`  
- [ ] Demo data seeded  
- [ ] `/api/videos` and `/api/creators` routes live  
- [ ] Likes/comments insert and bump engagement timestamp  
- [ ] Trending refresh populates entries  
