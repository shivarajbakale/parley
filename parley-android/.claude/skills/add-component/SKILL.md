---
name: add-component
description: Add a widget to the design system in lib/design_system/ — the style class, the four-layer resolution chain, the barrel export, the selection guidance, the catalog story, the test and the golden. Use when a screen needs a control the kit does not have, or when the user asks to "add a component", "add a DS widget", "make X reusable".
---

# add-component — a widget that joins the kit

Adding a file to `lib/design_system/` is not one edit. It is seven, spread
across six files, and four of them are gates: a component that skips one does
not merely lack polish, it fails `make check`. This is the order that works.

For a screen, use `add-screen`. For a data slice, use `add-feature`. This is
only for the kit itself.

## Before writing anything: does the kit already own this?

Read `docs/references/design-system-reference-llms.txt` in one pass. It lists
every component with a `Use when:` / `Instead:` line, which is exactly the
question you are asking. Most "we need a new component" turns out to be a
variant of one that exists, and a variant is a style field or a named
constructor, not a file.

A new file is right when the job has no owner — a control the kit cannot make
by composing what it ships, or a raw Material widget that `ui_lint` bans and
nothing wraps yet.

## The seven edits

### 1. The file

`lib/design_system/ds_<name>.dart`, snake case. **No leading underscore** — the
underscore prefix means "private to the kit", and the reference generator, the
catalog and the coverage gate all skip those files. A component named
`_ds_thing.dart` is invisible to every gate that would grade it.

The class name has the same trap at the other end. `tool/generate_ds_catalog.dart`
reads a suffix as a declaration of plumbing and drops the class from the
catalog, which means no superplan can cite it: `…Style` (a theme extension),
`…Painter`, `…Host`, `…Reporter`, and `…Skeleton` (the loading state of the kit
it is named after — the generic wrapper `DSSkeleton` is the one exception).
Name a real component past those endings.

### 2. The style class

Every component carries one, and it is the part that is mechanical enough to
get wrong. Copy `lib/design_system/ds_divider.dart` — it is the smallest
complete example.

```dart
@immutable
class DSThingStyle extends DSComponentStyle<DSThingStyle> {
  const DSThingStyle({this.padding, this.color});

  // Every field nullable. Null means "not decided at this layer", which is
  // what makes merge work.
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  DSThingStyle merge(DSThingStyle? other) { ... }   // other wins, field by field

  @override
  DSThingStyle copyWith({ ... }) => ...;

  @override
  DSThingStyle lerp(DSThingStyle? other, double t) => ...;  // Color.lerp, lerpDouble

  static DSThingStyle resolve(BuildContext context, [DSThingStyle? own]) {
    return resolveStyle(
      context: context,
      specDefaults: DSThingStyle(
        padding: context.design.space.md,
        color: context.palette.surface,
      ),
      own: own,
    );
  }
}
```

`resolveStyle` is what stacks the four layers — spec defaults, the theme
extension, the enclosing `DSScope`, then the instance's `style:`. Write it by
hand and you get one of those layers wrong; `component_contract_test.dart`
asserts all four and will say which.

**`specDefaults` reads tokens, never literals.** `context.design.space.*`,
`context.design.component.*`, `context.palette.*`. `ui_lint` fails a hardcoded
radius, duration, curve, shadow, text style or hex anywhere under
`lib/design_system/`.

### 3. The doc comment, in the parsed shape

The class doc comment must carry a `**Use when**` line and an `**Instead:**`
line. `tool/generate_ds_catalog.dart` parses exactly those two markers into the
catalog's `useWhen` / `instead` fields, and the superplan validator resolves
`kit:` references against that catalog. Prose without the markers produces a
catalog entry with empty guidance.

Say why the component exists rather than what it is. `ds_divider.dart`'s
comment explains that Material's `Divider` defaults `height` to 16 and silently
adds vertical space — that is the sentence that stops the next person deleting
the file.

