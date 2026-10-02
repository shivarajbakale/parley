// UI contract lint — the enforcing half of the design system.
//
// `flutter analyze` checks that the Dart is valid. It has nothing to say about
// whether a screen went through the design system, and that is where the look
// of an app actually erodes: a hand-rolled TextFormField that skips the
// validation contract, a press animation with its own hand-typed 180ms, a
// `Colors.white` that is invisible in light mode. Every one of those passes
// analysis and ships.
//
// So the conventions are a gate:
//
//   1. **Use the component.** Screens compose `DSButton`, `DSTextField`,
//      `DSCard` — not the Material widget underneath. The DS wrapper is where
//      validation, haptics, loading states and press motion live.
//   2. **Motion is a scale, not a number.** Durations and curves come from
//      `AppMotion`. A system whose components each choose their own timing
//      does not feel like one system.
//   3. **Colour, radius, depth and type are tokens.** `ColorScheme`,
//      `AppColors`, `AppRadius`, `AppShadows`, `Theme.of(context).textTheme`.
//      A literal is tuned for one theme and wrong in the other.
//   4. **Haptics go through `AppHaptics`,** or the user's "haptic feedback"
//      setting never reaches them.
//   5. **Layers point one way.** The design system may not reach up into
//      providers or services, and a model may not import Flutter. Both are
//      AGENTS.md constraints; before this file they were prose. Referred to by
//      wording, not by number — the list gets items inserted into it.
//   6. **The kit points one way.** An import inside `lib/design_system/` may
//      reach its own tier or below, and the kit may hold no import cycle at
//      all. See the tier ladder above `_tierFindings`.
//
// Rule 1 is lifted for the bottom of the kit, not for the directory: a file
// under `lib/design_system/` declares its layer on its first line
// (`// ds-tier: 2 — molecule`), and the rules that name a component are exempt
// only up to `exemptTier`. Wrapping the raw Material widget is exactly what an
// atom is for; a molecule reaching past the atom below it for the same widget
// is making the same mistake a screen makes, and for as long as the exemption
// was a directory nothing said so. `lib/theme/` is exempt from rules 2–4: it is
// where the tokens are defined.
//
// Escape hatch: `// ui-lint: allow <rule-id> — <reason>` on the offending line
// or the line above. Real exceptions exist (a full-screen tap-to-dismiss is not
// a control); a lint with no way to say so gets switched off entirely.
//
// Run: `dart run tool/ui_lint.dart` (part of `make check`).

import 'dart:io';

import 'lint_label_budget.dart';

class Rule {
  final String id;
  final RegExp pattern;
  final String message;

  /// Path fragments whose files this rule skips.
  final List<String> exempt;

  /// When set, the rule only applies to files under one of these fragments.
  final List<String>? only;

  /// When set, a design system file whose declared `ds-tier` is at most this
  /// skips the rule.
  ///
  /// This is the exemption that used to read `exempt: _designSystem`. Wrapping
  /// the raw Material widget is what a DS component is for — but only at the
  /// bottom of the kit. A molecule that reaches past the atom below it for a
  /// `TextField` or a `CircularProgressIndicator` is making the same mistake a
  /// screen would, and the blanket exemption was the reason nothing said so:
  /// `DSMessage` drew a Material spinner on iOS for as long as this was a
  /// directory rather than a tier.
  final int? exemptTier;

  const Rule({
    required this.id,
    required this.pattern,
    required this.message,
    this.exempt = const [],
    this.only,
    this.exemptTier,
  });
}

const _designSystem = ['lib/design_system/'];

/// The one file allowed to present a surface.
///
/// Plan 17's rule, as a list: `ds_overlay.dart` owns the route, the scrim,
/// the motion and the dismissal contract, and every other surface in the kit
/// is presented *through* it. The four mechanisms this replaced were four
/// barriers, four curves and four dismissal policies — one of which was an
/// `OverlayEntry` and therefore not on the navigator stack at all, so the
/// Android back button exited the screen underneath while the menu stayed.
/// The files allowed to drive a [PageView] themselves.
///
/// `ds_tour.dart` owns the idiom, and the rest of `lib/design_system/` is
/// exempt for the same reason every other `raw-*` rule exempts it: wrapping a
/// raw widget is the kit's job.
///
/// The two screens are named rather than covered by a blanket, because each is
/// a decision. `home_screen.dart` swipes between top-level destinations, which
/// is navigation — its position is the app's state, not a sequence with an
/// end. `form_page.dart` is a stepped form, and `DSTour` has no back control
/// and no validation between pages, so pointing it there would trade a lint
/// pass for a worse screen.
///
/// The catalog is exempt too. A story is a specimen, not a screen: `DSTabBar`'s
/// uncontrolled story drives a `PageView` so the reader can see the indicator
/// follow the finger, which is the behaviour the story exists to show. Pointing
/// it at `DSTour` would demonstrate the wrong component.
const _pagedSequenceOwner = [
  // The kit's own paged sequence. It was `_designSystem` — the whole
  // directory — until the tiers made it possible to say which file.
  'lib/design_system/ds_tour.dart',
  ..._stories,
  'lib/screens/home_screen.dart',
  'lib/screens/design_system/form_page.dart',
];

const _overlayOwner = [
  'lib/design_system/ds_overlay.dart',
  // The one deliberate exception, and the reason it is a line here rather
  // than a judgement made again at each call site: a snack bar must not take
  // focus, must not answer the back button and must not block what is under
  // it, and a route does all three (plan 30 §7).
  'lib/design_system/ds_snack_bar.dart',
];

/// The surfaces that float above content, and therefore the only files
/// allowed to reach for the glass material.
///
/// This list *is* the rule in `docs/principles/depth-and-materials.md` —
/// "may be glass: bottom nav bar, tab bar, large app bar, bottom sheets,
/// dialogs, menus, the FAB, a pinned action bar" — written where it can fail
/// a build. Adding a line here is a design decision, which is the point of
/// making it a line rather than a judgement call at the call site.
const _chromeLayer = [
  'lib/design_system/ds_bottom_nav_bar.dart',
  'lib/design_system/ds_bottom_sheet.dart',
  'lib/design_system/ds_compact_app_bar.dart',
  'lib/design_system/ds_dialog.dart',
  'lib/design_system/ds_fab.dart',
  'lib/design_system/ds_large_app_bar.dart',
  // The one surface behind all five presentations. It reads the sheet
  // material for a sheet and nothing for a dialog, which is the whole
  // distinction this list exists to keep — four files used to be on it for
  // the same idiom.
  'lib/design_system/ds_overlay.dart',
  'lib/design_system/ds_pinned_action_bar.dart',
  'lib/design_system/ds_sidebar.dart',
  'lib/design_system/ds_tab_bar.dart',
];
const _tokens = ['lib/theme/'];

/// The component gallery's own preview frames.
///
/// A story sizes a fake viewport so a sheet or a nav bar has something to sit
/// in — 360x640 is a phone, not a design decision the kit ships. Exempting it
/// is not debt: there is no token for "as tall as a demo needs to be".
const _stories = ['lib/screens/design_system/catalog/'];

/// Files that predate the component contract, per rule.
///
/// The contract rules below are written for the kit as it will be after plans
/// 01..32 land, and forty-five widgets do not move in one commit. A rule that
/// only switches on at the end of that is a rule that does nothing while the
/// work most likely to violate it is being written — so each rule is live now
/// and carries an explicit list of the files that do not yet satisfy it.
///
/// The list can only shrink. A file named here that no longer violates its
/// rule is reported as `contract-debt-stale`, which is what stops the waiver
/// outliving the defect; there is no mechanism for adding a file except
/// editing this map, and doing that in a review is a decision rather than an
/// accident.
const _contractDebt = <String, List<String>>{
  // Paid off by plans 22–31: every file this rule carried has been rewritten
  // against the contract. An empty list is the state the mechanism exists to
  // reach, not a switched-off rule — the rule below is live for every file.
  'ds-reads-scheme': <String>[],
  'bool-is-prefix': [],
  'pressable-floor': [],
  'slot-region-name': <String>[],
  // The type layer, mid-migration. `ds_text.dart` holds 21 roles — each a
  // named combination of step, weight, colour, tracking, line limit and scale
  // ceiling — and these files still read `Theme.of(context).textTheme` and
  // re-decide the rest by hand. Twenty-one call sites have moved already and
  // not one golden changed, which is the argument: the roles were describing
  // what these components were building anyway.
  //
  // What is left is not mechanical. Three kinds:
  //
  //   * a size ramp — `DSButtonSize.sm/md/lg` picking a step per size — which
  //     is the component's own scale rather than a role, and stays;
  //   * a combination no role has yet, and the count is the argument for
  //     adding one: `bodyMedium` + `textSecondary` appears five times and
  //     `labelSmall` with no colour six;
  //   * a divergence that is the defect — a hand-typed `letterSpacing: 0.4`
  //     where every other tracked line reads the token, a `textTertiary`
  //     where every sibling uses `textSecondary`.
  //
  // Each needs a decision, so each is a change a golden should be read for.
  // The list may only shrink; `ui_lint_test.dart` holds that.
  'raw-text-style': [
    'design_system/ds_avatar.dart',
    'design_system/ds_badge.dart',
    'design_system/ds_bottom_nav_bar.dart',
    'design_system/ds_button.dart',
    'design_system/ds_card.dart',
    'design_system/ds_chart.dart',
    'design_system/ds_chat_bubble.dart',
    'design_system/ds_chip.dart',
    'design_system/ds_date_strip.dart',
    'design_system/ds_dialog.dart',
    'design_system/ds_dismissible_tile.dart',
    'design_system/ds_hero.dart',
    'design_system/ds_icon_button.dart',
    'design_system/ds_list_tile.dart',
    'design_system/ds_media.dart',
    'design_system/ds_media_hero.dart',
    'design_system/ds_media_row.dart',
    'design_system/ds_media_tile.dart',
    'design_system/ds_menu.dart',
    'design_system/ds_message.dart',
    'design_system/ds_metric_bar.dart',
    'design_system/ds_overlay.dart',
    'design_system/ds_page_header_style.dart',
    'design_system/ds_progress_ring.dart',
    'design_system/ds_pull_quote.dart',
    'design_system/ds_radio.dart',
    'design_system/ds_section_header.dart',
    'design_system/ds_segmented_button.dart',
    'design_system/ds_segmented_progress.dart',
    'design_system/_ds_select_parts.dart',
    'design_system/_ds_select_style.dart',
    'design_system/ds_slider.dart',
    'design_system/ds_snack_bar.dart',
    'design_system/ds_stat_tile.dart',
    'design_system/ds_status_state.dart',
    'design_system/ds_stepper.dart',
    'design_system/ds_tab_bar.dart',
    'design_system/ds_text_field.dart',
    'design_system/ds_time_grid.dart',
    'design_system/ds_tour.dart',
  ],
};

/// What the contract still owes, for a test that asserts the list only
/// shrinks.
Map<String, List<String>> get contractDebt => _contractDebt;

