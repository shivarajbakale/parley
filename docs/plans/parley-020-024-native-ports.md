# parley-020…024 — Native ports: settings, voice edit, Explain, sync, Act

Status: built 2026-11-05; awaiting live verification. Spec for all five port
features, since they share one change: the engine's composition root now
wires everything the Electron main process wired, and the wire grew to
protocol v2 (ARCHITECTURE.md has the table).

## Engine

- `engine/headless/engine.ts` is a port of the old `electron/main.ts`
  composition: four gesture detectors, the session, voice edit targets,
  Explain, word offers and the correction watcher, the agent supervisor with
  approvals, and sync. OS effects go through `headless/platform.ts`.
- The sync token is encrypted with AES-256-GCM (`headless/secret.ts`) under a
  32-byte key the app keeps in the Keychain and passes in `hello`. A token
  stored by the Electron build (safeStorage) cannot be read: sign in again.
- The agent is spawned with the bundled Node from `Contents/Resources/parley-agent`;
  a server already answering at the agent URL is attached to instead.

## App

- `Accessibility.swift` — the focused field and selection in-process, same JSON
  as the old helper so `parseFocusedField` still decides.
- `Paster` (ParleyCore) — paste over the field, copy all, copy selection, erase,
  each restoring the clipboard; timings from `injector.ts`.
- `ExplainPanel` — glass card under the selection; clicks without stealing focus;
  a click outside dismisses.
- `SettingsWindow` — NavigationSplitView: General, Keys & gestures, Dictionary,
  Agent, Server & sync. Opens on first run when permissions are missing.
- HUD — mode hue per gesture, notices with hints (word offers, agent progress,
  approvals), positioned on the user's window.
- Speech (approvals read aloud), launch at login (`SMAppService`, only from
  /Applications), Keychain key.

## Not ported

- The four-slide product tour and the step-by-step wizard: the settings window
  and the permission prompts cover first run.

## Verification

- `make check`; engine tests drive each mode over the wire with a fake shell.
- Live, per feature: see each entry's `verification` in `feature_list.json`.
