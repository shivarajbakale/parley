#!/usr/bin/env bash
# Bundles the sibling parley-agent checkout (../Mastra/parley-agent) into
# resources/parley-agent, the server the packaged app spawns for act mode.
# Self-contained: `mastra build` emits index.mjs plus chunks with no runtime
# dependencies, and main runs it with ELECTRON_RUN_AS_NODE. Skips the work
# when the bundle is already newer than the checkout. Fails loud when the
# checkout or its node_modules are missing — a packaged app without the
# bundle would ship a dead Agent tab.
set -euo pipefail
cd "$(dirname "$0")/.."

AGENT_DIR=../Mastra/parley-agent
OUT=resources/parley-agent

if [[ ! -d "$AGENT_DIR" ]]; then
  echo "build-agent: no parley-agent checkout at $AGENT_DIR" >&2
  echo "build-agent: scaffold it (see the parley-013 handoff notes), then rebuild" >&2
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
