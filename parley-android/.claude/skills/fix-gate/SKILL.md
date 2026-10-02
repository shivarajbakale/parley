---
name: fix-gate
description: Diagnose and honestly fix a red `make check` — which of the twelve gates failed, what it is actually claiming, and the difference between the fix and the loosening that looks like one. Use whenever analyze, ui-lint, palette-lint, plan-lint, superplan-lint, doc-lint, design-system-reference, test, ui-probe, golden or ds-catalog-check fails.
---

# fix-gate — going green honestly

Twelve gates run in `make check`:

```
setup ds-catalog-check analyze ui-lint palette-lint plan-lint superplan-lint
doc-lint design-system-reference test ui-probe golden
```

Several of them **ratchet** — they compare against a recorded number rather
than against zero. A ratchet has an obvious wrong fix, and the wrong fix leaves
the tree green and the defect shipped. That is what this skill exists to
prevent.

## Rule zero

**Never make a gate pass by weakening it.** Every one of these is a loosening
wearing the costume of a fix:

- deleting or skipping a failing test
- adding `// ui-lint: allow …` with no reason, or with "temporary" as the reason
- raising a count in `test/probe/debt.dart`
- running `make golden-update` without opening the PNGs
- adding a screen to `ungradedScreens` so the probe stops walking it
- hand-editing `docs/references/design-system-reference-llms.txt`

If the honest fix is genuinely out of scope, say so and leave the gate red.
A red gate with an explanation is worth more than a green one with a lie in it.

## Read the failure before touching anything

Run the failing target alone — `make ui-probe`, not `make check`. Every gate
here prints the measurement, not just the verdict: "overflowed by 31.0pt on the
right" rather than "overflow". The measurement is usually the whole diagnosis.

## Gate by gate

### `ds-catalog-check`

> `ds-catalog.json drifted from lib/design_system/`

The kit changed and the fixture did not.

```
make ds-catalog
git add tool/fixtures/ds-catalog.json
```

It compares with `git diff --quiet`, so staging the file is what satisfies it.

### `analyze`

`flutter analyze` runs with **infos fatal**. An info is not a suggestion here.
Fix the code; do not add an ignore comment unless the analyzer is wrong about
this specific line, and say why in the comment.

### `ui-lint`

Thirty-six rules, each naming the replacement rather than only the ban —
`raw-button` tells you `DSButton`, `raw-divider` tells you `DSDivider`. Read
what it names and use it.

The escape hatch is one line, on the offending line:

```dart
// ui-lint: allow raw-card — this is the card the kit's own DSCard is built from
```

**The reason is the point.** An allow with a real reason is a decision someone
can argue with later; an allow with "needed here" is a hole. Scopes are already
exempt where wrapping is the job — `lib/design_system/` for the `raw-*` rules,
`lib/theme/` for the colour rules, the catalog stories for a few more — so if
you are reaching for an allow inside those directories, the rule is probably
right and the code is in the wrong place.

### `palette-lint`

Not a lint on call sites — it is `test/theme/palette_lint_test.dart`, rules
K1–K8, doing contrast maths on the palette itself in both brightnesses: every
`on` colour against the colour it sits on at 4.5:1, body text against all three
surface roles, the dim roles at 3.0:1, and the neighbouring steps of the
neutral ramp far enough apart to be distinguishable.

The fix is a palette value in `lib/theme/`, never the threshold. It caught five
surface steps whose neighbours sat at 1.06:1 and a filled success button at
1.82:1 in dark, which is exactly the class of defect nobody sees by looking.

It is a `flutter test` rather than a `dart run` tool because the maths returns
`Color` and `dart:ui` does not exist outside the engine — so it also runs
inside `make test`.

### `plan-lint` / `superplan-lint`

The rendered document and its source JSON have drifted. Re-render:

```
make plan        # FEATURE-PLAN.md from its JSON
make superplan   # SUPERPLAN.md from its JSON
```

Never edit the rendered markdown to match — the JSON is the source, and the
next render will overwrite you.

### `doc-lint`

Nine rules, D1–D9, on the documents an agent reads before it writes anything:
`AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md` and `claude-progress.md` within
their line budgets (D1–D5); the instructions describing *this* project rather
than the one it was forked from (D6); no link to a file that is not there (D7);
every hard constraint naming the failure it prevents (D8); and every `passing`
feature's evidence sitting where the register says (D9).

