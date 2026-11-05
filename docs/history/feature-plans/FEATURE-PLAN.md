<!-- feature-plan:v1 — generated, do not hand-edit.
     Regenerate with: node scripts/feature-plan.mjs parley-015.feature-plan.json -->

# Sync: dictionary and settings follow you between devices

`parley-015` · 2 surfaces

## Problem

Every Parley install keeps its own dictionary and settings. A word taught on one Mac, or a gesture key changed there, never reaches the other Mac (or, later, the Android app), so the user teaches the same words twice and the devices drift. The parley-api server (parley-014) now stores both per user. This feature signs the desktop app in to that server with an email, then pushes local edits and pulls remote ones on a timer and soon after any change, last writer wins. A new Sync tab in Settings shows four states: signed out (an email form), signing in, synced (account, last sync time, Sync now), and error (the last failure stays visible). API keys never leave the Mac, and a failed sync never blocks dictation. Frame note: the settings window is not PageShell, so the archetype below is illustrative and not probe-enforced, as in parley-007 to parley-013.

## Not in this feature

- Real identity: sign-in is email to bearer token with no password, good enough for one person on their own server.
- Syncing API keys (Groq, Deepgram, MiniMax) or the sync URL, email and switch themselves; those stay on this device.
- History and tasks resources: the API has room for them, the desktop does not sync them in v1.
- A retry queue or offline journal: a failed run is retried on the next timer tick.
- The Android client: it gets its own feature once the API is live.

## Surfaces

### Sync tab · signed in · `settings.html · settings · Sync`

