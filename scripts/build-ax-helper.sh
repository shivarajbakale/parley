#!/usr/bin/env bash
# Compiles native/parley-ax.swift into resources/parley-ax, the helper voice
# edit reads the focused text field with. Universal, so one build serves both
# Apple silicon and Intel. Skips the work when the binary is already current.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=native/parley-ax.swift
OUT=resources/parley-ax

if [[ "$(uname)" != "Darwin" ]]; then
  echo "build-ax-helper: macOS only, skipping"
  exit 0
fi
if [[ -x "$OUT" && "$OUT" -nt "$SRC" ]]; then
  exit 0
fi

mkdir -p resources
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos11" "$SRC" -o "$TMP/parley-ax-$arch"
done
lipo -create "$TMP"/parley-ax-* -output "$OUT"
echo "build-ax-helper: built $OUT"