/// The structural regions a bare `Widget?` parameter may name.
///
/// From 00b Section 5: a property with a common simple form and an open form
/// is two parameters, `label` and `labelSlot`. A property with no simple form
/// is one bare `Widget?`, and it names a *region* of the layout rather than an
/// override. The list is closed on purpose — a new bare hole in a component is
/// almost always a sub-component that has not been written yet.
///
/// `child` is not on the plan's list and is allowed anyway: it is Flutter's own
/// universal name for "the thing this wraps", and renaming it would make every
/// component in the kit read as unlike every widget around it.
const _slotRegions = {
  'child',
  'leading',
  'trailing',
  'header',
  'footer',
  'media',
  'image',
  'overlay',
  'background',
  'empty',
  'meta',
  'legend',
  'surface',
  'prefix',
  'suffix',
  'action',
  'helper',
  'center',
  'increment',
  'decrement',
  'loadingIndicator',
  // The regions plans 17..21 introduce. Each has a shipped occupant, which is
  // the test 00b Section 5 actually applies: `actions` takes DSDialogActions
  // or DSOverlayFooter's group, `icon` takes DSDialogIcon, `trigger` takes the
  // control a menu or a select is opened from, `noResults` takes DSEmptyState,
  // and `content` is the general body a dialog grew when `String message`
  // turned out not to cover a checkbox, a list or a field.
  'actions',
  'content',
  'icon',
  'trigger',
  'noResults',
  // The two states a remote picture has besides "arrived", as regions on
  // DSImage. Neither has a simple scalar form — a placeholder is a box and a
  // failure is a glyph, not a string — so each is one bare `Widget?` naming
  // the region it fills, and each ships with an occupant (a `DSSkeleton` at
  // the final box size, and one icon on the well).
  'placeholder',
  'failure',
  // DSHero's brand mark. It ships an occupant — the kit's glyph on an accent
  // tile — and it has no scalar form to override: a logo is a drawing, and
  // the one thing 00b Section 5 will not let a component do is bake words
  // into it. An app with real artwork fills the region and never touches the
  // plate underneath.
  'mark',
  // Plan 22's region. Its occupants are DSCheckbox, DSSwitch and DSRadio: the
  // tile places whichever control it was given at whichever edge the platform
  // puts it, which is a position in the layout rather than an override of a
  // scalar beside it.
  'control',
  // Plan 27's region: the strip pinned under a page title and above the
  // content — a tab bar, a search bar, a segmented control. It is the slot the
  // TabBarView case actually needed, and the reason a second header component
  // was forked in the first place.
  'below',
  // Plan 26's two regions on the search bar. `scopes` takes the chip row that
  // narrows the query — a slot on the bar rather than a widget the caller
  // places underneath, because the two otherwise drift apart — and
  // `suggestions` takes the rows the popover shows.
  'scopes',
  'suggestions',
  // Plan 28's region on the avatar: the last step of the fallback chain, for
  // a caller whose "no image, no initials" case is a logo rather than a
  // person glyph.
  'fallback',
  // Plan 29's two regions on a status state: the quieter second action
  // ("Learn more") beside the primary one, and the collapsed technical
  // disclosure under it. Their occupants ship — DSStatusAction and
  // DSErrorDetails.
  'secondary',
  'details',
  // DSPage's region for the button that floats over the content rather than
  // sitting in the layout. Its occupant is DSFab. There is no scalar form to
  // override — a floating button is an icon, a label and a callback, which is
  // a component and not a string — and the name is the region rather than
  // Material's `floatingActionButton` because the page places one thing there
  // and does not care that Material calls it that.
  'floatingAction',
};

/// Motion, colour and shape rules apply to what is drawn, not to what is
/// computed — a mock service sleeping for 400ms is latency, not an animation.
const _uiOnly = ['lib/design_system/', 'lib/screens/', 'lib/widgets/'];

/// Where a literal font weight or font feature is the definition rather than a
/// copy of one.
///
/// `type_spec.dart` declares the defaults and `design_spec.dart` is where each
/// brand states its own; a token has to be written down somewhere or it is not
/// a token. `app_typography.dart` holds the one `tabular` getter. Everything
/// else in `lib/` names the token instead.
const _typeTokens = [
  'lib/theme/spec/type_spec.dart',
  'lib/theme/spec/design_spec.dart',
  'lib/theme/app_typography.dart',
];

/// The host page for the catalog.
///
/// Catalog stories live in `lib/screens/design_system/catalog/`, but the page
/// that mounts them — and is therefore responsible for putting them inside
/// the page gutter — is this one. The catalog ships its own preview frames
/// (the `_StageFrame` exempted by `_stories`), and the lint above is the
/// reason: a 360x640 stage is a phone, not a design decision.
const _catalogHost = ['lib/screens/design_system/component_page.dart'];

