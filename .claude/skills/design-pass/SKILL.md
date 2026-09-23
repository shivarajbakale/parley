---
name: design-pass
description: Raise the design quality of a screen that already exists — hierarchy, spacing rhythm, colour weight, the peak-and-end moments — and translate generic mobile-UI advice into this app's tokens and design-system widgets. Use when the user says "make this screen look better", "improve the design", "polish this UI", "the layout feels flat", "add some delight", or brings in mobile-UI guidance written for React Native, SwiftUI or Tailwind that has to land in Flutter here.
---

# design-pass — good mobile design, spoken in this app's tokens

Most mobile-UI guidance on the internet is right about *what* to do and wrong
about *how* to do it here. It will tell you to use an 8-point grid, cap the type
scale, keep colour to 60/30/10, put the primary action in the thumb zone — all
true — and then hand you Tailwind classes, `rounded-3xl`, Lucide icons and
Recharts. None of that exists in this app, and reaching for the Flutter
equivalent by hand is exactly what `tool/ui_lint.dart` fails.

This skill is the translation layer. **Take the reasoning from the guidance;
take the values from the spec.** The spec is not a suggestion — it is a build
gate.

## Which skill you actually want

| Situation | Skill |
| --- | --- |
| New data-backed feature | `add-feature` |
| New routed screen, shape is obvious | `add-screen` |
| New screen or tab where the layout is a real argument | `plan-feature` |
| A screen exists and it does not feel good | **this one** |

If the pass turns into a re-architecture — a screen splitting in two, a new
route, a different archetype — stop and run `plan-feature`. Redrawing a screen
is a plan, not a polish.

## Step 1 — diagnose before you touch anything

Answer three questions in writing, in your reply, before the first edit:

1. **What is the user's primary goal on this screen?** Everything that does not
   serve it is competing with it.
2. **What should they notice first?** Name one element. If you can name three,
   the screen has no hierarchy and that is the finding.
3. **How should it feel?** Trust, calm, delight, urgency — this decides how much
   motion and colour the screen has earned.

Then **name the category and the user stage** (see
[`docs/references/industry-conventions.md`](../references/industry-conventions.md) —
finance, fitness, sleep, crypto and the rest each have a default visual
language users already expect). A finance screen that reads like a sleep
screen is wrong before you can say why.

Then name the archetype from `docs/principles/screen-archetypes.md` (Step 0
in that file is the category + stage check) and check the screen is honouring
it. A `focal` screen rendered as six equal tiles is the single most common
defect this pass catches. `test/screens/archetypes_test.dart` holds the demo
screens to their declared archetype.

## Step 2 — translate the advice

Generic guidance maps onto owners in this app. Use the owner, never the literal
value:

| The advice | The owner here |
| --- | --- |
| "8-point grid, no random spacing" | `lib/theme/spec/space_spec.dart` — `unit: 4` and the step list already produce 2/4/8/12/16/24/32/48. Read it as `context.design.space.*`; there is no spacing namespace to reach for, and `ui_lint` fails a bare number in an `EdgeInsets` |
| "Page padding / gutters" | `pageGutter` has exactly one owner — `DSPage`'s `DSPageSection`, `DSFormPage` and `DSGutter`. A screen that spells the token fails `ui_lint`'s `screen-gutter`; read `DSGutter.of(context)` where an `EdgeInsets` is required and there is no child to wrap. A row that insets itself asks `DSGutterScope.applied(context)` first, or it insets twice inside a container that already did |
| "Max 4 sizes, 2 weights" | `lib/theme/spec/type_spec.dart` — a modular scale off `baseSize` with four role weights plus one emphasis step. Pick a role, don't invent a size. See `docs/principles/spacing-and-type.md` |
| "60/30/10 colour, opacity for text hierarchy" | `lib/theme/spec/palette_spec.dart`. `make check` runs a contrast gate — a colour that fails WCAG fails the build, so you cannot fade text to taste |
| "Soft, tinted shadows — never harsh black" | `lib/theme/spec/elevation_spec.dart`, read as `context.design.elevation`. Surfaces come from `lib/theme/app_materials.dart`; see `docs/principles/depth-and-materials.md` |
| "Rounded 2xl/3xl cards" | `lib/theme/spec/shape_spec.dart`, read as `context.shapeOf(AppShape.card)` for the border or `context.radiusOf(...)` for the number |
| "Micro-animations, state transitions" | `lib/theme/spec/motion_spec.dart`, read as `context.design.motion` — durations, curves and the three springs, with `context.springsAvailable` deciding which of the two a state change uses; `docs/principles/motion.md` |
| "Celebratory feedback on success" | `lib/theme/app_haptics.dart` paired with motion — see `docs/principles/premium.md` |
| "44×44pt tap targets" | 48×48dp here (Material minimum), in the pre-pass checklist below |
| "Tailwind / Lucide / Recharts / backdrop-blur" | Nothing. Ignore it wholesale |

