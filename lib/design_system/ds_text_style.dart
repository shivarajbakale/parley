// ds-tier: 0 — foundation

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

// The style chain, and not the widget that draws it.
//
// [DSTextRole] and [DSTextStyle] are what a *style class* needs: a component
// that stores a `TextStyle?` — because that is what a `DefaultTextStyle`, a
// `TextPainter` or a Material widget's style slot takes — fills it from a
// role rather than from a Material step it picked itself. Those callers are
// tier-0 style classes, so the chain has to be reachable from tier 0, and a
// file is the unit the tier ladder checks. It depends on nothing above
// foundation: [DSComponentStyle], [DSScope] and the spec, all tier 0.
//
// `DSText`, the widget, stays an atom in `ds_text.dart` and exports this file,
// so every existing import of it keeps working.

/// What a piece of text *is*, rather than how big it is.
///
/// `TextTheme` names fifteen sizes — `displayLarge` through `labelSmall` —
/// and a size is not a decision anybody makes. Nobody sets out to write
/// `bodySmall`; they set out to write the supporting line under a row's
/// title, and then have to remember that the supporting line is `bodySmall`
/// in the secondary grey, wrapping to two lines, and that the one in the
/// metric strip is the same size but tabular and a step lighter.
///
/// That remembering is what drifted: the kit reached 237 `Text` call sites
/// carrying 205 `copyWith`s between them, 54 `maxLines` against 33 `overflow`
/// (so twenty-one places clipped with no ellipsis decision) and three
/// `semanticsLabel`s in the whole app.
///
/// A role is that decision, made once. It carries the step, the weight, the
/// grey, the tracking, the casing, whether the digits are tabular, how many
/// lines it takes before it truncates, how far it is allowed to grow under
/// the reader's text scale, and whether a screen reader should announce it as
/// a heading. Nothing on the scale changes: the roles *name* the steps
/// [TypeSpec] already grows, so moving `ratio` still re-proportions the app.
enum DSTextRole {
  /// The one oversized number or word on a screen that has one — a splash, a
  /// finished-state figure. At most once per screen; a second one means
  /// neither is the point.
  display,

  /// The title of a route, in a large app bar. Announced as a heading.
  pageTitle(heading: true),

  /// The title of a compact bar, a dialog or a sheet. One line, always.
  screenTitle(heading: true),

  /// The label above a group of rows or cards. Announced as a heading.
  sectionTitle(heading: true),

  /// The small tracked line above a title — "FRIDAY · MAY 16", "OVERDUE".
  /// Cased by [TypeSpec.eyebrowUppercase], never by the call site.
  eyebrow(uppercases: true),

  /// The title inside a card, which is quieter than the section that holds
  /// the card.
  cardTitle,

  /// The opening paragraph of an article or an empty state — one step up from
  /// [body], and only for the first paragraph.
  bodyLead,

  /// Running copy. The only role with no line limit, because the reader came
  /// for these words.
  body,

  /// Copy at reading size that is not the point of the screen: the line under
  /// a hero or an empty state's title, a ring's caption, the value beside a
  /// settings row. The same size as [body] and a step quieter in colour —
  /// which is the axis [bodyDetail] does not offer, because it drops the size
  /// too, and five components had built this by hand.
  bodySupport,

  /// Supporting copy under running copy: a caption, a disclosure, a footnote.
  bodyDetail,

  /// A pulled quote, set at title size in the display face.
  quote,

  /// The first line of a list row. One line, truncating — the row is a
  /// pointer at the thing, not the thing.
  itemTitle,

  /// The second line of a list row.
  itemSubtitle,

  /// The facts on a row that are not its name — a date, a size, a count.
  /// Tabular, so a column of them lines up.
  itemMeta,

