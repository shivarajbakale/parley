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
- Baseline: `make check` is **red** — 9 × D9, a missing `docs/evidence/<id>.md` for a01, a03, a05 and r01–r06. Pre-existing; fix before relying on the gate.
- Kotlin core: 200 tests across 14 suites, 0 failures (`cd android && ./gradlew :app:testDebugUnitTest`)
- Planned, not started: parley-a07 (Ask Parley) — `parley-a07.feature-plan.json`, `docs/plans/agent.md`, reviewable at `docs/plans/parley-a07-review.html`

## Notes

- Type is Nunito Sans + Nunito (parley-r07); the overlay's capsule label and timer in `OrbView.kt` read `NunitoSans-600.ttf` / `Nunito-600.ttf` from the Flutter asset bundle.
- Known, not fixed: Overview hero chips read "Orb on" while the service is off.
- The orb's confirmation design is a hold, not a button: hold to ask, hold to commit, hold longer to send. The first draft used a snap-sheet with four buttons; that was a desktop pattern on a phone and it is gone. Taps remain as the second language for TalkBack and switch control.
- `ScreenContextSerializer` is pure Kotlin with no Android types, so the edges that matter (a row scrolled off the fold, a label echoing at four levels, a password, an over-budget tree) are plain JVM tests. The adapter that walks a real `AccessibilityNodeInfo` into a `SourceNode` tree is not written yet.
- A password node is dropped with its **descendants**, not its siblings: a hint like "at least 8 characters" is not a disclosure, and dropping every sibling of a password field would take out the form around it.
- No budget pass may empty a screen that had content. An agent that answers from nothing is worse than one that answers from too much.

## Session Log

### Session 001 — Parley Android v1, end to end

**Built**
- Flutter: Aurora theme (Geist / Geist Mono / Instrument Serif, OKLCH seeds), Setup (6 steps), Overview, History, Transcript, Settings, API keys. Bridge interface, MethodChannel implementation and an offline `FakeParleyBridge`.
- Kotlin (`android/app/src/main/kotlin/com/shivarajbakale/parley/`): accessibility service, orb overlay, volume-down tap-tap-hold detector, recorder + mic foreground service, Groq transcriber, MiniMax rewriter, injector (SET_TEXT → paste → clipboard), SQLite history, encrypted config, MethodChannel/EventChannel bridge. 99 JUnit/Robolectric tests. Orb redesign: one morphing shape (sphere ↔ capsule with waveform + timer), springs, tuck into the edge, 44 dp default.

**Verified**
- `make check` green, including `native-test: 101 Kotlin test(s), 0 failure(s)`.
- Emulator (API 36): service connects, orb draws over Messages, orb turns to error with no key, hidden on password fields, the "Listening 0:04" pill sits beside the orb while holding, tap-tap-hold starts a session (driven via a `uinput` virtual keyboard — `adb input keyevent` never reaches the accessibility key filter). `verifyKey` hit the real Groq API and rejected a fake key. Evidence in `docs/evidence/`.

**Next**
1. User enters a Groq key (Setup step 2) and dictates on a physical phone: proves a02, and Spike A01 (background mic on Android 14+, SET_TEXT per app, volume replay).
2. Add a MiniMax key and try a voice edit: proves a04.
3. Debug-level logs remain on the volume-gesture path.

### Session 002 — Ask Parley: plan, review, and the first real code

**Planned** (nothing built for a07 beyond the serializer)
- The idea: the accessibility service already holds the foreground window's node tree — exact text, exact bounds — so Parley can read a screen rather than guess at pixels, and act in it.
- `parley-a07.feature-plan.json` — passes `tool/feature_plan.dart --check`; two Flutter surfaces (Agent settings, Agent run transcript), the ask sheet, the closed action set, the refusal table, blast radius.
- `docs/plans/agent.md` — the Kotlin half the plan tool cannot draw: context serialisation, the action sandbox, the sheet, the undo journal, revalidation.
- `docs/plans/parley-a07-review.html` — a review document with 19 sections, the frames, and a change-request composer that exports markdown. Seven open questions, of which the two that matter most: whether the question half ships before the acting half, and whether triple-tap is the right activation for Ask mode.

**Two corrections, both mine**
1. The first draft put a per-step confirm loop on a phone. Replaced with three holds on the orb — ask, commit, and a longer one to send — and the orb became the brake while a run is live rather than going inert to the person as well as to the agent.
2. A password node drops with its descendants, not its siblings. The original claim was broader and wrong.

**Register**
- Constraint 1 was violated: a02 and a06 were both `in_progress`. a06 is now `not_started` with its remaining step written down — it is waiting on a Deepgram key, which is a purchase rather than a walk. a02 keeps the slot.
- parley-a07 is registered `not_started`, priority 15. It does not go in flight until a02 closes.

**Built and verified**
- `ScreenContextSerializer.kt` + 26 tests. Prune, dedupe, reading order, stable ids, redaction, and a four-stage budget that declares what it dropped.
- `cd android && ./gradlew :app:testDebugUnitTest --rerun-tasks` → BUILD SUCCESSFUL, 200 tests, 0 failures.
- `plan-lint`, `superplan-lint` green. `doc-lint` unchanged at the 9 pre-existing D9s.
- Five tests failed first time. Two were real bugs (the label-cut pass never set `truncated`; the short-label pass could empty a screen entirely) and three were bad fixtures of mine where pruning was correct.

**Next**
1. User walks a02 on the phone: a chat app and a browser field, and the insert method recorded in history. That closes a02 and frees the slot.
2. Then a07: the `AccessibilityNodeInfo` → `SourceNode` adapter, then `AgentPolicy`.

**Known risk**
- The address-bar redaction is not built. It is a per-app rule and belongs in `AgentPolicy`, not the serialiser; the serialiser only redacts what is true of every app.
- Full `make check` was not run this session — the native gate and the three Dart lints were, and Flutter code was not touched.
