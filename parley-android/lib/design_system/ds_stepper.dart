// ds-tier: 2 — molecule

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:parley_android/design_system/_tap_target.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two designed stepper scales.
///
/// The compact *visual* is 36 points and its *target* is still the tap-target
/// floor. Shrinking the target along with the visual is the single most common
/// accessibility regression in a dense list, so the two are decoupled by
/// construction rather than by discipline.
enum DSStepperSize { compact, md }

/// [DSStepper]'s appearance, as data.
@immutable
class DSStepperStyle extends DSComponentStyle<DSStepperStyle> {
  const DSStepperStyle({
    this.height,
    this.buttonExtent,
    this.valueMinWidth,
    this.iconSize,
    this.radius,
    this.containerColor,
    this.pressedColor,
    this.dividerPolicy,
    this.valueStyle,
    this.labelStyle,
    this.decrementIcon,
    this.incrementIcon,
    this.repeatDelay,
    this.repeatInterval,
  });

  final double? height;
  final double? buttonExtent;

  /// Wide enough that 9 becoming 10 does not move the buttons under the
  /// user's thumb.
  final double? valueMinWidth;

  final double? iconSize;
  final BorderRadius? radius;
  final Color? containerColor;
  final Color? pressedColor;
  final DividerPolicy? dividerPolicy;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final IconData? decrementIcon;
  final IconData? incrementIcon;

  /// How long a hold waits before repeating, and how fast it repeats.
  ///
  /// Exposed because a build for a slow-motor audience has to slow both. There
  /// is deliberately no field to switch repeating *off* — that is
  /// [DSStepper.enableLongPressRepeat], a behaviour flag on the widget rather
  /// than paint.
  final Duration? repeatDelay;
  final Duration? repeatInterval;

  @override
  DSStepperStyle merge(DSStepperStyle? other) {
    if (other == null) return this;
    return DSStepperStyle(
      height: other.height ?? height,
      buttonExtent: other.buttonExtent ?? buttonExtent,
      valueMinWidth: other.valueMinWidth ?? valueMinWidth,
      iconSize: other.iconSize ?? iconSize,
      radius: other.radius ?? radius,
      containerColor: other.containerColor ?? containerColor,
      pressedColor: other.pressedColor ?? pressedColor,
      dividerPolicy: other.dividerPolicy ?? dividerPolicy,
      valueStyle: other.valueStyle ?? valueStyle,
      labelStyle: other.labelStyle ?? labelStyle,
      decrementIcon: other.decrementIcon ?? decrementIcon,
      incrementIcon: other.incrementIcon ?? incrementIcon,
      repeatDelay: other.repeatDelay ?? repeatDelay,
      repeatInterval: other.repeatInterval ?? repeatInterval,
    );
  }

  @override
  DSStepperStyle copyWith({
    double? height,
    double? buttonExtent,
    double? valueMinWidth,
    double? iconSize,
    BorderRadius? radius,
    Color? containerColor,
    Color? pressedColor,
    DividerPolicy? dividerPolicy,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
    IconData? decrementIcon,
    IconData? incrementIcon,
    Duration? repeatDelay,
    Duration? repeatInterval,
  }) => DSStepperStyle(
    height: height ?? this.height,
    buttonExtent: buttonExtent ?? this.buttonExtent,
    valueMinWidth: valueMinWidth ?? this.valueMinWidth,
    iconSize: iconSize ?? this.iconSize,
    radius: radius ?? this.radius,
    containerColor: containerColor ?? this.containerColor,
    pressedColor: pressedColor ?? this.pressedColor,
    dividerPolicy: dividerPolicy ?? this.dividerPolicy,
    valueStyle: valueStyle ?? this.valueStyle,
    labelStyle: labelStyle ?? this.labelStyle,
    decrementIcon: decrementIcon ?? this.decrementIcon,
    incrementIcon: incrementIcon ?? this.incrementIcon,
    repeatDelay: repeatDelay ?? this.repeatDelay,
    repeatInterval: repeatInterval ?? this.repeatInterval,
  );

