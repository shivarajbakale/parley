// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_checkbox.dart' show DSControlPaint;
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The glyph a switch draws inside its thumb, if any.
///
/// A function rather than two `IconData?` fields because the ✓ / ✕ pair some
/// houses use, the single icon that appears only when on, and the no-icon
/// default are all the same shape of answer — and a strategy covers all three
/// without the component growing a variant for each (plan 22 Section 8).
typedef DSSwitchThumbIcon = IconData? Function(bool value);

/// How a switch looks, at every layer of the resolution chain.
@immutable
class DSSwitchStyle extends DSComponentStyle<DSSwitchStyle> {
  const DSSwitchStyle({
    this.trackWidth,
    this.trackHeight,
    this.thumbSize,
    this.pressedThumbSize,
    this.trackOn,
    this.trackOff,
    this.trackBorderColor,
    this.thumbOn,
    this.thumbOff,
    this.thumbIcon,
    this.disabledOpacity,
  });

  final double? trackWidth;
  final double? trackHeight;

  /// The thumb at rest, and the size it grows to while a finger is on it —
  /// the platform behaviour on both, and absent from the switch this replaced.
  final double? thumbSize;
  final double? pressedThumbSize;

  final Color? trackOn;
  final Color? trackOff;

  /// The hairline around an off track. Without it an off switch on a recessed
  /// surface is a shape the eye has to find rather than one it sees.
  final Color? trackBorderColor;

  final Color? thumbOn;
  final Color? thumbOff;

  /// Data, not behaviour: it maps a value to a glyph and returns nothing else.
  final DSSwitchThumbIcon? thumbIcon;

  final double? disabledOpacity;

