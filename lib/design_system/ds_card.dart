// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three grounds a card can stand on, which are the three surface roles.
enum DSCardVariant {
  /// Raised off the page, with a shadow. The default.
  elevated,

  /// Recessed into the page. A tonal block, no shadow.
  filled,

  /// Flat on the page, with a hairline instead of a lift.
  outlined,
}

/// Which end of the card the [DSCard.media] slot bleeds to.
///
/// There is no `leading`: a picture beside the text at row scale is a
/// `DSMediaRow`, which already owns the picture extent, the gutter and
/// the two-line clamp. This enum is only about which edge of a *card* the
/// media reaches — a hero above the text, or a chart under it.
enum DSCardMediaPlacement { top, bottom }

/// [DSCard]'s appearance, as data — the worked example of the component
/// contract in `docs/plans/00a-component-contract.plan.md`.
///
/// Read it beside [DSComponentStyle], which states the four rules this class
/// obeys: every field nullable, defaults read from the spec inside [resolve]
/// and nowhere else, a real [lerp], and no behaviour.
///
/// What it buys a caller who cannot edit this file:
///
/// ```dart
/// // one card
/// DSCard(style: const DSCardStyle(elevation: DSElevation.none), child: …)
///
/// // every card on this screen
/// Theme(
///   data: Theme.of(context).copyWith(
///     extensions: const [DSCardStyle(elevation: DSElevation.none)],
///   ),
///   child: …,
/// )
///
/// // every card in the app — the identity, plan 00
/// DesignSpec.halo().copyWith(elevation: spec.elevation.copyWith(intensity: 0))
/// ```
///
/// None of those three was reachable before: the variant's colours and shadow
/// were computed inside `build` from `Theme.of(context).colorScheme`, so the
/// only way to change a card was to add a fourth variant to the enum — a
/// modification of this file, forever, which is the closed design the contract
/// exists to replace.
@immutable
class DSCardStyle extends DSComponentStyle<DSCardStyle> {
  const DSCardStyle({
    this.fillColor,
    this.fillGradient,
    this.outlineColor,
    this.outlineWidth,
    this.elevation,
    this.pressedElevation,
    this.pressScale,
    this.padding,
    this.margin,
    this.radius,
    this.selectedColor,
    this.selectedIcon,
    this.selectedIconColor,
    this.selectedIconSize,
    this.selectedAlignment,
    this.disabledOpacity,
    this.disabledElevation,
    this.dividers,
    this.dividerColor,
    this.dividerWidth,
    this.slotGap,
    this.clipBehavior,
  });

  /// The card's own ground. Null resolves per variant from the palette.
  final Color? fillColor;

  /// Paints the background. The `heroGradient` this replaces blended at 0.04
  /// and 0.03 alpha, which on the shipped palette is under a 1/255 step in two
  /// of three channels — a gradient paint that cost and showed nothing.
  final Gradient? fillGradient;

  /// The outline, when the variant draws one. Null means no outline.
  final Color? outlineColor;
  final double? outlineWidth;

  /// A role, never a number.
  final DSElevation? elevation;

  /// Where the card goes while it is pressed: one step *toward* the page.
  final DSElevation? pressedElevation;

  /// Shallower than a button's, because a card is larger and the same scale
  /// reads as a lurch at card size.
  final double? pressScale;

  final EdgeInsetsGeometry? padding;

  /// Zero. The page gutter has a single owner, so a card that margins itself
  /// double-spaces against the page that already spaced it — which is why the
  /// old default was a default the docs told you to override.
  final EdgeInsetsGeometry? margin;

  final BorderRadius? radius;

  /// The ground a selected card stands on.
  final Color? selectedColor;

  /// The tick that keeps selection off colour alone, as four values rather
  /// than four literals in `build`. A caller whose selection means "in the
  /// basket" wants a basket, at the corner their layout leaves free.
  final IconData? selectedIcon;
  final Color? selectedIconColor;
  final double? selectedIconSize;
  final AlignmentGeometry? selectedAlignment;

  /// What `enabled: false` looks like.
  ///
  /// It had no look at all: `enabled` gated the ink and the semantics and
  /// nothing else, so a disabled card was pixel-identical to a live one and
  /// simply stopped answering. Shallower than the .38 the controls use —
  /// `DSControlPaint.disabledOpacity` is tuned for a switch, and a whole card
  /// at .38 is a card the reader assumes has failed to load.
  final double? disabledOpacity;

