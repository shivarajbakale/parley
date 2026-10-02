// ds-tier: 2 — molecule

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_icon_button.dart'
    show DSIconButtonBadge;
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSBottomNavBar]'s appearance, as data.
///
/// See `docs/plans/15-ds-bottom-nav-bar.plan.md` §8. Two fields from the
/// plan's table are deliberately absent:
///
/// - **`indicatorSize`.** Material's `NavigationBar` builds its indicator
///   inside a private destination builder and passes no size through, so the
///   64 × 32 pill is a framework constant. A style field that silently does
///   nothing is worse than no field, so the size is documented here instead
///   of pretended at. `indicatorColor` and `indicatorShape` *are* settable
///   and are kept.
/// - **a per-destination label toggle.** [showLabels] is all-or-nothing by
///   construction, because Material's guidance is that mixing shown and
///   hidden labels is itself the failure.
@immutable
class DSBottomNavBarStyle extends DSComponentStyle<DSBottomNavBarStyle> {
  const DSBottomNavBarStyle({
    this.height,
    this.glyphSize,
    this.indicatorColor,
    this.indicatorGradient,
    this.indicatorShape,
    this.selectedColor,
    this.unselectedColor,
    this.disabledColor,
    this.labelStyle,
    this.selectedLabelStyle,
    this.showLabels,
    this.glyphLabelGap,
    this.badgeOffset,
    this.floating,
    this.margin,
  });

  /// The bar's own height, before the safe-area inset [NavigationBar] adds.
  final double? height;

  final double? glyphSize;

  /// The pill behind the selected glyph — one of the three channels selection
  /// is carried on.
  final Color? indicatorColor;

  /// The brand moment on the pill. Painted instead of [indicatorColor] when
  /// set — see the paint site, which nulls `color` when a gradient is
  /// present.
  final Gradient? indicatorGradient;

  final ShapeBorder? indicatorShape;
  final Color? selectedColor;
  final Color? unselectedColor;

  /// A destination that is present but unavailable. Rare enough that the
  /// `use` rule says a destination which is never available should not be a
  /// destination at all.
  final Color? disabledColor;

  final TextStyle? labelStyle;

  /// The weight change is the third SC 1.4.1 channel, so this is not merely
  /// [labelStyle] with a colour.
  final TextStyle? selectedLabelStyle;

  final bool? showLabels;
  final double? glyphLabelGap;

  /// Where the badge sits relative to the glyph's top-trailing corner.
  /// Anchored to the glyph rather than to the destination, or it drifts
  /// toward the neighbouring destination as the column gets wider.
  final Offset? badgeOffset;

  /// Whether the bar detaches from the bottom edge.
  ///
  /// Floating is the default. A bar welded to the edge has two square corners
  /// that belong to the device rather than to the app, and it cuts the screen
  /// with a hard horizontal line at the exact place the eye rests. Lifted off
  /// the edge it becomes an object: content passes *under* it, the shadow has
  /// something to fall on, and the glass has something to blur.
  ///
  /// Set it false for a bar that spans the full width and squares its corners
  /// — the Material 2 arrangement, and the right answer on a tablet where a
  /// pill floating in the middle of a 1024dp edge looks lost.
  final bool? floating;

  /// The gap between a floating bar and the screen's edges.
  ///
  /// The bottom safe area is *not* in here: it is read at build time and
  /// added, because the home indicator's height is a property of the device
  /// rather than of the design. Overriding this moves the bar within its
  /// margins; it never moves it under the indicator.
  final EdgeInsets? margin;

  @override
  DSBottomNavBarStyle merge(DSBottomNavBarStyle? other) {
    if (other == null) return this;
    return DSBottomNavBarStyle(
      height: other.height ?? height,
      glyphSize: other.glyphSize ?? glyphSize,
      indicatorColor: other.indicatorColor ?? indicatorColor,
      indicatorGradient: other.indicatorGradient ?? indicatorGradient,
      indicatorShape: other.indicatorShape ?? indicatorShape,
      selectedColor: other.selectedColor ?? selectedColor,
      unselectedColor: other.unselectedColor ?? unselectedColor,
      disabledColor: other.disabledColor ?? disabledColor,
      labelStyle: other.labelStyle ?? labelStyle,
      selectedLabelStyle: other.selectedLabelStyle ?? selectedLabelStyle,
      showLabels: other.showLabels ?? showLabels,
      glyphLabelGap: other.glyphLabelGap ?? glyphLabelGap,
      badgeOffset: other.badgeOffset ?? badgeOffset,
      floating: other.floating ?? floating,
      margin: other.margin ?? margin,
    );
  }