Archetype: `list-detail` — Show that this Mac is signed in, when it last synced, and let the user sync now or sign out.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Sync tab · signed in                          [ Sync now ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Agent         │ │ Parley           │ │ Sync                              │ │
│ Sync          │ │ ──────────────── │ │ Dictionary and settings follow yo…│ │
│ Sync tab · si…│ │ □ Overview       │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ SERVER                          … │ │
│               │ │ □ General        │ │ Sync URL [http://localhost:3100]… │ │
│               │ │ □ Agent          │ │ ACCOUNT                         … │ │
│               │ │ ▣ Sync           │ │ Account ...... me@example.com  S… │ │
│               │ └──────────────────┘ │ Sync ......... (on)             … │ │
│               │                      │ Last sync .... 2 min ago   Sync … │ │
│               │                      │   Synced 3 up, 1 down           … │ │
│               │                      │ ───────────────────────────────── │ │
│               │                      │ [Sync now]  [Sign out]            │ │
│               │                      └───────────────────────────────────┘ │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Sync tab · signed…⌕   │         │ ‹ Back  Sync             │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ □ Overview           │ │         │ │ Sync                 │ │
│ │ □ Gesture            │ │         │ │ Dictionary and setti…│ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ │ □ Agent              │ │         │ │ SERVER             … │ │
│ │ ▣ Sync               │ │         │ │ Sync URL [http://lo… │ │
│ └──────────────────────┘ │         │ │ ACCOUNT            … │ │
│       [ Sync now ]       │         │ │ Account ...... me@e… │ │
└──────────────────────────┘         │ │ Sync ......... (on)… │ │
                                     │ │ Last sync .... 2 mi… │ │
                                     │ │   Synced 3 up, 1 do… │ │
                                     │ │ ──────────────────── │ │
                                     │ │ [Sync now]  [Sign o… │ │
                                     │ └──────────────────────┘ │
                                     └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ Signed out (no       │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ token): the Account  │   │ The last run failed: │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ group is an email    │   │ a red Alert titled   │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ field and a Sign in  │   │ Last sync failed     │
│                      │   │ button. No Sync now, │   │ carries the message  │
│                      │   │ no Last sync row.    │   │ ('fetch failed',     │
│                      │   │                      │   │ 'Signed out: the     │
│                      │   │ [ Sync now ]         │   │ server rejected the  │
│                      │   │                      │   │ token') and the line │
│                      │   │                      │   │ 'Dictation keeps     │
│                      │   │                      │   │ working; sync        │
│                      │   │                      │   │ retries every five   │
│                      │   │                      │   │ minutes.' A failed   │
│                      │   │                      │   │ sign-in shows its    │
│                      │   │                      │   │ message under the    │
│                      │   │                      │   │ form.                │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: Synced: the account badge, Last sync as relative time, and after Sync now the outcome line ('Synced 3 up, 1 down'). A gesture key pulled from another device takes effect without a restart.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

### Sync tab · signed out · `settings.html · settings · Sync`

Archetype: `list-detail` — Sign this Mac in to the sync server with an email address.

**Desktop @1440**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ▨ Parley      ⌕ Search…                                     ⌘K   ◐   ⬤     │
├───────────────┬────────────────────────────────────────────────────────────┤
│ Overview      │ Sync tab · signed out                          [ Sign in ] │
│ Gesture       │                                                            │
│ General       │ ┌──────────────────┐ ┌───────────────────────────────────┐ │
│ Agent         │ │ Parley           │ │ Sync                              │ │
│ Sync          │ │ ──────────────── │ │ Dictionary and settings follow yo…│ │
│ Sync tab · si…│ │ □ Overview       │ │ ───────────────────────────────── │ │
│               │ │ □ Gesture        │ │ SERVER                            │ │
│               │ │ □ General        │ │ Sync URL [http://localhost:3100]  │ │
│               │ │ □ Agent          │ │ ACCOUNT                           │ │
│               │ │ ▣ Sync           │ │ Email [you@example.com]   Sign in │ │
│               │ └──────────────────┘ │ ───────────────────────────────── │ │
│               │                      │ [Sign in]                         │ │
│               │                      └───────────────────────────────────┘ │
└───────────────┴────────────────────────────────────────────────────────────┘
```

**Mobile @390** — design intent; the probe measures 1280 / 1440 / 1920 only.

```
┌──────────────────────────┐         ┌──────────────────────────┐
│ ☰  Sync tab · signed…⌕   │         │ ‹ Back  Sync             │
├──────────────────────────┤         ├──────────────────────────┤
│ ┌──────────────────────┐ │    ──▶  │ ┌──────────────────────┐ │
│ │ □ Overview           │ │         │ │ Sync                 │ │
│ │ □ Gesture            │ │         │ │ Dictionary and setti…│ │
│ │ □ General            │ │         │ │ ──────────────────── │ │
│ │ □ Agent              │ │         │ │ SERVER             … │ │
│ │ ▣ Sync               │ │         │ │ Sync URL [http://lo… │ │
│ └──────────────────────┘ │         │ │ ACCOUNT            … │ │
│       [ Sign in ]        │         │ │ Email [you@example.… │ │
└──────────────────────────┘         │ │ ──────────────────── │ │
                                     │ │ [Sign in]            │ │
                                     │ └──────────────────────┘ │
                                     └──────────────────────────┘
```

**States**

```
        loading                     empty                      error
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ The default: sync is │   │ ⚠                    │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ off and no token is  │   │ An invalid email is  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ stored, so only the  │   │ refused in the form  │
│ ▓▓▓▓▓▓▓▓▓  ▓▓▓▓▓     │   │ URL and the email    │   │ ('Enter an email     │
│                      │   │ form show.           │   │ address'); a server  │
│                      │   │                      │   │ that cannot be       │
│                      │   │ [ Sign in ]          │   │ reached or refuses   │
│                      │   │                      │   │ shows its message in │
│                      │   │                      │   │ a red Alert under    │
│                      │   │                      │   │ the form, and        │
│                      │   │                      │   │ nothing is stored.   │
│                      │   │                      │   │                      │
│                      │   │                      │   │ [ Try again ]        │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
 Skeleton mirrors rows       one CTA, 3 lines max      retry, never raw text
```

Success: The token is stored encrypted, the switch turns on, and the tab flips to the signed-in layout with 'Signed in and synced'.

Held to:

- B1 — two or more top-level panels sharing a top edge
- B2 — no panel scrolls; PageShell owns the single scroll region

## Components

Each choice states the neighbour it beat. `Use when:` / `Instead:` for every
component family lives in `.claude/skills/use-mantine/mantine-capabilities.md`;
the choices between families live in
`docs/principles/component-selection.md`.

| Surface | Control | Why this one | Not |
| --- | --- | --- | --- |
| sync-signed-out | `Email TextInput with react-hook-form + zod email, and a Sign in Button with loading` | The same validated-input-plus-action shape AgentUrlSection already uses; the button's loading state is the signing-in state. | `A Modal sign-in flow (one field does not earn an overlay), a magic-link step (the API returns the token directly)` |
| sync-tab | `SettingRow + Badge for the account, Switch for Sync, Button for Sync now` | Matches the Agent tab's row language: label left, state and its one action right. The Switch pauses sync without signing out. | `A Card per state (heavier than the other tabs), a SegmentedControl for on/off (a binary is a Switch)` |
| sync-tab | `Alert color=red role=alert titled 'Last sync failed'` | The failure persists across reopenings (syncLastError lives in the store), so it is a standing record, not a toast. | `Notification toast (gone before the user looks), inline dimmed text (too quiet for a broken sync)` |

## Data model

- **Settings**
  - `syncEnabled`: boolean — default false; device-local, never synced
  - `syncUrl`: string — default http://localhost:3100; device-local
  - `syncEmail`: string — device-local
  - `syncTokenEncrypted`: string — safeStorage-encrypted bearer token; set only through sync:signIn / sync:signOut
  - _relations:_ SettingsView gains hasSyncToken, syncLastAt (last successful run) and syncLastError; DictionaryEntry gains updatedAt and the store keeps tombstones for removals

## API endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| IPC invoke | `sync:signIn` | no | undefined |
| IPC invoke | `sync:signOut` | no | undefined |
| IPC invoke | `sync:now` | no | undefined |
| POST | `<syncUrl>/api/auth/token` | no | undefined |
| GET | `<syncUrl>/api/dictionary?since= · /api/settings?since=` | no | undefined |
| PUT | `<syncUrl>/api/dictionary · /api/settings` | no | undefined |

## Integration points

```
  electron/main.ts          ──▶  electron/sync/engine.ts   (the engine is rebuilt when the URL, the switch or the token changes; runs 10 s after rebuild, every 5 min, and 30 s after a settings or dictionary change; applySettings after a successful run)
  electron/sync/engine.ts   ──▶  electron/dictionary-store.ts + electron/settings-store.ts   (changedSince / applyRemote, last writer wins by updatedAt)
  src/settings/SyncTab.tsx  ──▶  window.parley.signInSync / signOutSync / syncNow   (hooks in use-parley.ts invalidate the settings query)
```

## Blast radius

```
new (6)
  ├── electron/sync/client.ts
  ├── electron/sync/engine.ts
  ├── electron/sync/__tests__/client.test.ts
  ├── electron/sync/__tests__/engine.test.ts
  ├── src/settings/SyncTab.tsx
  └── src/settings/__tests__/SyncTab.test.tsx

changed (14)
  ├── electron/main.ts
  ├── electron/preload.ts
  ├── electron/types.ts
  ├── electron/settings-store.ts
  ├── electron/dictionary-store.ts
  ├── electron/__tests__/settings-store.test.ts
  ├── electron/__tests__/dictionary-store.test.ts
  ├── src/settings/tabs.ts
  ├── src/settings/TabRail.tsx
  ├── src/settings/SettingsShell.tsx
  ├── src/settings/use-parley.ts
  ├── src/settings/SettingsShell.stories.tsx
  ├── src/settings/Wizard.stories.tsx
  └── feature_list.json
```

## Verification plan

- [ ] `make check`
- [ ] `npm run test -- electron/sync electron/__tests__/settings-store.test.ts electron/__tests__/dictionary-store.test.ts`
- [ ] `make -C parley-api check`
- [ ] `Storybook: SettingsShell SyncSignedOut, SyncSigningIn, SyncSynced, SyncError in dark and light`
- [ ] `make dev with parley-api running on :3100: sign in, add a dictionary word, see it in sqlite via prisma studio; stop the API, press Sync now, see the error line and dictate normally`
- [ ] `ux-prepass` — all seven boxes, `npm run ui-lint` green is the evidence for item 7

---

Approve this before any file is written. Every diagram above is rendered
from this feature's plan JSON, so the drawing and the build cannot drift;
the archetype frames are the same shapes `ui-probe` rules B1-B4 assert
against the real DOM once the screens exist.