  /// A small quiet label that is not a row's fact: a legend beside a metric
  /// segment, the percentage under a progress ring, the line under a sidebar
  /// title, the label on a media row, and the count beside a chip, a tab or a
  /// segmented option.
  ///
  /// The same three values as [itemMeta] and a different meaning. `itemMeta`
  /// says *row*, and the kit's text is not all in rows — eleven call sites
  /// built `labelSmall` in the secondary grey by hand because the only role
  /// carrying it named a place they were not in.
  ///
  /// It is tabular, which is what makes it the right role for a count that
  /// annotates a label: [count] is for a number that is the whole shape, and
  /// the difference between the two is not the number, it is whether there is
  /// a label beside it to stay quieter than.
  caption,

  /// The smallest fact on the screen, sitting inside the thing it annotates:
  /// the time on a chat bubble, a delivery mark, the seconds under a
  /// transport control.
  ///
  /// The one role below [caption], and the only one that reads
  /// [TypeSpec.micro] instead of a [TextTheme] step — Material's roles stop
  /// at `labelSmall`, and a timestamp set at the same size as the label above
  /// it competes with the message it is dating. It truncates at one line and
  /// is tabular, because a column of times that shifts as the digits change
  /// is a column nobody reads twice.
  timestamp,

  /// The label on a control: a button, a segment, a tab, a nav destination.
  /// Takes its colour from whatever it sits on rather than the palette,
  /// because a filled button's label is `onAccent` and an outlined one's is
  /// not.
  control,

  /// The same, one step down — a control inside a dense row or a footer.
  controlSmall,

  /// The label above or beside a field.
  fieldLabel,

  /// The line under a field that says what is expected.
  fieldHelper,

  /// The line under a field that says what is wrong. Announced as a live
  /// region, so it reaches a screen reader when it appears rather than when
  /// the user next moves focus.
  fieldError(live: true),

  /// The value in a stat tile or a metric strip. Tabular and heavy.
  metric,

  /// The unit or the period beside a [metric] — "MB", "this week".
  metricUnit,

  /// A number that is the whole of the shape it sits in — the figure inside a
  /// notification dot. Tabular, emphasised, and it takes no colour of its own
  /// so that it inherits the dot's foreground and moves with the dot's tone.
  ///
  /// Not the number *beside* a label. This role's first sentence used to say
  /// "a badge, a chip or a tab", and the chip, the tab and the segmented
  /// button had all independently declined it: each drew its count in
  /// `textSecondary` at the rest weight, which is [caption], and each was
  /// right to. A count annotating a label is a second, quieter fact about
  /// that label, so it stays quieter than the label; a count that is the
  /// shape's entire content has nothing to be quieter than. The colours were
  /// measured rather than argued — `textSecondary` on the selected chip's
  /// well is 5.55:1 under `halo` and higher under `ledger` and `signal`,
  /// against a 4.5:1 floor, so the grey was never a contrast defect this role
  /// could have been called in to fix.
  count;

  // There is deliberately no `code` role. It wants a monospace face, the app
  // bundles none, and a role that names a platform family it cannot guarantee
  // renders every character as a missing-glyph box on the first device that
  // lacks it — which is what the golden sheet showed the one time this was
  // tried. Bundle a mono face in `pubspec.yaml` first, add its weights to the
  // manifest `type_manifest_test` reads, and then this role is a four-line
  // change.

  const DSTextRole({
    this.heading = false,
    this.live = false,
    this.uppercases = false,
  });

  /// Whether a screen reader should announce this text as a heading, so that
  /// heading-by-heading navigation reaches it.
  final bool heading;

  /// Whether the text is announced when it appears rather than when focus
  /// next passes over it. True for the one role that reports a problem the
  /// reader did not ask for.
  final bool live;

  /// Whether the role asks [TypeSpec.eyebrowUppercase] how it is cased.
  ///
  /// The brand answers; the role only asks. A role that does not ask is drawn
  /// with the string it was handed, whatever the spec says.
  final bool uppercases;
}

/// What one role resolves to, before the caller's own arguments are applied.
///
/// Only what the *painted style* needs. A role's accessibility semantics and
/// its casing are constant across every brand and both brightnesses, so they
/// live on the enum rather than being re-derived from the theme each build.
typedef _Recipe = ({
  TextStyle? step,
  FontWeight? weight,
  // Null means "inherit from whatever encloses this" — the case a palette
  // colour cannot express, and the reason a button's label is legible on a
  // filled ground without the button naming a colour.
  Color? color,
  double extraTracking,
  bool tabular,
  int? maxLines,
  bool clampScale,
});

