![CI](https://github.com/allwaysblazin101/cliplaunch/actions/workflows/ci.yml/badge.svg) ![CodeQL](https://github.com/allwaysblazin101/cliplaunch/actions/workflows/codeql.yml/badge.svg)

# Cliplaunch

Fastify API + Postgres schema for posts, videos, and trending.

## Dev
- `pnpm i`
- `pnpm run dev:api` (API on :8080)
- `psql $DATABASE_URL -f sql/001_core.sql` (see /sql for migrations)

## Scripts
See `/scripts` for smoketests, seeders, and demo flows.
