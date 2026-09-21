---
name: add-feature
description: Scaffold a complete resource end-to-end (types → API service → MSW mock → query hooks → pages → route → nav → test), mirroring the Projects reference slice. Use when the user asks to "add a feature", "add a resource/page for X", "build CRUD for X", or "add a section" (e.g. Customers, Invoices, Tickets).
---

# add-feature — build a full vertical slice

This app ships one **reference slice**: **Projects**. Every layer already exists
for it. To add a new resource, copy that slice and rename. Study the reference
first, then reproduce every layer for the new resource — do not skip a layer.

## The reference slice (read these first)

| Layer | Projects file | What it is |
| --- | --- | --- |
| Types | `src/api/types/project.types.ts` | domain type + Create/Update DTOs |
| Service | `src/api/services/projectService.ts` | the HTTP calls (`extractData`) |
| Query hooks | `src/hooks/useProjects.ts` | `useX`, `useCreateX`, … + `xKeys` |
| Mock API | `src/mocks/handlers/projectHandlers.ts` | MSW handlers + seed data |
| Registry | `src/mocks/handlers/index.ts` | where handlers are registered |
| Page | `src/pages/Projects/ProjectsPage.tsx` | master-detail shell: list pane + detail pane |
| Columns | `src/pages/Projects/project-columns.tsx` | TanStack column definitions |
| Detail | `src/pages/Projects/ProjectDetailPane.tsx` | right-hand pane, owns its own scroll |
| Form | `src/pages/Projects/project-form.tsx` | RHF + zod over Mantine inputs, rendered in a `Modal` |
| Route | `src/router/router.tsx` | route registration |
| Nav | `src/config/nav.ts` | sidebar + ⌘K entry |
| API test | `src/test/example.test.ts` | exercises the handlers |
| UI test | `src/test/ui-contract.test.tsx` | renders the slice against MSW |

**Layout contract.** The shell is a fixed viewport (`src/App.tsx` is `h-svh
overflow-hidden`). Pages never scroll as a whole — they render inside
`PageShell`, which pins the title band and gives the body one `ScrollArea`.
`make smoke-ui` in the generating repo fails a build that adds `overflow-y-auto`
outside the design system.

## Procedure

Work top-down. Substitute your resource for `Project`/`project`/`projects`.

1. **Clarify the shape.** Ask for the resource name (singular + plural) and its
   fields if not given. Keep the first version small (3–6 fields).
2. **Types** — create `src/api/types/<resource>.types.ts` (copy
   `project.types.ts`). Export it from `src/api/types/index.ts`.
3. **Service** — create `src/api/services/<resource>Service.ts` (copy
   `projectService.ts`). Endpoints are `/api/<resource-plural>`.
4. **Mock handlers** — create `src/mocks/handlers/<resource>Handlers.ts` (copy
   `projectHandlers.ts`, adjust the seed). Register the array in
   `src/mocks/handlers/index.ts`.
5. **Query hooks** — create `src/hooks/use<Resource>s.ts` (copy `useProjects.ts`).
   Keep the `<resource>Keys` factory — reads and invalidations must use it.
6. **Pages** — create `src/pages/<Resource>s/` by copying the four Projects
   files above: the page, its columns, its detail pane, and its form. Wrap the
   page in `PageShell`. Render the list with `src/components/data-table.tsx` —
   never a hand-written `<table>` — and build the form on Mantine's inputs
   wired to React Hook Form rather than raw `register()` calls. Reach for the
   component Mantine already ships before writing markup: `Progress` for bars,
   `EmptyState` for zero states, `Textarea`, `SegmentedControl`, `Tabs`. Never
   hard-code a colour — Mantine owns colour, border, radius and elevation, and
   [`mantine-capabilities.md`](../use-mantine/mantine-capabilities.md) says
   which component owns which job.
7. **Routes** — register the page in `src/router/router.tsx` twice: once at
   `/<resources>` and once at `/<resources>/$<resource>Id`, both pointing at the
   same component. That is what keeps the list mounted when a row is selected.
   Creation is a Dialog on the list page, not a route.
8. **Nav** — add an entry to `navItems` in `src/config/nav.ts` (pick a
   `lucide-react` icon). This wires both the sidebar and ⌘K.
9. **Tests** — two of them. Copy `src/test/example.test.ts` for the API layer
   (list, create, 404; base fetch URLs on `location.origin`), and copy
   `src/test/ui-contract.test.tsx` for the UI (rows render, selecting one fills
   the detail pane while the list stays mounted). Mount routed components with
   the `renderRoutes` helper in `src/test/render.tsx`.

## Definition of done

Run the `verify` skill. Minimum bar:

```bash
npm run type-check   # tsc --noEmit — zero errors
npx vitest run       # your new test passes
npm run dev          # open the new nav item; list, create, and open a detail
```

Report what you added (one line per layer) and the verification result.

<!-- ux-prepass:v1 -->
<!-- MANDATORY before marking this task done. Same wording as evaluator-rubric.md "UI pre-pass". -->
## Pre-passing checklist (all mandatory)

- [ ] Four states handled: loading, empty, error, success
- [ ] Tap targets >= 44x44pt on all interactive elements
- [ ] Visible focus states on every interactive element
- [ ] Dark mode checked — token colors only, no raw hex/rgb
- [ ] Text overflow: long strings truncate/wrap without breaking layout
- [ ] Keyboard navigable: tab order logical, Enter/Esc behave as expected