final _rules = <Rule>[
  // ── 1. Use the component ────────────────────────────────────────────────
  // ── 0. Copy is what it says it is ───────────────────────────────────────
  Rule(
    id: 'markdown-in-copy',
    // Comments are blanked before the rules run, so a backtick left in a code
    // line is a backtick inside a string, and a string is what a `Text` paints.
    pattern: RegExp('`'),
    // Screens only. A backtick in `lib/design_system/` is in an assertion
    // message or a deprecation notice — developer-facing strings that are
    // never painted — and the eight of those in the kit are all correct.
    // Screens are where the strings are the words on the glass.
    only: ['lib/screens/'],
    message:
        'a backtick in on-screen copy — `Text` is not a markdown renderer, so '
        'this ships as a backtick on the screen. A demo blog quote read '
        '"A token called `brand-blue-500` is…" with the ticks drawn as '
        'accents on the letters beside them. Name the identifier in plain '
        'words, or spell the emphasis with a text style',
  ),
  Rule(
    id: 'raw-text-field',
    pattern: RegExp(r'(?<![\w.])Text(?:Form)?Field\s*\('),
    exemptTier: 1,
    message:
        'raw TextField/TextFormField — use DSTextField; it carries the '
        'validation contract (one error source, live re-check, autofill hints, '
        'a working submit action)',
  ),
  Rule(
    id: 'raw-button',
    pattern: RegExp(
      r'(?<![\w.])(?:ElevatedButton|FilledButton|OutlinedButton|TextButton)\s*[.(]',
    ),
    exemptTier: 1,
    message:
        'raw Material button — use DSButton; it carries the press dip, '
        'the haptic and the loading state',
  ),
  Rule(
    id: 'raw-network-image',
    pattern: RegExp(r'(?<![\w.])(?:Image\.network\s*\(|NetworkImage\s*\()'),
    exempt: ['lib/design_system/ds_image.dart'],
    only: _uiOnly,
    message:
        'a raw network image — use DSImage. A fetched picture has three '
        'states and the raw widget defaults to one: the avatar shipped an '
        'errorBuilder with no placeholder, so every list it was in reflowed '
        'when the bytes landed, and the two call sites disagreed about what '
        'a failure looks like. DSImage holds the box open, shimmers, fades '
        'the first uncached frame and draws one glyph when it never arrives '
        '(DSImage.provider takes a caching provider unchanged)',
  ),
  Rule(
    id: 'raw-divider',
    pattern: RegExp(r'(?<![\w.])(?:Divider|VerticalDivider)\s*\('),
    exempt: ['lib/design_system/ds_divider.dart'],
    only: _uiOnly,
    message:
        'a raw Divider — use DSDivider. Material\'s divider has two size '
        'knobs and defaults `height` to 16, so it silently adds 16 points '
        'of space wherever it lands: all nine call sites in the kit passed '
        '`height: thickness` to undo that, and two of them read the '
        'thickness from a different token than the other seven',
  ),
  Rule(
    id: 'raw-text-style',
    pattern: RegExp(r'\btextTheme\b'),
    only: _designSystem,
    exempt: ['lib/design_system/ds_text_style.dart'],
    message:
        'a Material text step read straight from the theme — name the role '
        'the text is playing instead (DSTextRole.fieldLabel.styleOf(context), '
        'and DSText for a widget). A step is a size; a role is a size, a '
        'weight, a grey, a tracking, a line limit and a scale ceiling, and '
        'every component that reads the step re-decides the other five. That '
        'is how `labelMedium + textSecondary` came to be written out at three '
        'call sites that each already meant fieldLabel, and how a secondary '
        'line ended up textSecondary in nine places and textTertiary in two. '
        'ds_text_style.dart is the one file allowed to read the theme, '
        'because it is the file that turns a role into a step',
  ),
  Rule(
    id: 'raw-font-weight',
    pattern: RegExp(r'(?<![\w.])FontWeight\.w\d{3}\b'),
    exempt: _typeTokens,
    message:
        'a literal font weight — name the TypeSpec token instead '
        '(context.design.type.emphasisWeight, .titleWeight, .labelWeight, '
        '.bodyWeight, .displayWeight). The literals were copied from the '
        'TypeSpec defaults, so they are invisible under the brand they were '
        'written against and wrong under the other two: `signal` sets '
        'emphasisWeight to w900 and `ledger` sets titleWeight and '
        'labelWeight to w700, and a hardcoded w700 does not move with '
        'either. Twenty-one sites disagreed this way — DSBottomNavBar wrote '
        'the literal for the unselected label and the token for the '
        'selected one, two lines apart in the same style block',
  ),
  Rule(
    id: 'raw-font-feature',
    pattern: RegExp(r'(?<![\w.])FontFeature\.'),
    exempt: _typeTokens,
    message:
        'a font feature written out by hand — use the `tabular` getter on '
        'the style (`text.labelMedium?.copyWith(color: x).tabular`). Twelve '
        'call sites spelled `fontFeatures: const '
        '[FontFeature.tabularFigures()]` while ds_text.dart called the '
        'helper, which is one decision with two spellings and no single '
        'place to change it. Any other font feature is a design decision '
        'that belongs in AppTypography beside this one',
  ),
  Rule(
    id: 'physical-direction',
    // A `left:`/`right:` named argument, and the two alignments that place
    // content rather than aim a gradient. `left: 0` beside `right: 0` is
    // symmetric and flips to itself, so a zero is not a finding.
    pattern: RegExp(
      r'(?<![\w.])(?:(?:left|right)\s*:(?!\s*0\s*[,)])'
      r'|Alignment\.center(?:Left|Right))',
    ),
    only: _uiOnly,
    message:
        'a physical direction — use the directional twin '
        '(EdgeInsetsDirectional.only(start:/end:), PositionedDirectional, '
        'BorderDirectional, AlignmentDirectional.centerStart/centerEnd). '
        'Arabic and Hebrew read right to left, and a leading inset written '
        'as `left` lands on the trailing edge there: the label indents away '
        'from the text it labels, the chevron points back the way the user '
        'came. See docs/principles/direction.md',
  ),
  Rule(
    id: 'raw-refresh-indicator',
    pattern: RegExp(r'(?<![\w.])Refresh(?:Progress)?Indicator\s*[.(]'),
    exempt: ['lib/design_system/ds_refresh.dart'],
    only: _uiOnly,
    message:
        'a raw refresh indicator — use DSRefresh. The pull is dead on a list '
        'short enough to fit unless the scrollable is forced always-'
        'scrollable, and both screens that got that right wrote the physics '
        'by hand; DSRefresh sets it through ScrollConfiguration, ticks the '
        'haptic at the moment the gesture commits, and settles the disc on a '
        'spring carrying the velocity the drag ended at. The bare '
        'RefreshProgressIndicator is the disc without any of that',
  ),
  Rule(
    id: 'raw-card',
    pattern: RegExp(r'(?<![\w.])Card\s*\('),
    exemptTier: 1,
    message:
        'raw Card — use DSCard; it is the only widget that speaks the '
        'AppShadows elevation contract',
  ),
  Rule(
    id: 'raw-list-tile',
    pattern: RegExp(r'(?<![\w.])ListTile\s*\('),
    // The one owner. It is a molecule, so the tier exemption does not reach
    // it — a rule whose owning file fails it is a rule with nowhere to live.
    exempt: ['lib/design_system/ds_list_tile.dart'],
    exemptTier: 1,
    message:
        'raw ListTile — use DSListTile; every list that hand-typed its '
        'own leading inset drifted out of alignment with the rows beside it',
  ),
  Rule(
    id: 'raw-dialog',
    pattern: RegExp(r'(?<![\w.])(?:showDialog\s*[<(]|AlertDialog\s*\()'),
    exempt: _overlayOwner,
    message:
        'raw dialog — use showDSDialog or showDSConfirm; they carry the '
        'themed surface, the platform action order and the route semantics',
  ),
  Rule(
    id: 'raw-bottom-sheet',
    pattern: RegExp(r'(?<![\w.])showModalBottomSheet\s*[<(]'),
    exempt: _overlayOwner,
    message:
        'raw showModalBottomSheet — use showDSBottomSheet; snap points are '
        'the opt-in for a sheet that has more than one useful height',
  ),
  // Plan 17's rule. A surface presented any other way is off the navigator,
  // which costs the back button, the focus trap, the barrier's localised
  // dismiss label and `Navigator.pop(result)`.
  Rule(
    id: 'raw-overlay-entry',
    pattern: RegExp(r'Overlay\s*\.\s*of\s*\([^)]*\)\s*\.\s*insert'),
    exempt: _overlayOwner,
    message:
        'Overlay.of(...).insert — a surface inserted as an OverlayEntry is '
        'not a route: the back button never sees it, focus never enters it, '
        'and it cannot pop a result. Present it with showDSOverlay',
  ),
  Rule(
    id: 'raw-popup-route',
    pattern: RegExp(r'extends\s+(?:PopupRoute|PageRouteBuilder)\b'),
    exempt: _overlayOwner,
    message:
        'a private route for one surface — DSOverlayRoute is public and '
        'subclassable, and five presentations already share it',
  ),
  Rule(
    id: 'raw-progress',
    pattern: RegExp(r'(?<![\w.])(?:Circular|Linear)ProgressIndicator\s*\('),
    exemptTier: 1,
    message:
        'raw progress indicator — use DSProgressIndicator, or DSSkeleton '
        'when something is loading into a known shape',
  ),
  Rule(
    id: 'raw-snackbar',
    pattern: RegExp(r'showSnackBar\s*\('),
    exemptTier: 1,
    message:
        'raw showSnackBar — use DSSnackBar for themed, '
        'brightness-correct variants',
  ),
  Rule(
    id: 'raw-popup-menu',
    pattern: RegExp(r'(?<![\w.])PopupMenuButton\s*[<(]'),
    exemptTier: 1,
    message:
        "Material's PopupMenuButton — use DSMenu, so a menu and a select "
        'opened from adjacent icons do not animate differently',
  ),
  Rule(
    id: 'raw-tour',
    pattern: RegExp(r'(?<![\w.])PageView\s*[.(]'),
    exempt: _pagedSequenceOwner,
    only: _uiOnly,
    message:
        'a hand-rolled paged sequence — use DSTour. The parts that make one '
        'work are not the PageView: a tint that travels with the fractional '
        'position, two planes moving at different rates, a detent tick fired '
        'at the crossing rather than after the settle, an indicator driven by '
        'the live position, and an entrance gated on `active` because a '
        'PageView builds its pages before they are looked at',
  ),
  Rule(
    id: 'raw-ink',
    pattern: RegExp(r'(?<![\w.])(?:InkWell|InkResponse|Ink)\s*\('),
    exempt: [
      // The file that owns DSInkSurface, and therefore the ink.
      'lib/design_system/ds_pressable.dart',
      // `DSPressable`'s story is about wrapping a widget the kit does *not*
      // own, and an InkWell is the clearest thing to wrap. Pointing it at
      // DSInkSurface would demonstrate the wrong component.
      ..._stories,
    ],
    only: _uiOnly,
    message:
        'a raw ink layer — use DSInkSurface. `Material(type: '
        'MaterialType.transparency)` around an `InkWell` appeared thirteen '
        'times in this kit and no two spellings agreed: four derived a radius '
        'for the ink and the same radius again for the focus ring, two of '
        'those from different tokens, and three of the thirteen set a minimum '
        'tap target while three did not. DSInkSurface takes one shape for '
        'both jobs and holds the tap floor by default',
  ),
  Rule(
    id: 'raw-tab-bar',
    pattern: RegExp(r'(?<![\w.])TabBar\s*\('),
    exemptTier: 1,
    message:
        'raw TabBar — use DSTabBar; it carries the selection haptic, the '
        'edge fade on a scrollable strip, and the press/focus states',
  ),

  // ── 2. Motion is a scale ────────────────────────────────────────────────
  Rule(
    id: 'hardcoded-duration',
    pattern: RegExp(r'Duration\s*\(\s*milliseconds:'),
    exempt: _tokens,
    only: _uiOnly,
    message: 'hand-typed duration — use an AppMotion token',
  ),
  Rule(
    id: 'hardcoded-curve',
    pattern: RegExp(r'(?<![\w.])Curves\.'),
    exempt: _tokens,
    only: _uiOnly,
    message: 'raw Curves.* — use an AppMotion curve token',
  ),

  // ── 3. Colour, radius, depth and type are tokens ────────────────────────
  Rule(
    id: 'hardcoded-color',
    pattern: RegExp(r'(?<![\w.])Colors\.(?!transparent\b)\w+'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'raw Colors.* — take the colour from ColorScheme or AppColors; a '
        'literal is tuned for one theme and wrong in the other',
  ),
  Rule(
    id: 'hardcoded-hex',
    pattern: RegExp(r'Color\s*\(\s*0x'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'hex literal — every colour in this app is defined once in '
        'lib/theme/app_colors.dart and reached through the scheme',
  ),
  Rule(
    id: 'hardcoded-radius',
    pattern: RegExp(r'BorderRadius\.circular\s*\(\s*\d'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'hand-typed corner radius — use an AppRadius token; a literal is '
        'the thing that makes two cards on one screen not match',
  ),
  Rule(
    id: 'hardcoded-shadow',
    pattern: RegExp(r'(?<![\w.])BoxShadow\s*\('),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'hand-rolled BoxShadow — take the depth from AppShadows; a '
        'literal shadow is tuned for one theme and invisible in the other',
  ),
  Rule(
    id: 'hardcoded-icon-size',
    pattern: RegExp(r'(?<![\w.])(?:size|iconSize|dimension):\s*[0-9]'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'hand-typed glyph size — take a step from the ComponentSpec ladder '
        '(iconSizeMicro/Small/Inline/iconSize/iconSizeLarge, or glyphHero '
        'above them). The kit reached 13 distinct icon sizes because this was '
        'the one dimension no rule read',
  ),
  Rule(
    id: 'hardcoded-box-size',
    pattern: RegExp(
      r'(?<![\w.])(?:width|height|minWidth|minHeight|maxWidth|maxHeight):'
      r'\s*\d+\s*[,)]',
    ),
    exempt: [..._tokens, ..._stories],
    only: _uiOnly,
    message:
        'hand-typed box dimension — name it in ComponentSpec. Three sheets '
        'drew the same grabber at two widths before this rule existed. '
        '(A fractional value is read as a line height and passes; say so with '
        'the escape hatch if it really is a box.)',
  ),
  Rule(
    id: 'token-namespace',
    pattern: RegExp(
      r'(?<![\w.])App(?:Spacing|Radius|Motion|Springs|Shadows|Shapes|Colors)'
      r'(?![\w])',
    ),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'a token namespace named directly. There is one source of truth for '
        'a number now and it is the `DesignSpec` in scope: `context.design.'
        'space`, `.motion`, `.elevation`, `context.shapeOf(role)`, '
        '`context.palette`. A `static const` cannot be swapped, themed or '
        'varied, so a namespace beside the spec is a second design the '
        'identity cannot reach',
  ),
  Rule(
    id: 'hardcoded-text-style',
    pattern: RegExp(r'TextStyle\s*\([^)]*font(?:Size|Family)\s*:\s*[\d\x27"]'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'hand-typed font size or family — take the style from '
        'Theme.of(context).textTheme and adjust it with copyWith',
  ),
  Rule(
    id: 'retired-palette-role',
    pattern: RegExp(
      r'\b(?:palette|p)\.(?:canvas|surface|well|text|textSecondary|'
      r'textTertiary|accent|onAccent|accentWell|onAccentWell|outline|'
      r'outlineSoft|inert|inverseSurface|onInverseSurface|scrim|categories|'
      r'categoryFor|info|error|surfaceHigh\w*|accentContainer|'
      r'onAccentContainer)\b',
    ),
    only: _uiOnly,
    message:
        'a palette role retired by the 15-role migration. Use background, '
        'foreground, card, muted, mutedForeground, primary, '
        'primaryForeground, secondary, secondaryForeground, border, ring, '
        'destructive, success, warning or overlay — or a derived getter '
        '(tint, borderSoft, onDestructive, primaryGradient, chart)',
  ),

  // ── 4. Haptics go through the setting ───────────────────────────────────
  Rule(
    id: 'raw-haptic',
    pattern: RegExp(r'(?<![\w.])HapticFeedback\.'),
    exempt: _tokens,
    only: _uiOnly,
    message:
        'raw HapticFeedback — use AppHaptics, or the haptics setting '
        'never reaches it',
  ),

  // ── 5. Layers point one way ─────────────────────────────────────────────
  Rule(
    id: 'ds-reaches-up',
    pattern: RegExp(
      r'''^import\s+['"]package:parley_android/(providers|services|data)/''',
    ),
    only: _designSystem,
    message:
        'the design system imported a provider, service or repository — '
        'AGENTS.md, "the design system depends on the theme and nothing above '
        'it". A widget that reaches into app state cannot be reused or '
        'previewed alone',
  ),
  Rule(
    id: 'model-imports-flutter',
    pattern: RegExp(r'''^import\s+['"]package:flutter/'''),
    only: ['lib/models/'],
    message:
        'a model imported Flutter — AGENTS.md, "models are pure Dart". '
        'A widget binding in the domain makes it untestable without one',
  ),

  // ── 6. Glass stays on the chrome layer ──────────────────────────────────
  Rule(
    id: 'glass-off-chrome',
    pattern: RegExp(r'(?<![\w.])(AppMaterials\.|AppChromeSurface\b)'),
    exempt: [..._tokens, ..._chromeLayer],
    message:
        'the glass material outside the chrome layer — '
        'docs/principles/depth-and-materials.md: glass belongs to the '
        'navigation and control layer that floats above content, and content '
        'stays opaque. It is also expensive — a BackdropFilter reads back the '
        'layer under it every frame, which is fine for one nav bar and not '
        'for fifty rows. If this file genuinely is chrome, add it to '
        '_chromeLayer',
  ),

  // ------------------------------------------------------------------ 6 ---
  // The component contract. See docs/plans/00a-component-contract.plan.md and
  // 00b-composition.plan.md; these are the half of those plans a build can
  // check. Files that predate the contract are carried in _contractDebt below
  // rather than waived one line at a time.
  Rule(
    id: 'slot-widget-type',
    pattern: RegExp(r'\bfinal\s+(?!Widget\?)[A-Za-z_][\w<>,?\s]*\s+\w+Slot\b'),
    only: _designSystem,
    message:
        'a parameter whose name ends in `Slot` must be `Widget?` — the '
        'suffix means "this replaces the scalar beside it with anything the '
        'caller likes", and a narrowly typed slot is the one shape that '
        'cannot do that (00b Section 5). If the type is right and the name is '
        'wrong, drop the suffix',
  ),
  Rule(
    id: 'bool-is-prefix',
    pattern: RegExp(r'\bfinal\s+bool\??\s+is[A-Z]'),
    only: _designSystem,
    message:
        'an `is`-prefixed boolean parameter — Flutter names these '
        '`enabled`, `selected` and `dense`, and a kit that writes `isLoading` '
        'beside `enabled` in the same constructor has taught the caller two '
        'conventions (00b Section 6). Drop the prefix',
  ),
  Rule(
    id: 'current-flex-floor',
    pattern: RegExp(r'currentFlex:\s*(?:0(?:\.\d+)?|1(?:\.0+)?)\s*[,)]'),
    only: _uiOnly,
    message:
        'DSSegmentedProgress.currentFlex set to 1 or less. The current '
        'step is marked by width as well as tone, and the width is the '
        'redundant channel WCAG 1.4.1 asks for — tuning it to nothing '
        'leaves colour as the only signal (plan 04 Section 3)',
  ),
  Rule(
    id: 'ds-reads-scheme',
    pattern: RegExp(r'\bTheme\.of\([^)]*\)\.colorScheme|\bcolorScheme\.'),
    // Was `only: _designSystem`, and the screens were the larger half of the
    // problem: 51 reads across 15 files, against nine in the kit. A rule that
    // holds the components to the palette and lets the screens read past it
    // protects the wrong side — the components were never where the drift
    // was going to show.
    only: [..._designSystem, 'lib/screens/'],
    message:
        'reading `colorScheme` directly — that bypasses every layer of the '
        'resolution chain, so nothing here can be restyled by an identity, a '
        'theme extension, a scope or a `style:` argument (00a Section 3). '
        '`ColorScheme` is built *from* `PaletteSpec` by `toColorScheme`, so '
        'every member has an exact palette equivalent and the swap moves no '
        'pixel — but the two do not mean the same thing: Material `surface` '
        'is `palette.background`, the page, and `palette.card` is Material '
        '`surfaceContainerLow`, a card. Read `context.palette`, and in the '
        'kit put the defaults in the style object`s resolve',
  ),
];

/// Doc comments are where these rules get explained; a comment naming
/// `Colors.white` must not trip the rule that forbids it.
/// Comments are where these rules get explained; a comment naming
/// `Colors.white` must not trip the rule that forbids it.
///
/// Blanked line by line rather than stripped from the whole source: collapsing
/// a block comment shifts every line number after it, and a violation reported
/// at the wrong line is a violation nobody finds.
List<String> _codeLines(String source) {
  final out = <String>[];
  var inBlock = false;
  for (final line in source.split('\n')) {
    if (inBlock) {
      final close = line.indexOf('*/');
      if (close == -1) {
        out.add('');
        continue;
      }
      inBlock = false;
      out.add(_stripLine(line.substring(close + 2)));
      continue;
    }
    final open = line.indexOf('/*');
    if (open != -1 && !line.substring(0, open).contains('//')) {
      final close = line.indexOf('*/', open + 2);
      if (close == -1) {
        inBlock = true;
        out.add(_stripLine(line.substring(0, open)));
        continue;
      }
      out.add(_stripLine(line.substring(0, open) + line.substring(close + 2)));
      continue;
    }
    out.add(_stripLine(line));
  }
  return out;
}

/// Drops a trailing `//` comment, but only when the `//` is not inside a
/// string literal — a URL in a Dart string is not a comment.
String _stripLine(String line) {
  var quote = '';
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote.isNotEmpty) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = '';
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      continue;
    }
    if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

/// Every widget file in `lib/design_system/` must be reachable through the
/// barrel, or a caller has to know the file name to find it — which is how a
/// component gets hand-rolled a second time.
///
/// Files whose name begins with `_` are private to the design system by
/// convention (see DECISIONS.md, 2026-05-16) and are deliberately not exported.
List<String> _barrelGaps() {
  final dir = Directory('lib/design_system');
  if (!dir.existsSync()) return const [];
  final barrel = File('lib/design_system/design_system.dart');
  if (!barrel.existsSync()) {
    return [
      'lib/design_system/design_system.dart is missing — there is no barrel',
    ];
  }
  final exported = RegExp(
    r"""export\s+['"]([^'"]+)['"]""",
  ).allMatches(barrel.readAsStringSync()).map((m) => m.group(1)!).toSet();

  final gaps = <String>[];
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.dart')) continue;
    if (name == 'design_system.dart') continue;
    if (name.startsWith('_')) continue;
    if (!exported.contains(name)) {
      gaps.add('lib/design_system/$name is not exported by design_system.dart');
    }
  }
  gaps.sort();
  return gaps;
}

/// A component that insets its own content to the page gutter must be shown
/// in a catalog lane that does not inset it again.
///
/// The two facts live in two files and neither can see the other, which is
/// how they drifted: `DSListTile` applies `space.pageGutter` so its divider
/// and press highlight can run to the edge while its content sits in the
/// gutter, and the catalog story frame applied the gutter a second time — so
/// every row on every list page rendered one whole gutter deeper than the
/// note above it. `test/probe/debt.dart` carried it as a stage artifact and
/// charged two probe failures to the components rather than to the frame.
///
/// The rule runs both ways. A demo whose component owns the gutter must be
/// tagged, and a demo that does not own one must not be — an untagged owner
/// renders a gutter deep, and a tagged non-owner renders flush to the screen
/// edge, which is the same defect mirrored. The second half is not
/// hypothetical: `DSBottomSheet` was tagged in a tree whose sheet has no
/// gutter of its own, and every button on its catalog page moved to x=0.
///
/// [_fullBleedByComposition] is the way out for the genuine exception — a
/// wrapper with no gutter of its own whose stories are built from rows that
/// have one. It is a list rather than a free pass so that each entry is a
/// claim someone made on purpose.
const _fullBleedByComposition = {
  // A dismissible wraps a row and adds no padding of its own; the row inside
  // it is the thing that owns the gutter.
  'DSDismissibleTile',
  // A sheet's own body padding is zero — its header and its rows own the
  // gutter. Drawn inside the catalog's frame it measured 280 points where a
  // sheet on a screen measures the full 320, and `ui-probe`'s `width-band`
  // rule reads exactly that: one idiom measured two ways is not one idiom.
  'DSBottomSheet',
};

/// The source with its comments blanked out, for a rule that searches for a
/// token by name.
///
/// Line comments and block comments both go; string literals are left alone,
/// which is safe here because no rule in this file looks for a token inside
/// one. Newlines are preserved so a caller's line numbers still line up.
String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// Classes that apply the gutter inside a surface the catalog frame never
/// insets, so the full-bleed pairing does not apply to them.
///
/// `DSSelect` is the case: the gutter is on the option rows of its overlay,
/// which is a route of its own, while the thing the catalog draws is the
/// trigger field — an ordinary form control that must stay inside the story
/// gutter like every other field beside it. Tagging it `fullBleed: true`
/// would push that field to the screen edge to satisfy rows the story never
/// shows.
const _gutterInsideOverlay = {'DSSelect'};

List<String> _catalogFullBleedGaps() {
  final ds = Directory('lib/design_system');
  final catalog = Directory('lib/screens/design_system/catalog');
  if (!ds.existsSync() || !catalog.existsSync()) return const [];

  // Which class owns the page gutter, by the file that declares it.
  //
  // A mention of the token is the test, rather than a pattern for the
  // `EdgeInsets` around it. `pageGutter` *is* the horizontal page inset —
  // there is no vertical use of it in the kit — and matching on the shape of
  // its use missed `DSCompactAppBar`, which reaches it through a `titleStart`
  // variable and an `EdgeInsetsDirectional.only(start:)` two statements
  // later. A rule that has to re-derive dataflow to spell a token is a rule
  // that will keep missing spellings.
  //
  // Comments are stripped before the search. A file that *explains* why it
  // does not use the token — "`lg` and `pageGutter` are both 16 here" — was
  // being read as a file that applies it, which failed `DSSelect` for a
  // sentence rather than for a layout.
  final horizontalGutter = RegExp(r'pageGutter\b');
  final declares = RegExp(r'^class\s+(DS\w+)', multiLine: true);

  final owning = <String>{};
  for (final f in ds.listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final source = f.readAsStringSync();
    if (!horizontalGutter.hasMatch(_withoutComments(source))) continue;
    for (final m in declares.allMatches(source)) {
      final name = m.group(1)!;
      if (_gutterInsideOverlay.contains(name)) continue;
      owning.add(name);
      // A style class carries the gutter for the component it resolves for,
      // and the two need not share a file: `DSPageHeaderStyle` moved into a
      // file of its own to break an import cycle and took the token with it,
      // which read here as a header that had stopped owning its gutter.
      if (name.endsWith('Style')) {
        final owner = name.substring(0, name.length - 'Style'.length);
        if (!_gutterInsideOverlay.contains(owner)) owning.add(owner);
      }
    }
  }

  // A component that resolves *another* component's style reaches the token
  // through it. `DSFormPage` resolves `DSPageStyle` on purpose — so the kit
  // has one gutter and not two, and `DSGutter.of(context)` answers for the
  // form as well as for the page — and a rule that only reads a file for the
  // token's spelling sees a page that has stopped owning its reading edge.
  //
  // To a fixpoint, because the chain can be longer than one link: a style
  // that resolves a style that carries the token still carries it.
  final resolvesStyle = RegExp(r'\b(DS\w+Style)\.resolve\s*\(');
  final files = ds
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  for (var pass = 0; pass < files.length; pass++) {
    var grew = false;
    for (final f in files) {
      final source = f.readAsStringSync();
      final reaches = resolvesStyle
          .allMatches(_withoutComments(source))
          .any((m) => owning.contains(m.group(1)!));
      if (!reaches) continue;
      for (final m in declares.allMatches(source)) {
        final name = m.group(1)!;
        if (_gutterInsideOverlay.contains(name)) continue;
        if (owning.add(name)) grew = true;
      }
    }
    if (!grew) break;
  }

  // Which demo declared which flag.
  final demo = RegExp(
    r"DSComponentDemo\(\s*\n\s*name:\s*'(DS\w+)',\s*\n(\s*fullBleed:\s*(true|false),)?",
    multiLine: true,
  );
  final gaps = <String>[];
  for (final f in catalog.listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final source = f.readAsStringSync();
    for (final m in demo.allMatches(source)) {
      final name = m.group(1)!;
      final tagged = m.group(3) == 'true';
      if (!owning.contains(name) &&
          tagged &&
          !_fullBleedByComposition.contains(name)) {
        gaps.add(
          "lib/screens/design_system/catalog/${f.uri.pathSegments.last}  "
          "$name is tagged `fullBleed: true` but does not apply "
          "space.pageGutter itself, so the catalog frame gives it no gutter "
          "and its stories render flush to the screen edge. Drop the tag, or "
          "add it to _fullBleedByComposition if its stories are built from "
          "rows that own the gutter",
        );
      }
      if (owning.contains(name) && !tagged) {
        gaps.add(
          "lib/screens/design_system/catalog/${f.uri.pathSegments.last}  "
          "$name applies space.pageGutter itself but its DSComponentDemo is "
          "not `fullBleed: true`, so the catalog frame insets it a second "
          "time and every story on its page sits one gutter deeper than its "
          "own note",
        );
      }
    }
  }
  gaps.sort();
  return gaps;
}

/// Is this line waived for this rule?
///
/// The marker may sit on the line itself or anywhere in the run of comment
/// lines directly above it — an exception worth making is an exception worth
/// explaining, and an explanation rarely fits beside the code.
bool _allowed(List<String> raw, int index, String ruleId) {
  final marker = 'ui-lint: allow $ruleId';
  if (raw[index].contains(marker)) return true;
  for (var i = index - 1; i >= 0; i--) {
    final line = raw[i].trimLeft();
    if (!line.startsWith('//')) return false;
    if (line.contains(marker)) return true;
  }
  return false;
}

/// Every tone keeps its glyph.
///
/// The icon is the SC 1.4.1 channel a message cannot lose: `showRule` may be
/// switched off and the fill is a hue, so a tone with no glyph is a message
/// whose only remaining channel is colour. `DSMessageStyle.merge` folds a
/// consumer's map key by key over this one, so the *resolved* map is total
/// exactly as long as this literal is — which is what this checks.
List<String> _messageIconsFindings(String path, List<String> lines) {
  if (!path.endsWith('ds_message.dart')) return const [];
  final start = lines.indexWhere((l) => l.contains('defaultIcons = {'));
  if (start == -1) {
    return [
      'FAIL  $path  message-icons-total — no `defaultIcons` map. Every tone '
          'needs a glyph, and the default set is where it comes from',
    ];
  }
  final end = lines.indexWhere((l) => l.trim() == '};', start);
  final body = lines.sublist(start, end == -1 ? lines.length : end).join('\n');
  final missing = _messageTones
      .where((t) => !body.contains('DSMessageTone.$t:'))
      .toList();
  if (missing.isEmpty) return const [];
  return [
    'FAIL  $path:${start + 1}  message-icons-total — `defaultIcons` has no '
        'glyph for ${missing.join(', ')}. A message shows an icon, a tone and '
        'text so that none of the three carries the meaning alone (WCAG SC '
        '1.4.1); a tone with no glyph is down to colour and text',
  ];
}

/// A toggle whose only signal is its fill.
///
/// `DSIconButton(selected: ...)` with no `selectedIcon:` leaves the fill
/// carrying the state on its own, which SC 1.4.1 forbids — and unlike a
/// checkbox there is no label beside it to read instead. Scanned across the
/// whole call, because the two arguments are rarely on the same line.
List<String> _toggleGlyphFindings(String path, List<String> lines) {
  if (!_uiOnly.any(path.contains)) return const [];
  final findings = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!RegExp(r'(?<![\w.])DSIconButton(\.\w+)?\s*\(').hasMatch(lines[i])) {
      continue;
    }
    // The call ends where its parentheses balance, so a nested widget cannot
    // end it early and a multi-line call is read whole.
    var depth = 0;
    final body = StringBuffer();
    var end = i;
    for (var j = i; j < lines.length; j++) {
      for (final rune in lines[j].runes) {
        final c = String.fromCharCode(rune);
        if (c == '(') depth++;
        if (c == ')') depth--;
      }
      body.write(lines[j]);
      end = j;
      if (depth <= 0) break;
    }
    final call = body.toString();
    if (call.contains('selected:') && !call.contains('selectedIcon:')) {
      findings.add(
        'FAIL  $path:${i + 1}  toggle-glyph — a DSIconButton with `selected:` '
        'and no `selectedIcon:`. The fill is then the only thing that '
        'says the control is on, and colour alone fails WCAG SC 1.4.1 — '
        'an icon button has no label beside it to read instead. Give the '
        'toggled state its own glyph (bookmark_border → bookmark)',
      );
    }
    i = end;
  }
  return findings;
}

/// A number typed into a metric constructor.
///
/// `EdgeInsets`, `BorderRadius` and `Duration` are where a hand-typed number
/// hides best: it looks like layout rather than like a decision, and the three
/// of them decide the app's rhythm, its corners and its pace. Every one of the
/// three has a spec — `space`, `shape`, `motion` — so a literal here is a
/// value the identity cannot move.
///
/// Scanned across the whole call rather than line by line, because
/// `dart format` puts a multi-argument `EdgeInsets` on four lines and a
/// line-based rule sees none of them.
///
/// Two things deliberately pass. **Zero** — a zero inset is the absence of
/// spacing rather than an amount of it, and `EdgeInsets.zero` is spelled with
/// a number nowhere. **An operand** — `space.lg * 2` is the scale being
/// multiplied, which is still the scale; only a number standing alone as an
/// argument is flagged.
List<String> _bareMetricFindings(
  String path,
  List<String> lines,
  List<String> raw,
) {
  if (!_uiOnly.any(path.contains)) return const [];
  final opener = RegExp(
    r'(?<![\w.])(EdgeInsets(?:Directional)?\.\w+|BorderRadius\.\w+|Duration)'
    r'\s*\(',
  );
  // A duration in minutes, hours or days is a quantity of time in the domain
  // — a date range, a trial length — and the motion scale is written in
  // milliseconds. Those units are read as data and pass; everything an
  // animation could be timed in is checked.
  final domainUnit = RegExp(r'(?:minutes|hours|days):');
  final bare = RegExp(r'[(,:]\s*(-?\d+(?:\.\d+)?)\s*[,)]');
  final findings = <String>[];

  for (var i = 0; i < lines.length; i++) {
    for (final open in opener.allMatches(lines[i])) {
      // The call ends where its parentheses balance, so a nested expression
      // cannot end it early and a formatted call is read whole.
      var depth = 0;
      final body = StringBuffer();
      var started = false;
      for (var j = i; j < lines.length; j++) {
        final text = j == i ? lines[j].substring(open.end - 1) : lines[j];
        for (final rune in text.runes) {
          final c = String.fromCharCode(rune);
          if (c == '(') {
            depth++;
            started = true;
          }
          if (c == ')') depth--;
          if (started && depth >= 0) body.write(c);
          if (started && depth <= 0) break;
        }
        if (started && depth <= 0) break;
      }
      final call = body.toString();
      if (open.group(1) == 'Duration' && domainUnit.hasMatch(call)) continue;
      if (_allowed(raw, i, 'bare-metric')) continue;
      final numbers = bare
          .allMatches(call)
          .map((m) => m.group(1)!)
          .where((n) => double.tryParse(n) != 0)
          .toList();
      if (numbers.isEmpty) continue;
      findings.add(
        'FAIL  $path:${i + 1}  bare-metric — ${open.group(1)} built from '
        '${numbers.join(", ")}. The spacing scale, the corner ladder and the '
        'timing scale are all fields of the DesignSpec in scope: '
        '`context.design.space`, `context.radiusOf(role)`, '
        '`context.design.motion`. A literal here is a decision the identity '
        'cannot move, and it is how one screen ends up on a different rhythm '
        'from the one beside it',
      );
    }
  }
  return findings;
}

/// The tone enum, spelled once. It is `DSTone` in `ds_scope.dart` and
/// `DSMessageTone` is its alias, so the lint reads the alias — which is what
/// the file it checks actually writes.
const _messageTones = ['neutral', 'info', 'success', 'warning', 'error'];

/// Every violation in one file, as `FAIL  path:line  rule — message`.
///
/// Separated from [main] so the rules can be tested against a string instead of
/// against the repository — a lint whose own behaviour is unverified is a lint
/// that quietly stops matching.
/// Is [path] carried in the migration list for [ruleId]?
bool _inDebt(String ruleId, String path) =>
    (_contractDebt[ruleId] ?? const []).any(path.endsWith);

/// The body of every class that declares itself a component style, as
/// `(className, startLine, lines)`.
///
/// Found by brace-free scanning: from the declaration to the next line that is
/// exactly `}`. That holds because every file here is `dart format`ted, and a
/// real parser for four checks would be a second analyzer to maintain.
List<(String, int, List<String>)> _styleClasses(List<String> lines) {
  final decl = RegExp(
    r'^class\s+(\w+)\s+extends\s+(?:ThemeExtension|DSComponentStyle)<',
  );
  final out = <(String, int, List<String>)>[];
  for (var i = 0; i < lines.length; i++) {
    final m = decl.firstMatch(lines[i]);
    if (m == null) continue;
    var end = i + 1;
    while (end < lines.length && lines[end] != '}') {
      end++;
    }
    out.add((m.group(1)!, i, lines.sublist(i, end)));
  }
  return out;
}

/// The four rules a style object obeys, from 00a Section 4.
///
/// Each of them is a way the merge chain fails silently rather than loudly: a
/// non-null default cannot be told from a deliberate override, a missing
/// `merge` means the layers cannot stack at all, defaults outside `resolve`
/// means two answers to one question, and a stubbed `lerp` makes one component
/// snap while the theme animation fades everything around it.
List<String> _styleClassFindings(String path, List<String> lines) {
  final findings = <String>[];
  final field = RegExp(r'^  final\s+(.+?)\s+(\w+);$');
  final lerpStub = RegExp(r'lerp\([^)]*\)\s*=>\s*this;');

  for (final (name, start, body) in _styleClasses(lines)) {
    for (var k = 0; k < body.length; k++) {
      final m = field.firstMatch(body[k]);
      if (m == null) continue;
      if (!m.group(1)!.endsWith('?')) {
        findings.add(
          'FAIL  $path:${start + k + 1}  style-field-nullable — '
          '$name.${m.group(2)} is not nullable. Null is how a style object '
          'says "not specified at this layer"; a field that always has a '
          'value cannot be overridden by the layer above it',
        );
      }
    }
    final joined = body.join('\n');
    if (!joined.contains('merge(')) {
      findings.add(
        'FAIL  $path:${start + 1}  style-merge-missing — $name has '
        'no merge, so the four layers of the chain cannot stack',
      );
    }
    if (!RegExp(r'static\s+\w+\s+resolve\(').hasMatch(joined)) {
      findings.add(
        'FAIL  $path:${start + 1}  style-resolve-missing — $name '
        'has no `static resolve`, which is the one place a component reads '
        'its spec defaults',
      );
    }
    for (var k = 0; k < body.length; k++) {
      if (lerpStub.hasMatch(body[k])) {
        findings.add(
          'FAIL  $path:${start + k + 1}  style-lerp-stub — $name '
          'returns itself from lerp, so this one component snaps while the '
          'theme animation fades everything around it',
        );
      }
    }
  }
  return findings;
}

/// A bare `Widget?` parameter names a region of the layout, and the set of
/// regions is closed (00b Section 5).
List<String> _slotRegionFindings(
  String path,
  List<String> lines, {
  required bool applyDebt,
}) {
  if (!_designSystem.any(path.contains)) return const [];
  if (applyDebt && _inDebt('slot-region-name', path)) return const [];
  final field = RegExp(r'^  final\s+Widget\?\s+(\w+);$');
  final findings = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final m = field.firstMatch(lines[i]);
    if (m == null) continue;
    final name = m.group(1)!;
    if (name.endsWith('Slot') || _slotRegions.contains(name)) continue;
    findings.add(
      'FAIL  $path:${i + 1}  slot-region-name — `$name` is a bare '
      'Widget? that is not one of the structural regions in 00b Section 5. '
      'Either it overrides a scalar, in which case it is `${name}Slot` '
      'beside the scalar, or it is a new region — and a new region is '
      'usually a sub-component that has not been written yet',
    );
  }
  return findings;
}

