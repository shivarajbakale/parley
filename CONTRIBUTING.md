# Contributing to Parley

Thanks for helping. Parley is small on purpose; the bar is that every change
is understood, tested and tried in the real app.

## Set up

```bash
./init.sh        # installs dependencies and runs the full check
make run         # builds Parley Native.app and opens it
```

You need macOS 26, Xcode 26, XcodeGen and Node 22+. See the README for the
server (`make api`) and for signing so permissions survive rebuilds.

## Where things go

- **macOS behaviour** — keys, microphone, Accessibility, windows — lives in
  `macos/Parley/`. Logic that can be tested without the app goes in
  `macos/ParleyCore/` with a test beside it.
- **Product logic** — the gesture, the session, transcription, the
  dictionary — lives in `engine/`, kept free of OS calls so it runs against
  fakes in `engine/__tests__/`.
- **The wire** between them is described in [ARCHITECTURE.md](ARCHITECTURE.md).
  An incompatible change bumps `protocolVersion` on both sides in the same PR.

## Before you open a pull request

1. `make check` passes.
2. You used the change in the real app, and the PR says what you did and saw.
3. A non-obvious choice has an entry at the top of [DECISIONS.md](DECISIONS.md).

Small, focused pull requests are reviewed fastest. For anything bigger than a
fix, open an issue first so we can agree on the shape.

## Reporting a security issue

Parley handles microphone audio and pastes into other apps. Please report
security problems privately through GitHub's “Report a vulnerability” on the
Security tab rather than in a public issue.