  /// Where a disabled card sits. On the page: a surface nobody can reach has
  /// no business floating above one.
  final DSElevation? disabledElevation;

  /// Whether a hairline separates the header, the child and the footer.
  ///
  /// Off by default — the gap is enough on a card with three lines in it. On
  /// for a card that is really three sections, where a gap the same size as
  /// the one inside the body does not say where one section ends.
  ///
  /// The rules run the full width of the card rather than the width of the
  /// text, which is why they are not something a caller can put in the
  /// [DSCard.child]: a rule that stops at the padding reads as an underline
  /// on the last line above it.
  final bool? dividers;
  final Color? dividerColor;
  final double? dividerWidth;

  /// Between the header, the child and the footer.
  final double? slotGap;

  final Clip? clipBehavior;

  @override
  DSCardStyle merge(DSCardStyle? other) {
    if (other == null) return this;
    return DSCardStyle(
      fillColor: other.fillColor ?? fillColor,
      fillGradient: other.fillGradient ?? fillGradient,
      outlineColor: other.outlineColor ?? outlineColor,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      elevation: other.elevation ?? elevation,
      pressedElevation: other.pressedElevation ?? pressedElevation,
      pressScale: other.pressScale ?? pressScale,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      radius: other.radius ?? radius,
      selectedColor: other.selectedColor ?? selectedColor,
      selectedIcon: other.selectedIcon ?? selectedIcon,
      selectedIconColor: other.selectedIconColor ?? selectedIconColor,
      selectedIconSize: other.selectedIconSize ?? selectedIconSize,
      selectedAlignment: other.selectedAlignment ?? selectedAlignment,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
      disabledElevation: other.disabledElevation ?? disabledElevation,
      dividers: other.dividers ?? dividers,
      dividerColor: other.dividerColor ?? dividerColor,
      dividerWidth: other.dividerWidth ?? dividerWidth,
      slotGap: other.slotGap ?? slotGap,
      clipBehavior: other.clipBehavior ?? clipBehavior,
    );
  }

  @override
  DSCardStyle copyWith({
    Color? fillColor,
    Gradient? fillGradient,
    Color? outlineColor,
    double? outlineWidth,
    DSElevation? elevation,
    DSElevation? pressedElevation,
    double? pressScale,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? radius,
    Color? selectedColor,
    IconData? selectedIcon,
    Color? selectedIconColor,
    double? selectedIconSize,
    AlignmentGeometry? selectedAlignment,
    double? disabledOpacity,
    DSElevation? disabledElevation,
    bool? dividers,
    Color? dividerColor,
    double? dividerWidth,
    double? slotGap,
    Clip? clipBehavior,
  }) => DSCardStyle(
    fillColor: fillColor ?? this.fillColor,
    fillGradient: fillGradient ?? this.fillGradient,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    elevation: elevation ?? this.elevation,
    pressedElevation: pressedElevation ?? this.pressedElevation,
    pressScale: pressScale ?? this.pressScale,
    padding: padding ?? this.padding,
    margin: margin ?? this.margin,
    radius: radius ?? this.radius,
    selectedColor: selectedColor ?? this.selectedColor,
    selectedIcon: selectedIcon ?? this.selectedIcon,
    selectedIconColor: selectedIconColor ?? this.selectedIconColor,
    selectedIconSize: selectedIconSize ?? this.selectedIconSize,
    selectedAlignment: selectedAlignment ?? this.selectedAlignment,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
    disabledElevation: disabledElevation ?? this.disabledElevation,
    dividers: dividers ?? this.dividers,
    dividerColor: dividerColor ?? this.dividerColor,
    dividerWidth: dividerWidth ?? this.dividerWidth,
    slotGap: slotGap ?? this.slotGap,
    clipBehavior: clipBehavior ?? this.clipBehavior,
  );

