.DEFAULT_GOAL := help
.PHONY: help up up-d setup down rebuild logs ps backend frontend psql \
        migrate seed console routes \
        test test-back test-front \
        lint lint-back lint-front format

DC := docker compose

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Build images, start db, prepare schema (idempotent — safe to rerun)
	@test -f .env || cp .env.example .env
	$(DC) build
	$(DC) up -d --wait db
	$(DC) run --rm backend bin/rails db:prepare

up: setup ## Foreground: ensure setup then start all services with logs (Ctrl+C stops)
	$(DC) up

up-d: setup ## Detached: ensure setup then start all services in background
	$(DC) up -d
	@echo "✅ Stack up. Use 'make logs' to follow or visit http://localhost:5173"

down: ## Stop and remove containers (keeps volumes — fast restart with `make up`)
	$(DC) down

rebuild: ## Wipe volumes and start fresh (build + migrate + up)
	$(DC) down -v
	$(MAKE) up

logs: ## Tail logs of all services
	$(DC) logs -f

ps: ## List running services
	$(DC) ps

backend: ## Open a bash shell in the backend container
	$(DC) run --rm backend bash

frontend: ## Open a sh shell in the frontend container
	$(DC) run --rm frontend sh

psql: ## Open psql connected to the dev database
	$(DC) exec db psql -U $${POSTGRES_USER:-locanotes} -d $${POSTGRES_DB:-locanotes_development}

migrate: ## Run pending Rails migrations
	$(DC) run --rm backend bin/rails db:migrate

seed: ## Run db:seed
	$(DC) run --rm backend bin/rails db:seed

console: ## Open Rails console
	$(DC) run --rm backend bin/rails console

routes: ## Show Rails routes
	$(DC) run --rm backend bin/rails routes

test: test-back test-front ## Run all unit tests (backend + frontend)

test-back: ## Run backend RSpec
	$(DC) run --rm backend bin/rspec

test-front: ## Run frontend Vitest (single run)
	$(DC) run --rm --no-deps frontend npm run test:unit -- --run

lint: lint-back lint-front ## Run all linters

lint-back: ## Run RuboCop on backend
	$(DC) run --rm --no-deps backend bin/rubocop

lint-front: ## Run ESLint + Oxlint on frontend
	$(DC) run --rm --no-deps frontend npm run lint

format: ## Run Prettier on frontend
	$(DC) run --rm --no-deps frontend npm run format
