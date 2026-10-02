#!/usr/bin/env bash
# Renames this boilerplate into a shippable app: display name, bundle id /
# applicationId, and (optionally) launcher icons + splash. Run it once per new
# project, right after cloning the boilerplate.
#
#   tool/rename_app.sh "My App" com.acme.myapp
#
# What it changes:
#   - Android: android/app/build.gradle  (namespace + applicationId)
#              android/app/src/main/AndroidManifest.xml  (android:label)
#   - iOS:     ios/Runner.xcodeproj/project.pbxproj  (PRODUCT_BUNDLE_IDENTIFIER)
#              ios/Runner/Info.plist  (CFBundleDisplayName, CFBundleName)
#   - Icons/splash: if assets/icon/icon.png exists, regenerates both.
#
# What it does NOT change: the Dart package name `parley_android` (it's internal,
# users never see it, and renaming it would churn every import). Leave it.
#
# Idempotent: safe to re-run with new values.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ "$#" -ne 2 ]; then
  echo "Usage: tool/rename_app.sh \"App Display Name\" com.bundle.id" >&2
  exit 1
fi

APP_NAME="$1"
BUNDLE_ID="$2"

# Validate the bundle id is reverse-DNS-ish (letters/digits/underscores,
# at least one dot). Stores reject anything else.
if ! [[ "$BUNDLE_ID" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]]; then
  echo "Error: '$BUNDLE_ID' is not a valid bundle id (e.g. com.acme.myapp)." >&2
  exit 1
fi

echo "==> App name:  $APP_NAME"
echo "==> Bundle id: $BUNDLE_ID"

# ── Android ──
GRADLE="android/app/build.gradle"
if [ -f "$GRADLE" ]; then
  perl -i -pe 's/(namespace\s*=\s*")[^"]*(")/${1}'"$BUNDLE_ID"'${2}/' "$GRADLE"
  perl -i -pe 's/(applicationId\s*=?\s*")[^"]*(")/${1}'"$BUNDLE_ID"'${2}/' "$GRADLE"
  echo "==> Updated $GRADLE"
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  perl -i -pe 's/(android:label=")[^"]*(")/${1}'"$APP_NAME"'${2}/' "$MANIFEST"
  echo "==> Updated $MANIFEST"
fi

# ── iOS ──
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
  # RunnerTests target keeps the ".RunnerTests" suffix; the app targets don't.
  perl -i -pe '
    if (/RunnerTests/) {
      s/(PRODUCT_BUNDLE_IDENTIFIER = )[^;]+;/${1}'"$BUNDLE_ID"'.RunnerTests;/;
    } else {
      s/(PRODUCT_BUNDLE_IDENTIFIER = )[^;]+;/${1}'"$BUNDLE_ID"';/;
    }
  ' "$PBXPROJ"
  echo "==> Updated $PBXPROJ"
fi

PLIST="ios/Runner/Info.plist"
PLISTBUDDY="/usr/libexec/PlistBuddy"
if [ -f "$PLIST" ] && [ -x "$PLISTBUDDY" ]; then
  for KEY in CFBundleDisplayName CFBundleName; do
    "$PLISTBUDDY" -c "Set :$KEY $APP_NAME" "$PLIST" 2>/dev/null \
      || "$PLISTBUDDY" -c "Add :$KEY string $APP_NAME" "$PLIST"
  done
  echo "==> Updated $PLIST"
elif [ -f "$PLIST" ]; then
  echo "!! PlistBuddy not found — set CFBundleDisplayName/CFBundleName in $PLIST by hand." >&2
fi

# ── Icons + splash (optional) ──
if [ -f "assets/icon/icon.png" ]; then
  echo "==> Generating launcher icons"
  dart run flutter_launcher_icons
  if [ -f "assets/icon/splash.png" ]; then
    echo "==> Generating splash screen"
    dart run flutter_native_splash:create
  else
    echo "   (skip splash: add assets/icon/splash.png to enable)"
  fi
else
  echo "!! assets/icon/icon.png not found — skipping icon/splash generation."
  echo "   Add a 1024x1024 PNG there and re-run, or:"
  echo "     dart run flutter_launcher_icons"
  echo "     dart run flutter_native_splash:create"
fi

echo
echo "==> Done. Next:"
echo "    flutter clean && flutter pub get"
echo "    (verify) ./init.sh"
