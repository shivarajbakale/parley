#!/usr/bin/env bash
# Canonical session-start script. Idempotent — safe to run any time.
# This is the standard startup path referenced by AGENTS.md / claude-progress.md.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "==> Working directory: $PWD"

echo "==> Installing dependencies (npm install)"
npm install
npm --prefix parley-agent install
echo "==> API dependencies (parley-api)"
(cd parley-api && [ -f .env ] || cp .env.example .env)
npm --prefix parley-api install
if command -v "${FLUTTER_BIN:-flutter}" >/dev/null 2>&1; then
  echo "==> Android dependencies (flutter pub get)"
  (cd parley-android && "${FLUTTER_BIN:-flutter}" pub get)
else
  echo "==> flutter not on PATH: skipping parley-android (set FLUTTER_BIN to include it)"
fi

echo
echo "==> Baseline verification passed."
echo "    Next: read claude-progress.md and feature_list.json, pick the one"
echo "    highest-priority unfinished feature, and run 'make check' before you stop."
