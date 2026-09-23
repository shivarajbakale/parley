// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/_tap_target.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// What a chip *is*, which decides how it behaves and what a reader hears.
///
/// See `docs/plans/14-ds-chip.plan.md` §3. This replaces inferring the role
/// from which callback happened to be non-null — an arrangement under which a
/// chip with both `onSelected` and `onDeleted` compiled and meant nothing.
enum DSChipRole {
  /// An attribute of something: "Draft", "PDF", "Beta". Not focusable, read
  /// as text. A filter row of twelve static tags that each take a tab stop is
  /// the failure this avoids.
  tag,

  /// A facet the user turns on and off. The row is a set.
  filter,

  /// A value the user entered and can take back — a recipient, a chosen tag.
  /// Carries a second, separately labelled remove control.
  input,
}

enum DSChipSize { sm, md }

/// How many chips in a [DSChipGroup] may be on at once.
enum DSChipSelectionMode { single, multiple }

/// [DSChip]'s appearance, as data.
@immutable
class DSChipStyle extends DSComponentStyle<DSChipStyle> {
  const DSChipStyle({
    this.height,
    this.padding,
    this.radius,
    this.chipStyle,
    this.showLeadingIcon,
    this.fillColor,
    this.selectedFill,
    this.outlineColor,
    this.selectedOutline,
    this.outlineWidth,
    this.selectedWidth,
    this.labelStyle,
    this.leadingSize,
    this.maxWidth,
    this.barGap,
  });

  /// The chip's *visual* height. Its tap target never drops below
  /// [ComponentSpec.minTapTarget], which is the decoupling this component has
  /// always been built around.
  final double? height;

  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;

  /// Filled, tonal or outlined — from [ComponentSpec.chipStyle], which the
  /// identity has always declared and the widget never read.
  final ChipStyle? chipStyle;

  /// From [ComponentSpec.chipIcons]. Off in this identity: at chip size an
  /// icon rarely says anything the label does not, and it costs enough width
  /// to push the last chip off the screen.
  final bool? showLeadingIcon;

  final Color? fillColor;
  final Color? selectedFill;
  final Color? outlineColor;
  final Color? selectedOutline;
  final double? outlineWidth;

  /// Heavier than the resting outline, so selection reads in greyscale.
  final double? selectedWidth;

  final TextStyle? labelStyle;
  final double? leadingSize;

  /// A chip that grows to fit any label is a button.
  final double? maxWidth;

  final double? barGap;

  @override
  DSChipStyle merge(DSChipStyle? other) {
    if (other == null) return this;
    return DSChipStyle(
      height: other.height ?? height,
      padding: other.padding ?? padding,
      radius: other.radius ?? radius,
      chipStyle: other.chipStyle ?? chipStyle,
      showLeadingIcon: other.showLeadingIcon ?? showLeadingIcon,
      fillColor: other.fillColor ?? fillColor,
      selectedFill: other.selectedFill ?? selectedFill,
      outlineColor: other.outlineColor ?? outlineColor,
      selectedOutline: other.selectedOutline ?? selectedOutline,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      selectedWidth: other.selectedWidth ?? selectedWidth,
      labelStyle: other.labelStyle ?? labelStyle,
      leadingSize: other.leadingSize ?? leadingSize,
      maxWidth: other.maxWidth ?? maxWidth,
      barGap: other.barGap ?? barGap,
    );
  }

  @override
  DSChipStyle copyWith({
    double? height,
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
    ChipStyle? chipStyle,
    bool? showLeadingIcon,
    Color? fillColor,
    Color? selectedFill,
    Color? outlineColor,
    Color? selectedOutline,
    double? outlineWidth,
    double? selectedWidth,
    TextStyle? labelStyle,
    double? leadingSize,
    double? maxWidth,
    double? barGap,
  }) => DSChipStyle(
    height: height ?? this.height,
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    chipStyle: chipStyle ?? this.chipStyle,
    showLeadingIcon: showLeadingIcon ?? this.showLeadingIcon,
    fillColor: fillColor ?? this.fillColor,
    selectedFill: selectedFill ?? this.selectedFill,
    outlineColor: outlineColor ?? this.outlineColor,
    selectedOutline: selectedOutline ?? this.selectedOutline,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    selectedWidth: selectedWidth ?? this.selectedWidth,
    labelStyle: labelStyle ?? this.labelStyle,
    leadingSize: leadingSize ?? this.leadingSize,
    maxWidth: maxWidth ?? this.maxWidth,
    barGap: barGap ?? this.barGap,
  );

