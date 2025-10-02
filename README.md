![CI](https://github.com/allwaysblazin101/cliplaunch/actions/workflows/ci.yml/badge.svg) ![CodeQL](https://github.com/allwaysblazin101/cliplaunch/actions/workflows/codeql.yml/badge.svg)

# Cliplaunch

Fastify API + Postgres schema for posts, videos, and trending.

## Dev
- `pnpm i`
- `pnpm run dev:api` (API on :8080)
- `psql $DATABASE_URL -f sql/001_core.sql` (see /sql for migrations)

## Scripts
See `/scripts` for smoketests, seeders, and demo flows.

## Environment

| Var | Default | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `postgres://cliplaunch:beams@localhost:5432/cliplaunch` | Postgres DSN |
| `PUB32` | `1111...` | Mock pubkey used by scripts |

## Branch / PR flow

- Feature branches: `feat/...`, `fix/...`, `chore/...`
- Open PR → CI must be green (lint, types, migrate, smoke)
- Squash merge to `main`.

## Repo standards

- Node version pinned in `.nvmrc`
- Keep PRs small; update SQL in idempotent, re-runnable files
- Run `make smoke` locally before PR if you changed DB/API.