  @override
  DSCardStyle lerp(DSCardStyle? other, double t) {
    if (other == null) return this;
    return DSCardStyle(
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      fillGradient: Gradient.lerp(fillGradient, other.fillGradient, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      elevation: t < 0.5 ? elevation : other.elevation,
      pressedElevation: t < 0.5 ? pressedElevation : other.pressedElevation,
      pressScale: lerpDouble(pressScale, other.pressScale, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      // A glyph and a boolean have no midpoint; they switch at the halfway
      // mark rather than pretending to interpolate.
      selectedIcon: t < 0.5 ? selectedIcon : other.selectedIcon,
      selectedIconColor: Color.lerp(
        selectedIconColor,
        other.selectedIconColor,
        t,
      ),
      selectedIconSize: lerpDouble(selectedIconSize, other.selectedIconSize, t),
      selectedAlignment: AlignmentGeometry.lerp(
        selectedAlignment,
        other.selectedAlignment,
        t,
      ),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
      disabledElevation: t < 0.5 ? disabledElevation : other.disabledElevation,
      dividers: t < 0.5 ? dividers : other.dividers,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      dividerWidth: lerpDouble(dividerWidth, other.dividerWidth, t),
      slotGap: lerpDouble(slotGap, other.slotGap, t),
      clipBehavior: t < 0.5 ? clipBehavior : other.clipBehavior,
    );
  }

  /// The four layers, in order, and the only place a card's defaults are read.
  ///
  /// [variant] and [tone] are parameters rather than fields because they
  /// select *which* defaults layer 1 supplies; they are choices about meaning,
  /// not values that a later layer overrides. Layer 3's contribution is
  /// [DSScope.density], which moves the padding one step down the space scale
  /// — a card inside a compact container is tighter without every call site
  /// saying so.
  ///
  /// The two are orthogonal and they answer different questions. [variant]
  /// says how far off the page the card sits; [tone] says what it is about.
  /// A `success` card is still `elevated` or `outlined`, and it keeps that
  /// variant's depth — only its ground and its hairline come from the tone.
  static DSCardStyle resolve(
    BuildContext context,
    DSCardVariant variant,
    DSTone tone, [
    DSCardStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;

    final specDefaults = switch (variant) {
      // `medium`, not `low`. It was raised when halo's light ladder was flat
      // — page and card the same white, the shadow carrying all of "in front"
      // rather than most of it — and it stays there now that the page has
      // stepped back to a grey. The two signals agree instead of one standing
      // in for the other, and a card is found by whichever the eye reaches
      // first. `ds_card_test` holds both: the tonal edge at 1.15:1 and the
      // two-layer shadow.
      DSCardVariant.elevated => DSCardStyle(
        fillColor: palette.card,
        // A hairline, on the variant that used to have none. In light the card
        // and the page are the same white, so there is no tonal edge left for
        // the shadow to reinforce — and a shadow on its own reads as a plane
        // down a list, which is the failure the flat ladder was backed out of
        // once already. The edge is put back on the card instead of taken out
        // of the page: `outlineSoft`, so it is found rather than drawn.
        outlineColor: palette.borderSoft,
        elevation: DSElevation.medium,
        padding: EdgeInsets.all(space.lg),
      ),
      DSCardVariant.filled => DSCardStyle(
        fillColor: palette.muted,
        elevation: DSElevation.none,
        padding: EdgeInsets.all(space.lg),
      ),
      // `low`, not `none`. This variant fills with the page's own colour, so
      // the hairline is the only thing that finds it, and a hairline alone
      // leaves a card with no depth at all. A card is always above the page it
      // sits on, so it always casts something; the contact layer is what makes
      // an outlined card read as paper on a desk rather than as a rectangle
      // drawn on the desk.
      DSCardVariant.outlined => DSCardStyle(
        fillColor: palette.background,
        outlineColor: palette.borderSoft,
        elevation: DSElevation.low,
        padding: EdgeInsets.all(space.lg),
      ),
    };

    // The tone replaces the ground the variant chose, and adds the hairline
    // that goes with it. `DSToneWash` is the same recipe `DSMessage` reads, so
    // a `success` card and a `success` message on one screen are the same
    // green — which is the whole reason a card has a tone at all instead of
    // every call site passing `fillColor` and `outlineColor` by hand.
    //
    // `neutral` is not a fifth family. It means "no tone", and a card with no
    // tone keeps whatever ground its variant chose.
    final Color? status = switch (tone) {
      DSTone.neutral => null,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };
    DSCardStyle? toned;
    if (status != null) {
      final fill = DSToneWash.fill(
        container: palette.tint(status),
        surface: palette.card,
      );
      toned = DSCardStyle(
        fillColor: fill,
        outlineColor: DSToneWash.border(
          accent: status,
          fill: fill,
          brightness: palette.brightness,
        ),
      );
    }

    final scope = DSScope.densityOf(context) == DSDensity.compact
        ? DSCardStyle(padding: EdgeInsets.all(space.md))
        : null;

    return resolveStyle(
      context: context,
      specDefaults: specDefaults
          .merge(toned)
          .merge(
            DSCardStyle(
              outlineWidth: context.design.component.surfaceOutlineWidth,
              pressedElevation: ElevationSpec.lower(
                specDefaults.elevation ?? DSElevation.none,
              ),
              pressScale: 0.99,
              margin: EdgeInsets.zero,
              selectedColor: palette.secondary,
              selectedIcon: Icons.check_circle_rounded,
              selectedIconColor: palette.primary,
              selectedIconSize: context.design.component.iconSize,
              selectedAlignment: AlignmentDirectional.topEnd,
              disabledOpacity: 0.5,
              disabledElevation: DSElevation.none,
              dividers: false,
              dividerColor: palette.borderSoft,
              dividerWidth: context.design.component.hairlineWidth,
              slotGap: space.md,
              clipBehavior: Clip.antiAlias,
            ),
          ),
      scope: scope,
      own: own,
    );
  }
}

/// The one raised surface in the kit.
///
/// See `docs/plans/09-ds-card.plan.md`. Everything else that looks like a card
/// is a `DSListTile` in a list, a `DSStatTile` in a grid, or a mistake: N rows
/// go in **one** card, not in N cards.
///
/// The margin defaults to zero. The page gutter has a single owner, and the
/// previous default was one the doc comment told every caller to override.
class DSCard extends StatefulWidget {
  const DSCard({
    super.key,
    this.child,
    this.variant = DSCardVariant.elevated,
    this.tone,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.header,
    this.footer,
    this.media,
    this.overlay,
    this.mediaPlacement = DSCardMediaPlacement.top,
    this.padding,
    this.margin,
  });

  /// The card's content, inside the padding.
  ///
  /// Nullable, and the null case is a real one: a card whose whole content is
  /// its [media] — a hero image, a chart, a map — has nothing to pad. Passing
  /// an empty box there drew the padding anyway, which is a band of card
  /// surface under the picture that reads as a rendering fault rather than as
  /// a card. With no header, child or footer the padded column is not built at
  /// all.
  final Widget? child;

  /// How far off the page the card sits.
  final DSCardVariant variant;

  /// What the card is about, when that is not "nothing in particular".
  ///
  /// Null falls back to the enclosing [DSScope], then to [DSTone.neutral],
  /// which keeps the variant's own ground. A tone replaces the ground and adds
  /// the hairline that goes with it, and nothing else: the depth stays the
  /// variant's.
  ///
  /// **Use it** for a card that reports the state of the thing it is about —
  /// the failed job, the expiring plan. **Instead:** `DSMessage` when the card
  /// would hold only the sentence, since a message is that sentence with the
  /// live region, the assertive announcement and the dismiss already attached.
  final DSTone? tone;

  final VoidCallback? onTap;

  /// A context menu, a multi-select entry point.
  ///
  /// Separate from [onTap] rather than folded into it because the two answer
  /// different questions, and because a card may have one without the other:
  /// a long-press-only card is a row you can act on but not open.
  final VoidCallback? onLongPress;

  /// Draws a fill *and* a check. A fill alone would leave colour carrying the
  /// meaning.
  final bool selected;

  final bool enabled;
  final bool loading;

  /// Layer 4 of the chain: this one card, here.
  final DSCardStyle? style;

  /// Above the child, inside the padding. Without it every caller re-derives a
  /// title row, and they drift.
  final Widget? header;

  /// Below the child. An action row, a timestamp.
  final Widget? footer;

  /// Above everything and *outside* the padding, clipped to the top corners.
  /// This is the slot that lets an image bleed to the card's radius without
  /// the caller setting `padding: zero` and re-adding it around the text.
  final Widget? media;

  /// Stacked over everything, clipped to the shape — a ribbon, a badge, a
  /// selection tick.
  final Widget? overlay;

  /// Which edge [media] bleeds to. A hero above the text, or a chart under it.
  final DSCardMediaPlacement mediaPlacement;

  /// Shorthands for the same fields on [style], read as the innermost layer.
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  State<DSCard> createState() => _DSCardState();
}

class _DSCardState extends State<DSCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final design = context.design;
    // An explicit tone wins, then the container's, then none — the scope
    // rule from `ds_scope.dart`: a scope supplies a default, never an
    // override.
    final tone = widget.tone ?? DSScope.toneOf(context) ?? DSTone.neutral;
    final resolved = DSCardStyle.resolve(
      context,
      widget.variant,
      tone,
      const DSCardStyle()
          .merge(widget.style)
          .merge(DSCardStyle(padding: widget.padding, margin: widget.margin)),
    );

    assert(
      widget.onTap == null ||
          widget.child == null ||
          !_hasInteractiveChild(widget.child!),
      'A card with onTap and an interactive child swallows the inner gesture '
      'and announces one target where there are two. Either the card is the '
      'target or the control inside it is.',
    );

    // Two different questions, and conflating them is what made `enabled`
    // invisible. `enabled` is whether the card is *available*, and it is what
    // the dim reads; `interactive` is whether a gesture may land now, which a
    // loading card also fails. A loading card is not dimmed — it already has a
    // skeleton, and dimming that reads as a card that failed to load.
    final enabled = widget.enabled && (DSScope.enabledOf(context) ?? true);
    final interactive = enabled && !widget.loading;
    final tappable = widget.onTap != null || widget.onLongPress != null;
    final level = !enabled
        ? (resolved.disabledElevation ?? DSElevation.none)
        : _pressed
        ? (resolved.pressedElevation ?? DSElevation.none)
        : (resolved.elevation ?? DSElevation.none);

    final shape =
        (resolved.radius == null
                ? context.shapeOf(AppShape.card)
                : RoundedRectangleBorder(borderRadius: resolved.radius!))
            .copyWith(
              side: resolved.outlineColor == null && !widget.selected
                  ? BorderSide.none
                  : BorderSide(
                      color: widget.selected
                          ? palette.primary
                          : resolved.outlineColor!,
                      // Two tokens rather than one and a multiplier: the
                      // selected edge is a decision an identity makes, and a
                      // literal 1.5 buried in a `copyWith` is not something a
                      // spec can move.
                      width: widget.selected
                          ? design.component.selectedOutlineWidth
                          : (resolved.outlineWidth ??
                                design.component.surfaceOutlineWidth),
                      // Outside, so the stroke costs no layout.
                      // `ShapeDecoration.padding` is `side.strokeInset` on
                      // every edge, so a centred hairline insets the card's
                      // contents by half its width — and the media slot, whose
                      // whole promise is that an image reaches the card's own
                      // corners, came back two logical pixels narrow.
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
            );

    final padding = resolved.padding ?? EdgeInsets.all(design.space.lg);

    // The selection check stands on the same grid as the content rather than
    // on a padding of its own. At `space.sm` it sat eight points above the
    // first line of text and eight points inside the text's own right edge —
    // on the one-line card, which is the common case, that reads as a badge
    // somebody forgot to align. Sharing the card's padding puts the icon's
    // box on the text's right edge. Clamped from below so a card that pays no
    // padding — the media-only card — still keeps the check clear of the
    // corner radius.
    final badgePadding = padding
        .resolve(Directionality.of(context))
        .clamp(
          EdgeInsets.all(design.space.sm),
          const EdgeInsets.all(double.infinity),
        );

    // Nothing to pad. A media-only card is the picture and its corners; the
    // padded column would be an empty band of surface below it, and an empty
    // band reads as a layout fault. See the `empty-padding` probe rule, which
    // is the gate that says so on any surface.
    final bool hasPadded =
        widget.header != null || widget.child != null || widget.footer != null;

    final gap = resolved.slotGap ?? design.space.md;
    final ruled = (resolved.dividers ?? false) && hasPadded;

    // Outside the padding, so an image reaches the card's own corners.
    final media = widget.media;
    final atTop = widget.mediaPlacement == DSCardMediaPlacement.top;

    // A card is a fresh surface, not the page: a row placed inside one sits
    // at the card's edge, and it does not know that unless something says so.
    // Without this, `DSGutterScope.applied` answers with whatever a page-level
    // `DSGutter` said above the card, and a full-bleed row two containers deep
    // reads its inset as already spent — see `DSGutterScope.reset`.
    Widget body = DSGutterScope.reset(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (media != null && atTop) media,
          // Ruled and unruled are two shapes, not one shape with a line in it.
          // A rule has to run the full width of the card, which means each
          // section carries its own padding — and with no rules that would be
          // three paddings where one will do, and three chances for them to
          // disagree.
          if (ruled)
            ..._ruledSections(resolved, padding)
          else if (hasPadded)
            Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.header != null) ...[
                    widget.header!,
                    SizedBox(height: gap),
                  ],
                  if (widget.child != null) widget.child!,
                  if (widget.footer != null) ...[
                    SizedBox(height: gap),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          if (media != null && !atTop) media,
        ],
      ),
    );

    if (widget.loading) body = DSSkeleton(child: body);

    Widget surface = Container(
      margin: resolved.margin,
      decoration: ShapeDecoration(
        color: resolved.fillGradient != null
            ? null
            : widget.selected
            ? (resolved.selectedColor ?? palette.secondary)
            : resolved.fillColor,
        gradient: resolved.fillGradient,
        shape: shape,
        shadows: design.elevation.resolve(
          elevation: design.elevation.levelOf(level),
          brightness: Theme.of(context).brightness,
          shadowColor: palette.overlay,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: resolved.clipBehavior ?? Clip.antiAlias,
        child: Stack(
          children: [
            if (!tappable)
              body
            else
              DSInkSurface(
                onTap: interactive ? widget.onTap : null,
                onLongPress: interactive ? widget.onLongPress : null,
                onHighlightChanged: (value) =>
                    setState(() => _pressed = value && interactive),
                shape: shape,
                child: body,
              ),
            if (widget.selected)
              Positioned.fill(
                // An `Align` and not an overflow box left the check at the
                // mercy of the card's height: a one-line card is 55 points
                // tall, the padded box inside it 23, and a 24-point icon
                // handed 23 comes out with a flat-bottomed circle that no
                // other check on the screen has. The padded rectangle is the
                // frame the icon aligns to, not a box it has to fit in.
                child: Padding(
                  padding: badgePadding,
                  child: _SelectionBadge(
                    alignment:
                        resolved.selectedAlignment ??
                        AlignmentDirectional.topEnd,
                    icon: Icon(
                      resolved.selectedIcon ?? Icons.check_circle_rounded,
                      size:
                          resolved.selectedIconSize ??
                          design.component.iconSize,
                      color: resolved.selectedIconColor ?? palette.primary,
                    ),
                  ),
                ),
              ),
            if (widget.overlay != null) widget.overlay!,
          ],
        ),
      ),
    );

    // Press feedback only when there is something to press. A card that dips
    // under a finger and does nothing is worse than one that never moved.
    if (tappable) {
      surface = DSPressable(
        enabled: interactive,
        scale: resolved.pressScale ?? 0.99,
        focusShape: shape,
        child: surface,
      );
      // The node has to advertise the action it actually has. Marking a
      // long-press-only card `button: true` and stopping there produces a
      // control a screen reader can name and cannot use — `semantics_test`'s
      // inert-control gate is what says so.
      surface = Semantics(
        container: true,
        button: widget.onTap != null,
        onLongPress: interactive ? widget.onLongPress : null,
        enabled: interactive,
        selected: widget.selected,
        child: surface,
      );
    }

    // Outermost, so the fill, the hairline, the shadow and the content all dim
    // together. Dimming the content alone leaves a full-strength card frame
    // around grey text, which reads as a rendering fault rather than as a card
    // that is not available.
    if (!enabled) {
      surface = Opacity(
        opacity: resolved.disabledOpacity ?? 0.5,
        child: surface,
      );
    }

    return surface;
  }

  /// The header, the child and the footer as three padded sections with a
  /// full-width rule between them.
  ///
  /// A rule that stops at the padding reads as an underline on the last line
  /// above it, which is why this cannot be something a caller puts in
  /// [DSCard.child].
  List<Widget> _ruledSections(
    DSCardStyle resolved,
    EdgeInsetsGeometry padding,
  ) {
    final rule = SizedBox(
      height: resolved.dividerWidth ?? 0,
      child: ColoredBox(color: resolved.dividerColor ?? Colors.transparent),
    );
    final sections = <Widget>[
      if (widget.header != null)
        Padding(padding: padding, child: widget.header!),
      if (widget.child != null) Padding(padding: padding, child: widget.child!),
      if (widget.footer != null)
        Padding(padding: padding, child: widget.footer!),
    ];
    return [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) rule,
        sections[i],
      ],
    ];
  }

  /// One level deep, and deliberately so: the common defect is a card with an
  /// `onTap` whose body is a `Row` ending in a button, and a full tree walk on
  /// every build to catch the rare case is a worse trade.
  static bool _hasInteractiveChild(Widget child) {
    bool interactive(Widget w) =>
        w is DSCard && w.onTap != null ||
        w.runtimeType.toString().startsWith('DSButton') ||
        w.runtimeType.toString().startsWith('DSIconButton');
    if (interactive(child)) return true;
    if (child is MultiChildRenderObjectWidget) {
      return child.children.any(interactive);
    }
    return false;
  }
}

