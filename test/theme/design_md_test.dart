// DESIGN.md — generated from the spec, and the gate that keeps it true.
//
// `DESIGN.md` is the file the outside world reads: a design system in one
// markdown document, tokens in YAML frontmatter, guidance in prose, in the
// format coding agents, Figma plugins and design tools have converged on.
// Nothing in this app needed it — `ui_lint` already fails a raw hex or a bare
// `EdgeInsets` number, so an agent working *inside* the repo cannot go off
// brand and still compile. It is needed at the boundary: a tool that has never
// seen `lib/theme/spec/` has no way to learn what this app looks like.
//
// The one rule that decides whether such a file is worth having: a stale
// DESIGN.md is worse than none, because a wrong hex is followed as confidently
// as a right one. So it is not written, it is *rendered* — every value below
// comes from the same `DesignSpec` the running app is wrapped in, and this
// test fails when the checked-in document and a fresh render disagree.
//
// This is a `flutter test` rather than a `dart run tool/` script for the
// reason `palette-lint` is: the tokens are `Color`s and `TextStyle`s grown at
// construction, `PaletteSpec.fromSeeds` derives both palettes in OKLCH, and
// halo's hexes exist nowhere as literals for a parser to find. `dart:ui` does
// not exist outside the engine, so the only place the values can be *read* is
// inside a test.
//
// Three rules:
//
//   M1  The document on disk is not a fresh render of the spec — somebody
//       edited the generated file, or changed a token and did not re-render.
//   M2  A field exists on `Palette`, `SpaceSpec` or `ComponentSpec` that no
//       token in the document carries. This is the rule that survives the
//       author: a new token added to the spec next year fails the build until
//       DESIGN.md learns about it, which is the only reason a generated
//       document stays complete rather than merely fresh.
//   M3  A "don't" cites a `ui_lint` rule id that does not exist. The section
//       claims the rule is enforced; M3 is what makes the claim checkable.
//
// Run: `make design-md` verifies. `make design-md-update` rewrites.
// Two targets on purpose — a gate that rewrites the tree it is checking
// cannot fail.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

import 'token_source.dart';

/// `make design-md-update` sets this. Without it the test only compares.
const bool _write = bool.fromEnvironment('WRITE');

// ---------------------------------------------------------------------------
// Curated prose. The parser produces the values; a person writes the guidance
// — the same split `tool/design_system_reference.dart` draws with `_selection`.
// A token with no line here renders with no gloss, which reads as an omission
// and is meant to.
// ---------------------------------------------------------------------------

const _identityBlurb = <String, String>{
  'halo':
      'The shipped identity. Warm neutral background, a single primary that '
      'carries every affordance, and a brand gradient plus a five-colour '
      'chart scale that read as one family because both are grown from the '
      "same seeds: the gradient's far stop sits 28 degrees round the wheel "
      'from the primary, and the chart is five separate hues spaced evenly '
      'from there, held to a shared lightness and chroma.',
  'ledger':
      'A second identity, cooler and flatter, kept in the tree so the swap is '
      'proven rather than claimed: a golden fails when two identities render '
      'the same pixels.',
  'signal':
      'A third identity, louder and higher-contrast. Held to the same palette '
      'gates as the shipped one, so an identity cannot ship a contrast failure '
      'the primary palette would have caught.',
};

const _colorGloss = <String, String>{
  'background': 'The page behind everything.',
  'foreground': 'Primary reading colour.',
  'card': 'A card, a sheet, a row — anything raised off the background.',
  'muted': 'A recess: an input, a track, a skeleton, a pressed state.',
  'mutedForeground': 'Supporting copy, metadata, captions, hints.',
  'primary': 'The one colour that means "this does something". Also info.',
  'primaryForeground': 'Text and icons on primary and on the brand gradient.',
  'secondary': 'Primary at container weight: a selected chip, a tinted slot.',
  'secondaryForeground': 'Text and icons on secondary.',
  'border': 'A border meant to be seen; dividers use it at 55%.',
  'ring': 'The focus indicator.',
  'destructive': 'Failed, destructive or invalid.',
  'success': 'Completed, saved, on track.',
  'warning': 'Attention, not failure.',
  'overlay': 'The dim behind a modal. Carries alpha.',
  'primaryGradientFrom':
      'Brand gradient, first stop — buttons, hero, nav pill, progress.',
  'primaryGradientTo': 'Brand gradient, last stop.',
};

