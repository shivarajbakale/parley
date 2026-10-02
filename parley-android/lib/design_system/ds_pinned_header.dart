// ds-tier: 1 — atom

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_ground.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a pinned header looks, at every layer of the chain.
@immutable
class DSPinnedHeaderStyle extends DSComponentStyle<DSPinnedHeaderStyle> {
  const DSPinnedHeaderStyle({this.fill, this.showHairline, this.hairlineColor});

  /// The band's ground. It has one whatever the caller says, because the band
  /// is pinned: the page scrolls *under* it, and a translucent band shows a
  /// headline sliding through the control the reader is aiming at.
  final Color? fill;

  /// A hairline along the bottom edge. Off by default: the band already
  /// separates itself from the list by sitting on the page ground while the
  /// rows move, and a second line under a search field that already has an
  /// outline is one border too many.
  final bool? showHairline;

  final Color? hairlineColor;

  @override
  DSPinnedHeaderStyle merge(DSPinnedHeaderStyle? other) {
    if (other == null) return this;
    return DSPinnedHeaderStyle(
      fill: other.fill ?? fill,
      showHairline: other.showHairline ?? showHairline,
      hairlineColor: other.hairlineColor ?? hairlineColor,
    );
  }

  @override
  DSPinnedHeaderStyle copyWith({
    Color? fill,
    bool? showHairline,
    Color? hairlineColor,
  }) => DSPinnedHeaderStyle(
    fill: fill ?? this.fill,
    showHairline: showHairline ?? this.showHairline,
    hairlineColor: hairlineColor ?? this.hairlineColor,
  );

  @override
  DSPinnedHeaderStyle lerp(DSPinnedHeaderStyle? other, double t) {
    if (other == null) return this;
    return DSPinnedHeaderStyle(
      fill: Color.lerp(fill, other.fill, t),
      showHairline: t < 0.5 ? showHairline : other.showHairline,
      hairlineColor: Color.lerp(hairlineColor, other.hairlineColor, t),
    );
  }

  static DSPinnedHeaderStyle resolve(
    BuildContext context, {
    DSPinnedHeaderStyle? own,
  }) {
    final palette = context.palette;
    return resolveStyle(
      context: context,
      specDefaults: DSPinnedHeaderStyle(
        // The page ground, which is what `colorScheme.surface` resolves to
        // here — the band is part of the page's chrome, not a card raised off
        // it, so it is the same ground the rows scroll over.
        fill: palette.background,
        showHairline: false,
        hairlineColor: palette.borderSoft,
      ),
      own: own,
    );
  }
}

/// The controls that filter a list, pinned to the top edge under the header.
///
/// The top-edge twin of [DSPinnedActionBar], and it exists for the same
/// reason: a control the reader needs *while* they read cannot be a control
/// that scrolls away. A search field and a filter strip that leave the screen
/// take the answer to "what am I looking at" with them, and the way back is a
/// fling to the top of the list — on a long list, the one place the reader is
/// not.
///
/// Three screens had hand-rolled this before it was a component — a
/// `PinnedHeaderSliver` wrapped in a `ColoredBox` of `colorScheme.surface`,
/// with the same comment retyped each time explaining why the band is opaque.
/// The opacity is not a screen's decision to make: the rows scroll behind
/// every one of them.
///
/// It is a **sliver**, and it takes its height from its child rather than
/// being told one. That is the whole reason it is not a
/// `SliverPersistentHeader`: a band holding chips or a field has a height that
/// moves with the reader's text size, and a number handed to it is a number
/// that is wrong at 1.3×. Stack as many as the screen needs — each honours the
/// overlap of the pinned slivers before it, so a field pins under the app bar
/// and a chip strip pins under the field.
///
/// The gutter is the child's, not this widget's. The bands that need one are
/// not the bands that hold a horizontally scrolling strip, which runs to the
/// screen edge and insets its own contents instead.
///
/// **Use when** a filter, a search field or a tab bar has to stay on screen
/// while the list under it scrolls. **Instead:** `DSPageHeader.sliver`'s
/// `below` slot when the control belongs to the title block and should
/// collapse with it, `DSPinnedActionBar` for an action at the bottom edge, and
/// a plain `SliverToBoxAdapter` for a band that is content and may leave.
class DSPinnedHeader extends StatelessWidget {
  const DSPinnedHeader({super.key, required this.child, this.style});

  /// The band's contents — a search field, a chip strip, a tab bar.
  final Widget child;

  final DSPinnedHeaderStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPinnedHeaderStyle.resolve(context, own: style);
    // On a washed page the band paints the slice of the wash behind it rather
    // than a flat fill: still opaque, so rows scrolling under it stay hidden,
    // but with no edge where it meets the page. An explicit fill wins.
    final Widget banded = DecoratedBox(
      decoration: BoxDecoration(
        border: resolved.showHairline!
            ? Border(
                bottom: BorderSide(
                  color: resolved.hairlineColor!,
                  width: context.design.component.hairlineWidth,
                ),
              )
            : null,
      ),
      child: child,
    );

    return PinnedHeaderSliver(
      child: style?.fill != null
          ? DecoratedBox(
              decoration: BoxDecoration(color: resolved.fill),
              child: banded,
            )
          : DSGroundSlice(fallback: resolved.fill!, child: banded),
    );
  }
}
