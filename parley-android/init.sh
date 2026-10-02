#!/usr/bin/env bash
# Canonical session-start script. Idempotent — safe to run any time.
#
# Honors $FLUTTER_BIN if set, otherwise falls back to whatever `flutter` is on
# PATH. Set RUN_DEV=1 to launch `flutter run` after verification.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

FLUTTER="${FLUTTER_BIN:-flutter}"

# Check the toolchain before using it. Without this, `set -e` kills the script
# on the first `flutter` call with a bare "command not found" and no hint that
# FLUTTER_BIN exists or where to get Flutter.
if ! FLUTTER_PATH="$(command -v "$FLUTTER" 2>/dev/null)"; then
  echo "==> flutter not found — install Flutter or set FLUTTER_BIN" >&2
  echo "    tried:   $FLUTTER" >&2
  echo "    install: https://docs.flutter.dev/get-started/install" >&2
  echo "    or:      FLUTTER_BIN=/path/to/flutter ./init.sh" >&2
  exit 1
fi

echo "==> Working directory: $PWD"
echo "==> Using flutter at: $FLUTTER_PATH"
echo "==> $("$FLUTTER" --version 2>/dev/null | head -1)"

echo "==> Syncing dependencies (flutter pub get)"
"$FLUTTER" pub get

echo "==> Static analysis (flutter analyze)"
"$FLUTTER" analyze

echo "==> Design-system contract (dart run tool/ui_lint.dart)"
dart run tool/ui_lint.dart

echo "==> Design-system reference (dart run tool/design_system_reference.dart --check)"
dart run tool/design_system_reference.dart --check

echo "==> Feature-plan lint (dart run tool/plan_lint.dart)"
dart run tool/plan_lint.dart

echo "==> DS catalog check (regenerate and verify against lib/design_system/)"
if ! dart run tool/generate_ds_catalog.dart > /tmp/ds-catalog-init.txt 2>&1; then
  cat /tmp/ds-catalog-init.txt
  exit 1
fi
# The drift check needs a repository to diff against. A project scaffolded with
# --skip-git has none, and `git diff` exits 128 there — which this read as
# "stale" and failed on, so the freshly generated project's own init.sh could
# never pass. `make ds-catalog-check` has carried this guard all along; this
# copy did not.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "    no git repository — regenerated, drift not checked."
elif ! git diff --quiet tool/fixtures/ds-catalog.json; then
  echo "    ds-catalog.json is stale vs. lib/design_system/."
  echo "    Run \`make ds-catalog\` and commit the regenerated file."
  exit 1
fi

echo "==> Superplan lint (dart run tool/superplan_lint.dart)"
dart run tool/superplan_lint.dart

echo "==> Doc-lint (dart run tool/doc_lint.dart)"
dart run tool/doc_lint.dart

echo "==> Tests (flutter test)"
"$FLUTTER" test

echo
echo "==> Baseline verification passed."
echo "    Run 'make dev' (or RUN_DEV=1 ./init.sh) to launch the app."

if [ "${RUN_DEV:-0}" = "1" ]; then
  echo "==> Launching the app"
  exec "$FLUTTER" run
fi