const _semanticGloss = <String, String>{};

/// The enforced half of the design system, and the rule id that enforces it.
///
/// Every id is checked by M3 against `tool/ui_lint.dart`. This is what
/// separates this document from an advisory one: the "don't" column is not
/// etiquette, it is a build failure with a name.
const _dontRules = <(String id, String dont, String instead)>[
  (
    'hardcoded-hex',
    'Write a `Color(0xFF…)` outside `lib/theme/`',
    'Read the role: `context.design.palette.primary`.',
  ),
  (
    'hardcoded-color',
    'Reach for a Material colour constant',
    'Every colour in this document has a role name. Use it.',
  ),
  (
    'hardcoded-radius',
    'Type a corner radius',
    '`context.shapeOf(AppShape.card)` for the border, '
        '`context.radiusOf(...)` for the number.',
  ),
  (
    'hardcoded-icon-size',
    'Size an icon by hand',
    'The `icon` component group below owns five sizes.',
  ),
  (
    'hardcoded-duration',
    'Type an animation duration',
    '`context.design.motion.fast` and its neighbours.',
  ),
  (
    'hardcoded-curve',
    'Type a curve',
    '`motion.enter`, `motion.exit`, `motion.emphasize`, `motion.standard`.',
  ),
  (
    'hardcoded-text-style',
    'Build a `TextStyle` at a call site',
    'Name a type role. There are fifteen plus `micro`.',
  ),
  (
    'physical-direction',
    'Position with `left` / `right`',
    '`start` / `end`. An inset written the physical way lands on the wrong '
        'edge in Arabic.',
  ),
  (
    'raw-button',
    'Use a Material or Cupertino button',
    'The kit owns it. `docs/references/design-system-reference-llms.txt` '
        'names the replacement for each.',
  ),
  (
    'raw-card',
    'Use `Card`',
    '`DSCard`, which reads elevation and shape from this spec.',
  ),
  (
    'raw-list-tile',
    'Use `ListTile`',
    '`DSListTile` — the row heights below are its, not Material\'s.',
  ),
  (
    'raw-dialog',
    'Call `showDialog` directly',
    '`DSDialog`. And ask first whether the answer really blocks the next step '
        '— if it does not, it is a sheet.',
  ),
  (
    'raw-bottom-sheet',
    'Call `showModalBottomSheet` directly',
    '`DSBottomSheet`, which already handles the safe area and the grabber.',
  ),
  (
    'token-namespace',
    'Invent a spacing or colour namespace',
    'There is one spec. `context.design.*` is the whole surface.',
  ),
];

/// Hex opens a YAML comment. Every scalar that can start with `#` is quoted.
String _yaml(String v) => '"$v"';

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