  @override
  DSChipStyle lerp(DSChipStyle? other, double t) {
    if (other == null) return this;
    return DSChipStyle(
      // Two enum-or-flag fields with no midpoint.
      chipStyle: t < 0.5 ? chipStyle : other.chipStyle,
      showLeadingIcon: t < 0.5 ? showLeadingIcon : other.showLeadingIcon,
      height: lerpDouble(height, other.height, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      selectedOutline: Color.lerp(selectedOutline, other.selectedOutline, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      selectedWidth: lerpDouble(selectedWidth, other.selectedWidth, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      leadingSize: lerpDouble(leadingSize, other.leadingSize, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      barGap: lerpDouble(barGap, other.barGap, t),
    );
  }

  static DSChipSize sizeOf(BuildContext context, DSChipSize? size) {
    if (size != null) return size;
    return switch (DSScope.sizeOf(context)) {
      DSSize.sm => DSChipSize.sm,
      // A chip has two sizes, not three: below 28 the label stops being
      // readable and above 32 it stops being a chip.
      DSSize.md || DSSize.lg || null => DSChipSize.md,
    };
  }

  static DSChipStyle resolve(
    BuildContext context,
    DSChipRole role,
    DSChipSize? size,
    DSTone tone, [
    DSChipStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final scale = sizeOf(context, size);

    final (height, padding, label) = switch (scale) {
      DSChipSize.sm => (
        component.minTapTarget - space.xl,
        EdgeInsets.symmetric(horizontal: space.sm + space.xs),
        text.labelSmall,
      ),
      DSChipSize.md => (
        component.minTapTarget - space.lg,
        EdgeInsets.symmetric(horizontal: space.md),
        text.labelMedium,
      ),
    };

    // A tone tints the chip and its label together, from the pair gate K1
    // holds at 4.5:1 — never a semantic hue on the surface behind it.
    final Color? toned = switch (tone) {
      DSTone.neutral => null,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };

    // The identity's own answer to "what does a chip look like here", which
    // ComponentSpec has always declared and this widget never read.
    final (styleFill, styleOutline) = switch (component.chipStyle) {
      ChipStyle.outlined => (null, palette.border),
      ChipStyle.tonal => (palette.muted, null),
      ChipStyle.filled => (palette.secondary, null),
    };

    // A tag is not a control, so it takes no outline: a boundary that says
    // "3:1, I am operable" on something nobody can operate is a lie.
    final fill =
        (toned == null ? null : palette.tint(toned)) ??
        (role == DSChipRole.tag ? palette.muted : styleFill);
    final outline = role == DSChipRole.tag || toned != null
        ? null
        : styleOutline;

    return resolveStyle(
      context: context,
      specDefaults: DSChipStyle(
        height: height,
        padding: padding,
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
        chipStyle: component.chipStyle,
        showLeadingIcon: component.chipIcons,
        fillColor: fill,
        selectedFill: palette.secondary,
        outlineColor: outline,
        selectedOutline: palette.primary,
        outlineWidth: component.surfaceOutlineWidth,
        selectedWidth: component.selectedOutlineWidth,
        labelStyle: label?.copyWith(color: palette.foreground),
        leadingSize: component.iconSizeSmall - space.xs,
        maxWidth: component.chipMaxWidth,
        barGap: space.sm,
      ),
      own: own,
    );
  }
}

/// A small, compact element carrying an attribute, a filter, or a value the
/// user entered.
///
/// See `docs/plans/14-ds-chip.plan.md`. Three things this does that a bare
/// [FilterChip] does not:
///
///   * it takes the platform corner rather than Material's default, so a row
///     of chips on iOS is not the one control on the screen with Android
///     geometry;
///   * its tap target is padded out to the platform floor. A chip's visual
///     height is around 32, which is below both 44 and 48 — the most common
///     accessibility failure in a kit that otherwise looks careful, because
///     the chip looks fine and only measures wrong;
///   * selecting one ticks. Selection is the interaction haptics exist for.
///
/// And two the redesign adds: a selected chip carries a check **and** an
/// outline **and** a fill, because a filter row photographed in greyscale had
/// no selection at all; and `Color? color` is gone, because a field typed
/// `Color?` with no further constraint is an invitation `ui_lint` cannot
/// decline.
///
/// **Use when** the content is short, secondary, and one of several — a filter
/// row, a set of tags, a token in an input. **Instead:** two to four visible,
/// mutually exclusive options are a `DSSegmentedButton`; a count or a status
/// that is not interactive is a `DSBadge`; the page's own search filters are
/// `DSSearchChip`.
class DSChip extends StatefulWidget {
  const DSChip({
    super.key,
    required this.label,
    this.role = DSChipRole.tag,
    this.selected = false,
    this.onSelected,
    this.onRemove,
    this.onTap,
    this.icon,
    this.markColor,
    this.tone = DSTone.neutral,
    this.count,
    this.enabled = true,
    this.loading = false,
    this.size,
    this.style,
    this.labelSlot,
    this.iconSlot,
    this.leading,
    this.trailing,
  }) : assert(
         onSelected == null || role == DSChipRole.filter,
         'onSelected belongs to DSChipRole.filter. A chip that toggles is a '
         'filter to a screen reader — it announces "toggled" — and a tag or '
         'an input token that also toggles has no defined meaning.',
       ),
       assert(
         !selected || role == DSChipRole.filter,
         'selected belongs to DSChipRole.filter. Nothing else in the kit has '
         'a selected state without a way to change it.',
       ),
       assert(
         onRemove == null || role == DSChipRole.input,
         'onRemove belongs to DSChipRole.input. The remove control is a '
         'second focusable node with its own name and its own 48dp target, '
         'which is what makes an input token different from a filter.',
       );

  final String label;
  final DSChipRole role;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onRemove;

  /// A tag or an input token that opens something.
  final VoidCallback? onTap;

  /// Drawn only when the identity's [ComponentSpec.chipIcons] allows it, or
  /// when the style says so.
  final IconData? icon;

  /// A dot, from `palette.chart[i]` for data. A graphical object: 3:1 as a
  /// mark, never used for the label.
  final Color? markColor;

  final DSTone tone;

  /// Folded into the chip's accessible name — "Documents, 12" — rather than
  /// exposed as a node of its own.
  final int? count;

  final bool enabled;
  final bool loading;
  final DSChipSize? size;
  final DSChipStyle? style;
  final Widget? labelSlot;
  final Widget? iconSlot;

  /// An avatar in a recipient chip, a flag, a favicon.
  final Widget? leading;

  /// A chevron for a chip that opens a menu. Replaces the generated count.
  final Widget? trailing;

  @override
  State<DSChip> createState() => _DSChipState();
}

class _DSChipState extends State<DSChip> with SingleTickerProviderStateMixin {
  AnimationController? _exit;

  @override
  void dispose() {
    _exit?.dispose();
    super.dispose();
  }

  /// Two phases: the chip goes, *then* the row re-flows. Starting the
  /// neighbours before the chip is gone means a mis-tap removes the one that
  /// moved under the finger.
  Future<void> _remove() async {
    AppHaptics.warning();
    if (!MediaQuery.disableAnimationsOf(context)) {
      final motion = context.design.motion;
      _exit ??= AnimationController(
        vsync: this,
        duration: motion.scaled(motion.fast),
        value: 1,
      );
      await _exit!.reverse();
    }
    widget.onRemove!();
  }

  void _toggle() {
    AppHaptics.selection();
    widget.onSelected!(!widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSChipStyle.resolve(
      context,
      widget.role,
      widget.size,
      widget.tone,
      widget.style,
    );
    final enabled =
        widget.enabled &&
        (DSScope.enabledOf(context) ?? true) &&
        !widget.loading;

    if (widget.loading) return _skeleton(context, resolved);

    final surface = _surface(context, resolved, enabled);

    // The target is grown around the chip, not by growing the chip: the row
    // keeps its density and the target stops being 32 tall. `DSShortTrack`
    // does it inside `_surface` now, so that the controls *within* the chip
    // get the same box rather than only the chip itself.
    final padded = surface;

    final Widget chip = switch (widget.role) {
      // Text with a background. No node, no tab stop.
      DSChipRole.tag =>
        widget.onTap == null
            ? Semantics(label: _name(), excludeSemantics: true, child: padded)
            : _tappable(context, resolved, padded, enabled, widget.onTap),
      DSChipRole.filter => Semantics(
        container: true,
        button: true,
        enabled: enabled,
        toggled: widget.selected,
        label: _name(),
        // Declared here because `excludeSemantics` removes the one the control
        // publishes for itself. Without it the node says "button", says what the
        // button is for, and offers nothing to activate — VoiceOver's double-tap
        // and TalkBack's click both arrive as this action.
        onTap: enabled && widget.onSelected != null ? _toggle : null,
        excludeSemantics: true,
        child: _pressable(
          resolved,
          enabled && widget.onSelected != null,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled && widget.onSelected != null ? _toggle : null,
            child: padded,
          ),
        ),
      ),
      // `explicitChildNodes` rather than `excludeSemantics`: the remove
      // control is a second node with its own name, and excluding the
      // subtree would take it with the label it is meant to survive.
      DSChipRole.input => Semantics(
        container: true,
        explicitChildNodes: true,
        button: widget.onTap != null,
        enabled: enabled,
        label: _name(),
        child: _pressable(
          resolved,
          enabled && widget.onTap != null,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onTap : null,
            child: padded,
          ),
        ),
      ),
    };

    if (_exit == null) return chip;
    return FadeTransition(
      opacity: _exit!,
      child: ScaleTransition(
        // Down to .8 rather than out of existence: the row re-flows in the
        // second phase, after this one has finished.
        scale: Tween<double>(begin: 0.8, end: 1).animate(_exit!),
        child: chip,
      ),
    );
  }

  Widget _tappable(
    BuildContext context,
    DSChipStyle resolved,
    Widget child,
    bool enabled,
    VoidCallback? onTap,
  ) => Semantics(
    container: true,
    button: onTap != null,
    enabled: enabled,
    label: _name(),
    // Declared here because `excludeSemantics` removes the one the control
    // publishes for itself. Without it the node says "button", says what the
    // button is for, and offers nothing to activate — VoiceOver's double-tap
    // and TalkBack's click both arrive as this action.
    onTap: enabled ? onTap : null,
    excludeSemantics: true,
    child: _pressable(
      resolved,
      enabled && onTap != null,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: child,
      ),
    ),
  );

  Widget _pressable(DSChipStyle resolved, bool enabled, Widget child) =>
      DSPressable(
        enabled: enabled,
        scale: 0.96,
        focusShape: RoundedRectangleBorder(borderRadius: resolved.radius!),
        child: child,
      );

  /// The count is part of the chip's name, not a second thing to tab to.
  String _name() =>
      widget.count == null ? widget.label : '${widget.label}, ${widget.count}';

  Widget _surface(BuildContext context, DSChipStyle resolved, bool enabled) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final motion = design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);

    final selected = widget.selected;
    final fill = selected ? resolved.selectedFill : resolved.fillColor;
    final outline = selected ? resolved.selectedOutline : resolved.outlineColor;
    final width = selected ? resolved.selectedWidth! : resolved.outlineWidth!;
    // Reachable but clearly unavailable, and gate K3 holds `textTertiary` at
    // 3:1 against the surface.
    final labelColor = enabled
        ? resolved.labelStyle?.color
        : palette.mutedForeground;

    final showIcon =
        (resolved.showLeadingIcon ?? false) ||
        widget.style?.showLeadingIcon == true;
    final removable =
        widget.role == DSChipRole.input && widget.onRemove != null;
    // Resolved left-to-right and re-declared directionally, so dropping the
    // trailing inset drops the trailing one in Arabic too.
    final pad = resolved.padding!.resolve(TextDirection.ltr);

    // The pill is painted behind the row rather than around it. It is 28 or
    // 32 tall on purpose — that is the density a row of chips reads at — and
    // the chip's own target has to be 48, which the old shape managed with a
    // Padding wrapped around the whole thing. What it could not manage was a
    // *second* target inside the chip: the remove control was a child of a
    // 32-point box and could not be taller than one, however much room the
    // padding outside it added.
    return ConstrainedBox(
      // A floor on the width as well as the height. A chip is a target, and a
      // target is 48 on both axes — but only the height was ever guaranteed,
      // so a chip with a short label was under the floor horizontally and
      // every page that used one had to know it. `repeat_rule_page` did know
      // it: it passed `space.lg` of horizontal padding with a comment saying
      // "Fri" measures 41 points otherwise. That is the atom's contract
      // written out by hand in a screen, and it only held while body copy was
      // 16pt — at 12.8 the same override measures 46 and the probe says so.
      constraints: BoxConstraints(
        minWidth: context.design.component.minTapTarget,
        maxWidth: resolved.maxWidth!,
      ),
      child: DSShortTrack(
        height: resolved.height!,
        background: AnimatedContainer(
          duration: reduced ? Duration.zero : motion.scaled(motion.fast),
          curve: motion.standard,
          decoration: ShapeDecoration(
            color: enabled ? fill : palette.muted,
            shape: RoundedRectangleBorder(
              borderRadius: resolved.radius!,
              side: outline == null
                  ? BorderSide.none
                  : BorderSide(
                      color: enabled ? outline : palette.borderSoft,
                      width: width,
                    ),
            ),
          ),
        ),
        child: Padding(
          // The trailing inset is dropped when a remove control is present:
          // its target is 48 wide around an 18-point glyph, so it brings 15
          // points of margin of its own, and the chip's own 12 on top of that
          // reads as a pill with a hole at the end of it.
          padding: removable
              ? EdgeInsetsDirectional.fromSTEB(pad.left, pad.top, 0, pad.bottom)
              : resolved.padding!,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The first of selection's three channels, and the only one that
              // survives a greyscale screenshot on its own.
              if (selected) ...[
                Icon(
                  Icons.check,
                  size: resolved.leadingSize,
                  color: palette.secondaryForeground,
                ),
                SizedBox(width: space.xs),
              ] else if (widget.leading != null) ...[
                widget.leading!,
                SizedBox(width: space.xs),
              ] else if (widget.markColor != null) ...[
                _mark(context, resolved),
                SizedBox(width: space.xs),
              ] else if (widget.iconSlot != null) ...[
                widget.iconSlot!,
                SizedBox(width: space.xs),
              ] else if (widget.icon != null && showIcon) ...[
                Icon(
                  widget.icon,
                  size: resolved.leadingSize,
                  // The icon is a graphical object on the tint (3:1); only
                  // the label is text.
                  color: enabled
                      ? switch (widget.tone) {
                          DSTone.neutral => labelColor,
                          DSTone.info => palette.primary,
                          DSTone.success => palette.success,
                          DSTone.warning => palette.warning,
                          DSTone.error => palette.destructive,
                        }
                      : labelColor,
                ),
                SizedBox(width: space.xs),
              ],
              Flexible(
                child: ExcludeSemantics(
                  child:
                      widget.labelSlot ??
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolved.labelStyle?.copyWith(color: labelColor),
                      ),
                ),
              ),
              if (widget.trailing != null) ...[
                SizedBox(width: space.xs),
                widget.trailing!,
              ] else if (widget.count != null) ...[
                SizedBox(width: space.xs),
                DSChipCount(count: widget.count!),
              ],
              if (removable) _removeControl(context, resolved, enabled),
            ],
          ),
        ),
      ),
    );
  }

  /// The category dot: a graphic at 3:1, never the thing carrying the word.
  Widget _mark(BuildContext context, DSChipStyle resolved) => SizedBox.square(
    dimension: resolved.leadingSize! - context.design.space.xs,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: widget.markColor,
        shape: const CircleBorder(),
      ),
    ),
  );

  /// A second node with its own name and its own target — never a bare ✕.
  Widget _removeControl(
    BuildContext context,
    DSChipStyle resolved,
    bool enabled,
  ) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Remove ${widget.label}',
      // Declared here because `excludeSemantics` removes the one the control
      // publishes for itself. Without it the node says "button", says what the
      // button is for, and offers nothing to activate — VoiceOver's double-tap
      // and TalkBack's click both arrive as this action.
      onTap: enabled ? _remove : null,
      excludeSemantics: true,
      // The visual sits inside the chip; the gesture area is the platform
      // floor, centred on it. This used to be an `OverflowBox` spilling to the
      // floor, which reads as a 48-point target and is not one: a pointer
      // outside a box is refused by `RenderBox.hitTest` before it ever reaches
      // the child, so every point of the spill was dead. The probe measured
      // what the tree actually offered — 18 by 18.
      child: DSTapTarget(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _remove : null,
          child: SizedBox.square(
            dimension: resolved.leadingSize! + context.design.space.xs,
            child: Icon(
              Icons.close,
              size: resolved.leadingSize,
              color: resolved.labelStyle?.color,
            ),
          ),
        ),
      ),
    );
  }

  /// A chip-shaped bone at the chip's own height, so the row does not jump
  /// when the labels arrive.
  Widget _skeleton(BuildContext context, DSChipStyle resolved) {
    final palette = context.palette;
    return DSSkeleton(
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical:
                ((context.design.component.minTapTarget - resolved.height!) / 2)
                    .clamp(0, resolved.height!),
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: palette.muted,
              shape: RoundedRectangleBorder(borderRadius: resolved.radius!),
            ),
            child: SizedBox(
              height: resolved.height,
              // Three plausible widths across a row, not one — a row of
              // identical grey pills reads as a bug rather than as loading.
              width:
                  resolved.maxWidth! * (0.3 + (widget.label.length % 3) * 0.15),
            ),
          ),
        ),
      ),
    );
  }
}

