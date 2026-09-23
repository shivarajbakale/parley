// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Two rungs of emphasis, not four.
///
/// See `docs/plans/13-ds-icon-button.plan.md` §3. The pair this replaces had
/// `filled` and `filledTonal` measured **1.19:1** apart in dark — two variants
/// the user cannot tell apart is one variant with a spelling variation — and
/// `outlined`, which on a 40dp control reads as a slightly heavier glyph. Both
/// removed cases are still reachable through [DSIconButtonStyle], where a
/// consumer sets them once instead of at every call site.
enum DSIconButtonVariant {
  /// An action that must be available but must not compete with the content.
  /// The default, and what an app bar and a row's trailing slot use.
  standard,

  /// The one prominent icon action in a context — a compose button, a primary
  /// toolbar action. At most one per surface.
  filled,
}

enum DSIconButtonSize { sm, md, lg }

/// [DSIconButton]'s appearance, as data.
@immutable
class DSIconButtonStyle extends DSComponentStyle<DSIconButtonStyle> {
  const DSIconButtonStyle({
    this.extent,
    this.iconSize,
    this.radius,
    this.fillColor,
    this.glyphColor,
    this.outlineColor,
    this.outlineWidth,
    this.disabledGlyph,
    this.disabledFill,
    this.selectedFill,
    this.pressedOverlay,
    this.pressScale,
    this.barGap,
  });

  /// What the control looks like it is. Deliberately separate from the tap
  /// target, which never drops below [ComponentSpec.minTapTarget].
  final double? extent;

  final double? iconSize;
  final BorderRadius? radius;
  final Color? fillColor;
  final Color? glyphColor;

  /// Null by default. The `outlined` variant this replaces lived here.
  final Color? outlineColor;

  final double? outlineWidth;
  final Color? disabledGlyph;

  /// The fill a disabled `filled` button takes. `standard` has no fill to
  /// drop, so this is null there.
  final Color? disabledFill;
  final Color? selectedFill;
  final double? pressedOverlay;

  /// Deeper than a button's 0.97: a small control needs a larger proportional
  /// change to register as pressed.
  final double? pressScale;

  /// The gap [DSIconButtonGroup] leaves between two buttons, which is what
  /// keeps two `sm` targets from overlapping.
  final double? barGap;

  @override
  DSIconButtonStyle merge(DSIconButtonStyle? other) {
    if (other == null) return this;
    return DSIconButtonStyle(
      extent: other.extent ?? extent,
      iconSize: other.iconSize ?? iconSize,
      radius: other.radius ?? radius,
      fillColor: other.fillColor ?? fillColor,
      glyphColor: other.glyphColor ?? glyphColor,
      outlineColor: other.outlineColor ?? outlineColor,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      disabledGlyph: other.disabledGlyph ?? disabledGlyph,
      disabledFill: other.disabledFill ?? disabledFill,
      selectedFill: other.selectedFill ?? selectedFill,
      pressedOverlay: other.pressedOverlay ?? pressedOverlay,
      pressScale: other.pressScale ?? pressScale,
      barGap: other.barGap ?? barGap,
    );
  }

  @override
  DSIconButtonStyle copyWith({
    double? extent,
    double? iconSize,
    BorderRadius? radius,
    Color? fillColor,
    Color? glyphColor,
    Color? outlineColor,
    double? outlineWidth,
    Color? disabledGlyph,
    Color? disabledFill,
    Color? selectedFill,
    double? pressedOverlay,
    double? pressScale,
    double? barGap,
  }) => DSIconButtonStyle(
    extent: extent ?? this.extent,
    iconSize: iconSize ?? this.iconSize,
    radius: radius ?? this.radius,
    fillColor: fillColor ?? this.fillColor,
    glyphColor: glyphColor ?? this.glyphColor,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    disabledGlyph: disabledGlyph ?? this.disabledGlyph,
    disabledFill: disabledFill ?? this.disabledFill,
    selectedFill: selectedFill ?? this.selectedFill,
    pressedOverlay: pressedOverlay ?? this.pressedOverlay,
    pressScale: pressScale ?? this.pressScale,
    barGap: barGap ?? this.barGap,
  );