String renderDesignMd(DesignSpec spec, {required bool isPrimary}) {
  final b = StringBuffer();
  final light = spec.palette.light;
  final dark = spec.palette.dark;
  final lightTokens = colorTokens(light);
  final darkTokens = colorTokens(dark);
  final type = typeTokens(spec);
  final spacing = spacingTokens(spec);
  final groups = componentGroups(spec.component);
  // Relative links resolve from the file they are written in. The shipped
  // identity sits at the repository root and reaches docs/ downward; the
  // others live inside docs/design/ and reach their siblings upward. doc-lint
  // D7 follows every link, so a document generated with the wrong prefix is a
  // build failure — which is the right outcome, and cheap to avoid.
  final rel = isPrimary ? 'docs/' : '../';

  // ── Frontmatter ────────────────────────────────────────────────────────
  b.writeln('---');
  b.writeln('version: alpha');
  b.writeln('name: ${spec.name}');
  b.writeln(
    'description: ${_yaml(_identityBlurb[spec.name] ?? 'A design identity of this app.')}',
  );
  b.writeln('colors:');
  lightTokens.forEach((k, v) => b.writeln('  $k: ${_yaml(hex(v))}'));
  darkTokens.forEach((k, v) => b.writeln('  dark-$k: ${_yaml(hex(v))}'));
  b.writeln('typography:');
  type.forEach((role, style) {
    b.writeln('  $role:');
    b.writeln('    fontFamily: ${style.fontFamily ?? spec.type.family}');
    b.writeln('    fontSize: ${px(style.fontSize ?? spec.type.baseSize)}');
    b.writeln('    fontWeight: ${(style.fontWeight ?? FontWeight.w400).value}');
    if (style.height != null) {
      b.writeln('    lineHeight: ${fmtNum(style.height!)}');
    }
    if (style.letterSpacing != null) {
      b.writeln('    letterSpacing: ${px(style.letterSpacing!)}');
    }
  });
  b.writeln('rounded:');
  for (final shape in AppShape.values) {
    b.writeln(
      '  ${kebab(shape.name)}: '
      '${px(spec.shape.radiusOf(shape, isApple: false))}',
    );
  }
  b.writeln('spacing:');
  spacing.forEach((k, v) => b.writeln('  $k: ${px(v)}'));
  b.writeln('components:');
  groups.forEach((group, tokens) {
    b.writeln('  $group:');
    tokens.forEach((token, v) => b.writeln('    $token: ${px(v)}'));
  });
  b.writeln('---');
  b.writeln();

  // ── Overview ───────────────────────────────────────────────────────────
  b.writeln('# ${spec.name}');
  b.writeln();
  b.writeln('## Overview');
  b.writeln();
  b.writeln(_identityBlurb[spec.name] ?? 'A design identity of this app.');
  b.writeln();
  if (isPrimary) {
    b.writeln(
      'This is the identity the app ships. `AppTheme.spec` names it, and the '
      'line that decides the entire look is the one that wraps the app in a '
      '`DesignSpec`:',
    );
  } else {
    b.writeln(
      'This identity is not the one the app ships — `DESIGN.md` at the '
      'repository root is. It is kept because a design system that has only '
      'ever rendered one look has not been shown to be swappable:',
    );
  }
  b.writeln();
  b.writeln('```dart');
  b.writeln('Design(');
  b.writeln('  spec: DesignSpec.${spec.name}(),');
  b.writeln('  child: child,');
  b.writeln(')');
  b.writeln('```');
  b.writeln();
  b.writeln(
    '**This file is generated.** Every value above and below is read out of '
    '`lib/theme/spec/` by `test/theme/design_md_test.dart`. Editing it by '
    'hand fails `make design-md`; changing a token and forgetting to '
    're-render fails the same way. Change the spec, then run '
    '`make design-md-update`.',
  );
  b.writeln();
  b.writeln('Two conventions this file adds to the format:');
  b.writeln();
  b.writeln(
    '- **`dark-` prefixed colour tokens.** The frontmatter carries one flat '
    'colour map and this app has two palettes, so every light role appears '
    'again with a `dark-` prefix. A consumer that only wants one palette can '
    'ignore the prefixed half.',
  );
  b.writeln(
    '- **A `## Motion` section.** Duration, curve and spring are real tokens '
    'here and the eight canonical sections have nowhere to put them.',
  );
  b.writeln();

  // ── Colors ─────────────────────────────────────────────────────────────
  b.writeln('## Colors');
  b.writeln();
  b.writeln(
    'Roles, not hues. Nothing in `lib/` names a colour; it names the job the '
    'colour does, which is why the whole app changes identity on one line.',
  );
  b.writeln();
  b.writeln(
    'Both palettes are grown in OKLCH from seeds rather than typed, so the '
    'steps stay in relation to each other. Contrast is gated, not trusted: '
    '`make palette-lint` (K1..K11) fails the build on a pair that misses its '
    'WCAG floor, in either brightness.',
  );
  b.writeln();
  b.writeln('| Role | Light | Dark | What it is for |');
  b.writeln('| --- | --- | --- | --- |');
  for (final key in lightTokens.keys) {
    final gloss = _glossFor(key);
    b.writeln(
      '| `$key` | `${hex(lightTokens[key]!)}` | '
      '`${hex(darkTokens[key]!)}` | $gloss |',
    );
  }
  b.writeln();
  b.writeln(
    'Fifteen roles cover every surface in the app; the brand moment — '
    'buttons, the hero card, the selected nav pill, a progress fill — is '
    '`primaryGradient`, and data visualisation draws from the five-colour '
    '`chart` scale, nowhere else.',
  );
  b.writeln();

  // ── Typography ─────────────────────────────────────────────────────────
  b.writeln('## Typography');
  b.writeln();
  b.writeln(
    '`${spec.type.family}` for text, `${spec.type.displayFamily}` for display '
    'and headline, falling back to ${spec.type.fallback.join(', ')}.',
  );
  b.writeln();
  b.writeln(
    'Sizes are not typed. They are powers of ${fmtNum(spec.type.ratio)} around '
    'two anchors — ${fmtNum(spec.type.baseSize)}px for running text, labels and '
    'controls, ${fmtNum(spec.type.displayBase)}px for display and headline. Two '
    'anchors because "make the text smaller" means one thing for a dense list '
    'and the opposite for the one title on the page. Moving an anchor '
    're-proportions its half of the scale and leaves every relationship inside '
    'it where it was.',
  );
  b.writeln();
  b.writeln('| Role | Size | Weight | Line height | Tracking |');
  b.writeln('| --- | --- | --- | --- | --- |');
  type.forEach((role, style) {
    final height = style.height == null ? '—' : fmtNum(style.height!);
    final tracking = style.letterSpacing == null
        ? '—'
        : px(style.letterSpacing!);
    b.writeln(
      '| `$role` | ${px(style.fontSize ?? spec.type.baseSize)} | '
      '${(style.fontWeight ?? FontWeight.w400).value} | $height | $tracking |',
    );
  });
  b.writeln();
  b.writeln(
    'Every weight above ships in the bundled face. A `TextStyle` that asks for '
    'a weight the font does not have is not an error — the engine substitutes '
    'a neighbour, and which neighbour is a property of the font matcher rather '
    'than a decision anybody made. `test/theme/type_manifest_test.dart` reads '
    'the manifest out of `pubspec.yaml` and fails the build on it.',
  );
  b.writeln();
  b.writeln(
    'Running copy grows with the reader\'s own text scale without a ceiling. '
    'Only the roles that truncate are clamped — controls at '
    '${fmtNum(spec.type.controlScaleCeiling)}x, titles at '
    '${fmtNum(spec.type.titleScaleCeiling)}x.',
  );
  b.writeln();

  // ── Layout ─────────────────────────────────────────────────────────────
  b.writeln('## Layout');
  b.writeln();
  b.writeln(
    'One grid: ${px(spec.space.unit)}, with eight steps grown off it and a '
    'density multiplier (${fmtNum(spec.space.density)}) that makes the whole '
    'layout airier or denser without a widget being edited.',
  );
  b.writeln();
  b.writeln('| Step | Value |');
  b.writeln('| --- | --- |');
  spacing.forEach((k, v) => b.writeln('| `$k` | ${px(v)} |'));
  b.writeln();
  b.writeln(
    '`page-gutter` is its own value rather than a step, because the gutter '
    'answers to the device and the steps answer to each other. It has exactly '
    'one owner — `DSPage`, `DSFormPage` and `DSGutter`. A screen that applies '
    'it itself fails `ui_lint`.',
  );
  b.writeln();
  b.writeln('The rules a phone layout is held to:');
  b.writeln();
  b.writeln(
    '- **Primary actions go bottom, full width, above the safe area** — not '
    'bottom-right, which is the desktop pattern.',
  );
  b.writeln(
    '- Titles, status and identity go top; a thumb lives at the bottom.',
  );
  b.writeln('- Destructive actions never sit adjacent to a common one.');
  b.writeln(
    '- Positions come from the reading direction (`start` / `end`), never from '
    'the screen.',
  );
  b.writeln(
    '- Every async surface renders four states — loading, empty, error, '
    'success. A missing one is a bug, not a gap.',
  );
  b.writeln();
  b.writeln(
    'The long form is [docs/UX.md](${rel}UX.md) and '
    '[docs/principles/](${rel}principles/).',
  );
  b.writeln();

  // ── Elevation & Depth ──────────────────────────────────────────────────
  b.writeln('## Elevation & Depth');
  b.writeln();
  b.writeln(
    'Five levels, and every one of them is two shadows: a contact shadow that '
    'says the surface is touching something, and an ambient shadow that says '
    'how far off the page it is. One shadow reads as a sticker.',
  );
  b.writeln();
  b.writeln('| Level | Value |');
  b.writeln('| --- | --- |');
  b.writeln('| `none` | ${fmtNum(spec.elevation.none)} |');
  b.writeln('| `low` | ${fmtNum(spec.elevation.low)} |');
  b.writeln('| `medium` | ${fmtNum(spec.elevation.medium)} |');
  b.writeln('| `high` | ${fmtNum(spec.elevation.high)} |');
  b.writeln('| `highest` | ${fmtNum(spec.elevation.highest)} |');
  b.writeln();
  b.writeln(
    'Contact: ${px(spec.elevation.contactBlur)} blur at '
    '${px(spec.elevation.contactOffset)}, alpha '
    '${fmtNum(spec.elevation.contactAlphaLight)} light / '
    '${fmtNum(spec.elevation.contactAlphaDark)} dark. Ambient: '
    '${px(spec.elevation.ambientBlur)} blur at '
    '${px(spec.elevation.ambientOffset)}, alpha '
    '${fmtNum(spec.elevation.ambientAlphaLight)} light / '
    '${fmtNum(spec.elevation.ambientAlphaDark)} dark. Dark needs roughly four '
    'times the alpha for the same read, which is why the two are separate '
    'numbers rather than one opacity.',
  );
  b.writeln();
  b.writeln(
    'Shadows are tinted, never black. Details in '
    '[docs/principles/depth-and-materials.md]'
    '(${rel}principles/depth-and-materials.md).',
  );
  b.writeln();

  // ── Motion ─────────────────────────────────────────────────────────────
  b.writeln('## Motion');
  b.writeln();
  b.writeln('| Token | Value |');
  b.writeln('| --- | --- |');
  b.writeln('| `instant` | ${spec.motion.instant.inMilliseconds}ms |');
  b.writeln('| `fast` | ${spec.motion.fast.inMilliseconds}ms |');
  b.writeln('| `normal` | ${spec.motion.normal.inMilliseconds}ms |');
  b.writeln('| `slow` | ${spec.motion.slow.inMilliseconds}ms |');
  b.writeln('| `press` | ${spec.motion.press.inMilliseconds}ms |');
  b.writeln(
    '| `press-release` | ${spec.motion.pressRelease.inMilliseconds}ms |',
  );
  b.writeln('| `route-enter` | ${spec.motion.routeEnter.inMilliseconds}ms |');
  b.writeln('| `route-exit` | ${spec.motion.routeExit.inMilliseconds}ms |');
  b.writeln('| `shimmer` | ${spec.motion.shimmer.inMilliseconds}ms |');
  b.writeln('| `reveal-step` | ${spec.motion.revealStep.inMilliseconds}ms |');
  b.writeln('| `speed` | ${fmtNum(spec.motion.speed)}x |');
  b.writeln('| `springiness` | ${fmtNum(spec.motion.springiness)} |');
  b.writeln();
  b.writeln(
    'Four curves — `enter`, `exit`, `emphasize`, `standard` — and three '
    'springs: `snappy`, `gentle`, `bouncy`. A spring is used where a gesture '
    'hands off to an animation and the user should not feel the seam; a curve '
    'is used everywhere else.',
  );
  b.writeln();
  b.writeln(
    'Spend motion where it is remembered — the **peak** of the interaction and '
    'the **end** of it — and keep the rest of the screen quiet. Motion on a '
    'row that does nothing reads as lag. '
    '[docs/principles/emotional-design.md]'
    '(${rel}principles/emotional-design.md) is the owner of that reasoning; '
    '[docs/principles/motion.md](${rel}principles/motion.md) is the owner of '
    'these numbers.',
  );
  b.writeln();

  // ── Shapes ─────────────────────────────────────────────────────────────
  b.writeln('## Shapes');
  b.writeln();
  b.writeln(
    'Corner style is `${spec.shape.style.name}`, scaled by '
    '${fmtNum(spec.shape.scale)}. `platform` means a superellipse on Apple and a '
    'circular arc on Android — the one value that differs by device.',
  );
  b.writeln();
  b.writeln('| Role | Apple | Material |');
  b.writeln('| --- | --- | --- |');
  for (final shape in AppShape.values) {
    b.writeln(
      '| `${kebab(shape.name)}` | '
      '${px(spec.shape.radiusOf(shape, isApple: true))} | '
      '${px(spec.shape.radiusOf(shape, isApple: false))} |',
    );
  }
  b.writeln();
  b.writeln(
    'The frontmatter `rounded` map carries the Material column, because the '
    'format has one value per role. `pill` is a stadium rather than a large '
    'radius, and is never scaled — scaling it turns a capsule into an '
    'arbitrary rounded rectangle. A sheet rounds only its top: the bottom is '
    'off-screen, and rounding it leaves two notches against the device edge.',
  );
  b.writeln();

  // ── Components ─────────────────────────────────────────────────────────
  b.writeln('## Components');
  b.writeln();
  b.writeln(
    'The kit is ${groups.length} token groups of geometry, and a component '
    'library that reads them. Widgets ask for a role and never for a number.',
  );
  b.writeln();
  b.writeln('| Group | Tokens |');
  b.writeln('| --- | --- |');
  groups.forEach((group, tokens) {
    final rendered = tokens.entries
        .map((e) => '`${e.key}` ${px(e.value)}')
        .join(', ');
    b.writeln('| `$group` | $rendered |');
  });
  b.writeln();
  b.writeln(
    'The widgets themselves — what each is for, and the neighbour it is '
    'confused with — are in '
    '[docs/references/design-system-reference-llms.txt]'
    '(${rel}references/design-system-reference-llms.txt), which is generated '
    'from the kit the same way this file is generated from the spec. Read that '
    'before composing a screen; it is the file that makes the "don\'t '
    'hand-roll a control" rule below fair.',
  );
  b.writeln();

  // ── Do's and Don'ts ────────────────────────────────────────────────────
  b.writeln("## Do's and Don'ts");
  b.writeln();
  b.writeln(
    'Most design-system documents are advisory. This half is not: every rule '
    'below is a build failure with a name, and `dart run tool/ui_lint.dart` is '
    'what fails. The rule id is the one it prints.',
  );
  b.writeln();
  b.writeln('| Rule | Don\'t | Do |');
  b.writeln('| --- | --- | --- |');
  for (final (id, dont, instead) in _dontRules) {
    b.writeln('| `$id` | $dont | $instead |');
  }
  b.writeln();
  b.writeln(
    'A genuine exception is waived inline with '
    '`// ui-lint: allow <rule-id> — <reason>`, which is a line somebody has to '
    'write and a reviewer can find. Silence is not an exception.',
  );
  b.writeln();
  b.writeln(
    'Three more that no linter can catch, and that are the difference between '
    'a screen that passes and a screen that is good:',
  );
  b.writeln();
  b.writeln(
    '- **Do not widen a token to make one screen work.** A token change is '
    'every screen\'s change.',
  );
  b.writeln(
    '- **Do design the passive states.** An empty state gets guidance, a '
    'reason and one action — not a grey sentence.',
  );
  b.writeln(
    '- **Do not spread polish evenly.** Pick the peak and the end. Everything '
    'else stays quiet.',
  );
  return b.toString();
}

