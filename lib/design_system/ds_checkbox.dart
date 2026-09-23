// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a checkbox looks, at every layer of the resolution chain.
///
/// See `docs/plans/22-ds-selection-controls.plan.md` Section 8. Every field is
/// nullable, the defaults live in [resolve], and `lerp` interpolates rather
/// than snapping — the three rules `ds_component_style.dart` states.
@immutable
class DSCheckboxStyle extends DSComponentStyle<DSCheckboxStyle> {
  const DSCheckboxStyle({
    this.size,
    this.shape,
    this.strokeColor,
    this.strokeWidth,
    this.fillColor,
    this.checkColor,
    this.indeterminateColor,
    this.errorColor,
    this.disabledOpacity,
  });

  /// The drawn box. The gesture area is [ComponentSpec.minTapTarget] square
  /// and is not this number — see the class comment on [DSCheckbox].
  final double? size;

  /// The corner role. [ComponentSpec.checkboxShape] by default, which is what
  /// an identity sets to tick circles rather than boxes.
  final AppShape? shape;

  final Color? strokeColor;
  final double? strokeWidth;

  /// The fill once the box is ticked, and the mark drawn on it.
  final Color? fillColor;
  final Color? checkColor;

  /// The indeterminate bar. Separate from [checkColor] because a house that
  /// draws "mixed" in a muted tone should not have to restyle the tick.
  final Color? indeterminateColor;

  /// The stroke a box in error takes, so a required-and-unticked checkbox is
  /// visible without the caller drawing a second control beside it.
  final Color? errorColor;

  final double? disabledOpacity;