Most failures are a budget or a dead link — shorten, or fix the path. D9 fails
when a feature was marked `passing` without its `docs/evidence/<id>.md`; the
fix is to write the evidence, never to change the status back.

### `design-system-reference`

The generated `.txt` is stale, or a component has no `_selection` entry.

```
make design-system-reference-update
```

If it fails saying a component has no entry, add one in
`tool/design_system_reference.dart` — that is the gate doing its job, and the
`add-component` skill covers what to write.

### `test`

Two failures here are structural rather than behavioural:

- **`screens_registry_test`** — a `*_page.dart` exists that is in neither
  `appScreens` nor `ungradedScreens` in `test/_screens.dart`. Register it, and
  the probe and the goldens both pick it up. Only write it into
  `ungradedScreens` when you can state a real reason, and state it.
- **`component_coverage_test`** — a component in `lib/design_system/` that no
  test names. Write the test. The `notComponents` escape map is for files with
  nothing a widget test could mount; adding a real component to it is how this
  gate stops working.

### `ui-probe`

Two kinds of rule, and the difference decides the fix.

**Absolute rules** — `overflow`, `gutter`, `short-measure`, `double-gutter`,
`word-break`, `empty-padding`, `baseline`, `fold`, `row-air`, `control-air`,
`nesting`, `width-band`, `dual-axis`, and on a tour `tour-art-semantics` and
`tour-progress-label`. Any instance fails. There is no recorded count and
nothing to adjust: fix the layout.

Common causes: a `Row` with no `Expanded` around its text; a fixed height that
stops fitting at textScale 2.0; a raw `SliverList` in a screen where a
`DSGutter.sliver` belongs.

The two width rules are the pair that catches a page whose elements do not span
it, and they fail in opposite directions:

- `short-measure` — a band stops short of the page gutter with nothing beside
  it. Usually a `SizedBox` width, or a `Row` whose children were sized rather
  than `Expanded`. A band *wider* than the page is not flagged: full bleed is a
  deliberate idiom here.
- `double-gutter` — a row's contents are inset twice, because a container
  applied the page gutter and the row applied it again. The rule walks to the
  leftmost painted descendant rather than trusting the row's own box, so it
  sees what the reader sees. The fix is never a negative padding: the container
  announces its gutter with `DSGutter.markApplied`, and `DSListTile` and
  `DSControlTile` read that through `DSGutterScope.applied(context)` and inset
  by zero. On a page only `DSPage`, `DSPageSection`, `DSFormPage` and
  `DSGutter` apply `pageGutter`, and `ui_lint`'s `screen-gutter` fails a screen
  that spells it.

**Graded rules** — `target`, `contrast`, `clipped-text`, `overlap`,
`dead-band`. These compare against per-surface counts in `test/probe/debt.dart`
and **fail when the count moves in either direction.**

- Count went **up**: you added an instance of a known defect class. Fix it.
  Raising the number in `debt.dart` to match is the loosening, not the fix.
- Count went **down**: you fixed something. Lower the number in `debt.dart`
  **and add a line to the doc comment saying what paid it.** That file is a
  history, and a number that changes with no story is a number nobody can
  audit later.
- Count went down to zero for a surface: delete the entry entirely.

### `golden`

A pixel diff is either a regression or the change you meant. There is no way to
tell from the exit code, so open the images.

```
make golden-update
```

Then review **every** changed PNG before staging. A baseline updated without
being looked at will defend the defect it captured for as long as the file
lives.

**If every glyph renders as a box**, the fonts did not load — the golden
harness needs Satoshi and MaterialIcons. That is a harness fault, not a design
change; do not record those baselines.

Goldens are excluded from `make test` (they carry the `golden` tag) and run
under `make golden`, which `make check` depends on. So `flutter test` passing
says nothing about them.

## When you are done

Re-run the full `make check`, not the one target you fixed. These gates
interact: regenerating the reference changes a file `doc-lint` reads, fixing a
layout moves numbers `ui-probe` grades, and adding a screen touches four gates
at once.

Then say which gate was red, what it was actually claiming, and what paid it.