  @override
  DSIconButtonStyle lerp(DSIconButtonStyle? other, double t) {
    if (other == null) return this;
    return DSIconButtonStyle(
      extent: lerpDouble(extent, other.extent, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      glyphColor: Color.lerp(glyphColor, other.glyphColor, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      disabledGlyph: Color.lerp(disabledGlyph, other.disabledGlyph, t),
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t),
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t),
      pressedOverlay: lerpDouble(pressedOverlay, other.pressedOverlay, t),
      pressScale: lerpDouble(pressScale, other.pressScale, t),
      barGap: lerpDouble(barGap, other.barGap, t),
    );
  }

  /// A container's size suggestion, unless the caller was explicit.
  static DSIconButtonSize sizeOf(BuildContext context, DSIconButtonSize? size) {
    if (size != null) return size;
    return switch (DSScope.sizeOf(context)) {
      DSSize.sm => DSIconButtonSize.sm,
      DSSize.lg => DSIconButtonSize.lg,
      DSSize.md || null => DSIconButtonSize.md,
    };
  }

  static DSIconButtonStyle resolve(
    BuildContext context,
    DSIconButtonVariant variant,
    DSIconButtonSize? size,
    DSTone tone, [
    DSIconButtonStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final scale = sizeOf(context, size);

    // The visual shrinks; the target does not. 32 / 40 / 48 against a floor
    // of 48 — which is why DSIconButtonGroup exists.
    final (extent, glyph) = switch (scale) {
      DSIconButtonSize.sm => (
        component.minTapTarget - space.lg,
        component.iconSizeSmall,
      ),
      DSIconButtonSize.md => (
        component.minTapTarget - space.sm,
        component.iconSize - space.xs,
      ),
      DSIconButtonSize.lg => (component.minTapTarget, component.iconSize),
    };

    // The tone moves the glyph on `standard`, where there is no fill to carry
    // it. On `filled` the fill is the tone and the glyph is its on-colour, so
    // the pair always clears gate K1's 4.5:1.
    final (Color, Color)? toned = switch (tone) {
      DSTone.neutral => null,
      DSTone.info => (palette.primary, palette.primaryForeground),
      DSTone.success => (palette.success, palette.onSuccess),
      DSTone.warning => (palette.warning, palette.onWarning),
      DSTone.error => (palette.destructive, palette.onDestructive),
    };

    final (fill, glyphColor) = switch (variant) {
      DSIconButtonVariant.standard => (null, toned?.$1 ?? palette.foreground),
      DSIconButtonVariant.filled => (
        toned?.$1 ?? palette.primary,
        toned?.$2 ?? palette.primaryForeground,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSIconButtonStyle(
        extent: extent,
        iconSize: glyph,
        // The identity's control shape, not a circle. An app that squares its
        // controls off gets square icon buttons without editing this file.
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
        fillColor: fill,
        glyphColor: glyphColor,
        outlineWidth: component.hairlineWidth,
        // Reachable but clearly unavailable. `textSecondary` rather than the
        // plan's `textTertiary`, which measures 2.59:1 on `well` in light —
        // and `well` is exactly where a disabled `filled` button puts it.
        // Gate K2 holds `textSecondary` at 4.5:1 on all three surface roles,
        // which is the same house rule DSButton's disabled label follows.
        disabledGlyph: palette.mutedForeground,
        // A disabled button that keeps its accent fill reads as available.
        disabledFill: fill == null ? null : palette.muted,
        selectedFill: palette.secondary,
        pressedOverlay: 0.08,
        pressScale: 0.94,
        barGap: space.sm,
      ),
      own: own,
    );
  }
}

/// An action with no label: a glyph, a target, and a name that only assistive
/// technology and a long-press ever see.
///
/// See `docs/plans/13-ds-icon-button.plan.md`. [semanticLabel] is **required**
/// and that is the point of the redesign rather than a convenience: a control
/// whose only content is a glyph, whose accessible name was optional, is a
/// control that ships unnamed — and it did, three times, in the demo screens.
/// Making it a constructor argument turns a review comment into a compile
/// error.
///
/// **Use when** the glyph is unambiguous *and* space genuinely does not allow
/// a label — an app bar, a row's trailing slot, a toolbar. The set of glyphs a
/// reader knows without a label is small: search, home, close, share, add,
/// delete, settings. **Instead:** in a form or a pinned action bar, a labelled
/// `DSButton`, always. An icon that needs its tooltip to be understood in a
/// primary action position is a design smell.
class DSIconButton extends StatefulWidget {
  const DSIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.variant = DSIconButtonVariant.standard,
    this.size,
    this.tone = DSTone.neutral,
    this.selected = false,
    this.selectedIcon,
    this.badgeCount,
    this.loading = false,
    this.style,
    this.iconSlot,
    this.badgeSlot,
  });

