---
name: ship
description: Take this app to the App Store and Play Store. Sweeps the project for everything still placeholder, unsigned, or missing, reports the blockers in fix order, applies the fixes, then builds and uploads. Use for any store release — first submission, TestFlight/internal beta, or a production update.
---

# ship — release readiness, then release

A fresh scaffold is deliberately not shippable: it carries a `com.example`
bundle id, a debug signing key, and placeholder store metadata. This skill finds
every one of those, fixes them, and drives the release. Run the whole thing —
do not skip to the build.

Two rules that never bend:

- **Never upload without an explicit go-ahead.** A build that reaches TestFlight
  or a Play track is public-facing and cannot be recalled. Ask, every time,
  even if you asked on a previous release.
- **Never invent credentials.** Keystores, App Store Connect keys, and service
  accounts belong to the human. If one is missing, stop and say what is needed.

## Step 1 — Sweep

Run this first, always, from the app root. One command, all of it:

```bash
echo "── identity ──"
grep -n 'applicationId\|namespace' android/app/build.gradle
grep -n 'android:label' android/app/src/main/AndroidManifest.xml
grep -n 'PRODUCT_BUNDLE_IDENTIFIER' ios/Runner.xcodeproj/project.pbxproj | head -3
grep -A1 'CFBundleDisplayName' ios/Runner/Info.plist
grep -n '^version:' pubspec.yaml

echo "── signing ──"
sed -n '/buildTypes/,/^    }/p' android/app/build.gradle
ls android/key.properties 2>&1
ls ios/ExportOptions.plist 2>&1

echo "── platform files ──"
ls ios/Runner/PrivacyInfo.xcprivacy 2>&1
grep -c 'ITSAppUsesNonExemptEncryption' ios/Runner/Info.plist
grep -o 'NS[A-Za-z]*UsageDescription' ios/Runner/Info.plist
grep -o 'android:name="android.permission[^"]*"' android/app/src/main/AndroidManifest.xml
ls assets/icon/icon.png 2>&1

echo "── config leaks ──"
grep -n 'api.example.com\|localhost' lib/config/env.dart

echo "── policy surface ──"
ls lib/screens/auth/ 2>&1
grep -rln 'deleteAccount\|delete_account' lib/ 2>&1 || echo "no account-deletion path found"

echo "── baseline ──"
flutter analyze 2>&1 | tail -3
dart run tool/ui_lint.dart 2>&1 | tail -3
dart run tool/design_system_reference.dart --check 2>&1 | tail -3
```

## Step 2 — Read the sweep

Classify every signal. Report the result as a grouped checklist with a
`file:line` for each finding, then a single line: how many blockers, and which
one you are starting with.

**Blockers — the store rejects these, or the build does not exist**

| Signal in the sweep | Why it blocks |
|---|---|
| `applicationId` or bundle id starts with `com.example` | reserved-looking id; both stores reject it |
| `android:label` or `CFBundleDisplayName` still "Rocketship" | ships the scaffolder's name |
| `version:` still `0.1.0+1`, or build number not above the last upload | Play and App Store Connect both refuse a duplicate build number |
| release `signingConfig` is `signingConfigs.debug` | a debug-signed bundle cannot be uploaded, and the key cannot be changed later |
| android/key.properties absent | nothing to sign the release with |
| ExportOptions.plist absent | `ios/fastlane/Fastfile` reads it; the iOS build fails without it |
| PrivacyInfo.xcprivacy absent | Apple hard-rejects since 2024 |
| assets/icon/icon.png absent | ships the stock Flutter launcher icon |
| a `NS*UsageDescription` describing a feature the app does not have | Apple rejects unjustified permissions |
| an Android permission no code path requests | same, and it widens the Play data disclosure |
| prod `apiBaseUrl` still `https://api.example.com` | the release talks to nothing |

**Manual — you cannot answer these from the filesystem; put them to the human**

| Item | What to ask |
|---|---|
| Account deletion | `lib/screens/auth/` exists but no deletion path. Both stores require an in-app way to delete the account whenever sign-up exists. Ask whether to build it now — it is a feature slice, so use the `add-feature` skill, not this one. |
| Export compliance | `ITSAppUsesNonExemptEncryption` count is 0. Without it every TestFlight build stalls on the compliance prompt. Ask: does the app use non-exempt encryption? Almost always "no" for HTTPS-only apps. |
| Privacy policy URL | Both stores require a reachable URL. Ask for it. |
| Sign in with Apple | If third-party social login is wired up, Apple requires Sign in with Apple beside it. |

