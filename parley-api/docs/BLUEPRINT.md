# Blueprint Protocol

How the upstream "describe the API → blueprint → approve → features" flow works.
This is the protocol; the living document is `BLUEPRINT.md` at the repo root.

## When it applies

At project start (or a major scope shift), `BLUEPRINT.md` is in **stub form**
(no one-liner, `approved` not ticked). If the user has described an API in that
state, you are in **Blueprint Mode** and must produce a blueprint **before**
writing any code or touching `feature_list.json`.

## The loop

1. **Read the brief.** Grep the repo for what already exists and should shape
   the design: the `{ data, meta }` envelope (`transform.middleware.ts`), the
   `validate`/`error` middleware, existing Prisma models, the todo/user
   resources as patterns.
2. **Fill in `BLUEPRINT.md`** — every section:
   - One-liner
   - Resources & endpoints table (method + path, auth, purpose)
   - Data model (Prisma entities + relations)
   - Validation rules per write endpoint
   - Conventions in force (envelope, status codes, pagination, auth posture)
   - Open questions
   Keep it ≈ one screen of scroll. It's an alignment doc, not a spec dump.
3. **Surface it to the user.** Do not create feature entries, route/service
   files, or schema changes yet.
4. **Iterate** by editing `BLUEPRINT.md` directly as the user responds.
5. **On approval** (user ticks `[x] approved`):
   - Record the approval + date in `claude-progress.md`.
   - Split the blueprint into `feature_list.json` entries — one per resource or
     substantial behavior. Each entry gets a real `verification` (the command
     that will prove it) written *before* coding, and a `notes` line referencing
     the resource `#` from the blueprint table.
   - Resume the normal operating loop (pick the highest-priority feature).

## Guardrails

- The **product-manager** subagent owns this flow. It writes no `src/` code and
  never self-approves the blueprint.
- Auth: this boilerplate ships none. If the brief needs it, decide the posture
  in the blueprint and add a `DECISIONS.md` entry before any auth code lands.
- Don't expand scope after approval without updating `BLUEPRINT.md` and noting
  the change. The blueprint and `feature_list.json` must stay in sync.
