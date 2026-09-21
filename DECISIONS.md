# Design Decisions

Append-only. New entries go at the top. Each entry answers **What / Why /
Rejected alternatives / Constraint** so future agents know what they must not
silently undo.

---

## 2026-09-21: `uiohook-napi` for the global key hook and paste keystroke

- **What:** Added `uiohook-napi` as a runtime dependency of the main process.
- **Why:** The tap-tap-hold gesture needs global keydown and keyup events for a
  bare modifier key. Electron's `globalShortcut` reports neither keyup nor bare
  modifiers. The same module sends the Cmd+V keystroke for paste injection.
- **Rejected alternatives:** `globalShortcut` (no keyup); AppleScript keystrokes
  (slow, and still no key listening); a Swift helper binary (kept as the
  fallback if the native module fails to load).
- **Constraint:** It is a native module. Keep it in `rollupOptions.external` in
  `vite.config.ts` and in `asarUnpack` in `electron-builder.json5`. It ships
  N-API prebuilds, so no `electron-rebuild` step is needed.

## 2026-09-21: The scaffold's demo app stays but is not opened

- **What:** Parley adds `orb.html` and `settings.html` as separate renderer
  entries. `index.html` and the demo pages remain in the tree, unopened.
- **Why:** The harness gates (`ui-probe`, `storybook-lint`, the a11y suite)
  exercise the demo pages. Deleting them is a large change unrelated to v1.
- **Rejected alternatives:** Hosting settings as a route in the demo shell
  (drags in auth and a sidebar a menu bar tool does not need).
- **Constraint:** `electron/main.ts` must never load `index.html`.

## 2026-07-01: Project scaffolded with a harness-first baseline

- **What:** Generated this Electron desktop app (Vite + React + TypeScript) with a complete agent harness from
  rocketship's `harness-core`.
- **Why:** Long-running agent work needs continuity, explicit verification, and a
  repository that is its own system of record — not a bare prompt.
- **Rejected alternatives:** A README-only scaffold — rejected because it leaves
  the agent to re-infer conventions and definition-of-done every session.
- **Constraint:** `make check` is the definition of done. Do not mark features
  `passing` without running their verification and recording evidence.