/// How text looks, at every layer of the resolution chain.
@immutable
class DSTextStyle extends DSComponentStyle<DSTextStyle> {
  const DSTextStyle({
    this.textStyle,
    this.color,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.maxScale,
  });

  /// The role's step, with its weight, tracking and line height already on
  /// it. Overriding this replaces the step; to change one property, reach it
  /// through a `copyWith` on the value you pass.
  final TextStyle? textStyle;

  /// Kept apart from [textStyle] because it is the field a tone, a scope and
  /// a disabled container each want to set without disturbing the step.
  final Color? color;

  /// Null means the role wraps without limit. It is the roles that truncate
  /// that need a number, which is the opposite of how the kit used to spell
  /// it — hence the twenty-one places that clipped with no ellipsis.
  final int? maxLines;

  final TextOverflow? overflow;
  final bool? softWrap;

  /// The ceiling on the reader's text scale for this role.
  ///
  /// A paragraph has none: running copy must grow as far as the reader asks.
  /// A tab label does, because a segmented control that grows to fit its
  /// longest label at 200% has stopped being a segmented control. Five
  /// components solved this independently, one of them against a hand-typed
  /// 1.3.
  final double? maxScale;

  @override
  DSTextStyle merge(DSTextStyle? other) {
    if (other == null) return this;
    return DSTextStyle(
      textStyle: textStyle == null
          ? other.textStyle
          : textStyle!.merge(other.textStyle),
      color: other.color ?? color,
      maxLines: other.maxLines ?? maxLines,
      overflow: other.overflow ?? overflow,
      softWrap: other.softWrap ?? softWrap,
      maxScale: other.maxScale ?? maxScale,
    );
  }

  @override
  DSTextStyle copyWith({
    TextStyle? textStyle,
    Color? color,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
    double? maxScale,
  }) => DSTextStyle(
    textStyle: textStyle ?? this.textStyle,
    color: color ?? this.color,
    maxLines: maxLines ?? this.maxLines,
    overflow: overflow ?? this.overflow,
    softWrap: softWrap ?? this.softWrap,
    maxScale: maxScale ?? this.maxScale,
  );

  @override
  DSTextStyle lerp(DSTextStyle? other, double t) {
    if (other == null) return this;
    return DSTextStyle(
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      color: Color.lerp(color, other.color, t),
      // Discrete: half a line and a third of an overflow policy are not
      // values, so they cross at the midpoint rather than interpolating.
      maxLines: t < 0.5 ? maxLines : other.maxLines,
      overflow: t < 0.5 ? overflow : other.overflow,
      softWrap: t < 0.5 ? softWrap : other.softWrap,
      maxScale: t < 0.5 ? maxScale : other.maxScale,
    );
  }

