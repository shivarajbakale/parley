#!/usr/bin/env bash
# run_and_capture — boot this app on a real simulator/device and keep the frame.
#
# Every other gate in `make check` runs the app's code without ever starting the
# app. `flutter analyze` reads types, `ui_lint` reads source text, `flutter test`
# checks what somebody thought to check, and `ui-probe` — the level-3 gate —
# mounts every surface in a widget-test binding, which is a Flutter engine with
# no platform under it. None of them link the native host, register a plugin, or
# read Info.plist, so an app can be green on all four and die on launch: a
# missing usage string, a plugin whose iOS half was never pod-installed, a
# `main()` that awaits a channel nothing answers.
#
# That gap used to be covered by a sentence — AGENTS.md constraint 3 says a
# screen is not verified until it ran on a simulator, and the instruction for
# doing it was "delegate to devops". A claim with nothing behind it passes
# whenever the claimant says it did. This is the same claim with an artifact and
# an exit code behind it:
#
#   tool/run_and_capture.sh                 # first screenshot-capable device
#   tool/run_and_capture.sh -d <device-id>  # a specific one
#   tool/run_and_capture.sh -o shot.png     # somewhere other than the default
#   tool/run_and_capture.sh --env staging   # a flavor other than dev
#
# What it proves: the app compiled for a real platform, the engine started, the
# framework reached its first frame, and something other than a blank rectangle
# was painted.
#
# What it does NOT prove: that any *particular* screen is correct. It captures
# the launch frame and cannot navigate — the router sets `initialLocation`
# explicitly, so `flutter run --route` is ignored, and the app registers no URL
# scheme to deep-link into. Driving to a named screen is a feature of its own;
# until it exists, a screen-level claim still needs a human or the devops agent
# on top of this.
#
# There is no skip path. A machine with no device fails, loudly, with the device
# list it did see — a gate that reports and passes cannot fail, which is the
# same reasoning that made `flutter analyze` fatal on infos (DECISIONS.md,
# 2026-08-28).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER="${FLUTTER_BIN:-flutter}"

DEVICE_ID="${RUN_CAPTURE_DEVICE:-}"
OUT_PATH=""
APP_ENV="dev"
# A debug build of a clean tree is a full Xcode/Gradle build the first time —
# minutes, not seconds. The timeout is the point at which we stop believing it
# is still working rather than hung.
TIMEOUT_SECS="${RUN_CAPTURE_TIMEOUT:-600}"

# A screenshot of a blank frame is a screenshot. A solid rectangle at phone
# resolution is a few kilobytes of PNG; a rendered screen with text on it is
# hundreds. This floor is the anti-vacuity rule: it does not grade the design,
# it refuses to accept "the app launched" from an image with nothing in it.
MIN_PNG_BYTES="${RUN_CAPTURE_MIN_BYTES:-40000}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--device) DEVICE_ID="${2:-}"; shift 2 ;;
    -o|--out)    OUT_PATH="${2:-}";  shift 2 ;;
    --env)       APP_ENV="${2:-}";   shift 2 ;;
    --timeout)   TIMEOUT_SECS="${2:-}"; shift 2 ;;
    -h|--help)   sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "run_and_capture: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# ── Pick a device ───────────────────────────────────────────────────────────
#
# `capabilities.screenshot` is Flutter's own answer to "can I photograph this",
# so the predicate is read off the device list rather than guessed from the
# platform: an iOS simulator and an Android emulator say true, a physical iPhone,
# macOS and Chrome all say false. Selecting on the capability means this script
# needs no per-platform branch and gains new device types for free.
DEVICES_JSON="$($FLUTTER devices --machine 2>/dev/null || true)"

if ! printf '%s' "$DEVICES_JSON" | grep -q '^  {'; then
  echo "run_and_capture: could not read \`$FLUTTER devices --machine\`." >&2
  echo "  Either no Flutter toolchain is on PATH, or its machine output is no" >&2
  echo "  longer the pretty-printed array this script parses. Run the command" >&2
  echo "  by hand to see which." >&2
  exit 1
fi

# Physical devices sort after emulated ones: a simulator is reproducible and
# always unlocked, which is what an unattended gate wants.
CANDIDATES="$(printf '%s\n' "$DEVICES_JSON" | awk '
  /^  \{/                          { id=""; name=""; sup=0; shot=0; emu=0 }
  /^    "id": /                    { id=$0;   sub(/^    "id": "/,   "", id);   sub(/",?$/, "", id) }
  /^    "name": /                  { name=$0; sub(/^    "name": "/, "", name); sub(/",?$/, "", name) }
  /^    "isSupported": true/       { sup=1 }
  /^    "emulator": true/          { emu=1 }
  /^      "screenshot": true/      { shot=1 }
  /^  \}/ { if (sup && shot && id != "") printf "%d\t%s\t%s\n", (emu ? 0 : 1), id, name }
' | sort -n)"

