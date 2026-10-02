// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a disclosure looks, at every layer of the resolution chain.
@immutable
class DSExpansionStyle extends DSComponentStyle<DSExpansionStyle> {
  const DSExpansionStyle({
    this.headerPadding,
    this.bodyPadding,
    this.titleStyle,
    this.subtitleStyle,
    this.iconColor,
    this.iconSize,
    this.gap,
    this.minHeaderHeight,
    this.showDivider,
  });

  final EdgeInsetsGeometry? headerPadding;
  final EdgeInsetsGeometry? bodyPadding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color? iconColor;
  final double? iconSize;

  /// Between the header's words and its chevron.
  final double? gap;

  /// The tap target floor. A header is a control, and a control shorter than
  /// this is one a thumb misses (`docs/principles/accessibility.md`).
  final double? minHeaderHeight;

  /// The rule under the header. On by default: a body with no line above it
  /// and no line below it floats, and two open panels in a column read as one
  /// long block.
  final bool? showDivider;

  @override
  DSExpansionStyle merge(DSExpansionStyle? other) {
    if (other == null) return this;
    return DSExpansionStyle(
      headerPadding: other.headerPadding ?? headerPadding,
      bodyPadding: other.bodyPadding ?? bodyPadding,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      iconColor: other.iconColor ?? iconColor,
      iconSize: other.iconSize ?? iconSize,
      gap: other.gap ?? gap,
      minHeaderHeight: other.minHeaderHeight ?? minHeaderHeight,
      showDivider: other.showDivider ?? showDivider,
    );
  }

  @override
  DSExpansionStyle copyWith({
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? bodyPadding,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    Color? iconColor,
    double? iconSize,
    double? gap,
    double? minHeaderHeight,
    bool? showDivider,
  }) => DSExpansionStyle(
    headerPadding: headerPadding ?? this.headerPadding,
    bodyPadding: bodyPadding ?? this.bodyPadding,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    iconColor: iconColor ?? this.iconColor,
    iconSize: iconSize ?? this.iconSize,
    gap: gap ?? this.gap,
    minHeaderHeight: minHeaderHeight ?? this.minHeaderHeight,
    showDivider: showDivider ?? this.showDivider,
  );

  @override
  DSExpansionStyle lerp(DSExpansionStyle? other, double t) {
    if (other == null) return this;
    return DSExpansionStyle(
      headerPadding: EdgeInsetsGeometry.lerp(
        headerPadding,
        other.headerPadding,
        t,
      ),
      bodyPadding: EdgeInsetsGeometry.lerp(bodyPadding, other.bodyPadding, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      gap: lerpDouble(gap, other.gap, t),
      minHeaderHeight: lerpDouble(minHeaderHeight, other.minHeaderHeight, t),
      // A boolean has no midpoint; it switches at the halfway mark.
      showDivider: t < 0.5 ? showDivider : other.showDivider,
    );
  }

  static DSExpansionStyle resolve(
    BuildContext context, [
    DSExpansionStyle? own,
  ]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;

    return resolveStyle(
      context: context,
      specDefaults: DSExpansionStyle(
        headerPadding: EdgeInsets.symmetric(vertical: space.sm),
        bodyPadding: EdgeInsets.only(top: space.sm, bottom: space.md),
        titleStyle: DSTextRole.cardTitle.styleOf(context),
        subtitleStyle: DSTextRole.itemSubtitle.styleOf(context),
        iconColor: palette.mutedForeground,
        iconSize: design.component.iconSize,
        gap: space.md,
        minHeaderHeight: design.component.minTapTarget,
        showDivider: true,
      ),
      own: own,
    );
  }
}

/// One question with its answer folded away under it.
///
/// **Use when** the content is secondary to the row that names it and most
/// readers will not open it — an FAQ, a "what's included" list, the technical
/// detail behind a failure, an advanced settings block. **Instead:**
/// `DSListTile` with an `onTap` when the content deserves its own screen: a
/// disclosure that opens onto three paragraphs and four controls is a route
/// pretending to be a row. `DSTabBar` when the sections are peers the reader
/// is meant to compare — an accordion hides everything but one thing, which is
/// the opposite of comparing.
///
/// **Never put a form field inside one.** A validation error on a collapsed
/// panel is an error the user cannot see, and "please fix the highlighted
/// field" with nothing highlighted is the worst screen in any app.
///
/// Uncontrolled by default: it owns its own open state, and
/// [initiallyExpanded] seeds it. Pass [expanded] to control it from the
/// parent, which is how a column of these becomes an accordion where only one
/// is open at a time — the parent holds the open index and each panel gets
/// `expanded: index == i`.
class DSExpansion extends StatefulWidget {
  const DSExpansion({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.leading,
    this.initiallyExpanded = false,
    this.expanded,
    this.onExpansionChanged,
    this.enabled = true,
    this.titleSlot,
    this.style,
  }) : assert(
         expanded == null || onExpansionChanged != null,
         'A controlled DSExpansion needs onExpansionChanged, or its header is '
         'a button that does nothing.',
       );

