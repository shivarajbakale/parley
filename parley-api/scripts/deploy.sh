#!/usr/bin/env bash
# Deploy this app to a self-hosted box (Mac mini / VPS) over SSH — registry-less.
#
# It ships the source, then builds + runs the container on the remote with the
# production compose file. Building on the remote sidesteps CPU-arch mismatches
# (e.g. building on an x86 laptop for an arm64 Mac mini).
#
# Requirements on the remote: Docker (with `docker compose`) + your SSH key.
#
# Usage:
#   DEPLOY_HOST=you@mini npm run deploy
#   DEPLOY_HOST=you@vps DEPLOY_DIR=/srv/api npm run deploy
#
# Env:
#   DEPLOY_HOST  (required)  ssh target, e.g. user@host
#   DEPLOY_DIR   (optional)  remote dir; default: apps/<package-name>
set -euo pipefail

: "${DEPLOY_HOST:?set DEPLOY_HOST=user@host}"
APP="$(node -p "require('./package.json').name")"
DIR="${DEPLOY_DIR:-apps/$APP}"
COMPOSE="docker-compose.prod.yml"

echo "==> deploying '$APP' to $DEPLOY_HOST:$DIR"

ssh "$DEPLOY_HOST" "mkdir -p '$DIR'"

# Ship source. node_modules/dist/.git are rebuilt on the remote; .env is NOT
# synced (--delete would wipe remote secrets) — set it once on the remote.
rsync -az --delete \
  --exclude node_modules --exclude dist --exclude .git \
  --exclude '.env' --exclude '*.log' --exclude 'prisma/dev.db*' \
  ./ "$DEPLOY_HOST:$DIR/"

echo "==> building + starting on remote"
ssh "$DEPLOY_HOST" "cd '$DIR' && docker compose -f '$COMPOSE' up -d --build"

echo "==> done — '$APP' is up on $DEPLOY_HOST"
echo "    logs:  ssh $DEPLOY_HOST 'cd $DIR && docker compose -f $COMPOSE logs -f'"