if [ -z "$CANDIDATES" ]; then
  echo "run_and_capture: no screenshot-capable device is available." >&2
  echo "  Boot an iOS simulator (\`open -a Simulator\`) or an Android emulator" >&2
  echo "  (\`emulator -list-avds\` then \`emulator -avd <name>\`) and try again." >&2
  echo "  Flutter currently sees:" >&2
  $FLUTTER devices 2>&1 | sed 's/^/    /' >&2
  exit 1
fi

if [ -n "$DEVICE_ID" ]; then
  if ! printf '%s\n' "$CANDIDATES" | cut -f2 | grep -qx -- "$DEVICE_ID"; then
    echo "run_and_capture: device '$DEVICE_ID' is not a screenshot-capable device." >&2
    echo "  Candidates:" >&2
    printf '%s\n' "$CANDIDATES" | awk -F'\t' '{ printf "    %s  (%s)\n", $2, $3 }' >&2
    exit 1
  fi
  DEVICE_NAME="$(printf '%s\n' "$CANDIDATES" | awk -F'\t' -v id="$DEVICE_ID" '$2 == id { print $3; exit }')"
else
  DEVICE_ID="$(printf '%s\n' "$CANDIDATES" | head -1 | cut -f2)"
  DEVICE_NAME="$(printf '%s\n' "$CANDIDATES" | head -1 | cut -f3)"
fi

if [ -z "$OUT_PATH" ]; then
  OUT_PATH="build/run-capture/$(date +%Y%m%d-%H%M%S)-${APP_ENV}.png"
fi
mkdir -p "$(dirname "$OUT_PATH")"

LOG_FILE="$(mktemp -t run_and_capture)"
RUN_PID=""

cleanup() {
  if [ -n "$RUN_PID" ] && kill -0 "$RUN_PID" 2>/dev/null; then
    kill "$RUN_PID" 2>/dev/null || true
    wait "$RUN_PID" 2>/dev/null || true
  fi
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

echo "==> Device:  $DEVICE_NAME ($DEVICE_ID)"
echo "==> Flavor:  ENV=$APP_ENV"
echo "==> Capture: $OUT_PATH"
echo "==> Booting (up to ${TIMEOUT_SECS}s; a cold build is minutes)..."

# `--machine` rather than the human output. The readable run prints "Flutter run
# key commands." only when it owns a terminal, and this script never does; the
# daemon protocol's `app.started` is emitted either way and is versioned, so it
# is the signal that survives a Flutter upgrade. The cost is that build errors
# arrive as JSON, which is why the failure paths below dump the log.
RUN_DEFINES=(--dart-define=ENV="$APP_ENV")

$FLUTTER run --machine -d "$DEVICE_ID" "${RUN_DEFINES[@]}" \
  > "$LOG_FILE" 2>&1 < /dev/null &
RUN_PID=$!

STARTED=0
WAITED=0
while [ "$WAITED" -lt "$TIMEOUT_SECS" ]; do
  if grep -q '"event":"app.started"' "$LOG_FILE" 2>/dev/null; then
    STARTED=1
    break
  fi
  if ! kill -0 "$RUN_PID" 2>/dev/null; then
    break
  fi
  sleep 2
  WAITED=$((WAITED + 2))
done

if [ "$STARTED" -ne 1 ]; then
  if kill -0 "$RUN_PID" 2>/dev/null; then
    echo "run_and_capture: the app did not reach its first frame within ${TIMEOUT_SECS}s." >&2
    echo "  Raise it with --timeout <seconds> if this machine's first build is slower." >&2
  else
    echo "run_and_capture: \`flutter run\` exited before the app started." >&2
  fi
  echo "  Last lines of the run log:" >&2
  tail -20 "$LOG_FILE" | sed 's/^/    /' >&2
  exit 1
fi

# The framework reports `app.started` when the engine has run `main()`, which is
# a frame or two ahead of the first painted one. Half a second of settle keeps
# the capture off the launch screen without pretending to wait for animations.
sleep 1

echo "==> Started. Capturing..."
if ! $FLUTTER screenshot -d "$DEVICE_ID" -o "$OUT_PATH" >/dev/null 2>&1; then
  echo "run_and_capture: the app started but \`flutter screenshot\` failed." >&2
  exit 1
fi

if [ ! -f "$OUT_PATH" ]; then
  echo "run_and_capture: \`flutter screenshot\` reported success and wrote nothing." >&2
  exit 1
fi

PNG_BYTES="$(wc -c < "$OUT_PATH" | tr -d ' ')"
if [ "$PNG_BYTES" -lt "$MIN_PNG_BYTES" ]; then
  echo "run_and_capture: captured $PNG_BYTES bytes, under the ${MIN_PNG_BYTES}-byte floor." >&2
  echo "  A frame that compresses this small is a blank or near-blank one, which" >&2
  echo "  means the app started and painted nothing. Look at $OUT_PATH." >&2
  exit 1
fi

echo "==> Captured $OUT_PATH ($PNG_BYTES bytes)"
echo "==> Level 3 evidence: this file, plus this exit code."
