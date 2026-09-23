# Standard targets called from AGENTS.md / CLAUDE.md.
# Honors $FLUTTER_BIN, otherwise uses `flutter` from PATH.

FLUTTER ?= $(if $(FLUTTER_BIN),$(FLUTTER_BIN),flutter)

.PHONY: setup analyze ui-lint palette-lint plan-lint plan superplan-lint superplan doc-lint loop-lint design-md design-md-update design-system-reference design-system-reference-update test ui-probe run-capture golden golden-update eval check dev run-staging run-prod build-prod gen watch clean help commit-feature

help:
	@echo "Targets:"
	@echo "  setup        flutter pub get"
	@echo "  analyze      flutter analyze"
	@echo "  ui-lint      design-system contract (tool/ui_lint.dart)"
	@echo "  palette-lint contrast + separation gates K1..K7 (both themes)"
	@echo "  plan-lint    feature plans validate + FEATURE-PLAN.md is in sync"
	@echo "  plan         render a feature plan: make plan PLAN=<id>.feature-plan.json"
	@echo "  superplan-lint  superplan validates + SUPERPLAN.md is in sync + route/feature coverage"
	@echo "  superplan    render SUPERPLAN.md from SUPERPLAN.json"
	@echo "  doc-lint     the entry files stay inside budget + D1..D9 (same as root doc-lint --strict)"
	@echo "  loop-lint    goal contracts L1..L7 (same seven rules as the Node scaffolders' loop-lint)"
	@echo "  design-md    DESIGN.md matches lib/theme/spec (M1..M3)"
	@echo "  design-md-update rewrite DESIGN.md after a token change"
	@echo "  design-system-reference        verify docs/references matches the kit"
	@echo "  design-system-reference-update rewrite it after adding a component"
	@echo "  test         flutter test (everything except the goldens and the probe)"
	@echo "  ui-probe     level 3: every surface, measured across the matrix"
	@echo "  run-capture  level 3 on a real device: boot the app, keep the frame"
	@echo "  golden       verify the pixel baselines"
	@echo "  golden-update rewrite the baselines after a deliberate visual change"
	@echo "  eval         harness evals: tasks run with and without .claude/ (costs money; not in check)"
	@echo "  check        setup + analyze + ui-lint + palette-lint + plan-lint + superplan-lint + doc-lint + loop-lint + design-md + design-system-reference + test + ui-probe + golden"
	@echo "  dev          flutter run (dev flavor, mock backend)"
	@echo "  run-staging  flutter run against the staging flavor"
	@echo "  run-prod     flutter run against the prod flavor"
	@echo "  build-prod   flutter build (release, prod flavor)"
	@echo "  gen          run build_runner once (freezed + drift codegen)"
	@echo "  watch        run build_runner in watch mode"
	@echo "  clean        flutter clean"

setup:
	$(FLUTTER) pub get

analyze:
# Infos are fatal on purpose. `--no-fatal-infos` let 14 lints sit unread for
# three months while six verification runs recorded "0 errors". A gate that
# reports and passes cannot fail. See DECISIONS.md, 2026-08-28.
	$(FLUTTER) analyze

ui-lint:
# The half `flutter analyze` cannot see: whether the screen went through the
# design system, and whether its colours, motion and shape came from the tokens.
	dart run tool/ui_lint.dart

palette-lint:
# K1..K7 — the half of a design that can be checked rather than reviewed.
# Every rule caught something real in the identity this replaced: five surface
# steps whose neighbours sat at 1.06:1, a ring and its own value label painted
# one colour, a filled success button at 1.82:1 in dark. It is a `flutter test`
# rather than a `dart run` tool because the maths it checks returns `Color`,
# and `dart:ui` does not exist outside the engine — so it also runs inside
# `make test`, which is what makes it a gate rather than a report.
	$(FLUTTER) test test/theme/palette_lint_test.dart