  @override
  DSStepperStyle lerp(DSStepperStyle? other, double t) {
    if (other == null) return this;
    return DSStepperStyle(
      height: lerpDouble(height, other.height, t),
      buttonExtent: lerpDouble(buttonExtent, other.buttonExtent, t),
      valueMinWidth: lerpDouble(valueMinWidth, other.valueMinWidth, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      containerColor: Color.lerp(containerColor, other.containerColor, t),
      pressedColor: Color.lerp(pressedColor, other.pressedColor, t),
      dividerPolicy: t < 0.5 ? dividerPolicy : other.dividerPolicy,
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      decrementIcon: t < 0.5 ? decrementIcon : other.decrementIcon,
      incrementIcon: t < 0.5 ? incrementIcon : other.incrementIcon,
      repeatDelay: t < 0.5 ? repeatDelay : other.repeatDelay,
      repeatInterval: t < 0.5 ? repeatInterval : other.repeatInterval,
    );
  }

  static DSStepperSize sizeOf(BuildContext context, DSStepperSize? size) =>
      size ??
      (DSScope.densityOf(context) == DSDensity.compact
          ? DSStepperSize.compact
          : DSStepperSize.md);

  static DSStepperStyle resolve(
    BuildContext context,
    DSStepperSize? size, [
    DSStepperStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;
    final compact = sizeOf(context, size) == DSStepperSize.compact;
    final height = compact
        ? design.component.fieldHeight - space.md
        : design.component.fieldHeight;

    return resolveStyle(
      context: context,
      specDefaults: DSStepperStyle(
        height: height,
        buttonExtent: height,
        valueMinWidth: compact
            ? design.component.wellSize
            : design.component.minTapTarget,
        iconSize: compact
            ? design.component.iconSizeSmall
            : design.component.iconSize,
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
        containerColor: palette.muted,
        pressedColor: palette.card,
        dividerPolicy: design.component.dividerPolicy,
        valueStyle: (compact ? text.titleSmall : text.titleMedium)
            ?.copyWith(
              color: palette.foreground,
              fontWeight: context.design.type.emphasisWeight,
            )
            .tabular,
        labelStyle: DSTextRole.fieldLabel.styleOf(context),
        decrementIcon: Icons.remove_rounded,
        incrementIcon: Icons.add_rounded,
        repeatDelay: design.motion.repeatDelay,
        repeatInterval: design.motion.repeatInterval,
      ),
      own: own,
    );
  }
}

/// A bounded numeric control: decrement, the value, increment.
///
/// See `docs/plans/06-ds-stepper.plan.md`. For a quantity the user adjusts by
/// small amounts and needs to read exactly — a count, a party size, a rating,
/// a repeat interval.
///
/// **It holds no state.** `value` in, [onChanged] out: a stepper with internal
/// state is a stepper that disagrees with the model it is editing.
///
/// At a bound the button is genuinely disabled and looks it. The most common
/// defect in a stepper is no feedback at the bound — the user taps, nothing
/// happens, and they tap harder.
class DSStepper extends StatefulWidget {
  const DSStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.enabled = true,
    this.loading = false,
    this.enableLongPressRepeat = true,
    this.errorText,
    this.semanticUnit = '',
    this.size,
    this.style,
    this.valueSlot,
    this.decrement,
    this.increment,
    this.valueFormatter,
    this.focusNode,
  }) : label = null,
       helperText = null,
       labelSlot = null,
       helper = null,
       assert(step > 0, 'a step of zero is a control that cannot move'),
       assert(min <= max),
       assert(
         value >= min && value <= max,
         'the value starts outside its own bounds',
       ),
       assert(
         (max - min) % step == 0,
         'a stepper that can be driven past its own bound by an odd step is '
         'a defect that surfaces as a disabled button the user can still '
         'reach',
       );

  /// The form-field form: a label, an optional helper, and the control below.
  ///
  /// A different thing from the bare control docked at a row's trailing edge —
  /// different semantics wrapper, different place in a layout.
  const DSStepper.labelled({
    super.key,
    required this.value,
    required this.onChanged,
    required String this.label,
    this.helperText,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.enabled = true,
    this.loading = false,
    this.enableLongPressRepeat = true,
    this.errorText,
    this.semanticUnit = '',
    this.size,
    this.style,
    this.valueSlot,
    this.decrement,
    this.increment,
    this.labelSlot,
    this.helper,
    this.valueFormatter,
    this.focusNode,
  }) : assert(step > 0),
       assert(min <= max),
       assert(value >= min && value <= max),
       assert((max - min) % step == 0);

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final bool loading;

  /// A behaviour flag rather than paint, which is why it is here and not on
  /// the style beside [DSStepperStyle.repeatDelay].
  final bool enableLongPressRepeat;

  /// Sets the error state. The message is always rendered — a border alone
  /// would leave colour carrying the meaning.
  final String? errorText;

  /// 'guests' makes the adjustable announce '3 guests'.
  final String semanticUnit;

  final DSStepperSize? size;
  final DSStepperStyle? style;

  /// The slot that makes the component general: a caller whose value is
  /// '2 kg', '$40', a duration or a localised plural renders it here and keeps
  /// the buttons, the bounds, the repeat, the haptics and the adjustable
  /// semantics.
  final Widget? valueSlot;