  @override
  DSCheckboxStyle merge(DSCheckboxStyle? other) {
    if (other == null) return this;
    return DSCheckboxStyle(
      size: other.size ?? size,
      shape: other.shape ?? shape,
      strokeColor: other.strokeColor ?? strokeColor,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      fillColor: other.fillColor ?? fillColor,
      checkColor: other.checkColor ?? checkColor,
      indeterminateColor: other.indeterminateColor ?? indeterminateColor,
      errorColor: other.errorColor ?? errorColor,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSCheckboxStyle copyWith({
    double? size,
    AppShape? shape,
    Color? strokeColor,
    double? strokeWidth,
    Color? fillColor,
    Color? checkColor,
    Color? indeterminateColor,
    Color? errorColor,
    double? disabledOpacity,
  }) => DSCheckboxStyle(
    size: size ?? this.size,
    shape: shape ?? this.shape,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    fillColor: fillColor ?? this.fillColor,
    checkColor: checkColor ?? this.checkColor,
    indeterminateColor: indeterminateColor ?? this.indeterminateColor,
    errorColor: errorColor ?? this.errorColor,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSCheckboxStyle lerp(DSCheckboxStyle? other, double t) {
    if (other == null) return this;
    return DSCheckboxStyle(
      // A corner role has no midpoint; it switches at the halfway mark.
      shape: t < 0.5 ? shape : other.shape,
      size: lerpDouble(size, other.size, t),
      strokeColor: Color.lerp(strokeColor, other.strokeColor, t),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      checkColor: Color.lerp(checkColor, other.checkColor, t),
      indeterminateColor: Color.lerp(
        indeterminateColor,
        other.indeterminateColor,
        t,
      ),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  /// The four layers, with the spec as layer 1.
  static DSCheckboxStyle resolve(BuildContext context, [DSCheckboxStyle? own]) {
    final component = context.design.component;
    final palette = context.palette;
    return resolveStyle(
      context: context,
      specDefaults: DSCheckboxStyle(
        size: component.checkboxSize,
        shape: component.checkboxShape,
        strokeColor: palette.border,
        strokeWidth: component.controlStroke,
        fillColor: palette.primary,
        checkColor: palette.primaryForeground,
        indeterminateColor: palette.primaryForeground,
        errorColor: palette.destructive,
        disabledOpacity: DSControlPaint.disabledOpacity,
      ),
      own: own,
    );
  }
}

/// The numbers the four selection controls draw themselves with, in one place.
///
/// Three controls fading a disabled state at three opacities is the same class
/// of defect as three sheets drawing one grabber at two widths, and it is not
/// a `ComponentSpec` field because it is not an identity's decision — WCAG's
/// disabled convention is 38% everywhere.
abstract final class DSControlPaint {
  static const double disabledOpacity = 0.38;
}

/// A box that is ticked, unticked, or — when [tristate] — neither.
///
/// See `docs/plans/22-ds-selection-controls.plan.md`. Three things distinguish
/// it from the twenty-eight-line [Checkbox] wrapper it replaces.
///
/// **The visual size and the tap target are two numbers.** The box is
/// [ComponentSpec.checkboxSize] and the gesture area is
/// [ComponentSpec.minTapTarget], so a control that meets the platform floor is
/// not also a grey slab. The old wrapper passed `VisualDensity.compact`, which
/// shrinks *both*.
///
/// **`null` is a value, not a missing one.** `onChanged` was already typed
/// `ValueChanged<bool?>` while `value` was a plain `bool`, so the third state
/// the signature promised could not be represented — which is exactly the
/// checkbox a "select all" over a partial selection needs. It announces
/// "mixed", the platform and ARIA term.
///
/// **The tick is drawn, not faded in.** A check that fades reads as an image
/// arriving; a check that draws reads as an act. It is two segments over
/// `motion.fast`, and under reduced motion it simply appears.
///
/// **Use when** a selection is committed by something else — a form's submit,
/// a list's "delete selected". **Instead:** [DSSwitch] when the change takes
/// effect the moment it is made. That distinction is semantic, not visual, and
/// no amount of styling fixes getting it wrong.
///
/// A bare checkbox carries no words, so [semanticLabel] is required unless a
/// [DSControlTile] is supplying the name.
class DSCheckbox extends StatefulWidget {
  const DSCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.semanticLabel,
    this.error = false,
    this.style,
    this.inTile = false,
  }) : assert(
         tristate || value != null,
         'a checkbox with `value: null` must set `tristate: true` — null is '
         'the indeterminate state, and a two-state box has nowhere to draw it',
       ),
       assert(
         semanticLabel != null || inTile,
         'a bare checkbox must be given a semanticLabel — the box carries no '
         'text of its own, so without one a form of five reads as five '
         'identical questions. A DSCheckboxTile supplies it from the label',
       );

  /// `null` is indeterminate, and only legal when [tristate].
  final bool? value;

  /// Null disables the control, which is Flutter's own convention and the one
  /// `docs/plans/00b-composition.plan.md` Section 6 adopted for the kit.
  final ValueChanged<bool?>? onChanged;

  /// Whether tapping cycles through the indeterminate state.
  final bool tristate;

  final String? semanticLabel;

  /// A required box that has not been ticked. Draws the error stroke and
  /// reports itself, so the message does not have to float somewhere else.
  final bool error;

  final DSCheckboxStyle? style;

  /// Set by [DSControlTile], which owns the row's name and its gesture. It
  /// waives [semanticLabel] and lets the tile be the one semantics node.
  final bool inTile;

  @override
  State<DSCheckbox> createState() => _DSCheckboxState();
}

class _DSCheckboxState extends State<DSCheckbox>
    with SingleTickerProviderStateMixin {
  // Created without a duration and given one in `didChangeDependencies`. A
  // `late final` that reads `context` is forced by `dispose()` when the build
  // it belonged to threw, and looking an ancestor up from a deactivated
  // element is an assertion of its own — one that hides the real failure.
  late final AnimationController _mark = AnimationController(
    vsync: this,
    value: widget.value == false ? 0 : 1,
  );

  bool _scopeEnabled = true;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = DSScope.enabledOf(context) ?? true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _mark.duration = context.design.motion.scaled(context.design.motion.fast);
  }

  @override
  void didUpdateWidget(covariant DSCheckbox old) {
    super.didUpdateWidget(old);
    final wants = widget.value == false ? 0.0 : 1.0;
    if (_reducedMotion) {
      _mark.value = wants;
    } else if (_mark.value != wants) {
      _mark.animateTo(wants);
    }
  }

  @override
  void dispose() {
    _mark.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null && _scopeEnabled;

  /// false → true → null → false, which is the order both platforms cycle in.
  void _toggle() {
    if (!_enabled) return;
    AppHaptics.selection();
    final bool? next = switch (widget.value) {
      false => true,
      true => widget.tristate ? null : false,
      _ => false,
    };
    widget.onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSCheckboxStyle.resolve(context, widget.style);
    final component = context.design.component;
    final shape = context.shapeOf(resolved.shape!);
    final size = resolved.size!;

    final Widget box = DSPressable(
      enabled: _enabled,
      focusShape: shape,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _mark,
          builder: (context, _) => CustomPaint(
            size: Size.square(size),
            painter: _CheckboxPainter(
              shape: shape,
              curve: context.design.motion.enter,
              progress: _mark.value,
              indeterminate: widget.value == null,
              strokeColor: widget.error
                  ? resolved.errorColor!
                  : resolved.strokeColor!,
              strokeWidth: resolved.strokeWidth!,
              fillColor: widget.error
                  ? resolved.errorColor!
                  : resolved.fillColor!,
              markColor: widget.value == null
                  ? resolved.indeterminateColor!
                  : resolved.checkColor!,
            ),
          ),
        ),
      ),
    );

    // The gesture area is the target, the drawing is the control. Opaque so
    // the whole square is hit, not only the pixels the box covers.
    final Widget target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? _toggle : null,
      child: SizedBox(
        width: component.minTapTarget,
        height: component.minTapTarget,
        child: Center(child: box),
      ),
    );

    final Widget faded = _enabled
        ? target
        : Opacity(opacity: resolved.disabledOpacity!, child: target);

    if (widget.inTile) return ExcludeSemantics(child: faded);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      checked: widget.value ?? false,
      mixed: widget.tristate ? widget.value == null : null,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: ExcludeSemantics(child: faded),
    );
  }
}