  @override
  DSBottomNavBarStyle copyWith({
    double? height,
    double? glyphSize,
    Color? indicatorColor,
    Gradient? indicatorGradient,
    ShapeBorder? indicatorShape,
    Color? selectedColor,
    Color? unselectedColor,
    Color? disabledColor,
    TextStyle? labelStyle,
    TextStyle? selectedLabelStyle,
    bool? showLabels,
    double? glyphLabelGap,
    Offset? badgeOffset,
    bool? floating,
    EdgeInsets? margin,
  }) => DSBottomNavBarStyle(
    height: height ?? this.height,
    glyphSize: glyphSize ?? this.glyphSize,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    indicatorGradient: indicatorGradient ?? this.indicatorGradient,
    indicatorShape: indicatorShape ?? this.indicatorShape,
    selectedColor: selectedColor ?? this.selectedColor,
    unselectedColor: unselectedColor ?? this.unselectedColor,
    disabledColor: disabledColor ?? this.disabledColor,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedLabelStyle: selectedLabelStyle ?? this.selectedLabelStyle,
    showLabels: showLabels ?? this.showLabels,
    glyphLabelGap: glyphLabelGap ?? this.glyphLabelGap,
    badgeOffset: badgeOffset ?? this.badgeOffset,
    floating: floating ?? this.floating,
    margin: margin ?? this.margin,
  );

  @override
  DSBottomNavBarStyle lerp(DSBottomNavBarStyle? other, double t) {
    if (other == null) return this;
    return DSBottomNavBarStyle(
      height: lerpDouble(height, other.height, t),
      glyphSize: lerpDouble(glyphSize, other.glyphSize, t),
      indicatorColor: Color.lerp(indicatorColor, other.indicatorColor, t),
      indicatorGradient: Gradient.lerp(
        indicatorGradient,
        other.indicatorGradient,
        t,
      ),
      indicatorShape: ShapeBorder.lerp(indicatorShape, other.indicatorShape, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      unselectedColor: Color.lerp(unselectedColor, other.unselectedColor, t),
      disabledColor: Color.lerp(disabledColor, other.disabledColor, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      selectedLabelStyle: TextStyle.lerp(
        selectedLabelStyle,
        other.selectedLabelStyle,
        t,
      ),
      // A bool has no midpoint. Snapping at the halfway mark is the honest
      // answer; interpolating it would show labels at half opacity, which is
      // the mixed state the research says not to build.
      showLabels: t < 0.5 ? showLabels : other.showLabels,
      glyphLabelGap: lerpDouble(glyphLabelGap, other.glyphLabelGap, t),
      badgeOffset: Offset.lerp(badgeOffset, other.badgeOffset, t),
      // Same reasoning as [showLabels]: half-floating is not a shape.
      floating: t < 0.5 ? floating : other.floating,
      margin: EdgeInsets.lerp(margin, other.margin, t),
    );
  }

  /// Layer 1 of the chain: the spec's answer, before the theme extension,
  /// the scope and the caller's `style:`.
  static DSBottomNavBarStyle resolve(
    BuildContext context, [
    DSBottomNavBarStyle? own,
  ]) {
    final design = context.design;
    final palette = context.palette;
    final label = Theme.of(context).textTheme.labelSmall;

    return resolveStyle(
      context: context,
      specDefaults: DSBottomNavBarStyle(
        height: _barHeight,
        glyphSize: design.component.iconSize,
        indicatorColor: palette.secondary,
        indicatorGradient: palette.primaryGradient,
        indicatorShape: const StadiumBorder(),
        // Stays `palette.primary`, not `primaryForeground`: this colour is
        // shared with the Cupertino branch, which never paints the pill
        // (see `_cupertinoBar`'s doc comment) and would sink an on-primary
        // colour into invisibility on the plain background it selects
        // against. The Material branch's pill glyph/label get
        // `primaryForeground` at the paint site instead, where the
        // gradient is actually behind them.
        selectedColor: palette.primary,
        // A destination that the user cannot read is one they cannot tap
        // reliably. `textSecondary` passed the contrast floor in light mode
        // (4.5:1) but sat at the edge of it, and at 9.3pt the size made
        // it feel worse than the number says. `palette.foreground` lifts the
        // unselected label and icon to the primary text colour, which keeps
        // the selection channel — accent vs primary text — without burying
        // it under a near-contrast label.
        unselectedColor: palette.foreground,
        // Disabled stays dimmed — SC 1.4.3 exempts inactive controls from
        // the contrast floor and a disabled destination that screams is a
        // destination the user already knows about.
        disabledColor: palette.mutedForeground.withValues(alpha: 0.38),
        labelStyle: label?.copyWith(
          fontWeight: context.design.type.labelWeight,
        ),
        selectedLabelStyle: label?.copyWith(
          fontWeight: context.design.type.emphasisWeight,
          color: palette.primary,
        ),
        showLabels: true,
        glyphLabelGap: design.space.xs,
        badgeOffset: Offset(design.space.md - design.space.hairline, -4),
        floating: true,
        margin: EdgeInsets.fromLTRB(
          design.space.lg,
          0,
          design.space.lg,
          design.space.sm,
        ),
      ),
      own: own,
    );
  }

  /// 64 plus the safe area, against Material's 80: the extra 16 is height a
  /// phone spends on chrome rather than on content, every screen, forever.
  static const double _barHeight = 64;
}

/// One top-level destination of [DSBottomNavBar].
///
/// The model is open where a destination needs to be — an avatar, a live
/// ring, a brand mark — and closed where the bar has to understand it. The
/// bar needs the label, the badge and the enabled state to build equal
/// columns and a mutually exclusive semantics group, which is why the
/// destinations are values rather than opaque widgets.
@immutable
class DSBottomNavItem {
  const DSBottomNavItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount,
    this.badgeDot = false,
    this.enabled = true,
    this.iconSlot,
    this.badgeSlot,
    this.semanticLabel,
  }) : assert(
         !(badgeDot && badgeCount != null),
         'A destination carries one badge. `badgeDot` says "something '
         'happened" and `badgeCount` says how much; setting both asks the '
         'bar to draw two answers to one question.',
       );