/// The page gutter has exactly one owner, and a screen is not it.
///
/// Three places in this repo said so before any of them shipped: `ui_probe`'s
/// `ruleGutter` doc comment, `_catalogFullBleedGaps` below, and the
/// `add-component` skill all named `DSPage`, `DSFormPage` or `DSGutter` as the
/// only widgets that may apply `space.pageGutter` — while twenty-seven screens
/// spelled it by hand seventy-three times, and the demo blog shipped with its
/// headers a gutter in and its rows flush against the edge.
///
/// `DSGutter` is now the widget, and `DSGutter.of(context)` the number for the
/// one place a widget cannot be wrapped: a scroll view's own `padding`, which
/// takes an `EdgeInsets` and not a child. Both resolve through `DSPageStyle`,
/// so a page made wider by a theme extension moves the scroller with it — a
/// screen reading `space.pageGutter` directly opts out of that silently.
///
/// Components are not in scope. A row that insets its content while its
/// divider runs to the edge is doing its job, and the tier ladder is what
/// governs the kit.
List<String> _screenGutterFindings(String path, List<String> lines) {
  if (!path.contains('lib/screens/')) return const [];
  // The catalog stages a fake viewport so a component has something to sit
  // in. A story's gutter is a picture of a page, not a page.
  if (_stories.any(path.contains)) return const [];
  final findings = <String>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains('pageGutter')) continue;
    findings.add(
      'FAIL  $path:${i + 1}  screen-gutter — a screen may not spell '
      'space.pageGutter. Wrap the content in DSGutter (or DSPageSection, '
      'which is the gutter plus the rhythm above it), or read '
      'DSGutter.of(context) where an EdgeInsets is required and there is no '
      'child to wrap',
    );
  }
  return findings;
}

