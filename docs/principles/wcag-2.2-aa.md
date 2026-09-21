<!-- principles:v1 -->

# WCAG 2.2 AA — applied to this app

This is the accessibility contract. Every screen must satisfy AA. Below
are the targets that matter most in this app, mapped to the rule that
enforces them. The machine check is `make a11y` (axe-core in jsdom); the
textual check is the relevant subset of `ux-prepass`.

> Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Level AA
> (https://www.w3.org/TR/WCAG22/). Free implementation guidance, not
> normative.

## The targets that matter

### 1. Perceivable

| Criterion | What | How we satisfy it | Enforced by |
| --- | --- | --- | --- |
| **1.1.1 Non-text content** | Images, icons need text alternatives | `alt` on `<img>`; `aria-label` on every icon-only `ActionIcon` — Mantine's tooltip is not a name | axe (image-alt) |
| **1.3.1 Info and relationships** | Headings, lists, form labels are programmatic | every Mantine input takes `label`/`description`/`error` as props and wires `for` and `aria-describedby` itself; table headers are `Table.Th`; headings are `Title order={n}` | axe (label) |
| **1.4.3 Contrast (minimum)** | Text has ≥ 4.5:1 contrast (≥ 3:1 for large text) | all text colour comes from the theme (`c="dimmed"`, `--mantine-color-text`); the ramps in `src/theme.ts` resolve to AA pairs in both schemes | axe (color-contrast) |
| **1.4.11 Non-text contrast** | UI components and graphical objects have ≥ 3:1 contrast | borders, focus rings and icons come from theme values (`--mantine-color-default-border`, `--mantine-primary-color-filled`) | axe (color-contrast) |
| **1.4.13 Content on hover or focus** | Hover content is hoverable, dismissable, persistent | tooltips on icon buttons use Mantine `Tooltip` (hoverable + dismissable); never a hover-only info popup | manual review |

### 2. Operable

| Criterion | What | How we satisfy it | Enforced by |
| --- | --- | --- | --- |
| **2.1.1 Keyboard** | All functionality is available via keyboard | no custom keyboard handling; every interactive element is a `<button>`, an `<a>`, or a Mantine component | axe + manual |
| **2.1.2 No keyboard trap** | Focus can move away from any component | never trap focus; the only traps are `Modal` and `Drawer`, which hold focus *inside* themselves but let `Esc` close | axe |
| **2.4.3 Focus order** | Tab order matches visual order | DOM order = visual order; never `tabindex > 0` | axe (tabindex) |
| **2.4.7 Focus visible** | Keyboard focus is visible | Mantine's own `:focus-visible` ring, tuned once via `theme.focusRing`; never `outline: none` without a replacement | axe |
| **2.5.5 Target size (enhanced)** | Touch targets are ≥ 44×44px (AA in 2.2) | Buttons default to `size="sm"` (36px) or `size="md"` (42px); icon-only buttons use `ActionIcon` at `size="lg"` (40×40) or larger; primary CTAs are `size="lg"` (44+ px) | manual review (no axe rule) |

### 3. Understandable

| Criterion | What | How we satisfy it | Enforced by |
| --- | --- | --- | --- |
| **3.2.1 On focus** | Focusing a component doesn't trigger a context change | No `onFocus` that navigates; `select` on text doesn't auto-submit | axe |
| **3.2.2 On input** | Changing a value doesn't trigger a context change without warning | No `onChange` that navigates; form submits only on user click | axe |
| **3.3.1 Error identification** | Errors are described in text | `FormMessage` renders the error; required fields use `aria-required` | axe |
| **3.3.2 Labels or instructions** | Inputs have labels | `FieldLabel` is mandatory; `aria-describedby` points at `FieldDescription` | axe (label) |

### 4. Robust

| Criterion | What | How we satisfy it | Enforced by |
| --- | --- | --- | --- |
| **4.1.2 Name, role, value** | All UI components have name + role | Mantine exposes the right ARIA for everything except `Spotlight`, whose combobox pattern `src/components/command-palette.tsx` supplies itself; never override `role` unless you also override the behaviour | axe |

## What `make a11y` actually catches

`make a11y` runs this app's vitest-axe suite, which mounts each
page under a memory router and asserts zero axe violations. Axe covers:

- color-contrast
- label (every input has a label)
- image-alt
- button-name
- link-name
- list
- listitem
- region (all content is in landmarks)
- landmark-one-main (one `<main>` per page)
- page-has-heading-one
- aria-allowed-attr
- aria-required-attr
- aria-required-children
- aria-required-parent
- aria-roles
- aria-valid-attr-value
- duplicate-id
- tabindex

It does **not** cover (manual review required):

- 2.5.5 Target size (44×44pt) — no axe rule; eyeball the icon buttons
- 1.4.13 Content on hover/focus (dismissable / hoverable) — no axe rule;
  verify by trying to reach the tooltip via keyboard
- 3.3.4 Error prevention (legal, financial) — N/A for a SaaS starter
- 4.1.3 Status messages — partial coverage; verify the live region
  announces correctly

## What `ux-prepass` covers (textual subset)

The `ux-prepass` skill's six items overlap WCAG as follows:

| ux-prepass item | WCAG criterion |
| --- | --- |
| Four states handled | 4.1.3 (status messages via toasts) |
| Tap targets ≥ 44×44pt | 2.5.5 (target size) |
| Visible focus states | 2.4.7 (focus visible) |
| Dark mode checked | 1.4.3 (contrast in dark mode) |
| Text overflow handled | 1.4.4 (resize text up to 200%) |
| Keyboard navigable | 2.1.1 + 2.4.3 (keyboard + focus order) |

## How to use this list

When you add a screen:

1. Mount it in a story and run `make a11y`.
2. If axe flags anything, fix the component — don't disable the rule.
3. For the targets axe doesn't cover (target size, dismissable hovers),
   eyeball-check.
4. For a new interactive control, prefer the Mantine component over a custom
   implementation — it already handles ARIA correctly, with the one documented
   exception of `Spotlight`.

When you add a new pattern (custom widget, new overlay type), check the
component's entry in `.claude/skills/use-mantine/mantine-capabilities.md` for
what it does and does not ship, then read its source before assuming.

This doc is read-only; it informs but does not enforce. The mechanical
check is `make a11y`. Add a smoke test that mounts the new screen and
asserts `await axe(container)` returns no violations, and the screen
becomes part of the contract.