  /// The recipe for one role, read from the spec and the palette.
  ///
  /// Every number here is a token. The roles differ in which token they name,
  /// never in a literal one of them types.
  static _Recipe _recipeFor(BuildContext context, DSTextRole role) {
    final type = context.design.type;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    const none = 0.0;
    return switch (role) {
      DSTextRole.display => (
        step: text.displayMedium,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: true,
      ),
      DSTextRole.pageTitle => (
        step: text.headlineMedium,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: true,
      ),
      DSTextRole.screenTitle => (
        step: text.headlineSmall,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.sectionTitle => (
        step: text.titleMedium,
        weight: type.emphasisWeight,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: false,
      ),
      DSTextRole.eyebrow => (
        step: text.labelSmall,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: type.eyebrowTracking,
        tabular: false,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.cardTitle => (
        step: text.titleSmall,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: false,
      ),
      DSTextRole.bodyLead => (
        step: text.bodyLarge,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: null,
        clampScale: false,
      ),
      DSTextRole.body => (
        step: text.bodyMedium,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: null,
        clampScale: false,
      ),
      DSTextRole.bodySupport => (
        step: text.bodyMedium,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: null,
        clampScale: false,
      ),
      DSTextRole.bodyDetail => (
        step: text.bodySmall,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: null,
        clampScale: false,
      ),
      DSTextRole.quote => (
        step: text.titleLarge,
        weight: null,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: null,
        clampScale: false,
      ),
      DSTextRole.itemTitle => (
        step: text.bodyLarge,
        weight: type.titleWeight,
        color: palette.foreground,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: false,
      ),
      DSTextRole.itemSubtitle => (
        step: text.bodySmall,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: false,
      ),
      DSTextRole.itemMeta => (
        step: text.labelSmall,
        weight: null,
        // `textTertiary`, which is where this started, renders 3.95:1 on the
        // light canvas at the label step — under the 4.5:1 floor, and the
        // probe said so the first time this role was drawn. A row's date and
        // size are facts the reader is scanning for, not decoration, so the
        // role moves up a grey rather than the floor moving down. The third
        // grey is left to the disabled state, which WCAG exempts.
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: true,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.caption => (
        step: text.labelSmall,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: true,
        maxLines: 2,
        clampScale: true,
      ),
      DSTextRole.timestamp => (
        step: type.micro,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: true,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.control => (
        step: text.labelLarge,
        weight: null,
        color: null,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.controlSmall => (
        step: text.labelMedium,
        weight: null,
        color: null,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.fieldLabel => (
        step: text.labelMedium,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: false,
      ),
      DSTextRole.fieldHelper => (
        step: text.bodySmall,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: false,
      ),
      DSTextRole.fieldError => (
        step: text.bodySmall,
        weight: null,
        color: palette.destructive,
        extraTracking: none,
        tabular: false,
        maxLines: 2,
        clampScale: false,
      ),
      DSTextRole.metric => (
        step: text.headlineLarge,
        weight: type.emphasisWeight,
        color: palette.foreground,
        extraTracking: none,
        tabular: true,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.metricUnit => (
        step: text.labelMedium,
        weight: null,
        color: palette.mutedForeground,
        extraTracking: none,
        tabular: false,
        maxLines: 1,
        clampScale: true,
      ),
      DSTextRole.count => (
        step: text.labelSmall,
        weight: type.emphasisWeight,
        color: null,
        extraTracking: none,
        tabular: true,
        maxLines: 1,
        clampScale: true,
      ),
    };
  }

  /// The four layers, for one role.
  ///
  /// [tone] and [emphasis] are the caller's two semantic knobs and both act on
  /// layer 1: a tone selects a palette family, emphasis takes the weight one
  /// step up. Neither is a colour or a number at the call site, which is the
  /// property that makes them survive a re-theme.
  static DSTextStyle resolve(
    BuildContext context, {
    required DSTextRole role,
    DSTone? tone,
    bool emphasis = false,
    bool numeric = false,
    DSTextStyle? own,
  }) {
    final type = context.design.type;
    final palette = context.palette;
    final recipe = _recipeFor(context, role);

    // Layer 3 reaches the step before the palette does: a scope that says
    // "small" is asking for a step down the same ratio the scale is grown
    // from, not for a hand-picked second size.
    final scaled = switch (DSScope.sizeOf(context)) {
      DSSize.sm => 1 / type.ratio,
      DSSize.lg => type.ratio,
      _ => 1.0,
    };

    var step = recipe.step ?? const TextStyle();
    if (scaled != 1.0 && step.fontSize != null) {
      step = step.copyWith(fontSize: step.fontSize! * scaled);
    }
    if (recipe.extraTracking != 0) {
      step = step.copyWith(letterSpacing: recipe.extraTracking);
    }
    final weight = emphasis ? type.emphasisWeight : recipe.weight;
    if (weight != null) step = step.copyWith(fontWeight: weight);
    if (recipe.tabular || numeric) step = step.tabular;

    // The tone a container lends its contents is a default; an explicit one
    // wins, which is the same precedence every other DSScope field has.
    final effectiveTone = tone ?? DSScope.toneOf(context);
    final toned = switch (effectiveTone) {
      null || DSTone.neutral => recipe.color,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };

    // A disabled container greys what it holds. Only when the role has a
    // colour of its own: a control label inside a disabled button is already
    // being greyed by the button, and greying it twice is a different grey.
    final disabled = DSScope.enabledOf(context) == false;
    final color = disabled && toned != null ? palette.mutedForeground : toned;

    return resolveStyle(
      context: context,
      specDefaults: DSTextStyle(
        textStyle: step,
        color: color,
        maxLines: recipe.maxLines,
        // The pairing the kit kept getting wrong: a line limit without an
        // overflow policy clips mid-glyph and tells the reader nothing was
        // cut. They are one decision, so they are set in one place.
        overflow: recipe.maxLines == null
            ? TextOverflow.clip
            : TextOverflow.ellipsis,
        softWrap: true,
        maxScale: switch (role) {
          // The two title roles take the looser ceiling. Both truncate — they
          // carry a line limit — so by this file's own rule neither may grow
          // without limit; but a title clamped at the *control* ceiling is
          // drawn smaller than the body it introduces at a doubled text
          // scale. See TypeSpec.titleScaleCeiling for where 1.6 comes from.
          //
          // `pageTitle` had no ceiling at all until the large app bar started
          // painting it: at 2x, "Rocketship Design Notes" lost its last word
          // to an ellipsis, which is the exact shape DSHero's own note
          // describes — big type at a raised scale is answered by stepping
          // the type down, not by growing the layout.
          DSTextRole.pageTitle ||
          DSTextRole.screenTitle => type.titleScaleCeiling,
          _ => recipe.clampScale ? type.controlScaleCeiling : null,
        },
      ),
      own: own,
    );
  }
}

/// The role's style as one [TextStyle], for the components that need a value
/// rather than a widget.
///
/// [DSText] is the way to draw a string; this is the way to *fill in a style
/// field*. A component's style class holds `TextStyle?` because that is what
/// it hands to a `DefaultTextStyle`, a `TextPainter` or a Material widget's
/// own style slot — and until this existed the only way to fill one was to
/// read `Theme.of(context).textTheme` and re-decide the weight, the grey and
/// the tracking at each of 118 call sites.
///
/// The role's colour is baked in, which is the difference from
/// [DSTextStyle.resolve]: that hands back the step and the colour apart so
/// [DSText] can decide between them, and a style field has nowhere to put a
/// second value.
///
/// A role that declares no colour of its own — `control`, `controlSmall`,
/// `count`, which leave it null so a filled button and an outlined one can
/// share the role — does not get one added here. It still arrives carrying
/// Material's, because `TextTheme` is built with `apply(bodyColor:)` and every
/// step off it already has a colour painted on. That is what the call sites
/// this replaces were handing to their style fields too, which is why
/// twenty-one of them moved without a golden changing; giving a component a
/// genuinely unset colour is `copyWith(color: null)` and is a different
/// request from this one.
extension DSTextRoleStyle on DSTextRole {
  /// [emphasis] takes the weight one step up, exactly as it does on a
  /// [DSText]. It is here because a style class has the same need a widget
  /// does — a page header's title is a `pageTitle` drawn heavy — and without
  /// it that call site has to name a `FontWeight` again, which is the whole
  /// thing the roles exist to stop.
  TextStyle styleOf(BuildContext context, {bool emphasis = false}) {
    final resolved = DSTextStyle.resolve(
      context,
      role: this,
      emphasis: emphasis,
    );
    final base = resolved.textStyle ?? const TextStyle();
    return resolved.color == null ? base : base.copyWith(color: resolved.color);
  }

  /// The same style with a different meaning's colour — the tone a role's
  /// own grey gives way to. `bodyDetail.toned(context, DSTone.error)` is the
  /// error line under a field without a second role for it.
  TextStyle toned(BuildContext context, DSTone tone) {
    final resolved = DSTextStyle.resolve(context, role: this, tone: tone);
    final base = resolved.textStyle ?? const TextStyle();
    return resolved.color == null ? base : base.copyWith(color: resolved.color);
  }
}
