SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

export DATABASE_URL ?= postgres://cliplaunch:beams@localhost:5432/cliplaunch
export PUB32        ?= 11111111111111111111111111111111

help: ## show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sed -E 's/:.*?## / - /'

health: ## ping API
	@curl -fsS http://127.0.0.1:8080/health | jq .

start: ## start API (no-op if already running)
	@bash scripts/start_api_bg.sh

seed: ## users + wallet bind + creator row
	@bash scripts/test_flow.sh

demo: ## faucet + build + execute + show feed
	@bash scripts/demo_trade_and_feed.sh

test: ## full regression (start if needed)
	@bash scripts/start_and_test.sh