/// Anything that floats at the bottom of a screen has to be under a host.
///
/// `DSBottomInsets` exists because a snack bar, a floating action button, a
/// pinned action bar and a bottom navigation bar are placed by different parts
/// of the tree and cannot see each other. The mechanism is opt-in — a screen
/// installs `DSBottomInsetsHost` above its scaffold — and ten screens shipped
/// without it: the bar could not report its height, nothing was cleared, the
/// snack bar landed on the action bar, and `DSFab.hideOnScroll` read a
/// `DSScrollRetreat` that nothing published.
///
/// `DSPage` and `DSFormPage` install the host themselves, so a page built on
/// the kit's scaffold satisfies this by construction and this rule only fires
/// on a screen that rolls its own.
const _floatingChrome = [
  'DSFab(',
  'DSFab.',
  'DSPinnedActionBar(',
  'DSBottomNavBar(',
];

/// What counts as installing the host.
///
/// Both page components carry their named constructors as well as the default.
/// The check used to read `DSPage(` alone, which is a screen on
/// `DSPage.headline`, `DSPage.surface` or `DSFormPage.hero` reported for a
/// host the component it is built on installs.
const _installsHost = [
  'DSBottomInsetsHost',
  'DSPage(',
  'DSPage.',
  'DSFormPage(',
  'DSFormPage.',
];

