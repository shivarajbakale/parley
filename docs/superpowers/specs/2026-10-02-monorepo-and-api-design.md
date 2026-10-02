# Parley monorepo and API design

Date: 2026-10-02. Status: draft for review.

## Goal

Keep every Parley project in one repository so one clone, one `./init.sh` and
one `make check` cover all of them, and add an Express backend that the
desktop and Android apps share.

## What exists today

| Project | Where | Stack | Harness |
|---|---|---|---|
| Desktop | `parley/` root | Electron, React 19, Mantine 9, TypeScript | rocketship, `make check` green |
| Agent | `parley/parley-agent/` | Mastra, TypeScript | smoke suite, installed by root `init.sh` |
| Android | `~/Projects/parley_android` (own git repo, no remote, 15 commits, uncommitted work on parley-a07) | Flutter | rocketship, `make check` |
| Backend | none | | |

Desktop calls Groq, Deepgram and MiniMax directly with keys the user types
into Settings. Dictionary, settings and history are local files.

## Layout (option A, approved)

Desktop stays at the root. Everything else is a sibling folder.

```
parley/
  electron/ src/ native/ ...       desktop, unchanged
  parley-agent/                    already in
  parley-api/                      new, scaffolded by create-express-app
  parley-android/                  moved in from ~/Projects/parley_android
  Makefile                         root targets fan out to every project
  init.sh                          installs every project
  docs/superpowers/specs/          this file
```

Not chosen: `apps/` and `packages/` layout. It would move every desktop file
and rewrite every path in hooks, scripts, electron-builder and the test
configs while parley-013 is still unverified by hand. It can come later.

## Part 1: bring Android in

- Commit the uncommitted parley-a07 work in `parley_android` first, on its own,
  so nothing is lost in the move.
- `git subtree add --prefix=parley-android ~/Projects/parley_android main`
  from the parley root. History is preserved as commits under the prefix.
- The Android project keeps its own `Makefile`, `init.sh`, `feature_list.json`,
  `claude-progress.md` and `.claude/` hooks. Its feature ids stay `parley-aNN`.
- `~/Projects/parley_android` is left in place until the user deletes it. The
  root README names `parley-android/` as the only copy to edit.
- Android `.gitignore` entries (`build/`, `.dart_tool/`, `ios/Pods/`) move
  with the subtree; the root `.gitignore` gains nothing.

## Part 2: scaffold the API

- Run `create-express-app parley-api --dir ./parley-api --skip-git` from the
  parley root. Output: Express 4, TypeScript strict, Prisma + SQLite, Zod
  validation, Winston logging with redaction, `{ data, meta }` envelope,
  `ApiError`, Helmet and CORS, sample health, users and todos routes, and its
  own rocketship harness.
- Delete the sample `todos` surface. Keep `health` and `users`.
- Nested `.git` is not created, so the API is tracked by the root repo.
- Port 3100 by default (`PORT` in `parley-api/.env`), so it never collides
  with the agent server.

### First job: sync store

The API's first feature is a sync store that the desktop and Android apps
both read and write. Key proxying and billing are explicitly out of scope
for this spec.

Resources, each scoped to one user:

| Resource | Fields | Notes |
|---|---|---|
| `dictionary` entries | `id`, `spoken`, `written`, `updatedAt`, `deletedAt` | mirrors parley-006 |
| `settings` | one JSON blob per user, `updatedAt` | provider choice, gesture keys, not API keys |
| `history` | `id`, `mode`, `text`, `app`, `createdAt` | last N transcripts, optional opt-in |
| `tasks` | `id`, `title`, `notes`, `dueAt`, `rrule`, `priority`, `status`, `sourceText`, `updatedAt`, `deletedAt` | from the tasks brainstorm on 2026-09-25 |

Rules:

- Auth: bearer token. `POST /api/auth/token` takes an email and returns a
  long-lived token stored by each client. No passwords in v1. Token hashes
  live in the `User` table. Good enough for one person on their own server;
  swap for a real identity provider later behind the same middleware.
- Sync model: last-writer-wins by `updatedAt`, soft deletes via `deletedAt`.
  Each resource exposes `GET /api/<resource>?since=<iso>` and
  `PUT /api/<resource>` with a batch body. Clients keep their local store as
  the source of truth and push or pull on a timer and on change.
- API keys for Groq, Deepgram and MiniMax never leave the client.

### Clients

- Desktop: a `sync` module in `electron/` with one IPC channel added through
  `add-ipc-channel`. Settings gains a Sync tab: server URL, email, token
  status, last sync time, sync now. Off by default.
- Android: out of scope for this spec. It gets its own feature once the API
  is live.

## Part 3: root harness

- Root `Makefile` gains `api-check` and `android-check` targets that run
  `make check` inside each folder, and root `check` depends on both.
  `android-check` skips with a message when `flutter` is not on PATH, so the
  desktop baseline still runs on a machine without Flutter.
- Root `init.sh` adds `npm --prefix parley-api install`, `npx prisma db push`
  in the API, and `flutter pub get` in `parley-android` when flutter exists.
- Root `feature_list.json` gains `parley-014` (monorepo) and `parley-015`
  (sync store), with their own evidence sections. The API and Android
  folders keep their own feature lists for work inside them.
- Root `.claude/hooks` unchanged. The Stop hook already runs `make check`.
- Root `README.md` gets a project map.

## Error handling

- API: scaffold's `ApiError` plus Zod validation errors in the envelope.
- Desktop sync: failures surface in the Sync tab and never block dictation.
  A failed push is retried on the next timer tick; no queue in v1.

## Testing

- API: vitest unit tests for the sync merge rule and supertest route tests
  with a temp SQLite file. `make check` in `parley-api` must be green.
- Desktop: unit tests for the sync module merge logic and the IPC boundary
  test the `add-ipc-channel` skill generates.
- Root: `make check` green on this machine with all four projects.
- Evidence recorded in `feature_list.json` per the rocketship contract.

## Order of work

1. Commit Android pending work, subtree add, root harness targets. Commit.
2. Scaffold API, strip samples, root harness targets. Commit.
3. Sync store in the API with tests. Commit.
4. Desktop sync module and Settings tab. Commit.

Steps 1 and 2 are mechanical and go first so the monorepo is real before
feature work starts.
