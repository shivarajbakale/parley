#!/usr/bin/env bash
# Bundles the in-repo parley-agent project (parley-agent/) into
# resources/parley-agent, the server the packaged app spawns for act mode.
# `mastra build` emits index.mjs plus its node_modules (~200M; externals
# cannot be bundled on mastra 1.30), and main runs it with
# ELECTRON_RUN_AS_NODE. Skips the work when the bundle is already newer
# than the project. Fails loud when node_modules are missing — a packaged
# app without the bundle would ship a dead Agent tab.
set -euo pipefail
cd "$(dirname "$0")/.."

AGENT_DIR=parley-agent
OUT=resources/parley-agent

if [[ ! -d "$AGENT_DIR" ]]; then
  echo "build-agent: no parley-agent project at $AGENT_DIR" >&2
  exit 1
fi
if [[ ! -x "$AGENT_DIR/node_modules/.bin/mastra" ]]; then
  echo "build-agent: $AGENT_DIR has no installed Mastra CLI" >&2
  echo "build-agent: run \`npm install\` in $AGENT_DIR, then rebuild" >&2
  exit 1
fi
if [[ -f "$OUT/index.mjs" && -z "$(find "$AGENT_DIR/src" "$AGENT_DIR/package.json" -newer "$OUT/index.mjs" 2>/dev/null)" ]]; then
  exit 0
fi

(cd "$AGENT_DIR" && ./node_modules/.bin/mastra build)
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$AGENT_DIR/.mastra/output/." "$OUT/"
echo "build-agent: bundled $AGENT_DIR/.mastra/output into $OUT"
