# Progress

## Now

- The Electron shell and React UI are gone (2026-11-05). Parley is the native
  SwiftUI app in `macos/` driving the TypeScript engine in `engine/` over stdio.
- **parley-019** (native shell, dictation) is `in_progress`: three live
  dictations pasted end to end on 2026-11-05. Left before `passing`: a dictation
  into Notes and Slack, and a like-for-like memory and latency comparison.
- The ports of what the Electron app did are `not_started`: parley-020 settings
  window, 021 voice edit, 022 Explain, 023 Act, 024 sync. Their Electron-era
  register entries are in `docs/history/electron-features.md`.

## Next step

Finish parley-019's live checks, mark it `passing`, then start parley-020
(settings window; design: https://claude.ai/artifact/Mirpic2JxR1ZZyewgN8nZL).
