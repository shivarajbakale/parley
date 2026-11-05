# Progress

## Now

- The Electron shell and React UI are gone (2026-11-05). Parley is the native
  SwiftUI app in `macos/` driving the TypeScript engine in `engine/` over stdio.
- **parley-019** (native shell, dictation) is `passing` (2026-11-05), archived in
  `docs/history/completed-features.md`. Merged to main in PR #1.
- Ports parley-020…024 are built on `feat/native-ports` (protocol v2, spec in
  `docs/plans/parley-020-024-native-ports.md`): settings window, voice edit,
  Explain, sync, Act. 020 is `in_progress`; 021–024 are `blocked` only on a
  live check by the user.

## Next step

Live-check each port in the real app (each feature's `verification`), mark
them `passing` one at a time, then open the PR.