  /// Total replacement of a button's contents, for an identity whose minus is
  /// a custom glyph.
  final Widget? decrement;
  final Widget? increment;

  final String? label;
  final String? helperText;
  final Widget? labelSlot;
  final Widget? helper;

  /// Pluralisation, units and currency are all this function, and none of them
  /// is a branch inside the widget.
  final String Function(int value)? valueFormatter;

  /// The focus lands on the container rather than on either button, so the
  /// arrow keys reach the control and the ring draws around the whole of it.
  /// Supplying one is how a form moves focus into the stepper.
  final FocusNode? focusNode;

  @override
  State<DSStepper> createState() => _DSStepperState();
}

class _DSStepperState extends State<DSStepper> {
  Timer? _repeat;
  int _ticks = 0;
  int _direction = 0;

  bool get _canDecrease =>
      widget.enabled &&
      !widget.loading &&
      widget.value - widget.step >= widget.min;
  bool get _canIncrease =>
      widget.enabled &&
      !widget.loading &&
      widget.value + widget.step <= widget.max;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  String _format(int value) => widget.valueFormatter?.call(value) ?? '$value';

  String _spoken(int value) => widget.semanticUnit.isEmpty
      ? _format(value)
      : '${_format(value)} ${widget.semanticUnit}';

  void _tick(int direction) {
    final next = widget.value + direction * widget.step;
    if (next < widget.min || next > widget.max) {
      // The absence of feedback *is* the feedback. A bounce here reads as
      // "it worked".
      _stopRepeat();
      return;
    }
    AppHaptics.selection();
    widget.onChanged(next);
  }

  void _startRepeat(int direction, DSStepperStyle resolved) {
    if (!widget.enableLongPressRepeat) return;
    _direction = direction;
    _ticks = 0;
    final delay = resolved.repeatDelay ?? context.design.motion.repeatDelay;
    final interval =
        resolved.repeatInterval ?? context.design.motion.repeatInterval;
    _repeat?.cancel();
    _repeat = Timer(delay, () => _schedule(interval));
  }