  @override
  DSSwitchStyle merge(DSSwitchStyle? other) {
    if (other == null) return this;
    return DSSwitchStyle(
      trackWidth: other.trackWidth ?? trackWidth,
      trackHeight: other.trackHeight ?? trackHeight,
      thumbSize: other.thumbSize ?? thumbSize,
      pressedThumbSize: other.pressedThumbSize ?? pressedThumbSize,
      trackOn: other.trackOn ?? trackOn,
      trackOff: other.trackOff ?? trackOff,
      trackBorderColor: other.trackBorderColor ?? trackBorderColor,
      thumbOn: other.thumbOn ?? thumbOn,
      thumbOff: other.thumbOff ?? thumbOff,
      thumbIcon: other.thumbIcon ?? thumbIcon,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSSwitchStyle copyWith({
    double? trackWidth,
    double? trackHeight,
    double? thumbSize,
    double? pressedThumbSize,
    Color? trackOn,
    Color? trackOff,
    Color? trackBorderColor,
    Color? thumbOn,
    Color? thumbOff,
    DSSwitchThumbIcon? thumbIcon,
    double? disabledOpacity,
  }) => DSSwitchStyle(
    trackWidth: trackWidth ?? this.trackWidth,
    trackHeight: trackHeight ?? this.trackHeight,
    thumbSize: thumbSize ?? this.thumbSize,
    pressedThumbSize: pressedThumbSize ?? this.pressedThumbSize,
    trackOn: trackOn ?? this.trackOn,
    trackOff: trackOff ?? this.trackOff,
    trackBorderColor: trackBorderColor ?? this.trackBorderColor,
    thumbOn: thumbOn ?? this.thumbOn,
    thumbOff: thumbOff ?? this.thumbOff,
    thumbIcon: thumbIcon ?? this.thumbIcon,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSSwitchStyle lerp(DSSwitchStyle? other, double t) {
    if (other == null) return this;
    return DSSwitchStyle(
      // A glyph strategy has no midpoint.
      thumbIcon: t < 0.5 ? thumbIcon : other.thumbIcon,
      trackWidth: lerpDouble(trackWidth, other.trackWidth, t),
      trackHeight: lerpDouble(trackHeight, other.trackHeight, t),
      thumbSize: lerpDouble(thumbSize, other.thumbSize, t),
      pressedThumbSize: lerpDouble(pressedThumbSize, other.pressedThumbSize, t),
      trackOn: Color.lerp(trackOn, other.trackOn, t),
      trackOff: Color.lerp(trackOff, other.trackOff, t),
      trackBorderColor: Color.lerp(trackBorderColor, other.trackBorderColor, t),
      thumbOn: Color.lerp(thumbOn, other.thumbOn, t),
      thumbOff: Color.lerp(thumbOff, other.thumbOff, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  static DSSwitchStyle resolve(
    BuildContext context, [
    DSSwitchStyle? own,
    bool compact = false,
  ]) {
    final component = context.design.component;
    final palette = context.palette;
    return resolveStyle(
      context: context,
      specDefaults: DSSwitchStyle(
        trackWidth: compact
            ? component.switchCompactTrackWidth
            : component.switchTrackWidth,
        trackHeight: compact
            ? component.switchCompactTrackHeight
            : component.switchTrackHeight,
        thumbSize: compact
            ? component.switchCompactThumbSize
            : component.switchThumbSize,
        pressedThumbSize: compact
            ? component.switchCompactPressedThumbSize
            : component.switchPressedThumbSize,
        trackOn: palette.primary,
        trackOff: palette.muted,
        trackBorderColor: palette.border,
        thumbOn: palette.primaryForeground,
        thumbOff: palette.border,
        disabledOpacity: DSControlPaint.disabledOpacity,
      ),
      own: own,
    );
  }
}

/// A control whose two positions take effect the moment they are moved.
///
/// See `docs/plans/22-ds-selection-controls.plan.md`. **Use when** flipping it
/// *is* the action — cellular sync on, notifications off. **Instead:**
/// [DSCheckbox] when something else commits the choice. That is a semantic
/// distinction, not a visual one, and it is the most common misuse in any kit.
///
/// The switch draws itself from [ComponentSpec] rather than wrapping
/// `Switch.adaptive`, which is what makes [DSSwitchStyle] real: the track was
/// previously whatever Material or Cupertino had chosen, so a house style
/// could not move it and the pressed-thumb growth both platforms ship was
/// missing on both. The geometry is one line off Cupertino's and equal to
/// Material 3's, so the control still reads as native on either.
///
/// The label, subtitle and icon that used to build a row here are gone: a
/// labelled switch is a [DSSwitchTile]. Three components built that row by
/// hand at two different vertical paddings, which is why a settings screen
/// with a switch above a slider had rows of two heights.
class DSSwitch extends StatefulWidget {
  const DSSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.semanticLabel,
    this.style,
    this.inTile = false,
    this.compact = false,
  }) : assert(
         semanticLabel != null || inTile,
         'a bare switch must be given a semanticLabel — a switch is a shape '
         'with two positions and no words in it, so a screen holding four of '
         'them announces "switch, on" four times. A DSSwitchTile supplies it',
       );

  final bool value;

  /// Null disables the control — Flutter's convention, adopted kit-wide by
  /// `docs/plans/00b-composition.plan.md` Section 6.
  final ValueChanged<bool>? onChanged;

  final String? semanticLabel;
  final DSSwitchStyle? style;

  /// Set by [DSControlTile], which owns the row's name and its gesture.
  final bool inTile;

  /// The smaller track a list row carries ([ComponentSpec.switchCompactTrackWidth]).
  /// [DSSwitchTile] sets it; a switch placed by hand in a row should too. The
  /// tap target stays [ComponentSpec.minTapTarget] either way.
  final bool compact;

  @override
  State<DSSwitch> createState() => _DSSwitchState();
}

class _DSSwitchState extends State<DSSwitch> with TickerProviderStateMixin {
  /// Where the thumb is, 0 off and 1 on. Its own controller because it settles
  /// on a spring while the colours cross-fade on a duration — one animation
  /// driving both would make the track's colour overshoot with the thumb.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  late final AnimationController _press = AnimationController(vsync: this);

  /// Read once when the dependencies change, not from a gesture callback.
  /// `dependOnInheritedWidgetOfExactType` is a build-phase operation, and
  /// reaching for it from `onTapDown` throws the moment the row it is in has
  /// been rebuilt out from under the pointer.
  bool _scopeEnabled = true;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeEnabled = DSScope.enabledOf(context) ?? true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final motion = context.design.motion;
    _travel.duration = motion.scaled(motion.fast);
    _press.duration = motion.scaled(motion.press);
  }

  @override
  void didUpdateWidget(covariant DSSwitch old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    final target = widget.value ? 1.0 : 0.0;
    if (_reducedMotion || !context.springsAvailable) {
      _travel.animateTo(target);
    } else {
      _travel.animateWith(
        context.design.motion.simulation(from: _travel.value, to: target),
      );
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null && _scopeEnabled;

  void _toggle() {
    if (!_enabled) return;
    AppHaptics.selection();
    widget.onChanged!(!widget.value);
  }

  void _setPressed(bool down) {
    if (!_enabled || _reducedMotion) return;
    down ? _press.forward() : _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSwitchStyle.resolve(
      context,
      widget.style,
      widget.compact,
    );
    final component = context.design.component;

    final Widget track = DSPressable(
      // The switch does not dip. A control docked at a row's trailing edge
      // that shrinks under the finger detaches from the row; the thumb's
      // growth is the press feedback, and the ring is what this is here for.
      enabled: false,
      focusShape: const StadiumBorder(),
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
          animation: Listenable.merge([_travel, _press]),
          builder: (context, _) {
            final t = _travel.value.clamp(0.0, 1.0);
            final thumb = lerpDouble(
              resolved.thumbSize!,
              resolved.pressedThumbSize!,
              _press.value,
            )!;
            final icon = resolved.thumbIcon?.call(widget.value);
            return SizedBox(
              width: resolved.trackWidth,
              height: resolved.trackHeight,
              child: CustomPaint(
                painter: _SwitchPainter(
                  travel: _travel.value,
                  thumbSize: thumb,
                  trackColor: Color.lerp(
                    resolved.trackOff!,
                    resolved.trackOn!,
                    t,
                  )!,
                  borderColor: resolved.trackBorderColor!.withValues(
                    alpha: 1 - t,
                  ),
                  borderWidth: component.hairlineWidth,
                  thumbColor: Color.lerp(
                    resolved.thumbOff!,
                    resolved.thumbOn!,
                    t,
                  )!,
                ),
                child: icon == null
                    ? null
                    : Align(
                        alignment: Alignment(_travel.value * 2 - 1, 0),
                        child: SizedBox(
                          width: resolved.thumbSize,
                          height: resolved.thumbSize,
                          child: Icon(
                            icon,
                            size: component.iconSizeMicro,
                            color: Color.lerp(
                              resolved.trackOff!,
                              resolved.trackOn!,
                              t,
                            ),
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );

    final Widget target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? _toggle : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: component.minTapTarget,
          minHeight: component.minTapTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: track),
      ),
    );

    final Widget faded = _enabled
        ? target
        : Opacity(opacity: resolved.disabledOpacity!, child: target);

    if (widget.inTile) return ExcludeSemantics(child: faded);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: ExcludeSemantics(child: faded),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  const _SwitchPainter({
    required this.travel,
    required this.thumbSize,
    required this.trackColor,
    required this.borderColor,
    required this.borderWidth,
    required this.thumbColor,
  });

  /// May sit slightly outside [0, 1] while the spring overshoots, which is the
  /// part that reads as physical. The thumb is clamped to the track's inside
  /// so the overshoot shows as a squeeze against the end rather than a thumb
  /// leaving the control.
  final double travel;
  final double thumbSize;
  final Color trackColor;
  final Color borderColor;
  final double borderWidth;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, radius),
      Paint()..color = trackColor,
    );
    if (borderColor.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(track.deflate(borderWidth / 2), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor,
      );
    }

    final inset = (size.height - thumbSize) / 2;
    final travelWidth = size.width - thumbSize - inset * 2;
    final x = (inset + travelWidth * travel).clamp(
      inset,
      size.width - thumbSize - inset,
    );
    canvas.drawOval(
      Rect.fromLTWH(x, inset, thumbSize, thumbSize),
      Paint()..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      old.travel != travel ||
      old.thumbSize != thumbSize ||
      old.trackColor != trackColor ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.thumbColor != thumbColor;
}
