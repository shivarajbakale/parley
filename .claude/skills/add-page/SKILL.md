---
name: add-page
description: Add a new routed page and wire it into the router, sidebar, and ⌘K command palette. Use when the user wants a standalone page/screen/tab that isn't a full CRUD resource (e.g. Billing, Reports, Team, an overview screen).
---

# add-page — add a routed screen

Use this for a page that isn't a full data resource (for that, use `add-feature`).

## Steps

1. **Create the page** at `src/pages/<Name>.tsx`. Start from the shape of
   `src/pages/Settings.tsx`:
   - Wrap everything in `<PageShell title="…" description="…" actions={…}>`
     from `@/components/page-shell`. It pins the title band and owns the page's
     single scroll region. Pass `scroll={false}` only when the page manages its
     own panes, as `ProjectsPage` does.
   - **Never add `overflow-y-auto`.** The shell is a fixed viewport
     (`src/App.tsx`), and `make smoke-ui` in the generating repo fails a build
     that breaks that contract.
   - If the page has more than two sections, prefer `Tabs` over stacking them —
     see `src/pages/Settings.tsx`. Long stacked pages are what the layout
     contract exists to prevent.
   - Compose from `@mantine/core` and read the theme — never hard-code a
     colour. Group content in a `Card` or a `Paper withBorder`, and lay it out
     with `Group` / `Stack` / `SimpleGrid` / `Flex` / `Box`. `make ui-lint`
     fails the build on a utility class: this app emits none, so one would
     style nothing.
   - For KPI tiles reuse `src/components/stat-card.tsx`; for zero states use
     Mantine's `EmptyState`; for lists use `src/components/data-table.tsx`.
   - Which component to reach for is documented, not guessed: read
     [`mantine-capabilities.md`](../use-mantine/mantine-capabilities.md)
     before composing.
2. **Register the route** in `src/router/router.tsx`: add a `createRoute({ path,
   component, getParentRoute: () => rootRoute })` and include it in
   `rootRoute.addChildren([...])`.
3. **Add navigation** in `src/config/nav.ts`: push an entry to `navItems` with a
   `lucide-react` icon. This lights up the sidebar link **and** the ⌘K palette,
   and the topbar page title (`pageTitleFor`).
4. If the page should be **public** (no auth), add its path to `PUBLIC_ROUTES` in
   `src/App.tsx`.

## Verify

`npm run type-check`, then `npm run dev` and confirm the sidebar link + ⌘K entry
navigate to the page and the topbar shows its title.

<!-- ux-prepass:v1 -->
<!-- MANDATORY before marking this task done. Same wording as evaluator-rubric.md "UI pre-pass". -->
## Pre-passing checklist (all mandatory)

- [ ] Four states handled: loading, empty, error, success
- [ ] Tap targets >= 44x44pt on all interactive elements
- [ ] Visible focus states on every interactive element
- [ ] Dark mode checked — token colors only, no raw hex/rgb
- [ ] Text overflow: long strings truncate/wrap without breaking layout
- [ ] Keyboard navigable: tab order logical, Enter/Esc behave as expected