  void _schedule(Duration interval) {
    _repeat?.cancel();
    _repeat = Timer.periodic(interval, (timer) {
      _ticks++;
      _tick(_direction);
      // Accelerates once the user has clearly committed to holding.
      if (_ticks == 6) _schedule(interval ~/ 2);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
    _ticks = 0;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowRight:
        if (!_canIncrease) return KeyEventResult.handled;
        _tick(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.arrowLeft:
        if (!_canDecrease) return KeyEventResult.handled;
        _tick(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        if (widget.enabled && !widget.loading) widget.onChanged(widget.min);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        if (widget.enabled && !widget.loading) widget.onChanged(widget.max);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final resolved = DSStepperStyle.resolve(context, widget.size, widget.style);
    final height = resolved.height ?? context.design.component.fieldHeight;
    final radius =
        resolved.radius ??
        BorderRadius.all(Radius.circular(context.radiusOf(AppShape.control)));
    final error = widget.errorText != null;

    final valueWidget =
        widget.valueSlot ??
        Text(
          _format(widget.value),
          style: resolved.valueStyle?.copyWith(
            color: widget.enabled ? null : palette.mutedForeground,
          ),
          maxLines: 1,
        );

    final control = Semantics(
      // One adjustable node for the whole control. This is what makes the
      // VoiceOver swipe-up/down gesture work, and it is why the two buttons
      // are not the primary nodes.
      slider: true,
      enabled: widget.enabled && !widget.loading,
      value: _spoken(widget.value),
      increasedValue: _canIncrease ? _spoken(widget.value + widget.step) : '',
      decreasedValue: _canDecrease ? _spoken(widget.value - widget.step) : '',
      onIncrease: _canIncrease ? () => _tick(1) : null,
      onDecrease: _canDecrease ? () => _tick(-1) : null,
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: _onKey,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.38,
          // The compact stepper paints a 36-point well, which is what makes it
          // sit in a list row without dominating it. Its two buttons are still
          // targets, and a target cannot be taller than the box it is in — so
          // the well stops being that box and becomes what is painted behind
          // one.
          child: DSShortTrack(
            height: height,
            background: DecoratedBox(
              decoration: BoxDecoration(
                color: resolved.containerColor ?? palette.muted,
                borderRadius: radius,
                border: error
                    ? Border.all(
                        color: palette.destructive,
                        width: context.design.component.hairlineWidth,
                      )
                    : null,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(
                  context,
                  resolved,
                  direction: -1,
                  enabled: _canDecrease,
                  icon: resolved.decrementIcon ?? Icons.remove_rounded,
                  label: 'Decrease',
                  replacement: widget.decrement,
                  radius: radius,
                ),
                if (resolved.dividerPolicy != DividerPolicy.none)
                  SizedBox(
                    width: context.design.component.hairlineWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: palette.borderSoft),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        resolved.valueMinWidth ??
                        context.design.component.minTapTarget,
                  ),
                  child: Center(
                    child: DSSkeleton(
                      enabled: widget.loading,
                      child: _AnimatedValue(
                        value: widget.value,
                        child: valueWidget,
                      ),
                    ),
                  ),
                ),
                if (resolved.dividerPolicy != DividerPolicy.none)
                  SizedBox(
                    width: context.design.component.hairlineWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: palette.borderSoft),
                    ),
                  ),
                _button(
                  context,
                  resolved,
                  direction: 1,
                  enabled: _canIncrease,
                  icon: resolved.incrementIcon ?? Icons.add_rounded,
                  label: 'Increase',
                  replacement: widget.increment,
                  radius: radius,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.label == null && widget.labelSlot == null && !error) {
      return control;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelSlot != null)
          widget.labelSlot!
        else if (widget.label != null)
          Text(widget.label!, style: resolved.labelStyle),
        if (widget.label != null || widget.labelSlot != null)
          SizedBox(height: space.xs),
        control,
        if (widget.helper != null || widget.helperText != null || error) ...[
          SizedBox(height: space.xs),
          widget.helper ??
              Text(
                widget.errorText ?? widget.helperText!,
                style: resolved.labelStyle?.copyWith(
                  color: error ? palette.destructive : null,
                ),
              ),
        ],
      ],
    );
  }

  Widget _button(
    BuildContext context,
    DSStepperStyle resolved, {
    required int direction,
    required bool enabled,
    required IconData icon,
    required String label,
    required Widget? replacement,
    required BorderRadius radius,
  }) {
    final extent = resolved.buttonExtent ?? resolved.height ?? 48;
    final target = context.design.component.minTapTarget;
    final palette = context.palette;

    final glyph =
        replacement ??
        Icon(
          icon,
          size: resolved.iconSize ?? context.design.component.iconSize,
          // Visibly dead rather than silently dead, which is the defect the
          // research names.
          color: enabled ? palette.foreground : palette.mutedForeground,
        );

    final name = widget.semanticUnit.isEmpty
        ? label
        : '$label ${widget.semanticUnit}';

    return Semantics(
      button: true,
      enabled: enabled,
      label: name,
      // Declared here because `excludeSemantics` removes the one the control
      // publishes for itself. Without it the node says "button", says what the
      // button is for, and offers nothing to activate — VoiceOver's double-tap
      // and TalkBack's click both arrive as this action.
      onTap: enabled ? () => _tick(direction) : null,
      excludeSemantics: true,
      child: DSPressable(
        enabled: false,
        focusShape: RoundedRectangleBorder(borderRadius: radius),
        // The container never scales: a control docked at a row's trailing
        // edge that scales visibly detaches from the row. DSPressable is here
        // for the zone fill contract, with its dip switched off.
        //
        // The tap target wraps the ink rather than sitting inside it: the ink
        // is the visual and stays the height of the well, and the target is
        // the box around it. Inside, the ripple would paint the twelve points
        // the well does not cover.
        child: DSTapTarget(
          child: DSInkSurface(
            onTap: enabled ? () => _tick(direction) : null,
            onTapDown: enabled
                ? (_) => _startRepeat(direction, resolved)
                : null,
            onTapUp: (_) => _stopRepeat(),
            onTapCancel: _stopRepeat,
            shape: RoundedRectangleBorder(borderRadius: radius),
            highlightColor: resolved.pressedColor ?? palette.card,
            // The floor is the `DSTapTarget` outside, not a constraint in
            // here: the ink stays the height of the well it paints.
            minTapTarget: false,
            // The visual is `extent`; the target is the floor. Decoupled by
            // construction rather than by discipline.
            child: SizedBox(
              width: extent < target ? target : extent,
              height: extent,
              child: Center(child: glyph),
            ),
          ),
        ),
      ),
    );
  }
}

/// The value, swapped in the direction of travel.
///
/// Direction is the second channel: it tells the user which button registered
/// even if they did not see the press.
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.design.motion;
    return AnimatedSwitcher(
      duration: motion.scaled(motion.instant),
      switchInCurve: motion.enter,
      switchOutCurve: motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<int>(value), child: child),
    );
  }
}
