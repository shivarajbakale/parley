# AGENTS.md

Parley is voice dictation for macOS: tap a modifier key, hold the last tap,
speak, release, and the words are pasted at the caret.

- **Stack:** a native SwiftUI menu-bar app (`macos/`, macOS 26, Liquid Glass)
  that runs the TypeScript engine (`engine/`) as a child process under a
  bundled Node, talking newline-delimited JSON-RPC over stdio. Provider keys
  live only in `parley-api/`.
- **Entry points:** `macos/Parley/ParleyApp.swift` (app),
  `engine/headless/main.ts` (engine).
- **The map:** [ARCHITECTURE.md](ARCHITECTURE.md).

This is the contract, read in full every session: what you must not get wrong.
How the code works is in ARCHITECTURE.md; what happened is the commit log.

## Start here

```
./init.sh        # install and verify — the canonical session-start command
make check       # type-check, lint, engine tests, harness lints, api, android, macos
make run         # build Parley Native.app and open it
make help        # everything else
```

## Hard constraints

1. **One feature in flight.** Exactly one `in_progress` in `feature_list.json` —
   two half-finished features leave a tree nobody can verify or revert as a unit.
2. **No `passing` without verification you actually ran**, in the real app —
   because dictation, paste and permissions fail in ways no unit test sees.
3. **stdout of the engine is the protocol.** Never write to stdout from
   `engine/` code (`headless/main.ts` sends console to stderr) — because one
   stray write corrupts a frame and the shell drops it.
4. **The wire changes on both sides at once.** `engine/headless/rpc.ts` and
   `macos/ParleyCore/Sources/ParleyCore/RPC.swift` share `protocolVersion`;
   bump it with any incompatible change — otherwise a mismatched shell and
   engine fail silently instead of at `hello`.
5. **The engine never asks the OS for permission.** Microphone, Accessibility
   and key events belong to the Swift app — because macOS would otherwise
   attribute them to `node`, a prompt nobody can explain.
6. **Engine logic stays pure.** OS effects enter `createSession`/`createEngine`
   as dependencies — because that is what lets every flow run with fakes in
   `engine/__tests__`.
7. **Provider keys never enter the app**; calls go through parley-api —
   because a key in a desktop app is a key anyone can extract.
8. **Never weaken or delete a test or a lint rule to look complete** — a deleted
   test turns a known failure into an unknown one.
9. **A feature reaching `passing` becomes a commit** (`make commit-feature`) —
   because verified but uncommitted work cannot be trusted or reverted.

`feature_list.json` uses four states: `not_started`, `in_progress`, `blocked`
(with the blocker written down) and `passing` (verification ran, evidence
recorded). Passing features move to `docs/history/`.

## The loop

1. `pwd`, then read `claude-progress.md` — the current state and the next step.
2. Pick the highest-priority unfinished feature from `feature_list.json`.
3. `git log --oneline -5`, then `./init.sh`. If the baseline is red, fix that first.
4. Plan non-trivial native work in `docs/plans/<id>-*.md` and record
   `"plan": "none: <reason>. Spec: docs/plans/..."` on the feature (the
   `plan-feature` skill renders web screens and does not apply here).
5. Work that one feature until it verifies or you document why it is blocked.

## Skills

| Skill | When |
| --- | --- |
| `verify` | prove a change works: tests, then the real app |
| `goal` | drive a feature through maker/checker loops |

## Before you stop

1. Record evidence and status in `feature_list.json`.
2. Rewrite `claude-progress.md` — the state now, not a log.
3. Walk `clean-state-checklist.md`, then `make check`, then `make commit-feature`.

## Where everything else is

| Read this | When |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | you need the layout or the protocol |
| [docs/plans/](docs/plans/) | the spec for the feature you are on |
| [DECISIONS.md](DECISIONS.md) | you are about to undo something deliberate |
| [docs/history/](docs/history/) | finished features, and the Electron-era ones awaiting a port |
| [docs/loops/](docs/loops/) | you are driving a feature through maker/checker cycles |