plan-lint:
# A plan is only an artifact if something checks it. Without this, "the JSON is
# the source of truth and FEATURE-PLAN.md is generated" is a sentence in a skill
# file that nothing enforces — and the document drifts from the plan it was
# rendered from the first time somebody fixes a typo in it.
	dart run tool/plan_lint.dart

# Render a feature plan to the document that gets reviewed. `plan-lint` then
# holds the two together.
plan:
	dart run tool/feature_plan.dart $(PLAN) -o FEATURE-PLAN.md

# A superplan is the app-level plan above `feature-plan`: every route the app
# needs, with look-and-feel, best practices, and APIs, all from one
# source-of-truth JSON. `superplan-lint` then holds it together the same way
# `plan-lint` holds a per-feature plan together.
superplan-lint:
	dart run tool/superplan_lint.dart

# Regenerate the DS catalog (`tool/fixtures/ds-catalog.json`) from
# `lib/design_system/*.dart`. The catalog is what every superplan `kit:`
# reference resolves to, and the validator rejects any name the catalog
# doesn't have. Run this target after adding or renaming a DS class —
# never hand-edit `ds-catalog.json`, because the next regeneration would
# silently overwrite the change.
ds-catalog:
	dart run tool/generate_ds_catalog.dart

# Same as `ds-catalog`, but exits non-zero if the on-disk catalog is already
# in sync. Wired into `make check` so a hand-edit (or a stale check-in) is
# caught at commit time. Skipping the run when the file is current keeps the
# commit loop quiet.
ds-catalog-check:
	@if ! dart run tool/generate_ds_catalog.dart > /tmp/ds-catalog-out 2>&1; then \
		echo "make ds-catalog failed"; cat /tmp/ds-catalog-out; exit 1; \
	fi
	@if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		echo "ds-catalog: no git repository — regenerated, drift not checked."; \
	elif ! git diff --quiet -- tool/fixtures/ds-catalog.json; then \
		echo "ds-catalog.json drifted from lib/design_system/"; \
		echo "Run \`make ds-catalog\` and commit the result."; \
		git diff --stat -- tool/fixtures/ds-catalog.json; \
		exit 1; \
	fi

# Render the SUPERPLAN.md from SUPERPLAN.json (writes the doc next to the
# source). Used by the `superplan` skill.
superplan:
	dart run tool/super_plan.dart SUPERPLAN.json -o SUPERPLAN.md

doc-lint:
# The Node `doc-lint.mjs` runs at the repo root and across every Node scaffold.
# This is its Dart counterpart: same nine rules (D1..D9), same budgets, same
# fixtures (tool/fixtures/shared-doc-lint-cases.json). The budget the root
# enforces on the source tree is the same budget the project you receive
# enforces on itself, so a drift that ships from this template fails on the
# next `make check` rather than the next sync to the root repo.
	dart run tool/doc_lint.dart

loop-lint:
# The other half of `scripts/loop-lint.mjs`, which every Node scaffolder runs:
# the same seven rules (L1..L7) against the same corpus
# (tool/fixtures/shared-loop-lint-cases.json). A goal contract is where the
# definition of done gets written before the work rather than after it, and this
# is what refuses one whose verification nothing here can run.
	dart run tool/loop_lint.dart

design-md:
# DESIGN.md is the design system in the one format the outside world reads —
# a tool that has never seen lib/theme/spec/ has no other way to learn what
# this app looks like. It is rendered from the same DesignSpec the app is
# wrapped in, because a stale DESIGN.md is worse than none: a wrong hex is
# followed as confidently as a right one. A `flutter test` for the reason
# `palette-lint` is one — the tokens are Colors grown at construction, and
# `dart:ui` does not exist outside the engine, so a parser cannot read them.
	$(FLUTTER) test test/theme/design_md_test.dart

design-md-update:
	$(FLUTTER) test test/theme/design_md_test.dart --dart-define=WRITE=true