String _glossFor(String key) {
  final camel = key.replaceAllMapped(
    RegExp(r'-([a-z])'),
    (m) => m[1]!.toUpperCase(),
  );
  final direct = _colorGloss[camel];
  if (direct != null) return direct;
  for (final entry in _semanticGloss.entries) {
    if (key == entry.key) return entry.value;
    if (key.startsWith('${entry.key}-')) {
      final part = key.substring(entry.key.length + 1);
      return '${entry.value} (${part.replaceAll('-', ' ')})';
    }
  }
  final chart = RegExp(r'^chart-(\d+)$').firstMatch(key);
  if (chart != null) return 'Chart series ${chart.group(1)} — data only.';
  return '';
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

/// The shipped identity is the root file, because the root file is the one
/// every tool looks for. The others sit under `docs/design/`, named.
String pathFor(DesignSpec spec) => spec.name == AppTheme.spec.name
    ? 'DESIGN.md'
    : 'docs/design/${spec.name}.md';

void main() {
  final specs = DesignSpec.shipped;

  group('M1 — DESIGN.md is a fresh render of the spec', () {
    for (final spec in specs) {
      test(spec.name, () {
        final path = pathFor(spec);
        final rendered = renderDesignMd(
          spec,
          isPrimary: spec.name == AppTheme.spec.name,
        );
        final file = File(path);
        if (_write) {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(rendered);
          return;
        }
        expect(
          file.existsSync(),
          isTrue,
          reason: 'M1 — $path does not exist. Run `make design-md-update`.',
        );
        expect(
          file.readAsStringSync(),
          rendered,
          reason:
              'M1 — $path is not what the spec renders. Either a token moved '
              'and the document was not re-rendered, or the document was '
              'edited by hand. It is generated: change '
              'lib/theme/spec/ and run `make design-md-update`.',
        );
      });
    }
  });

  group('M2 — every spec field has a token', () {
    final emittedColors = colorTokens(specs.first.palette.light).keys.toSet();
    final emittedSpacing = spacingTokens(specs.first).keys.toSet();
    final emittedComponents = componentFields(
      specs.first.component,
    ).keys.toSet();

    test('Palette', () {
      final declared = declaredFields(
        'lib/theme/spec/palette_spec.dart',
        RegExp(r'^  final Color (\w+);'),
        fromClass: 'Palette',
        untilClass: 'PaletteSeeds',
      );
      // Anti-vacuity. Every rule in this file passes trivially if the scan
      // returns nothing — a renamed class or a reformatted declaration turns
      // M2 into a test that asserts an empty set is a subset, forever green.
      expect(
        declared.length,
        greaterThanOrEqualTo(15),
        reason:
            'M2 — the scan of Palette found ${declared.length} colour fields. '
            'The class has at least fifteen, so the scan is broken, not the '
            'class, and M2 is passing on nothing.',
      );
      for (final field in declared) {
        expect(
          emittedColors,
          contains(kebab(field)),
          reason:
              'M2 — Palette.$field carries no token in DESIGN.md. Add it to '
              'colorTokens in test/theme/design_md_test.dart, then run '
              '`make design-md-update`.',
        );
      }
    });

    test('SpaceSpec', () {
      final declared = declaredFields(
        'lib/theme/spec/space_spec.dart',
        RegExp(r'^  double get (\w+) =>'),
      );
      expect(
        declared.length,
        greaterThanOrEqualTo(9),
        reason:
            'M2 — the scan of SpaceSpec found ${declared.length} getters. '
            'It has at least nine; the scan is broken and M2 is passing on '
            'nothing.',
      );
      for (final field in declared) {
        expect(
          emittedSpacing,
          contains(kebab(field)),
          reason:
              'M2 — SpaceSpec.$field carries no token in DESIGN.md. Add it to '
              'spacingTokens, then run `make design-md-update`.',
        );
      }
    });

    test('ComponentSpec', () {
      final declared = declaredFields(
        'lib/theme/spec/component_spec.dart',
        RegExp(r'^  final double (\w+);'),
      );
      expect(
        declared.length,
        greaterThanOrEqualTo(80),
        reason:
            'M2 — the scan of ComponentSpec found ${declared.length} fields. '
            'It has at least eighty; the scan is broken and M2 is passing on '
            'nothing.',
      );
      for (final field in declared) {
        expect(
          emittedComponents,
          contains(field),
          reason:
              'M2 — ComponentSpec.$field carries no token in DESIGN.md. Add it '
              'to componentFields, then run `make design-md-update`.',
        );
      }
    });
  });

  group('M3 — every cited rule is a rule', () {
    final source = File('tool/ui_lint.dart').readAsStringSync();
    for (final (id, _, _) in _dontRules) {
      test(id, () {
        expect(
          source.contains("id: '$id'"),
          isTrue,
          reason:
              "M3 — DESIGN.md tells the reader `$id` is enforced, and "
              'tool/ui_lint.dart declares no such rule. Either the rule was '
              'renamed and the document still names the old id, or the '
              'document is promising a gate that does not exist.',
        );
      });
    }
  });
}