  /// Shown under the glyph, and announced. One or two words — a label that
  /// wraps at the default text size is a label for a different control.
  final String label;

  /// The unselected, outline form.
  final IconData icon;

  /// The selected, filled form.
  ///
  /// Strongly recommended and not defaulted for you: a filled twin cannot be
  /// derived from an [IconData]. Without it selection still carries the
  /// indicator and the label weight, but it loses the channel that survives
  /// being seen out of the corner of an eye.
  final IconData? selectedIcon;

  /// `null` means no badge. Replaces the `badgeCount` + `showBadge` pair, in
  /// which `showBadge: true` with a null count compiled and meant nothing.
  final int? badgeCount;

  /// A badge with no count. Available, and the `use` rule asks for a reason:
  /// a dot says only "something", which NN/g finds worse than no badge when
  /// a count is knowable.
  final bool badgeDot;

  /// A destination that exists but cannot be entered. Rare — a destination
  /// that is never available should not be a destination.
  final bool enabled;

  /// Replaces the glyph: an avatar, a progress ring, a live indicator. It is
  /// given the destination's colour and size through an [IconTheme], so a
  /// plain [Icon] inside still tints with selection.
  final Widget? iconSlot;

  /// Replaces the badge the count or the dot would have drawn.
  final Widget? badgeSlot;

  /// What assistive technology should hear in addition to [label] — a
  /// profile destination whose visible word is "You" and whose name is the
  /// signed-in person.
  final String? semanticLabel;

  /// Whether this destination draws a badge at all.
  bool get hasBadge => badgeSlot != null || badgeDot || badgeCount != null;
}

