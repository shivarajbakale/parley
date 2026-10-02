# Design Decisions

Append-only. New entries go at the top. Each entry should answer:

- **What** changed
- **Why** (the forcing function — constraint, deadline, stakeholder ask, bug)
- **Rejected alternatives** (and why)
- **Constraint or invariant** the decision creates (so future agents know what
  they can't silently undo)

---

## 2026-09-24 — Nunito replaces the serif; empty states are drawn scenes

**What.** Aurora's type is Nunito Sans for interface text and the user's own
words (italic 500), and rounded Nunito for titles (800 display, 700 headline)
and figures. Geist, Geist Mono and Instrument Serif are removed from the
bundle, and the Kotlin pill reads the Nunito files. Parley's empty states
(History first run, History while Parley cannot run, History with no match,
Overview before the first dictation) show a looping `EmptyScene` and one
line, with at most one action; a missing transcript returns with a snack bar.

**Why.** The owner found the serif-and-mono mix unpleasant and asked for a
rounded face, then for Avenir, and for animated empty states with far less
text.

**Rejected.** Avenir (a Monotype face; bundling it in an APK needs an
app-embedding licence, and Apple's system copy may not be redistributed).
Quicksand (no italic, thin at body size). Lottie or Rive files for the scenes
(assets to source and license, and they could not share the orb's painter or
hold still under `flutter test`).

**Invariant.** Nunito has no `tnum` feature; figures line up because both
families draw every digit on a 600-unit advance. A replacement face must keep
that, or the counters jitter. `EmptyScene` loops on `OrbMotion.breathe` and
holds a single chosen frame under reduce-motion and `flutter test`, like
`AuroraOrb`.

## 2026-09-24 — Aurora identity; Parley shell replaces the template's

**What.** `DesignSpec.aurora()` is the shipped identity (dark by default):
ink ground at hue 285, one indigo accent at hue 277 carried over from the
Mac app's orb, Instrument Serif for titles and the user's own words, Geist
for interface text, Geist Mono for figures. The orb's mode colours live in
`lib/theme/parley_modes.dart` because they must match the Kotlin `OrbView`
byte for byte, not grow from seeds. The template's five-tab shell, auth gate,
welcome and tour are replaced by Overview / History / Settings and one
`/setup` gate on `onboarding_complete`.

**Why.** The user asked for a UI that looks amazing with a very good theme,
and approved the mockups at https://claude.ai/artifact/KHuAChbQqTC4rzpxnreHBj.
Parley is personal-use with keys on device, so there is no account to gate.

**Rejected.** Seeding the orb colours from the palette (they would drift from
the Mac app and the overlay); a Flutter-drawn overlay orb (a second engine in
memory for the one path that must feel instant).

**Invariant.** The dark ground ladder `[0.162, 0.268, 0.114]` is the only
window that clears K6 (card/page 1.22), the card test's 1.25 and K10's .045
spacing at once — move a rung and `make palette-lint` says which gate broke.
`AuroraOrb` holds still under `flutter test` so every settle-based test,
golden and probe frame can finish.

## 2026-09-24 — The native core owns the pipeline and the stores

**What.** Recording, transcription, rewriting, insertion, history (SQLite)
and config (EncryptedSharedPreferences) live in Kotlin inside the
accessibility service process. Flutter talks to it only through
`docs/plans/bridge-contract.md`; `FakeParleyBridge` stands in off-device.

**Why.** The pipeline runs while the Flutter UI is closed.

**Invariant.** A change to a bridge method changes the contract doc, the
Kotlin handler, `MethodChannelParleyBridge` and `FakeParleyBridge` in one
commit.
