---
name: verify
description: Prove a change actually works by type-checking, testing, and driving the real app — not just reading the diff. Run before declaring any non-trivial change done. Use after add-feature/add-page/add-api-endpoint or any change with runtime behavior.
---

# verify — don't declare done until it runs

A change is not done because it compiles. Observe it working end-to-end.

## The loop

1. **Type-check** — `npm run type-check` (`tsc --noEmit`). Zero errors. Fix and
   repeat; never suppress with `any` or `@ts-ignore`.
2. **Test** — `npx vitest run`. Data behaviour needs a test that hits the MSW
   handlers (copy `src/test/example.test.ts`; base URLs on `location.origin`).
   UI behaviour needs a rendering test (copy `src/test/ui-contract.test.tsx`;
   mount routed components with the `renderRoutes` helper in
   `src/test/render.tsx`). Main-process behaviour that can be expressed as a
   pure function belongs in `electron/__tests__/` — see
   `electron/window-options.ts`, which exists precisely so the window can be
   asserted without a display.
3. **Boot and drive** — `npm run dev` launches Vite *and* the Electron window.
   Drive the real window, not a browser tab:
   - Navigate to the affected page (sidebar or ⌘K).
   - For a mutation, perform it and confirm the UI updates + a toast fires.
   - Toggle the theme once to confirm nothing hard-codes a color.
   - **Resize the window short** (~700px tall). The page must not grow a
     page-level scrollbar — only the region inside `PageShell` scrolls, and the
     header must stay put.
   - Drag the window by the titlebar, and confirm any control you added there
     responds to a click instead of moving the window.
   - Watch the DevTools console — zero errors/warnings from your code.
4. **Lint** — `npm run lint`. Zero errors and zero warnings; the script runs
   with `--max-warnings 0`.

## Report

State exactly what you ran and what you observed (e.g. "created a project → row
appeared, toast fired, detail page opened"). If a step was skipped, say so. Do not
report success on the basis of the diff alone.
