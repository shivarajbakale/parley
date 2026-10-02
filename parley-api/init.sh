#!/usr/bin/env bash
# Canonical session-start script. Idempotent — safe to run any time.
#
# Honors $NPM_BIN if set, otherwise uses whatever `npm` is on PATH.
# Set RUN_DEV=1 to launch the dev server after verification.
#
# Steps: ensure .env -> install -> generate Prisma client -> push the SQLite
# schema -> type-check -> lint -> tests (Level 1+2) -> DB-backed e2e (Level 3).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

NPM="${NPM_BIN:-npm}"

echo "==> Working directory: $PWD"
echo "==> Using npm at: $(command -v "$NPM" || echo "$NPM")"

if [ ! -f .env ]; then
  echo "==> Creating .env from .env.example"
  cp .env.example .env
fi

echo "==> Installing dependencies ($NPM install)"
"$NPM" install

echo "==> Generating Prisma client"
"$NPM" run db:generate

echo "==> Pushing the database schema (prisma db push)"
"$NPM" run db:push

echo "==> Type-check"
"$NPM" run type-check

echo "==> Lint"
"$NPM" run lint

echo "==> Tests (Level 1 + 2: routing, validation, error envelope)"
"$NPM" run test

echo "==> End-to-end tests (Level 3: full stack against the database)"
RUN_DB_TESTS=1 "$NPM" run test

echo
echo "==> Baseline verification passed."
echo "    Run 'make dev' (or RUN_DEV=1 ./init.sh) to launch the server."

if [ "${RUN_DEV:-0}" = "1" ]; then
  echo "==> Launching the dev server"
  exec "$NPM" run dev
fi
