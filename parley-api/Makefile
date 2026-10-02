# Standard targets referenced from AGENTS.md / CLAUDE.md.
# Honors $NPM_BIN, otherwise uses `npm` from PATH.

NPM ?= $(if $(NPM_BIN),$(NPM_BIN),npm)

.PHONY: setup generate db seed type-check lint test e2e check verify dev build start studio clean help plan-lint db-lint api-lint capability-lint doc-links boot-check commit-feature doc-lint loop-lint

help:
	@echo "Targets:"
	@echo "  setup       npm install (runs prisma generate via postinstall)"
	@echo "  generate    prisma generate"
	@echo "  db          prisma db push (create/sync the SQLite schema)"
	@echo "  seed        prisma db seed (demo user + todos)"
	@echo "  type-check  tsc --noEmit"
	@echo "  lint        eslint"
	@echo "  test        Level 1+2 tests (no database needed)"
	@echo "  e2e         Level 3 tests (full stack, in a throwaway database)"
	@echo "  check       type-check + lint + plan-lint + db-lint + api-lint + capability-lint + doc-links + test + e2e + boot-check"
	@echo "  verify      db + check + e2e (full pipeline, mirrors ./init.sh)"
	@echo "  dev         start the dev server (hot reload)"
	@echo "  build       compile TypeScript to dist/"
	@echo "  start       run the compiled server"
	@echo "  studio      open Prisma Studio"
	@echo "  clean       remove dist/ and the local SQLite database"

setup:
	$(NPM) install

generate:
	$(NPM) run db:generate

db:
	$(NPM) run db:push

seed:
	$(NPM) run db:seed

type-check:
	$(NPM) run type-check

lint:
	$(NPM) run lint

test:
	$(NPM) run test

# Level 3 in its own throwaway database, so it can run as part of `check`
# without touching the developer's dev.db and without needing one to exist.
# Before this, the DB-backed tier was gated behind RUN_DB_TESTS and `check`
# never set it, so those tests were reported as "skipped" on every run and
# nobody was verifying the stack below the controller.
e2e:
	@tmp=$$(mktemp -d); \
	DATABASE_URL="file:$$tmp/e2e.db" $(NPM) run db:push -- --skip-generate >/dev/null; \
	DATABASE_URL="file:$$tmp/e2e.db" RUN_DB_TESTS=1 $(NPM) run test; \
	status=$$?; rm -rf "$$tmp"; exit $$status

boot-check: build ## Runtime gate — the built server starts, serves, refuses cleanly and stops
	npm run boot-check

api-lint: ## API layering — no database in a controller, no raw env, no hand-built envelope, no leaked stack
	npm run api-lint

capability-lint: ## Capability map — every row names a real call, a real package, a real layer, a real file
	npm run capability-lint

doc-links: ## Source contract — the capability map's references are the vendor's own docs, and recently read
	npm run doc-links

db-lint: ## Database contract — schema, DATABASE_URL and every provider named in code agree
	npm run db-lint

plan-lint: ## Planning contract — every feature plan validates and FEATURE-PLAN.md matches its source
	npm run plan-lint

doc-lint: ## Instruction budget — the harness files stay small, true and non-duplicating
	npm run doc-lint

loop-lint: ## Goal contracts — the definition of done was written first, and something ran against it
	npm run loop-lint

check: type-check lint plan-lint db-lint api-lint capability-lint doc-links test e2e boot-check doc-lint loop-lint

verify: db check

dev:
	$(NPM) run dev

build:
	$(NPM) run build

start:
	$(NPM) start

studio:
	$(NPM) run db:studio

clean:
	rm -rf dist prisma/dev.db prisma/dev.db-journal

commit-feature: ## Commit the work for any feature that just reached `passing` (runs make check first)
	node .claude/hooks/commit-feature.mjs
