---
name: ux-prepass
description: The mandatory UI/UX pre-pass checklist every UI-touching skill runs before declaring its task done. Single source of truth — the shared items and this platform's items live here, every UI skill links here, and evaluator-rubric.md's "UI pre-pass" row references this same wording.
---

<!-- ux-prepass:v4 -->
<!-- Stamped from harness-core/ux-prepass by stamp-principles.mjs in create-rocketship. A hand edit is overwritten by the next stamp. -->

# ux-prepass — the UI pre-pass checklist

This is the **single source of truth** for the items every UI-touching task must
pass before it's done. The wording here is the wording referenced from:

- The `verify` and `design-pass` skills.
- The `add-screen`, `add-component`, `add-form` and `add-feature` skills (their Verify sections).

Do not inline the checklist into another file — that is what this skill exists
to prevent.

> This checklist catches *how* a screen is built. The decisions that come before
> it — which shape the screen takes, which controls it uses, how much it shows
> at once — are argued in:
>
> - [`docs/principles/density-and-disclosure.md`](../../../docs/principles/density-and-disclosure.md)
> - [`docs/principles/microcopy.md`](../../../docs/principles/microcopy.md)
> - [`docs/principles/accessibility.md`](../../../docs/principles/accessibility.md)
> - [`docs/principles/component-selection.md`](../../../docs/principles/component-selection.md)
> - [`docs/principles/screen-archetypes.md`](../../../docs/principles/screen-archetypes.md)
> - [`docs/principles/spacing-and-type.md`](../../../docs/principles/spacing-and-type.md)
> - [`docs/principles/motion.md`](../../../docs/principles/motion.md)

## Shared items (every platform)

- [ ] **Four states handled:** loading, empty, error, success. Every async
  surface renders all four. Missing any one is a bug.
- [ ] **Tap targets ≥ 44×44** on every interactive element. On Flutter that is 48×48 logical pixels, Material's own floor.
- [ ] **Visible focus states** on every interactive element (`:focus-visible`
  ring, not a colour change alone).
- [ ] **Keyboard navigable** — tab order is logical, Enter / Esc behave as
  expected, and the surface is fully usable without a pointer. On Flutter, "focus ring" above means a visible focus decoration, and the
  pointer-free check is a hardware keyboard and a screen reader.
- [ ] **Density and disclosure** — the page fits its job without a long scroll:
  at most 2.5 viewports tall on a 1040px-tall desktop, the primary action inside
  the first viewport, at most one banner at a time, success shown as a toast,
  confirmation as a modal, and secondary content in a sidebar, a tab or a
  collapsed section rather than one more card down the page.

## Flutter items

- [ ] **Through the design system** — screens use the `DS*` widgets and theme
  tokens, not raw `Text(`, literal colours or ad-hoc durations. `make ui-lint`
  is the evidence.
- [ ] **Every new screen is registered** in `test/_screens.dart`, or no gate
  mounts it.

## Where the boxes get checked

`make ui-lint` is the evidence for the design-system box. `make ui-probe` mounts every registered screen at three widths, three text scales and both platform skins. `make golden` catches a change against a recorded baseline. The rest are yours to confirm on a device — see the `verify` skill.

## How skills reference this

In a skill's Verify section, replace any inline pre-pass block with:

```md
See `ux-prepass` for the mandatory UI gates. Confirm every box
before marking this task done.
```

The `<!-- ux-prepass:v4 -->` marker at the top of this file is the version — bump
it and update every reference if the items ever change in a breaking way.

## Why it's a skill, not a doc

A skill is an actionable unit an agent can read by name, and it appears in the
same Skills table every agent already reads at session start. A checklist in
`docs/` gets found only by someone already looking for it.