  /// A pointer for a generated app that pulls an update, rather than a
  /// missing symbol. Removed in the next release.
  @Deprecated(
    'DSIconButton.destructive is now tone: DSTone.error — the same value, '
    'expressible alongside four others, and no longer a private bool behind '
    'a constructor. See docs/plans/13-ds-icon-button.plan.md.',
  )
  const DSIconButton.destructive({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.size,
    this.selected = false,
    this.selectedIcon,
    this.badgeCount,
    this.loading = false,
    this.style,
    this.iconSlot,
    this.badgeSlot,
  }) : variant = DSIconButtonVariant.standard,
       tone = DSTone.error;

  /// [IconData] rather than a widget, because the glyph must be tintable,
  /// sized by the button and mirrored for RTL. [iconSlot] is the hatch for
  /// anything else.
  final IconData icon;

  /// Required. An icon is not a name.
  final String semanticLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Defaults to [semanticLabel]. A caller wanting a longer tooltip passes
  /// one; a caller passing neither still gets both.
  final String? tooltip;

  final DSIconButtonVariant variant;

  /// Null takes the size a container suggested, then `md`.
  final DSIconButtonSize? size;

  /// Meaning, not colour. Replaces the private `_useErrorColor` bool that the
  /// deleted `.destructive` constructor set.
  final DSTone tone;

  final bool selected;

  /// The toggled glyph. A toggle whose fill is its only signal fails SC 1.4.1,
  /// so `tool/ui_lint.dart` warns when a `selected:` button has none.
  final IconData? selectedIcon;

  /// Folded into the accessible name — "Notifications, 3 unread" — rather than
  /// exposed as a second node, because a badge is not separately actionable.
  final int? badgeCount;

  final bool loading;
  final DSIconButtonStyle? style;
  final Widget? iconSlot;
  final Widget? badgeSlot;

  @override
  State<DSIconButton> createState() => _DSIconButtonState();
}