/// An avatar inside an input chip — the occupant of [DSChip.leading].
// ds-tier: 1 — atom — A chip's leading likeness.
class DSChipAvatar extends StatelessWidget {
  const DSChipAvatar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = context.design.component.iconSizeSmall;
    return ClipOval(
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

/// The count on a chip, in tabular figures so a row of them does not jitter.
// ds-tier: 1 — atom — A number inside a chip.
class DSChipCount extends StatelessWidget {
  const DSChipCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text('$count', style: DSTextRole.caption.styleOf(context)),
  );
}

/// A vertical hairline between two groups of chips in one row.
///
/// Arrived here from `ds_search_chip.dart`, which was a fourth chip painting
/// `primary` and `onPrimary` straight from the scheme. The separator was the
/// one thing in that file the kit did not already have, and it belongs to the
/// chip that stayed: a [DSChipGroup] holding two kinds of facet needs a way to
/// say where one ends.
class DSChipSeparator extends StatelessWidget {
  const DSChipSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: design.space.sm),
      child: Center(
        child: SizedBox(
          width: design.component.hairlineWidth,
          height: design.component.iconSizeInline,
          child: ColoredBox(color: context.palette.borderSoft),
        ),
      ),
    );
  }
}

/// A row of chips with the gaps, the wrap-or-scroll decision, and the overflow
/// the chips cannot decide for themselves.
///
/// Takes `List<Widget>` rather than `List<DSChip>`: a caller who wraps a chip
/// in a `Tooltip`, a `Hero` or their own gesture detector should not be locked
/// out of the container that lays it out.
class DSChipGroup extends StatelessWidget {
  const DSChipGroup({
    super.key,
    required this.children,
    this.selectionMode = DSChipSelectionMode.multiple,
    this.scrollable = false,
    this.selectedFirst = false,
    this.maxVisible,
    this.style,
  });