/// The app's bottom navigation: three to five top-level destinations, always
/// visible, above the content.
///
/// See `docs/plans/15-ds-bottom-nav-bar.plan.md`. Deliberately a thin wrapper
/// on Material 3's [NavigationBar] rather than a re-implementation: the
/// equal columns, the indicator, the text scaling, the mutually exclusive
/// semantics group and the platform accessibility behaviour are all
/// Flutter's, and a hand-rolled bar loses every one of them silently. What
/// this adds is the destination model, the badge, the chrome material, the
/// floating geometry, and the rule about how many destinations a bar may
/// have.
///
/// The bar is the clearest case of the chrome rule: it sits above content
/// that scrolls under it, so on Apple it is glass and elsewhere the same tint
/// painted opaque. [NavigationBar] paints nothing here — [AppChromeSurface]
/// is the surface, which is why the background is transparent rather than a
/// colour.
///
/// **It floats by default.** A pill inset from three edges, with the safe
/// area under it rather than inside it. That is what makes the chrome rule
/// visible: an edge-to-edge bar blurs the strip of content it happens to
/// cover, while a floating one has content passing on every side of it. The
/// host [Scaffold] wants `extendBody: true` so the content actually runs
/// underneath — without it the bar floats over a band of empty page, which
/// is the one arrangement that looks worse than not floating at all. See
/// [DSBottomNavBarStyle.floating] for when to switch it off.
///
/// **Use when** there are 3–5 top-level destinations, each with its own
/// navigation stack. **Instead:** six or more, or a tablet width, is a
/// `DSSidebar`; peer views inside one destination are a `DSTabBar`; two
/// choices are a `DSSegmentedButton`. A bottom bar and a drawer are
/// alternatives, not layers.
class DSBottomNavBar extends StatelessWidget {
  const DSBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.style,
    this.leading,
    this.trailing,
    this.surface,
    this.badgeFormatter,
  }) : assert(
         items.length >= 3 && items.length <= 5,
         'A bottom bar takes 3 to 5 destinations. Two is a DSSegmentedButton '
         'or a DSTabBar; six or more is a DSSidebar. Neither is a smaller or '
         'larger version of this control — a two-column bar wastes the width '
         'a phone has, and a six-column bar puts 60dp targets under a thumb.',
       );

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Asserted to be 3..5. See the constructor's message.
  final List<DSBottomNavItem> items;

  final DSBottomNavBarStyle? style;

  /// Before the first destination. Rare, and the `use` rule is a brand mark
  /// on a tablet-width bar — not a sixth destination in disguise, which is
  /// what the count assertion exists to prevent.
  final Widget? leading;

  /// After the last destination. Same rule as [leading].
  final Widget? trailing;

  /// Replaces [AppChromeSurface] behind the bar. The hatch for a brand that
  /// needs a gradient or an image there, without giving up the destinations,
  /// the safe area or the semantics.
  final Widget? surface;

  /// How a large count is written — "9+" past a threshold, and localised. A
  /// bar that hardcodes '99+' cannot be translated, and where the threshold
  /// sits is a brand decision.
  final String Function(int)? badgeFormatter;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final resolved = DSBottomNavBarStyle.resolve(context, style);
    final format = badgeFormatter ?? _capAt99;

    // At two lines of label the bar has to grow, or the labels clip. Past
    // 1.8× they are dropped entirely and the long-press tooltip carries them:
    // three lines of 22pt text under a 24dp glyph is a bar taller than the
    // content it navigates.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final labelled = resolved.showLabels! && scale <= _labelDropScale;
    final baseHeight = resolved.height! * (labelled ? math.max(1, scale) : 1);

    // The Cupertino branch's column is `MainAxisSize.max` so the column
    // *is* the bar's height and the destination is the tap target. A bar
    // shorter than glyph + gap + label overflows by 2dp at the bottom
    // because the children don't shrink. The label height scales with
    // [scale], so the floor scales with it; glyphSize and glyphLabelGap
    // don't. Past 1.8× the labels are dropped and the floor collapses to
    // the icon plus the kit's tap-target minimum, which catches the
    // unlabelled case at small heights too.
    final naturalContent = labelled
        ? resolved.glyphSize! +
              resolved.glyphLabelGap! +
              _labelNaturalHeight * scale
        : resolved.glyphSize!;
    final height = math.max(
      baseHeight,
      math.max(naturalContent, design.component.minTapTarget),
    );

    final bar = context.isApplePlatform
        ? _cupertinoBar(
            context,
            resolved,
            format,
            height: height,
            labelled: labelled,
          )
        : _materialBar(
            context,
            resolved,
            format,
            height: height,
            labelled: labelled,
          );

    // Plan 38 §6: shrink the label font size so every destination label
    // fits its column without ellipsizing. `LayoutBuilder` reads the
    // outer constraint — the bar's allocated width inside its parent's
    // padding chrome — and divides by `items.length`. The column width
    // is the bar-wide pick the Material branch needs (`labelTextStyle`
    // resolves uniformly); the Cupertino branch gets the same pick and
    // the per-destination `Text` widgets apply it.
    //
    // The shrink runs only when labels are drawn. Past 1.8× text scale
    // [labelled] is false and the label widget is gone — there is
    // nothing to size.
    final Widget content =
        labelled && resolved.labelStyle != null && items.isNotEmpty
        ? LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = constraints.maxWidth / items.length;
              final fontSize = _pickLabelFontSize(
                items: items,
                columnWidth: columnWidth,
                baseStyle: resolved.labelStyle!,
                textScale: scale,
              );
              final shrunken = resolved.copyWith(
                labelStyle: resolved.labelStyle!.copyWith(fontSize: fontSize),
                selectedLabelStyle: resolved.selectedLabelStyle?.copyWith(
                  fontSize: fontSize,
                ),
              );
              final shrunkenBar = context.isApplePlatform
                  ? _cupertinoBar(
                      context,
                      shrunken,
                      format,
                      height: height,
                      labelled: labelled,
                    )
                  : _materialBar(
                      context,
                      shrunken,
                      format,
                      height: height,
                      labelled: labelled,
                    );
              return leading == null && trailing == null
                  ? shrunkenBar
                  : Row(
                      children: [
                        if (leading != null) leading!,
                        Expanded(child: shrunkenBar),
                        if (trailing != null) trailing!,
                      ],
                    );
            },
          )
        : (leading == null && trailing == null
              ? bar
              : Row(
                  children: [
                    if (leading != null) leading!,
                    Expanded(child: bar),
                    if (trailing != null) trailing!,
                  ],
                ));

    final floating = resolved.floating!;

    // A floating bar consumes no safe area of its own: the inset becomes the
    // gap *under* the bar rather than dead space inside it. Without this the
    // pill is 34dp taller than it looks on a device with a home indicator,
    // and the indicator sits inside the glass.
    final Widget inner = floating
        ? MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            // The indicator is a 64dp pill that Material centres in its
            // column, and the outer columns' pills would otherwise run out
            // through the stadium's round ends. This is the inset that keeps
            // the selected destination inside the surface it belongs to.
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: design.space.md),
              child: content,
            ),
          )
        : content;

    final Widget surfaced = surface != null
        ? Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: surface!),
              inner,
            ],
          )
        : AppChromeSurface(
            shape: floating ? AppShape.pill : AppShape.bar,
            child: inner,
          );

    // The bar reports its own height into `DSBottomInsets`, so a snack bar
    // arrives above it and a scroll view can reserve room for it. Measured
    // rather than declared: a floating pill and an edge-to-edge bar are not
    // the same height, and neither is one at text scale 2.
    if (!floating) {
      return DSBottomSlotReporter(slot: DSBottomSlot.navBar, child: surfaced);
    }

    // `viewPadding`, not `padding`: the latter is zeroed while the keyboard
    // is up, which would drop the bar onto the home indicator at exactly the
    // moment a search field pushed it up the screen.
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final margin = resolved.margin!;

    // The safe area is a floor, not a stack. Adding the margin *on top of*
    // the 34pt inset an iPhone reports parks the bar a third of the way up
    // the screen's bottom edge and makes it read as sliding away rather than
    // as resting there. The inset is sized for full-width content that must
    // not be swiped away; a pill sits into the last of it, clearing the home
    // indicator's own stroke by `xs` and no more.
    //
    // The back-off is also *capped*. `inset − xs` tracks the safe area all
    // the way up, so a 34dp iPhone inset parked the pill 30dp off the edge —
    // visibly adrift, and the gap the user reported. The home indicator's
    // stroke tops out about 13dp from the edge, so `lg` (16dp) clears it
    // with 3dp to spare and reads as resting on the edge rather than
    // floating away from it. Below the cap the old formula still applies,
    // so a small inset never pushes the pill *down* into the indicator.
    final bottom = math.max(
      margin.bottom,
      math.min(inset - design.space.xs, design.space.lg),
    );

    return DSBottomSlotReporter(
      slot: DSBottomSlot.navBar,
      child: Padding(
        padding: margin.copyWith(bottom: bottom),
        child: surfaced,
      ),
    );
  }

  /// Material 3's own bar: equal columns, a stadium indicator behind the
  /// selected glyph, and the label weight as the third selection channel.
  Widget _materialBar(
    BuildContext context,
    DSBottomNavBarStyle resolved,
    String Function(int) format, {
    required double height,
    required bool labelled,
  }) {
    final motion = context.design.motion;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: height,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // The gradient is not a Color, so Material's own indicator (which
        // only paints a flat fill) is turned off and [_glyph] paints the
        // pill itself for the selected destination.
        indicatorColor: resolved.indicatorGradient != null
            ? Colors.transparent
            : resolved.indicatorColor,
        indicatorShape: resolved.indicatorShape,
        labelPadding: EdgeInsets.only(top: resolved.glyphLabelGap!),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: resolved.glyphSize,
            color: _stateColor(resolved, states),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = states.contains(WidgetState.selected)
              ? resolved.selectedLabelStyle
              : resolved.labelStyle;
          return base?.copyWith(color: _stateColor(resolved, states));
        }),
        labelBehavior: labelled
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.alwaysHide,
      ),
      child: NavigationBar(
        // The indicator's slide between destinations. Material's own default
        // is a flat 500ms, which on a bar this size reads as the pill lagging
        // the finger; the spec's `normal` is the same duration every other
        // selection in the kit takes, and it scales with the motion knob.
        animationDuration: motion.scaled(motion.normal),
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // Nothing changed, so nothing is announced by the hand either. A
          // bar that buzzes when the user taps where they already are is a
          // bar that taught them the buzz means nothing.
          if (index != currentIndex) AppHaptics.selection();
          onTap(index);
        },
        destinations: [
          for (final item in items)
            NavigationDestination(
              label: item.label,
              enabled: item.enabled,
              icon: _glyph(context, resolved, item, format, selected: false),
              selectedIcon: _glyph(
                context,
                resolved,
                item,
                format,
                selected: true,
                paintIndicator: true,
              ),
            ),
        ],
      ),
    );
  }

  /// Apple's own bar: a glyph over its label, tinted when selected, and no
  /// indicator at all.
  ///
  /// The pill is Material's way of saying "you are here", and on iOS it is a
  /// costume — the platform has never drawn one, and a floating capsule with
  /// a second capsule sliding around inside it is the most obviously
  /// non-native thing this kit shipped.
  ///
  /// Built here rather than with [CupertinoTabBar], which was the first
  /// attempt: that widget paints its own background and, whenever the colour
  /// it is given is not opaque, wraps itself in a second `BackdropFilter`.
  /// Inside this kit's glass that is two blurs on one bar — and it survived
  /// the "high contrast makes the chrome opaque" test only in the sense that
  /// the test caught it. The layout it was carrying is a row of equal
  /// columns, which is four lines.
  Widget _cupertinoBar(
    BuildContext context,
    DSBottomNavBarStyle resolved,
    String Function(int) format, {
    required double height,
    required bool labelled,
  }) => SizedBox(
    height: height,
    child: Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: _cupertinoDestination(
              i,
              context,
              resolved,
              format,
              labelled,
            ),
          ),
      ],
    ),
  );

  /// One column of the Cupertino branch. Extracted so the [for]-loop index
  /// `i` is captured by value into each destination's closures — the same
  /// rule every other for-loop closure in the kit follows — and so the
  /// per-column work has one home rather than being inlined into the
  /// [_cupertinoBar] builder.
  Widget _cupertinoDestination(
    int i,
    BuildContext context,
    DSBottomNavBarStyle resolved,
    String Function(int) format,
    bool labelled,
  ) {
    final item = items[i];
    return _AppleDestination(
      item: item,
      selected: i == currentIndex,
      labelled: labelled,
      resolved: resolved,
      glyph: (selected) =>
          _glyph(context, resolved, item, format, selected: selected),
      onTap: () {
        // Disabled destinations still receive the tap (the gesture arena
        // does not know `enabled`); the bar is responsible for swallowing
        // it. A button that fires a tab switch for a destination it draws
        // grey is a kit that taught the user the grey means nothing.
        if (!item.enabled) return;
        if (i != currentIndex) AppHaptics.selection();
        onTap(i);
      },
    );
  }

  /// The glyph, its badge, and the part of the destination's name that the
  /// visible label does not carry.
  ///
  /// **On the name.** [NavigationDestination.label] is a `String` that is both
  /// drawn and announced, and Material merges the whole destination into one
  /// semantics node in tree order. A wrapper cannot silence the drawn label,
  /// so the count and [DSBottomNavItem.semanticLabel] are contributed here,
  /// from the glyph, and are announced *before* it: "3 new, Library, tab 2 of
  /// 4". One node, not two — a badge is not separately actionable, and it is
  /// never the thing a screen-reader user tabs to.
  Widget _glyph(
    BuildContext context,
    DSBottomNavBarStyle resolved,
    DSBottomNavItem item,
    String Function(int) format, {
    required bool selected,
    bool paintIndicator = false,
  }) {
    final icon = item.iconSlot != null
        ? item.iconSlot!
        : Icon(selected ? (item.selectedIcon ?? item.icon) : item.icon);

    Widget glyph = icon;
    // The gradient pill: Material's built-in indicator only paints a flat
    // colour, so when the spec carries a gradient this paints the pill
    // itself, behind the selected glyph, instead.
    if (paintIndicator && selected && resolved.indicatorGradient != null) {
      final space = context.design.space;
      glyph = Container(
        padding: EdgeInsets.symmetric(horizontal: space.md, vertical: space.xs),
        decoration: ShapeDecoration(
          gradient: resolved.indicatorGradient,
          shape: resolved.indicatorShape ?? const StadiumBorder(),
        ),
        // The glyph reads against the gradient, not against the bar
        // behind it, so it takes the on-primary colour locally rather
        // than through `resolved.selectedColor` — which stays
        // `palette.primary` for the Cupertino branch, where there is no
        // pill to put it on.
        child: IconTheme.merge(
          data: IconThemeData(color: context.palette.primaryForeground),
          child: glyph,
        ),
      );
    }
    if (item.hasBadge) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          // The offset reads from the glyph's top-trailing corner: x is how
          // far outside the glyph the badge hangs, y is how far down.
          PositionedDirectional(
            top: resolved.badgeOffset!.dy,
            end: -resolved.badgeOffset!.dx,
            // The count does not scale with the rest of the text, and this
            // is the one place in the kit where that is the right answer.
            // The pill is a fixed 14dp tall so that it stays a mark on a
            // 24dp glyph rather than a second control; scaled up, the digit
            // outgrows the pill and is clipped by it — which the textScale
            // 2.0 golden showed before this line existed. The count is not
            // lost to a low-vision user: it is in the destination's name
            // ("Library, 3 new"), which a screen reader reads and which
            // scales with everything else.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: _badgeMaxTextScale,
              child: _NavBadge(
                child:
                    item.badgeSlot ??
                    (item.badgeDot
                        ? const _NavBadgeDot()
                        : DSIconButtonBadge(
                            count: item.badgeCount!,
                            formatter: format,
                          )),
              ),
            ),
          ),
        ],
      );
    }

    final extra = _extraName(item, format);
    if (extra != null) {
      glyph = Semantics(label: extra, excludeSemantics: true, child: glyph);
    }
    return glyph;
  }

  /// What the visible label leaves out: the caller's own name for the
  /// destination, and the badge, in that order.
  String? _extraName(DSBottomNavItem item, String Function(int) format) {
    final parts = <String>[
      if (item.semanticLabel != null) item.semanticLabel!,
      if (item.badgeCount != null && item.badgeCount != 0)
        '${format(item.badgeCount!)} new',
      if (item.badgeDot) 'new activity',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  static Color? _stateColor(
    DSBottomNavBarStyle resolved,
    Set<WidgetState> states,
  ) {
    if (states.contains(WidgetState.disabled)) return resolved.disabledColor;
    if (states.contains(WidgetState.selected)) return resolved.selectedColor;
    return resolved.unselectedColor;
  }

  static String _capAt99(int count) => count > 99 ? '99+' : '$count';

  /// Plan 38 §6: the three label font sizes the shrink picks from.
  /// Starts at the spec's `labelSmall` (~9.3pt at the default scale) and
  /// steps down in 1pt increments. 7pt is the floor: smaller and the
  /// digits stop being recognisable at a glance, and the bulletin is the
  /// ellipsis the next line down.
  static const List<double> _labelShrinkSteps = [9.3, 8.0, 7.0];

  /// The largest [_labelShrinkSteps] entry at which every label in
  /// [items] fits in [columnWidth] when measured with the given
  /// [baseStyle]. Returns the floor (7pt) if no step fits.
  ///
  /// `TextPainter` measures in logical pixels (`TextScaler.noScaling`),
  /// so the result is comparable to a `LayoutBuilder`'s constraint
  /// directly. The textScale factor is read from the parent
  /// `MediaQuery` and multiplied into the baseStyle's fontSize for the
  /// measurement — a 1.3× accessibility setting sees the same step
  /// sizes grow by 1.3×, which is what the user asked for.
  static double _pickLabelFontSize({
    required List<DSBottomNavItem> items,
    required double columnWidth,
    required TextStyle baseStyle,
    required double textScale,
  }) {
    for (final size in _labelShrinkSteps) {
      final style = baseStyle.copyWith(fontSize: size * textScale);
      var allFit = true;
      for (final item in items) {
        final tp = TextPainter(
          text: TextSpan(text: item.label, style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        if (tp.width > columnWidth) {
          allFit = false;
          tp.dispose();
          break;
        }
        tp.dispose();
      }
      if (allFit) return size;
    }
    return _labelShrinkSteps.last;
  }

  /// Past this, the labels are dropped and the tooltip carries them.
  static const double _labelDropScale = 1.8;

  /// How far the badge's own text is allowed to scale. See [_glyph].
  static const double _badgeMaxTextScale = 1;

  /// labelSmall at fontSize 11 with the spec's bodyHeight (1.45) renders
  /// ~16dp nominally, but the platform font's ascent and descent push the
  /// measured height to 18dp on Roboto and San Francisco. The Cupertino
  /// column's overflow floor uses the measured value, not the nominal one,
  /// because the overflow is measured in pixels, not in multiplier.
  static const double _labelNaturalHeight = 18;
}

/// One destination of the Apple bar: glyph over label, three colours, one
/// semantics node.
///
/// A widget rather than a method so the whole column is the tap target and so
/// the node the screen reader lands on is the column — `MergeSemantics` folds
/// the badge's contribution and the label into one announcement, in the order
/// they are drawn, which is what the Material branch gets from
/// `NavigationDestination`.
class _AppleDestination extends StatelessWidget {
  const _AppleDestination({
    required this.item,
    required this.selected,
    required this.labelled,
    required this.resolved,
    required this.glyph,
    required this.onTap,
  });

  final DSBottomNavItem item;
  final bool selected;
  final bool labelled;
  final DSBottomNavBarStyle resolved;
  final Widget Function(bool selected) glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final states = <WidgetState>{
      if (selected) WidgetState.selected,
      if (!item.enabled) WidgetState.disabled,
    };
    final color = DSBottomNavBar._stateColor(resolved, states);
    final labelStyle =
        (selected ? resolved.selectedLabelStyle : resolved.labelStyle)
            ?.copyWith(color: color);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: item.enabled,
      child: MergeSemantics(
        child: DSPressable(
          enabled: item.enabled,
          // The whole column, ringed as the destination it is. A tab that
          // dips is not an Apple detail, but a tab a keyboard cannot reach
          // is not one either, and the ring is what `DSPressable` is the
          // floor for.
          focusShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              context.radiusOf(AppShape.control),
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            // The cell is already `Expanded`; this is what makes the
            // destination *use* it. Vertically `max` does the same job —
            // together they mean the target is the cell rather than whatever
            // the glyph and its label happen to measure. Height alone was
            // enough while labels were 16pt wide enough to clear 48 on their
            // own; at 12.8 the column measured 41 across and the probe said
            // so, which is the same lesson twice: a target that is a function
            // of its label is not a floor.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: resolved.glyphSize, color: color),
                    child: glyph(selected),
                  ),
                  if (labelled) ...[
                    SizedBox(height: resolved.glyphLabelGap),
                    Text(
                      item.label,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scale-in a badge arrives with.
///
/// The one place in the kit that uses the spec's `bouncy` spring: a badge
/// appearing is the single event that is allowed to draw the eye, and if two
/// things on a screen bounce then neither of them is special.
class _NavBadge extends StatefulWidget {
  const _NavBadge({required this.child});

  final Widget child;

  @override
  State<_NavBadge> createState() => _NavBadgeState();
}

class _NavBadgeState extends State<_NavBadge>
    with SingleTickerProviderStateMixin {
  // No duration on the controller: the spring path has none, and the curve
  // path takes the motion spec's, which needs a context this cannot reach
  // from a field initialiser.
  late final AnimationController _in = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isDismissed) _arrive();
  }

  void _arrive() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
    } else if (context.springsAvailable) {
      final motion = context.design.motion;
      _in.animateWith(motion.simulation(spring: motion.bouncy));
    } else {
      final motion = context.design.motion;
      _in.animateTo(
        1,
        duration: motion.scaled(motion.fast),
        curve: motion.enter,
      );
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _in, child: widget.child);
}

/// A badge with no count: "something happened", and nothing more.
class _NavBadgeDot extends StatelessWidget {
  const _NavBadgeDot();

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: space.sm,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: context.palette.destructive,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}
