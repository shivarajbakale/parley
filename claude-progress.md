# parley-012 — Deepgram Nova-3 as a transcription provider (branch feat/deepgram-nova3)

Deepgram Nova-3 now sits next to Groq's Whisper as a second speech-to-text
provider. The user picks one on the Overview's Transcription row (Whisper (Groq)
/ Deepgram Nova-3 SegmentedControl) and stores that provider's key there.
Design approved by the user 2026-09-24. The plan is
`parley-012.feature-plan.json`, and `FEATURE-PLAN.md` is its render.

## Current state

- Code complete on `feat/deepgram-nova3`, automated gates green (see Evidence
  on parley-012 in `feature_list.json`). Not pushed, not merged.
- `parley-012` stays `in_progress`: the "Deepgram Nova-3 provider (parley-012)"
  block in `docs/MANUAL_CHECKLIST.md` needs a human with `make dev` and a real
  Deepgram key. No live Deepgram request has been made from this repo.
- parley-011 was moved to `blocked` (waiting only on its manual walk), so
  parley-012 is the one feature in flight on this branch.

## Shape

- `electron/transcriber.ts` keeps `Transcriber`, `TranscribeError` and the
  error kinds and picks a provider per call via `getProvider()`. The providers
  live in `electron/transcribers/` (`groq.ts`, `deepgram.ts`, `shared.ts`).
  A `server` error names the provider ("Deepgram error").
- Transcribe options are `{ vocabulary, terms? }`: Groq still gets the
  `whisperPrompt` sentence, and Deepgram gets `terms` (from `vocabularyTerms` in
  `dictionary.ts`, plus the selection words in Explain) as `keyterm` params,
  deduplicated and capped at 100 terms / 1000 chars.
- Settings: `transcriptionProvider` (default `groq`) is set only through
  `settings:setTranscriptionProvider`, never by an update patch.
  `deepgramKeyEncrypted` is a third safeStorage key. `hasApiKey()` and
  `SettingsView.hasApiKey` mean "the selected provider has a key".
- IPC: `settings:setDeepgramKey` (tests against `GET /v1/projects` first) and
  `settings:setTranscriptionProvider`. The first-run wizard stays Groq-only.

## Next step

Walk the parley-012 checklist block with `make dev` and a real Deepgram key,
record the evidence, then mark `passing` and let `make commit-feature` take it.