If a piece of advice has no owner in the table, it is a component question:
`docs/references/design-system-reference-llms.txt` lists every widget with a
`Use when:` / `Instead:` line, and `docs/principles/component-selection.md`
covers the families where three choices are all defensible. The **Components**
tab (`lib/screens/design_system/`) renders the same catalog live.

## Step 3 — spend the polish where it is remembered

People remember the **peak** and the **end** of an interaction, not its average.
Do not sprinkle motion evenly across the screen.

- Find the peak — the moment the core task completes, the number lands, the
  thing they came for appears. That is where a spring, a haptic and a colour
  accent are worth their cost.
- Find the end — the last thing on screen before they leave. A summary, a state
  of progress, a reason to come back.
- Everything else stays quiet. Motion on a row that does nothing reads as lag.

The owner of this reasoning is
[`docs/principles/emotional-design.md`](../principles/emotional-design.md).
Read it before this step if the peak is not obvious — the Peak-End mapping
exercise (lay out every step in the core flow, ask where stress peaks, pick
ONE "holy dang" moment) is what makes the peak findable, and the Spotify
three (Trojan Horse, Vanity Mirror, Comfort Trap) are what keep the rest of
the screen quiet.

## Step 4 — make the passive states as designed as the happy one

A pass is not done while the screen only looks good full of data. Loading, empty
and error are surfaces with their own hierarchy: an empty state gets guidance,
an illustration and a call to action, not a grey sentence. Error copy names what
the user can do. `docs/principles/premium.md` and the checklist below are the
bar.

## Rules

- No `Color(0xFF…)` outside `lib/theme/`. No literal `EdgeInsets` numbers —
  `AppSpacing.*` or nothing.
- Never hand-roll a control the kit owns. `ui_lint` names the replacement; if the
  exception is genuine, waive it inline with
  `// ui-lint: allow <rule-id> — <reason>` and justify it in your reply.
- Don't widen a token to make one screen work. A token change is every screen's
  change and needs the goldens re-approved.
- Changing pixels changes goldens. Run `make golden` and look at the diffs —
  approving a golden you did not read defeats the whole gate.

## Verify

`flutter analyze`, then `dart run tool/ui_lint.dart` (zero violations), then
`flutter test`, then `make golden` if anything visual moved — and then run the
app and look at the screen in both themes. Run the `verify` skill for the full
bar. A design pass that nobody looked at is not a design pass.

<!-- ux-prepass:v2 -->
<!-- MANDATORY before marking this task done. Same wording as evaluator-rubric.md "UI pre-pass". -->
## Pre-passing checklist (all mandatory)

- [ ] Four states handled: loading, empty, error, success
- [ ] Touch targets >= 48x48dp (Material minimum)
- [ ] Semantics labels on icon-only controls (screen readers)
- [ ] Dark mode checked — theme scheme roles only, no hardcoded hex
- [ ] Content wraps, labels ellipsise. A headline, title or body string cut
      with "…" is a defect, not a fitted layout — give it lines. `make
      ui-probe` fails it (`clipped-text`), and fails a box narrower than a
      word of what it holds (`word-break`)
- [ ] Every new screen registered in `test/_screens.dart` — that list is what
      `make ui-probe` walks and `make golden` records, and an unregistered
      screen is graded by nothing
- [ ] Navigation works via keyboard/external input where supported
