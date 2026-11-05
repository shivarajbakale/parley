# Standard targets called from AGENTS.md / CLAUDE.md.
# Honors $NPM_BIN, otherwise uses `npm` from PATH.

NPM ?= $(if $(NPM_BIN),$(NPM_BIN),npm)

.PHONY: help setup type-check lint test plan-lint skill-lint doc-lint loop-lint \
	api-check android-check macos-check check engine app run api clean commit-feature

help:
	@echo "Targets:"
	@echo "  setup        npm install (engine, parley-agent, parley-api)"
	@echo "  check        type-check + lint + test + plan/skill/doc/loop lints + api, android and macos checks"
	@echo "  engine       bundle the engine and its Node runtime into macos/build/engine"
	@echo "  app          build Parley Native.app (Debug)"
	@echo "  run          build and open the app"
	@echo "  api          run parley-api, the Parley server (keys in parley-api/.env)"
	@echo "  clean        remove node_modules and native build output"

setup:
	$(NPM) install
	$(NPM) --prefix parley-agent install
	$(NPM) --prefix parley-api install

type-check:
	$(NPM) run type-check

lint:
	$(NPM) run lint

test:
	$(NPM) test

# A feature in flight has a plan, or says why it needs none. See scripts/plan-lint.mjs.
plan-lint:
	$(NPM) run plan-lint

skill-lint:
	$(NPM) run skill-lint

doc-lint:
	$(NPM) run doc-lint

loop-lint:
	$(NPM) run loop-lint

api-check:
	$(NPM) --prefix parley-api run check

# The Android app verifies with its own harness. Skipped, not failed, when
# flutter is absent.
android-check:
	@if command -v "$${FLUTTER_BIN:-flutter}" >/dev/null 2>&1; then \
		$(MAKE) -C parley-android check; \
	else \
		echo "android-check: flutter not on PATH, skipped (set FLUTTER_BIN to run it)"; \
	fi

# The native macOS app: ParleyCore unit tests. Skipped off macOS (it imports
# AppKit) or without a Swift toolchain.
macos-check:
	@if [ "$$(uname)" = Darwin ] && command -v swift >/dev/null 2>&1; then \
		$(MAKE) -C macos test; \
	else \
		echo "macos-check: needs macOS and Swift, skipped"; \
	fi

check: setup type-check lint test plan-lint skill-lint doc-lint loop-lint api-check android-check macos-check

engine:
	$(NPM) run build:engine

app:
	$(MAKE) -C macos build

run:
	$(MAKE) -C macos run

# The Parley server: holds the provider keys (parley-api/.env) and answers
# transcription, voice edit, Explain and the agent's model.
api:
	$(NPM) --prefix parley-api start

clean:
	rm -rf node_modules
	$(MAKE) -C macos clean

commit-feature: ## Commit the work for any feature that just reached `passing` (runs make check first)
	node .claude/hooks/commit-feature.mjs