List<String> _floatingChromeFindings(String path, List<String> lines) {
  if (!path.contains('lib/screens/')) return const [];
  if (_stories.any(path.contains)) return const [];
  final source = lines.join('\n');
  if (_installsHost.any(source.contains)) return const [];
  for (var i = 0; i < lines.length; i++) {
    final hit = _floatingChrome.firstWhere(lines[i].contains, orElse: () => '');
    if (hit.isEmpty) continue;
    return [
      'FAIL  $path:${i + 1}  floating-chrome-host — this screen places '
          '${hit.replaceAll('(', '')} with no DSBottomInsetsHost above its '
          'scaffold, so it cannot report its height. Whatever else floats at the '
          'bottom of this screen will be drawn on top of it. Build the screen on '
          'DSPage, which installs the host, or wrap the scaffold in '
          'DSBottomInsetsHost',
    ];
  }
  return const [];
}

/// `DSPressable` is the kit's floor: target sizing, press feedback, focus,
/// haptics and disabled semantics, with no paint (00b Section 9).
///
/// The rule is not "never use InkWell" — `DSPressable` documents that it
/// observes the press without entering the gesture arena, so something
/// underneath has to own the tap. It is that a file which builds its own tap
/// handling and never reaches the floor has re-implemented the floor badly.
List<String> _pressableFloorFindings(
  String path,
  List<String> lines,
  List<String> rawLines, {
  required bool applyDebt,
}) {
  if (!_designSystem.any(path.contains)) return const [];
  if (path.endsWith('ds_pressable.dart')) return const [];
  if (applyDebt && _inDebt('pressable-floor', path)) return const [];
  if (lines.any((l) => l.contains('DSPressable'))) return const [];
  // The escape the message names, and now honours: a component that
  // deliberately does not dip — a full-bleed row detaches from its column if
  // it shrinks — says so in one line rather than importing a widget it will
  // not use.
  // [raw] rather than [lines]: the marker is a comment, and `_codeLines`
  // has already blanked every comment out.
  if (rawLines.any((l) => l.contains('ui-lint: allow pressable-floor'))) {
    return const [];
  }
  // `DSInkSurface` counts as a tap handler here. It replaced the raw
  // `InkWell`s this rule used to see, and without it named the rule would
  // have gone quiet on the three rows that had skipped `DSPressable` — which
  // is precisely the set it exists to catch.
  final raw = RegExp(r'(?<![\w.])(GestureDetector|InkWell|DSInkSurface)\s*\(');
  for (var i = 0; i < lines.length; i++) {
    if (raw.hasMatch(lines[i])) {
      return [
        'FAIL  $path:${i + 1}  pressable-floor — a tap handler in the design '
            'system that never reaches DSPressable, so this control has no '
            'press feedback, no focus ring and no haptic while every other '
            'control does. Wrap it, or say why with `ui-lint: allow '
            'pressable-floor`',
      ];
    }
  }
  return const [];
}

/// Every violation in one file, as `FAIL  path:line  rule — message`.
///
/// Separated from [main] so the rules can be tested against a string instead of
/// against the repository — a lint whose own behaviour is unverified is a lint
/// that quietly stops matching.
///
/// [applyDebt] is false when the caller is asking what a file would fail
/// *without* its migration waiver, which is how a stale waiver is found.

/// `DSSection` ships its body at `EdgeInsets.zero`, on the assumption that the
/// caller owns the gutter — the catalog page is the caller that must own it,
/// and every `DSSection(` it builds for a story body must say so.
///
/// A `DSSection(` that names `contentPadding:` and gives it `EdgeInsets.zero`
/// also fails the check: an explicit zero is a deliberate intent to ship
/// edge-to-edge, and the lint is here to make that intent visible at review.
///
/// Scanned across the whole call rather than line by line, because a
/// `contentPadding:` that is the last argument sits on its own line and a
/// line-based rule sees neither opener nor closer.
List<String> _catalogGutterFindings(String path, List<String> lines) {
  if (!_catalogHost.any(path.contains)) return const [];
  final findings = <String>[];
  final opener = RegExp(r'(?<![\w.])DSSection\s*\(');
  for (var i = 0; i < lines.length; i++) {
    final open = opener.firstMatch(lines[i]);
    if (open == null) continue;
    var depth = 0;
    final body = StringBuffer();
    var started = false;
    for (var j = i; j < lines.length; j++) {
      final text = j == i ? lines[j].substring(open.end - 1) : lines[j];
      for (final rune in text.runes) {
        final c = String.fromCharCode(rune);
        if (c == '(') {
          depth++;
          started = true;
        }
        if (c == ')') depth--;
        if (started && depth >= 0) body.write(c);
        if (started && depth <= 0) break;
      }
      if (started && depth <= 0) break;
    }
    final call = body.toString();
    final hasPadding = call.contains('contentPadding:');
    if (!hasPadding || call.contains('contentPadding: EdgeInsets.zero')) {
      findings.add(
        'FAIL  $path:${i + 1}  catalog-gutter — a DSSection built on the '
        'catalog page without a non-zero contentPadding. The gutter belongs '
        'to the page; DSSection ships its body at EdgeInsets.zero; without '
        'a contentPadding the story renders edge-to-edge. Pass '
        '`EdgeInsets.symmetric(horizontal: space.pageGutter)` (or the '
        'composed `space.pageHorizontal`); the bottom of `fromLTRB(...)` '
        'is the inter-section gap and belongs here too',
      );
    }
  }
  return findings;
}

/// A header may only be expanded if it carries something beyond the title.
///
/// The measurement that produced this rule: 162 of an 844-point screen
/// consumed before the first content pixel on a pushed route, because
/// `DSLargeAppBar` reserves a toolbar row *plus* a measured title block no
/// matter what either holds. Worse, a screen with a real headline then had to
/// render a second one below the bar — the blog list showed "Blog" and
/// "Rocketship Design Notes" stacked, and neither was clearly the page's name.
///
/// Payload is a `subtitle`, an `eyebrow`, a `below`, a `background`, or a
/// non-empty `actions`. A `leading` is not payload: a back chevron or a drawer
/// button is on almost every screen, so counting it would make the rule
/// vacuous.
///
/// Screens only. The kit's own files build both forms by definition.
List<String> _headerPayloadFindings(String path, List<String> lines) {
  if (!path.contains('lib/screens/')) return const [];
  final findings = <String>[];
  final opener = RegExp(
    r'(?<![\w.])(?:DSLargeAppBar|DSPageHeader\.sliver)\s*\(',
  );
  for (var i = 0; i < lines.length; i++) {
    final open = opener.firstMatch(lines[i]);
    if (open == null) continue;
    var depth = 0;
    final body = StringBuffer();
    var started = false;
    for (var j = i; j < lines.length; j++) {
      final text = j == i ? lines[j].substring(open.end - 1) : lines[j];
      for (final rune in text.runes) {
        final c = String.fromCharCode(rune);
        if (c == '(') {
          depth++;
          started = true;
        }
        if (c == ')') depth--;
        if (started && depth >= 0) body.write(c);
        if (started && depth <= 0) break;
      }
      if (started && depth <= 0) break;
    }
    final call = body.toString();
    final hasPayload =
        call.contains('subtitle:') ||
        call.contains('eyebrow:') ||
        call.contains('below:') ||
        call.contains('background:') ||
        (call.contains('actions:') && !call.contains('actions: []'));
    if (!hasPayload) {
      findings.add(
        'FAIL  $path:${i + 1}  header-earns-its-height — an expanded header '
        'holding nothing but its title. It costs the first screenful a '
        'toolbar row plus a measured title block for a word the bottom nav '
        'bar is already showing, and a screen with a real headline then has '
        'to render a second one below it. Use DSPageHeader.compactSliver, or '
        'give the bar payload: a subtitle, an eyebrow, a below or actions',
      );
    }
  }
  return findings;
}

/// The five layers of the kit, and the name each one answers to.
///
/// Atomic design as a checked property rather than a shared belief. Every file
/// under `lib/design_system/` declares its layer on its first line —
/// `// ds-tier: 2 — molecule` — and two things then hold:
///
///   * **An import may not reach up.** A molecule composes atoms; an atom that
///     imports a molecule has stopped being an atom, and the file that reads
///     as the small reusable piece is now the one carrying a whole region of a
///     screen behind it.
///   * **A layer is earned, not declared.** A file at tier N must construct a
///     component at tier N-1. The ceiling alone is satisfied by composing
///     nothing — reaching up to nothing is not reaching up — which is how
///     `ds_switch.dart` sat at molecule while drawing its entire surface with
///     a `CustomPainter`, and `ds_sidebar.dart` at organism while assembling
///     atoms exactly as `ds_bottom_nav_bar.dart` does one tier below it.
///   * **The rules above know where they are.** `exemptTier: 1` is the reason
///     `raw-text-field` and the seven rules beside it can be exempt for the
///     kit's own atoms without being switched off for the whole directory.
///
/// The tiers, and what earns each one:
///
///   0. **foundation** — declares no component that paints: the style chain,
///      the scopes, the press and inset plumbing.
///   1. **atom** — the smallest thing that paints. It may reach a foundation,
///      and it may reach another atom for a part it does not draw itself (a
///      skeleton for its loading bones); nothing above that. *May*, not must:
///      the floor starts at tier 2, because an atom that paints a raw Flutter
///      widget and composes nothing is doing its job.
///   2. **molecule** — atoms composed into one unit of meaning: a row, a card,
///      a bar.
///   3. **organism** — molecules composed into a region of a screen.
///   4. **template** — organisms composed into a page, owning nothing but
///      layout. Empty today; `DSPage` is the component that belongs here.
///
/// Same-tier imports pass. Two atoms are peers, and a rule that forbade it
/// would only push a shared part into a file nobody can name. What may not
/// happen is a cycle, which is the shape "same tier or lower" cannot catch on
/// its own — and the kit had two of them, `DSSkeletonList` reaching back into
/// `ds_list_tile.dart` and `DSPageHeaderStyle` reaching back into the two app
/// bars that resolve it.
const _tierNames = ['foundation', 'atom', 'molecule', 'organism', 'template'];

final _tierMarker = RegExp(r'^// ds-tier: (\d+) — (\w+)$');

/// The tier a design system file declares, or null when it declares none.
///
/// Deliberately lenient about the name beside the number: a file that says
/// `// ds-tier: 2 — molecul` still resolves as tier 2 for the rules that read
/// it, and `_tierFindings` fails the typo separately. A misspelling that
/// silently un-tiered a file would hand it every exemption back.
int? _declaredTier(String source) {
  final newline = source.indexOf('\n');
  final first = newline == -1 ? source : source.substring(0, newline);
  final match = RegExp(r'^// ds-tier: (\d+)').firstMatch(first);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

/// A class that disagrees with its file about which layer it is on.
///
/// The file's marker is the ceiling for its *imports*, which is a file-level
/// fact because Dart imports are. The layer a *component* occupies is a fact
/// about the component, and the two stopped agreeing the moment a file held
/// more than one class: `DSChevron` was a molecule for sharing a file with
/// `DSListTile`, `DSSelectSeparator` an organism for sharing one with
/// `DSSelect`, and the catalog published all 154 of them labelled by filename.
///
/// So a class may declare its own, on the line above it, with the reason:
///
///     // ds-tier: 1 — atom — A glyph that says the row leads somewhere.
///
/// It may only declare a tier *below* its file's. Above would be a class whose
/// imports are not checked against the layer it claims — the file's ceiling is
/// the only thing the import rule can see — which is the one direction that
/// would make the marker a way of escaping the ladder rather than describing
/// it.
List<String> _classTierFindings(String path, List<String> raw) {
  if (!path.contains('lib/design_system/')) return const [];
  final fileTier = _declaredTier(raw.join('\n'));
  if (fileTier == null) return const [];
  final marker = RegExp(r'^\s*// ds-tier: (\d+) — (\w+)(?: — (.+))?$');
  final findings = <String>[];
  for (var i = 1; i < raw.length; i++) {
    final m = marker.firstMatch(raw[i]);
    if (m == null) continue;
    final declared = int.parse(m.group(1)!);
    final name = m.group(2)!;
    if (declared >= _tierNames.length || _tierNames[declared] != name) {
      findings.add(
        'FAIL  $path:${i + 1}  class-tier-name — tier $declared is not '
        '"$name". The word and the number are one fact spelled twice, and a '
        'typo that un-tiered a class would hand it back every exemption',
      );
      continue;
    }
    if (declared > fileTier) {
      findings.add(
        'FAIL  $path:${i + 1}  class-tier-above-file — a class may not claim '
        'a higher layer than its file. The file is a '
        '${_tierNames[fileTier]} and its imports are checked against that, so '
        'a ${_tierNames[declared]} here is a component whose composition '
        'nothing verifies. Move it to a file at its own tier',
      );
      continue;
    }
    if (m.group(3) == null || m.group(3)!.trim().isEmpty) {
      findings.add(
        'FAIL  $path:${i + 1}  class-tier-reason — a class that disagrees '
        'with its file about its layer says why on the spot: '
        '`// ds-tier: 1 — atom — A glyph that says the row leads somewhere.` '
        'Without it the next reader has the disagreement and not the argument',
      );
    }
  }
  return findings;
}

/// The kit's layering, checked: every file declares a tier, no import reaches a
/// higher one, and no import cycle exists at all.
List<String> _tierFindings() {
  final dir = Directory('lib/design_system');
  if (!dir.existsSync()) return const [];
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return tierFindings({
    for (final f in files)
      if (f.path.endsWith('.dart'))
        f.uri.pathSegments.last: f.readAsStringSync(),
  });
}

/// The layering check itself, over a kit given as file name to source.
///
/// Split from the directory walk so the rules can be run against a kit of
/// three strings: a lint that only runs on the real tree is a lint whose own
/// behaviour nobody can state.
List<String> tierFindings(Map<String, String> sources) {
  final findings = <String>[];
  final tier = <String, int>{};
  final imports = <String, List<String>>{};

  for (final entry in sources.entries) {
    final name = entry.key;
    if (!name.endsWith('.dart')) continue;
    // The barrel is a list of exports. It sits across the tiers rather than in
    // one of them, which is the whole reason it exists.
    if (name == 'design_system.dart') continue;
    final path = 'lib/design_system/$name';
    final source = entry.value;

    final newline = source.indexOf('\n');
    final first = newline == -1 ? source : source.substring(0, newline);
    final match = _tierMarker.firstMatch(first);
    if (match == null) {
      findings.add(
        '$path:1  ds-tier-undeclared — the first line of a design system '
        'file names its layer: `// ds-tier: 2 — molecule`. Without it the '
        'file is exempt from nothing and imports it from anywhere, which is '
        'the state the whole directory used to be in. The tiers are '
        '${_tierNames.indexed.map((e) => '${e.$1} ${e.$2}').join(', ')}',
      );
      continue;
    }
    final declared = int.parse(match.group(1)!);
    if (declared >= _tierNames.length) {
      findings.add(
        '$path:1  ds-tier-unknown — tier $declared does not exist. The '
        'ladder stops at ${_tierNames.length - 1} '
        '(${_tierNames.last}); a sixth layer is a design decision, not a '
        'typo, so add it to _tierNames on purpose',
      );
      continue;
    }
    if (match.group(2) != _tierNames[declared]) {
      findings.add(
        '$path:1  ds-tier-name — tier $declared is '
        '"${_tierNames[declared]}", not "${match.group(2)}". The word is '
        'there so the line reads without the table beside it, which only '
        'works while the two agree',
      );
    }
    tier[name] = declared;
    imports[name] = RegExp(
      r"""import\s+['"]package:parley_android/design_system/([\w]+)\.dart['"]""",
    ).allMatches(source).map((m) => '${m.group(1)!}.dart').toList();
  }

  for (final name in tier.keys) {
    for (final dep in imports[name]!) {
      final depTier = tier[dep];
      if (depTier == null) continue;
      if (depTier > tier[name]!) {
        findings.add(
          'lib/design_system/$name  ds-tier-order — a '
          '${_tierNames[tier[name]!]} (tier ${tier[name]}) imports $dep, '
          'which is a ${_tierNames[depTier]} (tier $depTier). An import may '
          'reach its own tier or below and no further: either this file is '
          'not what it says it is, or the part it needs belongs lower down',
        );
      }
    }
  }

  findings.addAll(_tierCycles(tier.keys.toList(), imports));
  findings.addAll(_tierFloorFindings(tier, sources));
  findings.sort();
  return findings;
}

/// What each file is still allowed to claim without composing it.
///
/// Same contract as `_contractDebt` and the same rule: shrink only. A file
/// listed here declares a layer it has not earned, and the entry says why the
/// answer is a design decision rather than a marker to move.
const _tierFloorDebt = <String, String>{
  'ds_radio.dart':
      'DSRadioGroup composes its radios through `List<Widget> children`, so '
      'the atoms arrive from the call site and the file never names one. '
      'Slot composition is invisible to any rule that reads types — the slot '
      'is declared `Widget`, so a resolved element graph would not see it '
      'either — and narrowing the slot to `List<DSRadio>` is a decision about '
      'every slot in the kit, not a fix for this file.',
  'ds_theme_mode_picker.dart':
      'It composes DSSegmentedButton, which is its own tier. A component that '
      'configures another at the same layer is a preset, and the ladder has '
      'no name for one: calling it an organism would make a single control a '
      'region of a screen, and calling it an atom would put a molecule inside '
      'it. The missing rung is the finding.',
};

/// What the ladder's floor still owes, for a test that asserts it only shrinks.
Map<String, String> get tierFloorDebt => _tierFloorDebt;

/// The floor of the ladder: a layer has to be earned by what a file composes.
///
/// The ceiling rule — no import reaches up — is half of atomic design, and it
/// is the half that cannot be satisfied by doing nothing. A file that composes
/// nothing at all passes it, which is how `ds_switch.dart` sat at molecule
/// while drawing its whole surface with a `CustomPainter`, and how
/// `ds_sidebar.dart` sat at organism while assembling atoms exactly the way
/// `ds_bottom_nav_bar.dart` does one tier below it.
///
/// So: a file at tier N must construct at least one component at tier N-1.
/// Exactly N-1, not "anything lower" — a molecule standing on a foundation is
/// the case this exists to catch, and "lower" would pass it.
///
/// Tiers 0 and 1 have no floor, which is the ladder's own wording: an atom
/// *may* reach a foundation, where a molecule *is* atoms composed. An atom
/// that paints a raw Flutter widget and composes nothing is doing its job.
///
/// **What this cannot see.** A component that takes its children through a
/// `Widget` slot composes them at the call site, and the slot's declared type
/// is `Widget`, so neither this rule nor a resolved element graph can tell
/// what arrives in it. Those files go in `_tierFloorDebt` with that as the
/// reason rather than being quietly exempted — a blind spot nobody wrote down
/// is a rule that looks stronger than it is.
List<String> _tierFloorFindings(
  Map<String, int> fileTier,
  Map<String, String> sources,
) {
  // Every component the kit declares, at the tier it declares. A class marker
  // wins over its file's, which is what flutter-072 made possible and what
  // lets one file hold an atom and the molecule that composes it.
  final componentTier = <String, int>{};
  final componentFile = <String, String>{};
  final classDecl = RegExp(r'^(?:abstract |final |sealed |base )*class (\w+)');
  final classMarker = RegExp(r'^\s*// ds-tier: (\d+) — \w+ — ');
  for (final entry in sources.entries) {
    final name = entry.key;
    if (!fileTier.containsKey(name)) continue;
    final lines = entry.value.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final decl = classDecl.firstMatch(lines[i]);
      if (decl == null) continue;
      var tier = fileTier[name]!;
      for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
        final m = classMarker.firstMatch(lines[j]);
        if (m != null) {
          tier = int.parse(m.group(1)!);
          break;
        }
      }
      componentTier[decl.group(1)!] = tier;
      componentFile[decl.group(1)!] = name;
    }
  }

  // `DSFoo(` and `DSFoo<Bar>(`. Comments are blanked first, so a name in a
  // doc example does not satisfy the floor — the one failure mode that would
  // make this rule congratulate a file for describing composition it does not
  // do.
  final call = RegExp(r'\b(DS[A-Z]\w*)(?:<[^<>()]*>)?\s*\(');
  final findings = <String>[];
  for (final name in fileTier.keys.toList()..sort()) {
    final tier = fileTier[name]!;
    if (tier < 2) continue;
    final wanted = tier - 1;
    final body = _codeLines(sources[name]!).join('\n');
    final composed = <String>{};
    for (final m in call.allMatches(body)) {
      final used = m.group(1)!;
      final at = componentTier[used];
      if (at == null) continue;
      // A file cannot satisfy its own floor with a class of its own tier.
      if (componentFile[used] == name && at == tier) continue;
      if (at == wanted) composed.add(used);
    }
    if (composed.isNotEmpty) {
      if (_tierFloorDebt.containsKey(name)) {
        findings.add(
          'lib/design_system/$name  ds-tier-floor-stale — listed in '
          '_tierFloorDebt, and it now composes ${composed.first}, a '
          '${_tierNames[wanted]}. Delete the entry: the list is only true '
          'while it shrinks',
        );
      }
      continue;
    }
    if (_tierFloorDebt.containsKey(name)) continue;
    findings.add(
      'lib/design_system/$name  ds-tier-floor — a ${_tierNames[tier]} '
      '(tier $tier) composes no ${_tierNames[wanted]}. A layer is earned by '
      'what a file builds from, not by the marker on its first line: either '
      'this belongs at tier $wanted, or the part it should have been '
      'composing is still drawn by hand here',
    );
  }
  return findings;
}

