# Progress Log

## Current Verified State

- Repository root: this project (Parley for Android — floating orb + accessibility service)
- Standard startup path: `./init.sh`
- Standard verification path: `make check` (analyze, lints, Flutter tests, probe, goldens, `native-test` for the Kotlin core)
- Device evidence: `make run-capture RUN_CAPTURE_ARGS="-d emulator-5554 -o <png>"`
- Passing: parley-a01 (service + orb), a03 (volume gesture), a05 (Aurora), r01–r06 (all six screens), r07 (Nunito type + animated empty states), r08 (launcher icon from the Mac app)
- In progress: parley-a02 (dictation) — proven live on the Oppo CPH2791 into Settings search; chat app + browser field still to try
- Blocked: parley-a04 (voice edit) — needs a MiniMax key on the phone
- Device: Oppo CPH2791 (Android 16) over USB, release build installed (`flutter build apk --release`, debug-signed)

## Notes

- Type is Nunito Sans + Nunito (parley-r07); the overlay's capsule label and timer in `OrbView.kt` read `NunitoSans-600.ttf` / `Nunito-600.ttf` from the Flutter asset bundle.
- Known, not fixed: Overview hero chips read "Orb on" while the service is off.

## Session Log

### Session 001 — Parley Android v1, end to end

**Built**
- Flutter: Aurora theme (Geist / Geist Mono / Instrument Serif, OKLCH seeds), Setup (6 steps), Overview, History, Transcript, Settings, API keys. Bridge interface, MethodChannel implementation and an offline `FakeParleyBridge`.
- Kotlin (`android/app/src/main/kotlin/com/shivarajbakale/parley/`): accessibility service, orb overlay, volume-down tap-tap-hold detector, recorder + mic foreground service, Groq transcriber, MiniMax rewriter, injector (SET_TEXT → paste → clipboard), SQLite history, encrypted config, MethodChannel/EventChannel bridge. 99 JUnit/Robolectric tests. Orb redesign: one morphing shape (sphere ↔ capsule with waveform + timer), springs, tuck into the edge, 44 dp default.

**Verified**
- `make check` green, including `native-test: 99 Kotlin test(s), 0 failure(s)`.
- Emulator (API 36): service connects, orb draws over Messages, orb turns to error with no key, hidden on password fields, the "Listening 0:04" pill sits beside the orb while holding, tap-tap-hold starts a session (driven via a `uinput` virtual keyboard — `adb input keyevent` never reaches the accessibility key filter). `verifyKey` hit the real Groq API and rejected a fake key. Evidence in `docs/evidence/`.

**Next**
1. User enters a Groq key (Setup step 2) and dictates on a physical phone: proves a02, and Spike A01 (background mic on Android 14+, SET_TEXT per app, volume replay).
2. Add a MiniMax key and try a voice edit: proves a04.
3. Debug-level logs remain on the volume-gesture path.

**Known risk**
- Flutter warns Kotlin 2.2.20 support will be dropped (wants 2.3.20+); `settings.gradle` untouched.
- Tap-to-undo only works while the orb is visible.
