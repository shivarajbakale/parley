# Parley

Tap-tap-hold voice dictation for macOS. Tap Right Option twice, hold the third
press, speak, release: Groq Whisper transcribes and the text is pasted at your
cursor. Design: [docs/superpowers/specs/2026-09-21-parley-design.md](docs/superpowers/specs/2026-09-21-parley-design.md).

Voice edit is the same gesture on a second key (Right Command by default):
with the cursor in a text field, say "make it shorter" and the selection, or
the whole field, is rewritten by MiniMax and pasted back. It needs a MiniMax
API key and reads the field with `native/parley-ax.swift`, which `npm run dev`
and `npm run build` compile (Xcode command line tools required).

Run it with `make dev`. It needs Microphone and Accessibility permission and a
Groq API key, all set from the tray's Settings window.

## Run

```bash
npm install
cp .env.example .env   # if not already created
npm run dev
```

The dev command opens an Electron window backed by the Vite dev server.

## What's inside

- Electron + React 19 + Vite + TypeScript (strict)
- Mantine 9 as the single design system — no second styling layer
- TanStack Router + TanStack Query
- MSW (Mock Service Worker) for API mocking
- Storybook for component development
- electron-builder for packaging

## Scripts

```bash
npm run dev          # Vite dev server + Electron window
npm run build        # tsc && vite build && electron-builder
npm run preview      # preview the production renderer build
npm run lint         # ESLint
```

## Identifiers

- npm package: `parley`

See `CLAUDE.md` for the full architecture guide and conventions.