design-system-reference:
# ui_lint forbids hand-rolling a control the kit owns. That is only fair if the
# kit is findable, so it describes itself in docs/references/. This verifies
# rather than writes: a gate that rewrites the tree it is checking cannot fail.
	dart run tool/design_system_reference.dart --check

design-system-reference-update:
	dart run tool/design_system_reference.dart

test:
# Everything except the goldens, which are a separate target because they are
# the only tests whose result depends on the machine they run on, and the
# probe, which is its own target because it is a different kind of claim —
# these tests assert what somebody thought to assert, and the probe asserts
# the same handful of things about every surface there is.
	$(FLUTTER) test --exclude-tags "golden || probe"

# The host the baselines in test/golden/goldens/ were recorded on, as `uname
# -s` reports it. Text rasterisation is not identical across operating
# systems, so a baseline belongs to one of them. If your team works on Linux,
# change this to `Linux`, change the runner of the `goldens` job in
# .github/workflows/ci.yml to match, and run `make golden-update` once.
GOLDEN_HOST ?= Darwin

golden:
	@if [ "$$(uname -s)" != "$(GOLDEN_HOST)" ]; then \
		echo "golden: skipped — baselines belong to $(GOLDEN_HOST), this is $$(uname -s)."; \
		echo "        The goldens job in CI runs them. See GOLDEN_HOST in this Makefile."; \
	else \
		$(FLUTTER) test --tags golden; \
	fi

golden-update:
# Rewrites every baseline. Read the diff before committing it — that reading is
# the review, and it is the only thing standing between a deliberate visual
# change and one nobody noticed.
	$(FLUTTER) test --tags golden --update-goldens

ui-probe:
# Level 3, the gate the other ten scaffolders have and this one did not. It
# mounts every catalog page and every screen across three widths, three text
# scales and both platform skins, and fails on absolute facts: a row that
# overflowed, a control under the tap floor, a page whose subject is below the
# fold. `analyze` reads types, `ui_lint` reads source text, a test checks what
# somebody thought to check, and a golden only fails on a *change* — so none of
# the four grades a first draft. This does.
#
# Inside `make check` rather than beside it, unlike the browser probes in the
# other scaffolders: this one is a widget test, so it costs seconds, and a gate
# that is not in `check` is a gate that runs when somebody remembers.
	$(FLUTTER) test --tags probe

run-capture:
# The one claim no other gate makes: the app starts on a real platform. Every
# target above this line runs the app's code without ever launching the app —
# even `ui-probe`, which mounts real widgets in a binding with no platform under
# it — so a missing usage string, an uninstalled pod or a channel nothing
# answers is green all the way through `check` and dead on the first launch.
#
# Not inside `check`, for the same reason `golden` is not: it needs hardware
# that not every machine running `check` has. It fails rather than skips when
# there is none, and the artifact it leaves is the level-3 evidence.
	tool/run_and_capture.sh $(RUN_CAPTURE_ARGS)

eval:
# Whether the harness helps, not whether one change is good: every task in
# evals/tasks.yaml runs as a real agent in a copy with .claude/ and a copy
# without, graded by this project's own commands. Minutes and dollars per run,
# so it stays out of `check`. See evals/README.md.
	cd evals && npm install --no-audit --no-fund --silent && npm run eval

check: setup ds-catalog-check analyze ui-lint palette-lint plan-lint superplan-lint doc-lint loop-lint design-md design-system-reference test ui-probe golden

dev:
	$(FLUTTER) run --dart-define=ENV=dev

run-staging:
	$(FLUTTER) run --dart-define=ENV=staging

run-prod:
	$(FLUTTER) run --dart-define=ENV=prod

build-prod:
	$(FLUTTER) build apk --release --dart-define=ENV=prod

gen:
	dart run build_runner build

watch:
	dart run build_runner watch

clean:
	$(FLUTTER) clean

commit-feature: ## Commit the work for any feature that just reached `passing` (runs make check first)
	node .claude/hooks/commit-feature.mjs