### 4. Barrel export

Add the export to `lib/design_system/design_system.dart`. `ui_lint`'s
barrel-drift rule fails a component the barrel does not name.

### 5. Selection guidance — the one that fails the build

Add an entry to `_selection` in `tool/design_system_reference.dart`:

```dart
'ds_thing': Selection(
  use: 'The job this is for, stated so a wrong fit is obvious.',
  instead: 'The neighbour reached for by mistake, and the question that separates them.',
),
```

**A component with no entry fails `make design-system-reference`.** That is
deliberate: a widget cannot join the kit with no guidance attached.

`instead` is the half that earns the file. "Use DSDialog for dialogs" teaches
nothing; "DSDialog when the answer blocks the next step, DSBottomSheet when it
does not" is the decision somebody is actually making.

Then `make design-system-reference-update` to regenerate the `.txt`. **Never
edit that file by hand** — it is generated, and `make check` compares it byte
for byte.

### 6. Catalog story

Add a `DSComponentDemo` to the matching `lib/screens/design_system/catalog/*_stories.dart`
(action, input, navigation, overlay, surface, structure, state, foundation,
motion). It flows into `catalogComponents` automatically.

Each `DSStory` needs a `title` in the words someone would search for, and a
`note` saying when to reach for *this* configuration rather than the one above
it. Show a run of the component, not a single specimen — one row tells you
nothing about rhythm.

**Set `fullBleed: true` when the component insets its own content to the page
gutter** — every list tile, header and app bar does. Miss it and the story
frame applies the gutter on top of the component's own, the component renders
one whole gutter deeper than its neighbours, and `ui-probe`'s `gutter` rule
fails. Only `DSPage`, `DSPageSection`, `DSFormPage` and `DSGutter` apply
`pageGutter` on a page; a component applies it to inset its own content, which
is what lets a row run its divider to the edge.

**A self-insetting component asks before it insets.** Write the padding as
`(DSGutterScope.applied(context) ? 0.0 : space.pageGutter)`, not as
`space.pageGutter`. The component has to work as the direct child of a scroll
view with nothing above it, *and* inside a `DSPageSection`, a `DSFormPage` or a
settings card that has already applied the page's inset — and in the second case
the unconditional form insets twice. That is how the settings rows once drew
their icons at 40pt and their switches out to 350pt on a 390pt phone while the
section's own label sat at 20pt. `DSGutterScope` lives in `ds_scope.dart` (tier
0, so a molecule can read it without importing a template); the containers post
it with `DSGutter.markApplied`. Keep the literal `space.pageGutter` inside the
expression or the catalog's `fullBleed` tag check stops seeing it. `ui-probe`'s
`double-gutter` rule fails the build on the unconditional form.

### 7. Test and golden

`test/design_system/ds_<name>_test.dart`. `component_coverage_test.dart` fails
any file in `lib/design_system/` whose primary class is named by no test — a
deliberately weak bar, because the alternative bars are unmeasurable, and it
exists because components kept landing with a story, an export and a reference
entry while the test was left for later.

Test the behaviour, not the paint: the style chain resolves, the callback
fires, the semantics label is there, the disabled state does not respond.

Then add a group to `test/golden/design_system_golden_test.dart`, run
`make golden-update`, and **look at every PNG it writes.** A baseline recorded
without being read is a baseline that will defend a defect for the next year.

## Regenerate the catalog

```
make ds-catalog
git add tool/fixtures/ds-catalog.json
```

`ds-catalog-check` compares with `git diff --quiet`, so staging the file is
what satisfies it.

## Verify

`make check` — all twelve gates. A new component touches at least five of them
(`ds-catalog-check`, `ui-lint`, `design-system-reference`, `test`, `ui-probe`,
`golden`), so a partial run proves nothing.

If a gate goes red, use the `fix-gate` skill rather than improvising. Several
of these gates ratchet, and the improvised fix usually loosens the ratchet.
