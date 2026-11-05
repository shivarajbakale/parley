#!/usr/bin/env bash
# Bundles the headless engine (engine/headless/main.ts, no Electron imports)
# into one ESM file for the native shell, and lays down the Node runtime that
# runs it. Output: macos/build/engine/{engine.mjs,node}, which the Xcode
# project copies into Parley.app/Contents/Resources.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/macos/build/engine"
mkdir -p "$OUT"

VERSION="$(node -p "require('$ROOT/package.json').version")"

"$ROOT/node_modules/.bin/esbuild" "$ROOT/engine/headless/main.ts" \
  --bundle \
  --platform=node \
  --format=esm \
  --target=node22 \
  --define:process.env.PARLEY_ENGINE_VERSION="\"$VERSION\"" \
  --outfile="$OUT/engine.mjs" \
  --log-level=warning

# The runtime is an official, statically linked Node release, pinned and
# checksum-verified. A package-manager node (Homebrew) links its own dylibs
# and cannot be copied into an app bundle. PARLEY_NODE overrides it with a
# binary you trust to be self-contained.
NODE_VERSION="v24.22.1"
ARCH="$(uname -m)"; [ "$ARCH" = "x86_64" ] && ARCH="x64"
DIST="node-$NODE_VERSION-darwin-$ARCH"
CACHE="$ROOT/macos/build/cache"
if [ -n "${PARLEY_NODE:-}" ]; then
  cp -f "$PARLEY_NODE" "$OUT/node"
else
  if [ ! -x "$CACHE/$DIST/bin/node" ]; then
    mkdir -p "$CACHE"
    curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/$DIST.tar.gz" -o "$CACHE/$DIST.tar.gz"
    curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/SHASUMS256.txt" -o "$CACHE/SHASUMS256-$NODE_VERSION.txt"
    EXPECTED="$(grep " $DIST.tar.gz\$" "$CACHE/SHASUMS256-$NODE_VERSION.txt" | cut -d' ' -f1)"
    ACTUAL="$(shasum -a 256 "$CACHE/$DIST.tar.gz" | cut -d' ' -f1)"
    if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
      echo "build-engine: checksum mismatch for $DIST.tar.gz" >&2
      rm -f "$CACHE/$DIST.tar.gz"
      exit 1
    fi
    tar -xzf "$CACHE/$DIST.tar.gz" -C "$CACHE" "$DIST/bin/node"
    rm -f "$CACHE/$DIST.tar.gz"
  fi
  cp -f "$CACHE/$DIST/bin/node" "$OUT/node"
fi
chmod 755 "$OUT/node"

echo "build-engine: $OUT/engine.mjs ($(du -h "$OUT/engine.mjs" | cut -f1)), node $("$OUT/node" --version)"
