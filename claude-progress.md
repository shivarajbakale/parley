# Progress Log

## Current Verified State

- Repository root: this project (Parley for Android — floating orb + accessibility service)
- Standard startup path: `./init.sh`
- Standard verification path: `make check` (analyze, lints, Flutter tests, probe, goldens, `native-test` for the Kotlin core)
- Device evidence: `make run-capture RUN_CAPTURE_ARGS="-d emulator-5554 -o <png>"`
- Passing: parley-a01 (service + orb), a03 (volume gesture), a05 (Aurora), r01–r06 (all six screens), r07 (Nunito type + animated empty states)
- Blocked: parley-a02 (dictation) and parley-a04 (voice edit) — both need the user's real Groq / MiniMax keys to prove live
- Current blocker: no API keys on this machine; no physical phone run yet

## Branch note (parley-r07)

- r07 was built on branch `nunito-empty-states` (worktree `../parley_android-r07`) while an orb/pill redesign was uncommitted in the main tree.
- Merge hazard: r07 deletes Geist/GeistMono/InstrumentSerif and points `PillView.kt` at `NunitoSans-600.ttf` / `Nunito-600.ttf`. The redesign deletes `PillView.kt` and its `OrbView.kt` loads `Geist-500.ttf` / `GeistMono-500.ttf`. Whoever merges second: delete `PillView.kt`, and switch those two names in `OrbView.kt` to the Nunito files.
- Known, not fixed: Overview hero chips read "Orb on" while the service is off.

## Session Log

### Session 001 — Parley Android v1, end to end

**Built**
- Flutter: Aurora theme (Geist / Geist Mono / Instrument Serif, OKLCH seeds), Setup (6 steps), Overview, History, Transcript, Settings, API keys. Bridge interface, MethodChannel implementation and an offline `FakeParleyBridge`.
- Kotlin (`android/app/src/main/kotlin/com/shivarajbakale/parley/`): accessibility service, orb overlay, volume-down tap-tap-hold detector, recorder + mic foreground service, Groq transcriber, MiniMax rewriter, injector (SET_TEXT → paste → clipboard), SQLite history, encrypted config, MethodChannel/EventChannel bridge. 92 JUnit/Robolectric tests.

**Verified**
- `make check` green, including `native-test: 92 Kotlin test(s), 0 failure(s)`.
- Emulator (API 36): service connects, orb draws over Messages, orb turns to error with no key, hidden on password fields, the "Listening 0:04" pill sits beside the orb while holding, tap-tap-hold starts a session (driven via a `uinput` virtual keyboard — `adb input keyevent` never reaches the accessibility key filter). `verifyKey` hit the real Groq API and rejected a fake key. Evidence in `docs/evidence/`.

**Next**
1. User enters a Groq key (Setup step 2) and dictates on a physical phone: proves a02, and Spike A01 (background mic on Android 14+, SET_TEXT per app, volume replay).
2. Add a MiniMax key and try a voice edit: proves a04.
3. Debug-level logs remain on the volume-gesture path.

**Known risk**
- Flutter warns Kotlin 2.2.20 support will be dropped (wants 2.3.20+); `settings.gradle` untouched.
- Tap-to-undo only works while the orb is visible.