class _DSIconButtonState extends State<DSIconButton> {
  @override
  void didUpdateWidget(covariant DSIconButton old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) AppHaptics.selection();
  }

  void _handlePress() {
    if (widget.tone == DSTone.error) AppHaptics.warning();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSIconButtonStyle.resolve(
      context,
      widget.variant,
      widget.size,
      widget.tone,
      widget.style,
    );
    final design = context.design;
    final enabled =
        widget.onPressed != null &&
        (DSScope.enabledOf(context) ?? true) &&
        !widget.loading;
    final target = design.component.minTapTarget;
    final extent = resolved.extent!;

    final fill = enabled
        ? (widget.selected ? resolved.selectedFill : resolved.fillColor)
        : resolved.disabledFill;
    final glyphColor = enabled ? resolved.glyphColor! : resolved.disabledGlyph!;

    Widget visual = SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: resolved.radius!,
            side: resolved.outlineColor == null
                ? BorderSide.none
                : BorderSide(
                    color: resolved.outlineColor!,
                    width: resolved.outlineWidth!,
                  ),
          ),
        ),
        child: Center(child: _glyph(context, resolved, glyphColor)),
      ),
    );

    if (widget.badgeSlot != null || widget.badgeCount != null) {
      visual = _badged(context, visual, extent);
    }

    // The target is transparent and centred on the visual, so an `sm` button
    // still answers to a 48dp finger without looking like a 48dp control.
    final button = SizedBox.square(
      dimension: target,
      child: DSInkSurface(
        onTap: enabled ? _handlePress : null,
        // The splash is a circle wider than the glyph, not a box clipped to
        // it — the one control in the kit that wants an unbounded ink.
        unbounded: true,
        unboundedRadius: target / 2,
        highlightColor: resolved.glyphColor!.withValues(
          alpha: resolved.pressedOverlay!,
        ),
        // The `SizedBox.square` above is already the floor.
        minTapTarget: false,
        child: Center(child: visual),
      ),
    );

    // The annotation is the outermost thing this widget builds. `getSemantics`
    // — and a screen reader's own walk — reads upward, so a node buried under
    // the tooltip and the press transform is a node that answers to the
    // Scaffold instead of to the button.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      // `excludeSemantics` drops the button's own node, and the tap action
      // went with it: the tree published a node that said "button", said what
      // it was for, and offered nothing to activate. VoiceOver's double-tap
      // and TalkBack's click both go through this action, so the control was
      // announced and could not be used.
      onTap: enabled ? _handlePress : null,
      toggled: widget.selectedIcon != null || widget.selected
          ? widget.selected
          : null,
      label: _label(),
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip ?? widget.semanticLabel,
        excludeFromSemantics: true,
        child: DSPressable(
          enabled: enabled,
          scale: resolved.pressScale!,
          focusShape: RoundedRectangleBorder(borderRadius: resolved.radius!),
          child: button,
        ),
      ),
    );
  }

  /// The badge count belongs to the button's name, not to a node of its own.
  String _label() {
    final count = widget.badgeCount;
    if (count == null || count == 0) return widget.semanticLabel;
    return '${widget.semanticLabel}, $count unread';
  }

  /// The glyph, the toggled glyph, or the spinner — cross-faded, and swapped
  /// instantly under reduced motion. The swap itself is never skipped: it is
  /// the SC 1.4.1 channel that the fill alone cannot carry.
  Widget _glyph(BuildContext context, DSIconButtonStyle resolved, Color color) {
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);

    final Widget child;
    if (widget.loading) {
      child = SizedBox.square(
        key: const ValueKey('loading'),
        dimension: resolved.iconSize!,
        child: CircularProgressIndicator(
          strokeWidth: context.design.component.hairlineWidth + 1,
          color: color,
        ),
      );
    } else if (widget.iconSlot != null) {
      child = IconTheme.merge(
        key: const ValueKey('slot'),
        data: IconThemeData(color: color, size: resolved.iconSize),
        child: widget.iconSlot!,
      );
    } else {
      final glyph = widget.selected
          ? (widget.selectedIcon ?? widget.icon)
          : widget.icon;
      child = Icon(
        glyph,
        key: ValueKey(glyph),
        size: resolved.iconSize,
        color: color,
      );
    }

    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : motion.scaled(motion.fast),
      switchInCurve: motion.enter,
      child: child,
    );
  }

  /// The badge sits on the visual extent, not on the tap target — anchored to
  /// the target it would float away from the button it belongs to.
  Widget _badged(BuildContext context, Widget visual, double extent) {
    final space = context.design.space;
    return SizedBox.square(
      dimension: extent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: visual),
          PositionedDirectional(
            top: -space.xs,
            end: -space.xs,
            child:
                widget.badgeSlot ??
                DSIconButtonBadge(count: widget.badgeCount!),
          ),
        ],
      ),
    );
  }
}

/// The count on an icon button, drawn as a pill and read out as part of the
/// button's name rather than as a control of its own.
class DSIconButtonBadge extends StatelessWidget {
  const DSIconButtonBadge({super.key, required this.count, this.formatter});

  final int count;

  /// How a large count is written. The default caps at 99+, because a badge
  /// wider than the button it sits on stops being a badge.
  final String Function(int)? formatter;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final label = (formatter ?? _cap)(count);

    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: palette.destructive,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.xs),
          child: SizedBox(
            height: space.lg - space.hairline,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.onDestructive,
                  fontWeight: context.design.type.emphasisWeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _cap(int count) => count > 99 ? '99+' : '$count';
}

/// A row of icon buttons with the gap that keeps their targets apart.
///
/// At `sm` the visual is 32 and the target is 48, so two adjacent buttons
/// overlap their targets unless something keeps them apart. That overlap is
/// the most common failure in the whole category, so the group asserts against
/// it rather than trusting the caller to leave room.
class DSIconButtonGroup extends StatelessWidget {
  const DSIconButtonGroup({super.key, required this.children, this.style});

  final List<Widget> children;
  final DSIconButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSIconButtonStyle.resolve(
      context,
      DSIconButtonVariant.standard,
      null,
      DSTone.neutral,
      style,
    );
    final gap = resolved.barGap!;
    assert(
      gap >= 8,
      'DSIconButtonGroup lays targets of ${context.design.component.minTapTarget}dp '
      'side by side, and WCAG 2.2 SC 2.5.8 asks for 8dp between them. A '
      'barGap of $gap lets two targets overlap, so the button a user hits is '
      'not the one they aimed at.',
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          children[i],
        ],
      ],
    );
  }
}
