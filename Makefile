SHELL := /bin/bash
DEV := docker compose -f docker-compose.dev.yml
MIX := deploy/scripts/mix
TEST := $(DEV) run --rm -T -e MIX_ENV=test toolbox mix

.PHONY: help setup dev dev-api dev-web stop test test-unit test-integration test-bitcoin test-e2e test-resilience test-web lint format benchmark reset-sandbox up down logs codegen admin

help:
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

setup: ## Install dependencies and prepare development databases
	pnpm install
	$(DEV) build toolbox
	$(DEV) up -d postgres bitcoin-0 bitcoin-1
	$(MIX) deps.get
	$(DEV) exec -T postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='satops_dev'" | grep -q 1 || $(DEV) exec -T postgres psql -U postgres -c "CREATE DATABASE satops_dev"
	$(MIX) ecto.migrate

dev: ## Run development dependencies (Postgres and two regtest nodes)
	$(DEV) up -d postgres bitcoin-0 bitcoin-1

dev-api: ## Run the Phoenix API in development mode on :4000
	$(DEV) run --rm --service-ports -p 127.0.0.1:4000:4000 toolbox mix phx.server

dev-web: ## Run the Vite dev server on :5173
	pnpm --filter @satops/web dev

stop: ## Stop development dependencies
	$(DEV) down

test: test-unit test-integration test-bitcoin test-web ## Run every automated suite except e2e

test-unit: ## Backend unit and property tests (no external services)
	$(TEST) test --exclude integration --exclude bitcoin

test-integration: ## Backend tests that commit to a real PostgreSQL
	$(TEST) test --only integration

test-bitcoin: ## Backend tests against real Bitcoin Core regtest nodes
	$(TEST) test --only bitcoin

test-resilience: ## Concurrency and crash resilience tests
	$(TEST) test --only resilience

test-web: ## Frontend unit tests, typecheck and lint
	pnpm --filter @satops/web typecheck
	pnpm --filter @satops/web lint
	pnpm --filter @satops/web test
	pnpm --filter @satops/demo-fintech test

test-e2e: ## Playwright against a running stack (SATOPS_E2E_URL, SATOPS_E2E_EMAIL, SATOPS_E2E_PASSWORD)
	pnpm --filter @satops/web test:e2e

lint: ## Formatting and static analysis
	$(MIX) format --check-formatted
	$(MIX) credo --strict
	pnpm --filter @satops/web lint
	pnpm --filter @satops/web format:check

format: ## Format backend and frontend code
	$(MIX) format
	pnpm --filter @satops/web format

codegen: ## Export the GraphQL schema and regenerate TypeScript types
	$(MIX) absinthe.schema.sdl --schema SatOpsWeb.GraphQL.Schema ../../packages/graphql-types/schema.graphql
	pnpm --filter @satops/web codegen

benchmark: ## Run k6 HTTP benchmarks against SATOPS_BENCH_URL
	docker run --rm -i --network host -e SATOPS_BENCH_URL -e SATOPS_BENCH_EMAIL -e SATOPS_BENCH_PASSWORD -v $(PWD)/benchmarks:/bench grafana/k6:1.3.0 run /bench/k6/api.js

up: ## Build and start the sandbox stack
	docker compose up -d --build

down: ## Stop the sandbox stack (volumes are kept)
	docker compose down

logs: ## Follow API logs
	docker compose logs -f api

admin: ## Create the first administrator: make admin EMAIL=you@example.com
	@test -n "$(EMAIL)" || (echo "EMAIL is required" && exit 1)
	docker compose exec -T api /app/bin/sat_ops rpc 'SatOps.Release.create_admin("$(EMAIL)")'

reset-sandbox: ## Destroy sandbox volumes after explicit confirmation
	@deploy/scripts/reset-sandbox.sh

screenshots: ## Regenerate README screenshots against a running stack (SATOPS_E2E_EMAIL, SATOPS_E2E_PASSWORD)
	pnpm --filter @satops/web exec playwright test --config playwright.screenshots.config.ts