  /// The question, in the words a reader would search for.
  final String title;

  /// One line under the title, for a count or a summary — "3 items",
  /// "Off". Not a second sentence of the answer: the answer is [child].
  final String? subtitle;

  /// An icon or avatar before the title.
  final Widget? leading;

  /// The answer. Built even while collapsed, so a body that is expensive to
  /// build belongs behind a builder of the caller's own.
  final Widget child;

  /// The open state for an uncontrolled panel, read once.
  final bool initiallyExpanded;

  /// Set to control the open state from the parent. When non-null the panel
  /// never changes its own state — it reports the tap and rebuilds with what
  /// the parent sends back.
  final bool? expanded;

  final ValueChanged<bool>? onExpansionChanged;

  /// A disabled panel keeps its header and cannot be opened. It is the state
  /// for a section that is empty rather than one that is hidden: removing the
  /// row entirely is better than a row that does nothing.
  final bool enabled;

  /// Replaces the title text entirely, for a header that carries a badge or a
  /// two-part label. [title] is still required — it is the semantic label.
  final Widget? titleSlot;

  final DSExpansionStyle? style;

  @override
  State<DSExpansion> createState() => _DSExpansionState();
}

class _DSExpansionState extends State<DSExpansion> {
  late bool _open = widget.initiallyExpanded;

  bool get _isOpen => widget.expanded ?? _open;

  void _toggle() {
    if (!widget.enabled) return;
    AppHaptics.selection();
    final next = !_isOpen;
    if (widget.expanded == null) setState(() => _open = next);
    widget.onExpansionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSExpansionStyle.resolve(context, widget.style);
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced ? Duration.zero : motion.scaled(motion.normal);

    final header = Padding(
      padding: resolved.headerPadding ?? EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: resolved.minHeaderHeight ?? 48),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              SizedBox(width: resolved.gap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.titleSlot ??
                      Text(widget.title, style: resolved.titleStyle),
                  if (widget.subtitle != null)
                    Text(widget.subtitle!, style: resolved.subtitleStyle),
                ],
              ),
            ),
            SizedBox(width: resolved.gap),
            // Rotated rather than swapped: the chevron turning is what says
            // the panel below it moved, and two different glyphs cutting to
            // each other says nothing.
            AnimatedRotation(
              turns: _isOpen ? 0.5 : 0,
              duration: duration,
              curve: motion.standard,
              child: Icon(
                Icons.expand_more,
                size: resolved.iconSize,
                color: resolved.iconColor,
              ),
            ),
          ],
        ),
      ),
    );

    final body = _isOpen
        ? Padding(
            padding: resolved.bodyPadding ?? EdgeInsets.zero,
            child: widget.child,
          )
        : const SizedBox(width: double.infinity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Merged, and the expanded flag on the same node as the words: an
        // `expanded` wrapper above a label-less button is two stops for a
        // screen reader, and the one it lands on has nothing to read.
        MergeSemantics(
          child: Semantics(
            expanded: _isOpen,
            enabled: widget.enabled,
            button: true,
            label: widget.title,
            // Declared here because `excludeSemantics` removes the one the
            // control publishes for itself: without it the node says
            // "button", says what for, and offers nothing to activate.
            onTap: widget.enabled ? _toggle : null,
            excludeSemantics: true,
            child: DSPressable(
              enabled: widget.enabled,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.enabled ? _toggle : null,
                child: header,
              ),
            ),
          ),
        ),
        if (resolved.showDivider ?? true) const DSDivider(),
        // AnimatedSize over the whole body: the height is what moves, and a
        // fade with no height change is a body that appears on top of the
        // content under it.
        //
        // Dropped entirely under reduced motion rather than run at zero:
        // `AnimatedSize` with a zero duration re-dirties itself inside its own
        // `performLayout`, which is a framework assertion, not a slow frame.
        if (reduced)
          body
        else
          AnimatedSize(
            duration: duration,
            curve: motion.standard,
            alignment: Alignment.topCenter,
            child: body,
          ),
      ],
    );
  }
}
