SHELL := /usr/bin/env bash
COMPOSE := docker-compose

export DATABASE_URL ?= postgres://cliplaunch:beams@db:5432/cliplaunch
export PUB32 ?= 11111111111111111111111111111111

.PHONY: up down ps logs migrate api health smoke

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down -v

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200

# Run every sql/NNN_*.sql file in lexicographic order inside the db container
migrate:
	@set -euo pipefail; \
	echo ">> migrate: running ordered SQL files"; \
	for f in $$(ls -1 sql/[0-9][0-9][0-9]_*.sql 2>/dev/null | sort); do \
		echo ">> running $$f"; \
		$(COMPOSE) exec -T db sh -lc "psql -U \$$POSTGRES_USER -d \$$POSTGRES_DB -v ON_ERROR_STOP=1 -f /app/$$f"; \
	done; \
	echo ">> migrate: done"

api:
	$(COMPOSE) up -d api

health:
	curl -fsS http://127.0.0.1:8080/health | jq .

smoke:
	$(COMPOSE) exec -T api bash -lc 'DATABASE_URL="$$DATABASE_URL" PUB32="$$PUB32" scripts/run_regression.sh'

# ---- Database Seeding ----
seed:
	@echo ">> Seeding demo data..."
	docker-compose exec -T db bash -lc 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /app/scripts/seed_demo.sql'
	@echo ">> Demo data seeded successfully."

# ==== Demo Bring-up ====

.PHONY: demo demo-clean migrate api seed health smoke status

demo: ## Full demo: db up, migrate, seed, api, health, smoke
	@echo ">> Starting DB..."
	docker-compose up -d db
	@$(MAKE) migrate
	@$(MAKE) seed
	@$(MAKE) api
	@$(MAKE) health
	@$(MAKE) smoke
	@echo ">> Demo ready. API on http://127.0.0.1:8080"

demo-clean: ## Nuke containers + volumes and re-run demo
	docker-compose down -v
	$(MAKE) demo

migrate: ## Run ordered SQL files inside the API container
	@echo ">> migrate"
	docker-compose exec -T api bash -lc 'node packages/api/src/index.js --migrate-only || true'

api: ## Start API in background
	@echo ">> api up"
	docker-compose up -d api
	@sleep 2

seed: ## Seed demo data
	@echo ">> Seeding demo data..."
	docker-compose exec -T db bash -lc 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -f /app/scripts/seed_demo.sql'
	@echo ">> Demo data seeded."

health: ## Check /health
	@echo ">> /health"
	curl -fsS http://127.0.0.1:8080/api/health | jq .

smoke: ## Minimal smoke of routes + counts
	@echo ">> Route sanity"
	- curl -fsS http://127.0.0.1:8080/api/creators | jq '.[0]'
	- curl -fsS http://127.0.0.1:8080/api/videos   | jq '.[0]'
	@echo ">> Counts"
	docker-compose exec -T db bash -lc 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -c "SELECT count(*) FROM videos; SELECT count(*) FROM video_likes; SELECT count(*) FROM video_comments;"'

status: ## System audit
	./scripts/status.sh