/// A card's title row — the intended occupant of [DSCard.header].
///
/// Without it every caller re-derives a title row, which is exactly the drift
/// the audit found across the demo screens.
class DSCardHeader extends StatelessWidget {
  const DSCardHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.actions = const [],
    this.titleSlot,
    this.subtitleSlot,
    this.dense = false,
  }) : assert(
         title != null || titleSlot != null,
         'A card header with neither a title nor a titleSlot is a row of '
         'padding. `title` was `required` and then ignored whenever a '
         'titleSlot was passed, so every caller with a custom title invented '
         'a dead string for it.',
       );

  /// Null only when [titleSlot] replaces it.
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Rendered at the trailing edge under a small [DSScope], so the buttons in
  /// a card header do not have to be told their own size.
  final List<Widget> actions;

  final Widget? titleSlot;
  final Widget? subtitleSlot;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, SizedBox(width: space.md)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleSlot ??
                  Text(
                    title!,
                    style: (dense ? text.titleSmall : text.titleMedium)
                        ?.copyWith(
                          color: palette.foreground,
                          fontWeight: context.design.type.emphasisWeight,
                        ),
                    // Two lines, for the reason `DSListTile._title` gives:
                    // a card's title is the thing the card is about.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              if (subtitleSlot != null || subtitle != null) ...[
                SizedBox(height: space.hairline),
                subtitleSlot ??
                    Text(
                      subtitle!,
                      style: DSTextRole.bodyDetail.styleOf(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: space.sm), trailing!],
        if (actions.isNotEmpty) ...[
          SizedBox(width: space.sm),
          Builder(
            builder: (context) => DSScope.merge(
              context,
              size: DSSize.sm,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
        ],
      ],
    );
  }
}