/// The box, its fill, and whichever mark belongs in it.
class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({
    required this.shape,
    required this.curve,
    required this.progress,
    required this.indeterminate,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillColor,
    required this.markColor,
  });

  final OutlinedBorder shape;

  /// The identity's easing. Passed in rather than reached for: a painter has
  /// no [BuildContext], and a hand-typed curve here is how one control ends
  /// up easing differently from the row it sits in.
  final Curve curve;

  /// 0 empty, 1 marked. The fill and the mark are both driven from it: the
  /// fill over the first half, the mark over the second, so the tick is drawn
  /// onto a box that is already accented rather than racing it.
  final double progress;
  final bool indeterminate;
  final Color strokeColor;
  final double strokeWidth;
  final Color fillColor;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect, textDirection: TextDirection.ltr);

    final fill = curve.transform(progress.clamp(0, 1));
    if (fill > 0) {
      canvas.drawPath(path, Paint()..color = fillColor.withValues(alpha: fill));
    }

    // The stroke fades out as the fill arrives; two full-strength edges at
    // once read as a second border.
    if (fill < 1) {
      final inset = rect.deflate(strokeWidth / 2);
      canvas.drawPath(
        shape.getOuterPath(inset, textDirection: TextDirection.ltr),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = strokeColor.withValues(alpha: 1 - fill),
      );
    }

    if (progress <= 0) return;
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = markColor;

    if (indeterminate) {
      // A bar that scales from the centre, so the transition out of a tick
      // reads as the tick collapsing rather than as two unrelated marks.
      final half = size.width * 0.28 * progress;
      canvas.drawLine(
        Offset(size.width / 2 - half, size.height / 2),
        Offset(size.width / 2 + half, size.height / 2),
        mark,
      );
      return;
    }

    // Two segments, drawn in order. `PathMetric.extractPath` is what makes it
    // a stroke that travels rather than an image that fades.
    final check = Path()
      ..moveTo(size.width * 0.26, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.71)
      ..lineTo(size.width * 0.76, size.height * 0.31);
    final metric = check.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * curve.transform(progress)),
      mark,
    );
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) =>
      old.progress != progress ||
      old.indeterminate != indeterminate ||
      old.strokeColor != strokeColor ||
      old.fillColor != fillColor ||
      old.markColor != markColor ||
      old.strokeWidth != strokeWidth ||
      old.shape != shape ||
      old.curve != curve;
}
