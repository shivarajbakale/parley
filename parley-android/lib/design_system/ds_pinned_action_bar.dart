// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a pinned action bar arranges what it carries.
enum DSActionBarLayout {
  /// Side by side, each button taking an equal share.
  row,

  /// One under the other, the first one on top. What a phone at text scale
  /// 2.0 needs, and what two long labels need at any scale.
  stack,

  /// Side by side, the last button taking the room the others leave. Cancel
  /// beside Publish.
  spread,

  /// A leading summary — a price, a count — with one action beside it.
  leadingAndAction,
}

/// How a pinned action bar looks, at every layer of the chain.
@immutable
class DSActionBarStyle extends DSComponentStyle<DSActionBarStyle> {
  const DSActionBarStyle({
    this.padding,
    this.gap,
    this.fill,
    this.showHairline,
    this.hairlineColor,
    this.layout,
    this.buttonSize,
  });

  final EdgeInsetsGeometry? padding;
  final double? gap;

  /// Null keeps the chrome material, which is what a bar floating over
  /// content wants. A colour here opts out of it.
  final Color? fill;

  final bool? showHairline;
  final Color? hairlineColor;
  final DSActionBarLayout? layout;
  final DSSize? buttonSize;

  @override
  DSActionBarStyle merge(DSActionBarStyle? other) {
    if (other == null) return this;
    return DSActionBarStyle(
      padding: other.padding ?? padding,
      gap: other.gap ?? gap,
      fill: other.fill ?? fill,
      showHairline: other.showHairline ?? showHairline,
      hairlineColor: other.hairlineColor ?? hairlineColor,
      layout: other.layout ?? layout,
      buttonSize: other.buttonSize ?? buttonSize,
    );
  }

  @override
  DSActionBarStyle copyWith({
    EdgeInsetsGeometry? padding,
    double? gap,
    Color? fill,
    bool? showHairline,
    Color? hairlineColor,
    DSActionBarLayout? layout,
    DSSize? buttonSize,
  }) => DSActionBarStyle(
    padding: padding ?? this.padding,
    gap: gap ?? this.gap,
    fill: fill ?? this.fill,
    showHairline: showHairline ?? this.showHairline,
    hairlineColor: hairlineColor ?? this.hairlineColor,
    layout: layout ?? this.layout,
    buttonSize: buttonSize ?? this.buttonSize,
  );

  @override
  DSActionBarStyle lerp(DSActionBarStyle? other, double t) {
    if (other == null) return this;
    return DSActionBarStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      gap: lerpDouble(gap, other.gap, t),
      fill: Color.lerp(fill, other.fill, t),
      showHairline: t < 0.5 ? showHairline : other.showHairline,
      hairlineColor: Color.lerp(hairlineColor, other.hairlineColor, t),
      layout: t < 0.5 ? layout : other.layout,
      buttonSize: t < 0.5 ? buttonSize : other.buttonSize,
    );
  }

  static DSActionBarStyle resolve(
    BuildContext context, {
    DSActionBarStyle? own,
  }) {
    final design = context.design;
    final palette = context.palette;
    return resolveStyle(
      context: context,
      specDefaults: DSActionBarStyle(
        padding: EdgeInsets.symmetric(
          horizontal: design.space.pageGutter,
          vertical: design.space.md,
        ),
        gap: design.space.sm,
        showHairline: true,
        hairlineColor: palette.borderSoft,
        layout: DSActionBarLayout.row,
        buttonSize: DSSize.md,
      ),
      own: own,
    );
  }
}

/// The primary action, pinned to the bottom edge over the content.
///
/// Four archetypes need this and none could have it before
/// (`docs/principles/screen-archetypes.md`): Detail keeps its primary action
/// reachable while the reader scrolls, Form puts the submit button in the
/// thumb's reach instead of at the end of a scroll the user has to find,
/// Sequence pins Next so it never shares the bottom edge with a keyboard, and
/// Offer keeps the purchase button — and the renewal line in the same bar —
/// off the end of a scroll nobody reaches.
///
/// It is chrome, not content — it floats above the page and the page moves
/// under it — so it takes [AppChromeSurface] and is glass on Apple, a tonal
/// container on Android. That is also why this widget exists rather than each
/// screen assembling its own: `glass-off-chrome` in `tool/ui_lint.dart` refuses
/// the material outside the chrome layer, and the screens are not on that list.
///
/// The safe-area inset is handled here and only here. A bar that pads for the
/// home indicator *and* sits inside a screen that already did reads as a bar
/// with a mysterious gap under it, which is the usual result of both halves
/// being careful.
///
/// It takes `List<Widget>` rather than one `child`
/// (`docs/plans/30-ds-snackbar-fab-action-bar.plan.md`): with a single child
/// the layout, the button sizing and the gap were the caller's problem, and
/// every screen solved them differently. It reports its own height into
/// [DSBottomInsets], so the snack bar arrives above it and the screen's scroll
/// view can reserve room for it.
class DSPinnedActionBar extends StatelessWidget {
  const DSPinnedActionBar({
    super.key,
    required this.children,
    this.leading,
    this.helper,
    this.helperText,
    this.layout,
    this.loading = false,
    this.enabled = true,
    this.style,
  });

  /// The buttons. One is the common case; two is Cancel and the action.
  final List<Widget> children;

  /// A price, a count, a summary on the leading edge.
  final Widget? leading;

  /// A line above the buttons — "You can edit this later".
  final Widget? helper;
  final String? helperText;

  final DSActionBarLayout? layout;

  /// Disables every button and lets the primary one show its own spinner —
  /// the pattern a pending dialog uses, for the same reason.
  final bool loading;

  final bool enabled;

  final DSActionBarStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSActionBarStyle.resolve(context, own: style);
    final arrangement = layout ?? resolved.layout!;
    final gap = resolved.gap!;

    final helperLine =
        helper ??
        (helperText == null
            ? null
            : Text(helperText!, style: DSTextRole.bodyDetail.styleOf(context)));

    Widget row;
    switch (arrangement) {
      case DSActionBarLayout.row:
        row = Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: children[i]),
            ],
          ],
        );
      case DSActionBarLayout.stack:
        row = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      case DSActionBarLayout.spread:
        row = Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              if (i == children.length - 1)
                Expanded(child: children[i])
              else
                children[i],
            ],
          ],
        );
      case DSActionBarLayout.leadingAndAction:
        row = Row(
          children: [
            if (leading != null) Flexible(child: leading!),
            SizedBox(width: gap),
            for (final child in children) Expanded(child: child),
          ],
        );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (arrangement != DSActionBarLayout.leadingAndAction &&
            leading != null) ...[
          leading!,
          SizedBox(height: gap),
        ],
        if (helperLine != null) ...[helperLine, SizedBox(height: gap)],
        row,
      ],
    );

    return DSBottomSlotReporter(
      slot: DSBottomSlot.actionBar,
      child: AppChromeSurface(
        shape: AppShape.bar,
        // A fill named at any layer opts the bar out of the chrome material;
        // null keeps the glass, which is what a bar over content wants.
        material: resolved.fill == null
            ? null
            : AppMaterials.accent(context, resolved.fill!),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: resolved.showHairline!
                ? Border(
                    top: BorderSide(
                      color: resolved.hairlineColor!,
                      width: context.design.component.hairlineWidth,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: resolved.padding!,
              // The buttons are one group at one size, and every one of them
              // is disabled together: a bar with a live Cancel beside a dead
              // Publish is a bar the user has to read twice.
              child: DSScope(
                size: resolved.buttonSize!,
                enabled: enabled && !loading,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