/// Which end of the footer the actions sit at.
enum DSCardFooterAlign { start, end, spaceBetween }

/// A card's action row — the intended occupant of [DSCard.footer].
class DSCardFooter extends StatelessWidget {
  const DSCardFooter({
    super.key,
    this.actions = const [],
    this.helper,
    this.align = DSCardFooterAlign.end,
  });

  final List<Widget> actions;

  /// A line of explanation beside the actions — see [DSCardHelperText].
  final Widget? helper;

  final DSCardFooterAlign align;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final row = Row(
      mainAxisAlignment: switch (align) {
        DSCardFooterAlign.start => MainAxisAlignment.start,
        DSCardFooterAlign.end => MainAxisAlignment.end,
        DSCardFooterAlign.spaceBetween => MainAxisAlignment.spaceBetween,
      },
      children: [
        if (helper != null) Expanded(child: helper!),
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: space.sm),
          actions[i],
        ],
      ],
    );
    return Builder(
      builder: (context) => DSScope.merge(context, size: DSSize.sm, child: row),
    );
  }
}

/// The line of explanation beside a card's actions.
// ds-tier: 1 — atom — One supporting line under a card's actions.
class DSCardHelperText extends StatelessWidget {
  const DSCardHelperText(this.text, {super.key, this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: DSTextRole.bodyDetail.styleOf(context),
  );
}

/// An image that bleeds to the card's own corners — the intended occupant of
/// [DSCard.media].
// ds-tier: 1 — atom — The card's picture slot: a clip and a box.
class DSCardMedia extends StatelessWidget {
  const DSCardMedia({
    super.key,
    required this.child,
    this.aspectRatio,
    this.overlay,
  });

