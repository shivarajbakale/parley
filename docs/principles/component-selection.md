<!-- principle:component-selection:v1 -->
<!-- Stamped from scaffolders/harness-core/principles by scripts/stamp-principles.mjs in create-rocketship. Edit the source and re-stamp: a hand edit fails principles-drift. -->

# Component Selection

Every other gate in this repo checks that a screen was built *correctly*.
None of them check that it was built out of the *right parts*.

`ui-lint`'s eighteen rules all ask one question — did you hand-roll or
hardcode something the kit already owns? The evaluator rubric's design-system
row asks the same. `ux-prepass` item 7 asks the same. So a Settings page built
as a nine-tab tab bar, a required warning buried in a tooltip, or a
twelve-option `Select` passes every automated check in the repository, because
every control on the screen came from `@mantine/core`.

Choosing the wrong control is the most common way a screen built entirely from
the design system still feels wrong to use. This document is the missing half:
per-family guidance lives in `Use when:` / `Instead:` in
`.claude/skills/use-mantine/mantine-capabilities.md`; the cross-family decisions
— the ones where three or four components are all defensible and only one is
right — live here.

## The default

**When two options are defensible, pick the one that is visible, addressable,
and works without a pointer.** Nearly every rule below is that sentence applied
to a specific family. A route beats a modal because it has a URL. Visible
helper text beats a tooltip because it survives touch and scanning. A grid
beats a carousel because nothing is hidden. Reach for the cleverer option only
when you can say what it buys.

## Disclosure — Tooltip / Popover / HoverCard / Dialog

Three questions, in order:

1. **Is the content needed to succeed at the task?** If yes, it is not
   disclosure at all — put it on the page as visible helper text. Tooltips and
   hover cards do not exist for touch users, screen scanners, or anyone
   working quickly.
2. **Is it interactive?** Anything with a control inside — a button, a field, a
   link the user must click — needs `Popover` (or `Dialog`). Hover-triggered
   surfaces cannot hold interactive content; the pointer has to travel there
   and the surface closes.
3. **Does it deserve a focus trap?** If the user must finish or dismiss before
   continuing, it is a `Dialog`. If they can click away and lose nothing, it is
   a `Popover`.

| Atom | Trigger | Content | Typical use |
| --- | --- | --- | --- |
| `Tooltip` | hover / focus | a few passive words | naming an icon button |
| `HoverCard` | hover | rich, passive, optional | previewing a user or a link |
| `Popover` | click | small, may be interactive | a filter, a colour picker, a mini form |
| `Dialog` | click | a task with a beginning and an end | create / edit / confirm |

An icon-only button always gets a `Tooltip` **and** an `aria-label`. The
tooltip is for sighted pointer users; the label is for everyone else. Neither
substitutes for the other.

## Task surfaces — Dialog / Drawer / Sheet / route

| Surface | Reach for it when | |
| --- | --- | --- |
| `Dialog` | short focused task, page context worth keeping visible | 1–2 fields, a confirm |
| `Sheet` | mid-length task or secondary context, desktop width | detail panel, filters |
| `Drawer` | the same, at mobile width | bottom sheet |
| a route | long, deep-linkable, expensive, or shareable | full create/edit flow |

The discriminator is **length and addressability**, not visual preference. If a
user would ever want to send someone a link to this state, or refresh without
losing it, it is a route. If the task has more than about five fields, it is a
route. Modals lose their content on reload and cannot be bookmarked; that is
the cost you are paying, so get something for it.

Destructive confirmation is a separate case and always `AlertDialog`, naming
the object: `Delete "Acme"?`. A reversible action gets no dialog at all —
apply it optimistically and put undo in a `Sonner` toast. Interrupting someone
to confirm something you could simply undo is a worse experience than the
mistake you are preventing.

## Sectioning — Tabs / Accordion / sidebar rail / separate routes

| Pattern | Reach for it when |
| --- | --- |
| `Tabs` | 2–6 peer views of one subject, cheap to switch, never needed side by side |
| `Accordion` | independent sections, long content, users need one at a time |
| `Sidebar` rail | more than ~6 sections, or the sections are destinations rather than views |
| separate routes | each view is deep-linkable, independently loadable, or expensive |

Failure modes worth naming, because agents hit all three:

- **Tabs that should be routes.** If tab state should survive a refresh or be
  linkable, it belongs in the URL.
- **Tabs for settings.** Settings sections are destinations, not peer views of
  one object. Use the Stripe-style sidebar rail — see the `add-settings` skill.
- **Tabs that keep growing.** Past six, the row wraps or scrolls and scanning
  collapses. Move to a rail before that, not after.

Content the user needs to **compare** must never be split across tabs or
accordion panels. Comparison requires simultaneity.

## Choosing a value — Select / Combobox / RadioGroup / ToggleGroup

Option count decides it, then whether the options need explaining:

| Count | Pattern |
| --- | --- |
| 2, mutually exclusive, applies instantly | `Switch` |
| 2–5, comparison helps, options need labels or descriptions | `RadioGroup` |
| 2–5, compact, usually icons, in a toolbar or above a view | `ToggleGroup` |
| ~5–10, fixed and known | `Select` |
| 10+, or the user knows the name and typing is faster | `Combobox` |
| many, and more than one may be chosen | `Combobox` with chips |

`Switch` vs `Checkbox` is not a style choice: **`Switch` applies immediately,
`Checkbox` is submitted with a form.** A switch beside a Save button is a
broken promise, and a checkbox that silently persists on click is a different
one.

Never make someone type a value you already have — that is a `Combobox`, not
an `Input`.

## Telling the user something — Sonner / Alert / FormMessage / EmptyState

| Atom | Lifetime | Scope |
| --- | --- | --- |
| `Sonner` toast | transient | the action that just completed, plus undo |
| `Alert` | persistent | a region or the page — standing state or warning |
| `FormMessage` | until fixed | one field |
| `EmptyState` | until data exists | one list or pane |

A validation error never goes in a toast: it must sit beside the field, and it
must persist until fixed. Anything the user has to act on later never goes in a
toast either — toasts leave, and they leave fastest for the people reading
slowest.

## Showing records — Table / DataTable / Card grid / Chart

- `Table` — static, small, no interaction on the data itself.
- `DataTable` — the instant sorting, filtering, pagination, or selection
  appears. Do not grow a `Table` into one by hand.
- `Card` grid — the record is visual or has few shared attributes; a table of
  it would be mostly empty columns.
- `Chart` — the trend or comparison is the point. If the user came for exact
  values, they came for a table; a chart plus a table is often the honest
  answer.

Every one of these still needs all four states (loading / empty / error /
success). `EmptyState` is not optional decoration; a blank region is a bug.

## When nothing here fits

Say so in `DECISIONS.md` and explain the trade. A deviation with a recorded
reason is fine — that is what the file is for. A deviation nobody wrote down
becomes the next agent's precedent.

## How this is checked

- `.claude/skills/use-mantine/mantine-capabilities.md` carries `Use when:` and
  `Instead:` for every component family the app uses, and `capability-lint`
  fails the build when an entry loses either — or when the source imports a
  component the map does not explain, so a new one cannot land without
  selection guidance.
- The evaluator rubric's **Control fit** row scores whether the chosen control
  suited the job, not merely whether it came from the kit. That row is judged,
  not linted: no static rule can tell a well-chosen `Tabs` from a badly-chosen
  one.