**Warnings — ship without them, but say so**

- release build omits `--obfuscate --split-debug-info`
- no store screenshots at the required device sizes
- `flutter analyze` not clean

## Step 3 — Fix, in this order

Order matters. Each step depends on the one above it — a keystore is bound to
the application id, so renaming after signing invalidates it.

**1. Identity.** One script does every file, idempotently:

```bash
tool/rename_app.sh "My App" com.acme.myapp
```

**2. Version.** `pubspec.yaml` — the part after `+` is the build number and must
increase on every single upload, including re-uploads of the same version:

```bash
sed -i '' 's/^version: .*/version: 1.0.0+1/' pubspec.yaml
```

**3. Android signing.** Generate the upload key, then wire it in. The keystore
never enters git — confirm `.gitignore` covers it before writing anything:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload

cat > android/key.properties <<'EOF'
storePassword=<from the keytool prompt>
keyPassword=<from the keytool prompt>
keyAlias=upload
storeFile=/Users/<you>/upload-keystore.jks
EOF
```

Then in `android/app/build.gradle`, load it above `android {` and point the
release build at it instead of `signingConfigs.debug`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

Losing this keystore means never updating the app again under the same
listing. Tell the human to back it up somewhere outside the repo.

**4. iOS build inputs.** Both files are missing on a fresh scaffold:

```bash
cat > ios/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>YOUR_TEAM_ID</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF

cat > ios/Runner/PrivacyInfo.xcprivacy <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
  </array>
</dict>
</plist>
EOF
```

The collected-data array must reflect what the app actually collects — if auth
is live it collects at minimum an email address. Fill it from the real code, not
from this template, and keep it consistent with the Play Data Safety answers.
Add the new plist to the Runner target in Xcode, or it will not be bundled.

**5. Permissions.** Delete any usage string or manifest permission the app does
not exercise. Every one you keep must name the real feature that uses it —
Apple reads these.

**6. Prod API base URL.** Either edit the prod branch in `lib/config/env.dart`
or pass it at build time, which is preferred because it keeps hostnames out of
git:

```bash
--dart-define=API_BASE_URL=https://api.acme.com
```

**7. Launcher icon.** Drop a 1024×1024 PNG at assets/icon/icon.png, then re-run
`tool/rename_app.sh` with the same two arguments — it regenerates icons and
splash when that file exists.

Re-run the Step 1 sweep after the fixes. Report the new count. Do not proceed
to a build while any blocker stands.

## Step 4 — Build

```bash
flutter build appbundle --release \
  --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.acme.com \
  --obfuscate --split-debug-info=build/symbols

flutter build ipa --release \
  --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.acme.com \
  --obfuscate --split-debug-info=build/symbols \
  --export-options-plist=ios/ExportOptions.plist
```

Then verify the build is genuinely a production build, not a mock one — this is
the failure that survives every other check, because it compiles and runs fine:

```bash
grep -r 'useMockBackend\|USE_MOCK' lib/config/env.dart
```

`useMockBackend` must resolve false under `ENV=prod`. Install the release build
on a real device and confirm it reaches the live API before uploading.

## Step 5 — Upload

**Stop and ask before running either of these.** Name the track and the build
number in the question, and wait for a yes.

```bash
cd android && fastlane beta      # Play internal testing
cd ios     && fastlane beta      # TestFlight
cd android && fastlane release   # Play production
```

Credentials come from the environment, never from source — see
`android/fastlane/Appfile` and `ios/fastlane/Appfile` for the variable names.
If one is unset, stop and say which.

Store-console work stays with the human: listing copy, screenshots, the Play
Data Safety form, and Apple's privacy labels. Offer the list; do not pretend to
have done it.

## Step 6 — Record

Append to `claude-progress.md`: the version and build number, the track, and
which manual items are still open. The next release starts by reading that
entry, so an unfinished policy item must be visible there rather than
rediscovered by a rejection email.