  final Widget child;
  final double? aspectRatio;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    Widget media = child;
    if (aspectRatio != null) {
      media = AspectRatio(aspectRatio: aspectRatio!, child: media);
    }
    if (overlay == null) return media;
    return Stack(
      children: [
        media,
        Positioned.fill(child: overlay!),
      ],
    );
  }
}

/// A card-shaped skeleton, built from the slots the real card will have.
class DSCardSkeleton extends StatelessWidget {
  const DSCardSkeleton({
    super.key,
    this.showHeader = false,
    this.showFooter = false,
    this.showMedia = false,
    this.contentLines = 3,
    this.variant = DSCardVariant.elevated,
  });

  final bool showHeader;
  final bool showFooter;
  final bool showMedia;
  final int contentLines;
  final DSCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return DSCard(
      variant: variant,
      loading: true,
      media: showMedia
          ? DSCardMedia(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: context.palette.muted),
            )
          : null,
      header: showHeader
          ? const DSCardHeader(
              title: 'Placeholder headline',
              subtitle: 'Secondary line of placeholder copy',
            )
          : null,
      footer: showFooter
          ? const DSCardFooter(helper: DSCardHelperText('Placeholder note'))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < contentLines; i++) ...[
            if (i > 0) SizedBox(height: space.xs),
            const Text('A line of placeholder copy for the loading state'),
          ],
        ],
      ),
    );
  }
}