/// Import cycles inside the kit, reported once each as the loop they form.
///
/// "Same tier or lower" tolerates a cycle between peers, and a cycle is the
/// thing that makes a tier meaningless: two files that each need the other are
/// one file wearing two names, and every tool that walks the kit — this lint
/// included — has to special-case them.
List<String> _tierCycles(List<String> names, Map<String, List<String>> edges) {
  final findings = <String>[];
  final state = <String, int>{}; // 1 = on the stack, 2 = finished
  final stack = <String>[];

  void walk(String name) {
    state[name] = 1;
    stack.add(name);
    for (final dep in edges[name] ?? const <String>[]) {
      if (!edges.containsKey(dep)) continue;
      if (state[dep] == 1) {
        final loop = stack.sublist(stack.indexOf(dep))..add(dep);
        findings.add(
          'lib/design_system/$dep  ds-tier-cycle — ${loop.join(' -> ')}. '
          'Move the shared part down into a file both can import: '
          '`DSSkeletonList` went to `ds_list_tile.dart` and '
          '`DSPageHeaderStyle` to a file of its own for exactly this',
        );
      } else if (state[dep] == null) {
        walk(dep);
      }
    }
    stack.removeLast();
    state[name] = 2;
  }

  for (final name in names) {
    if (state[name] == null) walk(name);
  }
  return findings;
}

