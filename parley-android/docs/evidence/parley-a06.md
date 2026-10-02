# parley-a06 — Deepgram Nova-3 as a transcription provider

Verified 2026-09-25 on `feat/deepgram-nova3` (automated only).

- `make check` exit 0: 144 Kotlin tests, 0 failures; all Flutter suites pass;
  ui-lint, plan-lint and superplan-lint report 0 violations. The 9 doc-lint D9
  lines are older features missing evidence files; none of them is this one.
- Native: `DeepgramTranscriber` posts the WAV to `/v1/listen?model=nova-3`
  with `smart_format` and one `keyterm` per term (deduplicated, capped at 100
  terms / 1500 chars) and verifies keys with `GET /v1/projects`.
  `DeepgramTranscriberTest`, `StoresTest` and `SessionTest` cover it.
- Config: `transcriptionProvider` defaults to `groq`, so existing installs do
  not change. The Deepgram key is stored encrypted next to the others. The
  session asks for the chosen provider's key and uses that provider's copy
  when the key is missing.
- UI: the API keys page has a Transcription radio and the chosen provider's
  key field. It switches provider only once that provider has a key. The
  setup key step offers "Use Deepgram Nova-3 instead". Goldens were
  re-baselined and reviewed.

Pending: a device walk with a real Deepgram key (save key, switch, dictate).