/// The tick on a selected card, placed on the content's first line rather
/// than in the corner of the box.
///
/// The two are the same thing only by accident. A top-anchored badge aligned
/// to the padded rectangle puts the icon's *top* on the content's top, so its
/// centre sits `(iconSize - lineHeight) / 2` below the line's centre — which
/// was 0.4pt while body copy was 16pt against a 24pt icon, and became 2.7pt
/// the moment the type scale came down. The card's own comment described that
/// arithmetic as though it were a mechanism. This is the mechanism.
///
/// Only a top-anchored badge is line-aligned. A `bottomStart` tick is a
/// corner mark and has no first line to stand on, so it keeps the whole
/// padded rectangle as its frame.
class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.alignment, required this.icon});

  final AlignmentGeometry alignment;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final resolved = alignment.resolve(Directionality.of(context));

    // The icon is wider and taller than the box it is offered, and being
    // clipped to fit is what gave the check a flat bottom. It overflows on
    // purpose; the frame decides where its centre lands, not its size.
    Widget released(Alignment at) => OverflowBox(
      alignment: at,
      // Zero, not a spec value: the padded rectangle arrives tightly
      // constrained, so leaving the minimums alone stretched the icon to the
      // full content width.
      // ui-lint: allow hardcoded-box-size — a released minimum
      minWidth: 0,
      maxWidth: double.infinity,
      // ui-lint: allow hardcoded-box-size — a released minimum
      minHeight: 0,
      maxHeight: double.infinity,
      child: icon,
    );

    if (resolved.y != -1.0) return released(resolved);

    // The card's content inherits `bodyMedium`, which is what `DSTextRole.body`
    // names, so the line the tick stands on is that role's line — asked for by
    // name rather than measured off whatever happens to be drawn.
    final line = DSTextRole.body.styleOf(context);
    final design = context.design;
    final height =
        MediaQuery.textScalerOf(
          context,
        ).scale(line.fontSize ?? design.type.baseSize) *
        (line.height ?? design.type.bodyHeight);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        width: double.infinity,
        // Centred *within the line*, which is the whole point: the frame is
        // one line tall, so a centred icon shares the line's centre however
        // large either of them is.
        child: released(Alignment(resolved.x, 0)),
      ),
    );
  }
}