List<String> lintSource(String path, String source, {bool applyDebt = true}) {
  final findings = <String>[];
  final raw = source.split('\n');
  final lines = _codeLines(source);
  final tier = _declaredTier(source);

  for (var i = 0; i < lines.length; i++) {
    for (final rule in _rules) {
      if (rule.exempt.any(path.contains)) continue;
      if (rule.only != null && !rule.only!.any(path.contains)) continue;
      if (rule.exemptTier != null && tier != null && tier <= rule.exemptTier!) {
        continue;
      }
      if (applyDebt && _inDebt(rule.id, path)) continue;
      if (_allowed(raw, i, rule.id)) continue;
      if (rule.pattern.hasMatch(lines[i])) {
        findings.add('FAIL  $path:${i + 1}  ${rule.id} — ${rule.message}');
      }
    }
  }

  findings.addAll(_styleClassFindings(path, lines));
  findings.addAll(_slotRegionFindings(path, lines, applyDebt: applyDebt));
  findings.addAll(
    _pressableFloorFindings(path, lines, raw, applyDebt: applyDebt),
  );
  findings.addAll(_messageIconsFindings(path, lines));
  findings.addAll(_toggleGlyphFindings(path, lines));
  findings.addAll(_bareMetricFindings(path, lines, raw));
  findings.addAll(_catalogGutterFindings(path, lines));
  findings.addAll(_screenGutterFindings(path, lines));
  findings.addAll(_floatingChromeFindings(path, lines));
  findings.addAll(_headerPayloadFindings(path, lines));
  findings.addAll(_classTierFindings(path, raw));
  findings.addAll(lintLabelBudget(path, lines));
  return findings;
}

/// The rule ids, for a test that asserts the set has not silently shrunk.
List<String> get ruleIds => _rules.map((r) => r.id).toList();

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('ui-lint: no lib/ directory — run from the project root.');
    exit(1);
  }

  var scanned = 0;
  final findings = <String>[];

  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          // Generated code is not hand-written UI and is not ours to fix.
          .where((f) => !RegExp(r'\.(g|freezed)\.dart$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // What each waived file would fail without its waiver — the input to the
  // staleness check below.
  final withoutDebt = <String, Set<String>>{};
  final debtPaths = {for (final v in _contractDebt.values) ...v};

  for (final file in files) {
    scanned++;
    final source = file.readAsStringSync();
    findings.addAll(lintSource(file.path, source));
    if (debtPaths.any(file.path.endsWith)) {
      withoutDebt[file.path] = lintSource(
        file.path,
        source,
        applyDebt: false,
      ).map((f) => f.split('  ')[2].split(' — ').first).toSet();
    }
  }

  // A waiver that outlives the defect is worse than no waiver: it reads as a
  // list of known problems while quietly permitting new ones in the same file.
  _contractDebt.forEach((ruleId, paths) {
    for (final path in paths) {
      final match = withoutDebt.keys.where((p) => p.endsWith(path)).firstOrNull;
      if (match == null) {
        findings.add(
          'FAIL  $path  contract-debt-missing — listed in '
          '_contractDebt for $ruleId, but no such file was scanned. Delete '
          'the line',
        );
        continue;
      }
      if (!withoutDebt[match]!.contains(ruleId)) {
        findings.add(
          'FAIL  $path  contract-debt-stale — listed in '
          '_contractDebt for $ruleId, and it no longer violates it. Delete '
          'the line: the list is what says how much of the contract is '
          'still owed, and it is only true if it shrinks',
        );
      }
    }
  });

  for (final gap in _catalogFullBleedGaps()) {
    findings.add('FAIL  $gap');
  }

  for (final gap in _tierFindings()) {
    findings.add('FAIL  $gap');
  }

  for (final gap in _barrelGaps()) {
    findings.add(
      'FAIL  $gap  barrel-drift — export it, or rename it to a '
      'leading underscore if it is private to the design system',
    );
  }

  findings.forEach(stdout.writeln);
  stdout.writeln(
    '\nui-lint: $scanned file(s) scanned, ${findings.length} violation(s)',
  );
  exit(findings.isEmpty ? 0 : 1);
}