  final List<Widget> children;
  final DSChipSelectionMode selectionMode;
  final bool scrollable;

  /// Leads with what is on, so the user does not re-read the row to find out
  /// what they filtered by. Only reorders children that are [DSChip]s — a
  /// caller's own wrapper keeps the position it was given.
  final bool selectedFirst;

  /// Beyond this many, an overflow chip that names how many are hidden.
  final int? maxVisible;

  final DSChipStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSChipStyle.resolve(
      context,
      DSChipRole.filter,
      null,
      DSTone.neutral,
      style,
    );
    final gap = resolved.barGap!;
    assert(
      gap >= 8,
      'DSChipGroup lays 48dp targets side by side, and WCAG 2.2 SC 2.5.8 asks '
      'for 8dp between them. A barGap of $gap lets two targets overlap, so '
      'the chip a user hits is not the one they aimed at.',
    );

    var ordered = children;
    if (selectedFirst) {
      ordered = [...children]
        ..sort((a, b) {
          final av = a is DSChip && a.selected ? 0 : 1;
          final bv = b is DSChip && b.selected ? 0 : 1;
          return av.compareTo(bv);
        });
    }

    var hidden = 0;
    if (maxVisible != null && ordered.length > maxVisible!) {
      hidden = ordered.length - maxVisible!;
      ordered = ordered.take(maxVisible!).toList();
    }

    final laid = <Widget>[
      ...ordered,
      if (hidden > 0)
        // Named rather than counted: "+3" alone tells a reader nothing about
        // what it is three of, so the chip's own label is replaced for the
        // reader while the row keeps its compact "+3".
        Semantics(
          label: '$hidden more filters',
          excludeSemantics: true,
          child: DSChip(label: '+$hidden'),
        ),
    ];

    final row = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < laid.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  laid[i],
                ],
              ],
            ),
          )
        : Wrap(spacing: gap, runSpacing: gap, children: laid);

    // A single-select row is a mutually exclusive group, which is what makes
    // both platforms announce "3 of 8".
    return Semantics(
      container: true,
      explicitChildNodes: true,
      inMutuallyExclusiveGroup: selectionMode == DSChipSelectionMode.single
          ? true
          : null,
      child: row,
    );
  }
}
