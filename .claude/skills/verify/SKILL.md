---
name: verify
description: Prove a change actually works by type-checking, testing, and using the real native app — not just reading the diff. Run before declaring any non-trivial change done.
---

# verify — don't declare done until it runs

A change is not done because it compiles. Observe it working end to end.

## The loop

1. **Type-check and lint** — `npm run type-check` and `npm run lint`. Zero
   errors, zero warnings. Never suppress with `any` or `@ts-ignore`.
2. **Engine tests** — `npm test`. Behaviour of the session, gestures, wire and
   stores belongs in `engine/__tests__/` and runs against fakes; copy
   `engine/__tests__/headless-engine.test.ts` for a flow driven over the wire.
3. **Swift tests** — `make -C macos test`. Logic that can live in
   `macos/ParleyCore` (codecs, mappings, rules) is tested there.
4. **Build and run** — `make run` (builds `Parley Native.app` and opens it).
   Quit the Electron Parley first if it is installed and running.
   - Grant Microphone and Accessibility from the menu if asked.
   - Do the gesture into a real text field (TextEdit, Notes, Slack): the pill
     shows listening → writing → pasted, and the text lands at the caret.
   - Check the clipboard holds what it held before.
   - Read the log for each step:
     `log show --last 5m --info --predicate 'subsystem == "com.shivarajbakale.parley.mac"'`.

## Report

State exactly what you ran and what you observed (e.g. "three dictations into
TextEdit: listening → transcribing → pasted 14/29/23 chars"). If a step was
skipped, say so and why. Do not report success on the basis of the diff alone.
