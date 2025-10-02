SHELL := /usr/bin/env bash

export DATABASE_URL ?= postgres://cliplaunch:beams@localhost:5432/cliplaunch
export PUB32 ?= 11111111111111111111111111111111

.PHONY: setup db-up migrate api health smoke fmt

setup:
	pnpm install --frozen-lockfile

db-up:
	docker run --rm --name pg -e POSTGRES_PASSWORD=beams -e POSTGRES_USER=cliplaunch \
	-e POSTGRES_DB=cliplaunch -p 5432:5432 -d postgres:16

migrate:
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f sql/001_core.sql
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f sql/010_posts_videos.sql

api:
	pnpm --filter packages/api dev

health:
	curl -fsS http://127.0.0.1:8080/health | jq .

smoke:
	bash scripts/run_regression.sh

fmt:
	find . -name '*.sql' -print0 | xargs -0 -I{} sh -c 'sed -i "s/[ \t]*$$//" "{}"'
