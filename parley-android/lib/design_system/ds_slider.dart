// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A window on a continuum: the two ends of a [DSRangeSlider].
///
/// Its own value class rather than Material's `RangeValues` so the kit does
/// not re-export a Material type through its public API — the same reason plan
/// 15 opened the navigation bar's destination model.
@immutable
class DSRange {
  const DSRange(this.start, this.end);

  final double start;
  final double end;

  DSRange copyWith({double? start, double? end}) =>
      DSRange(start ?? this.start, end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is DSRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DSRange($start, $end)';
}

/// Turns a slider's raw double into the words the user reads.
///
/// It is the injected strategy rather than a format string because percentage,
/// currency, duration and byte-rate are all correct answers depending on the
/// caller — and because it feeds the *accessibility* value as well as the
/// visible one, so the two cannot disagree. A screen reader reading
/// "0.6299999999" while the screen shows "63%" is the defect this replaces.
typedef DSSliderFormatter = String Function(double value);

/// Where the formatted value is drawn.
enum DSSliderValuePosition { trailing, above, none }

/// How a slider looks, at every layer of the resolution chain.
@immutable
class DSSliderStyle extends DSComponentStyle<DSSliderStyle> {
  const DSSliderStyle({
    this.trackHeight,
    this.activeColor,
    this.inactiveColor,
    this.thumbSize,
    this.pressedThumbSize,
    this.thumbColor,
    this.thumbShadows,
    this.tickSize,
    this.showTicks,
    this.valueTextStyle,
    this.valuePosition,
    this.focusColor,
    this.focusRingWidth,
    this.disabledOpacity,
  });

  final double? trackHeight;
  final Color? activeColor;

  /// The remainder of the track. [Palette.muted]. A surface colour is not enough here: a recess is a *surface*, so the track vanished the
  /// moment the control was placed on a card.
  final Color? inactiveColor;

  final double? thumbSize;
  final double? pressedThumbSize;
  final Color? thumbColor;
  final List<BoxShadow>? thumbShadows;

  final double? tickSize;

  /// Null means "when there are divisions", which is the only correct default:
  /// ticks on a continuum are noise, and a discrete track without them hides
  /// the stops the thumb is going to snap to.
  final bool? showTicks;

  final TextStyle? valueTextStyle;
  final DSSliderValuePosition? valuePosition;

  /// The ring drawn around a focused thumb, and how thick it is.
  final Color? focusColor;
  final double? focusRingWidth;

  final double? disabledOpacity;

  @override
  DSSliderStyle merge(DSSliderStyle? other) {
    if (other == null) return this;
    return DSSliderStyle(
      trackHeight: other.trackHeight ?? trackHeight,
      activeColor: other.activeColor ?? activeColor,
      inactiveColor: other.inactiveColor ?? inactiveColor,
      thumbSize: other.thumbSize ?? thumbSize,
      pressedThumbSize: other.pressedThumbSize ?? pressedThumbSize,
      thumbColor: other.thumbColor ?? thumbColor,
      thumbShadows: other.thumbShadows ?? thumbShadows,
      tickSize: other.tickSize ?? tickSize,
      showTicks: other.showTicks ?? showTicks,
      valueTextStyle: other.valueTextStyle ?? valueTextStyle,
      valuePosition: other.valuePosition ?? valuePosition,
      focusColor: other.focusColor ?? focusColor,
      focusRingWidth: other.focusRingWidth ?? focusRingWidth,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSSliderStyle copyWith({
    double? trackHeight,
    Color? activeColor,
    Color? inactiveColor,
    double? thumbSize,
    double? pressedThumbSize,
    Color? thumbColor,
    List<BoxShadow>? thumbShadows,
    double? tickSize,
    bool? showTicks,
    TextStyle? valueTextStyle,
    DSSliderValuePosition? valuePosition,
    Color? focusColor,
    double? focusRingWidth,
    double? disabledOpacity,
  }) => DSSliderStyle(
    trackHeight: trackHeight ?? this.trackHeight,
    activeColor: activeColor ?? this.activeColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    thumbSize: thumbSize ?? this.thumbSize,
    pressedThumbSize: pressedThumbSize ?? this.pressedThumbSize,
    thumbColor: thumbColor ?? this.thumbColor,
    thumbShadows: thumbShadows ?? this.thumbShadows,
    tickSize: tickSize ?? this.tickSize,
    showTicks: showTicks ?? this.showTicks,
    valueTextStyle: valueTextStyle ?? this.valueTextStyle,
    valuePosition: valuePosition ?? this.valuePosition,
    focusColor: focusColor ?? this.focusColor,
    focusRingWidth: focusRingWidth ?? this.focusRingWidth,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSSliderStyle lerp(DSSliderStyle? other, double t) {
    if (other == null) return this;
    return DSSliderStyle(
      // Two flag-or-enum fields with no midpoint.
      showTicks: t < 0.5 ? showTicks : other.showTicks,
      valuePosition: t < 0.5 ? valuePosition : other.valuePosition,
      trackHeight: lerpDouble(trackHeight, other.trackHeight, t),
      activeColor: Color.lerp(activeColor, other.activeColor, t),
      inactiveColor: Color.lerp(inactiveColor, other.inactiveColor, t),
      thumbSize: lerpDouble(thumbSize, other.thumbSize, t),
      pressedThumbSize: lerpDouble(pressedThumbSize, other.pressedThumbSize, t),
      thumbColor: Color.lerp(thumbColor, other.thumbColor, t),
      thumbShadows: BoxShadow.lerpList(thumbShadows, other.thumbShadows, t),
      tickSize: lerpDouble(tickSize, other.tickSize, t),
      valueTextStyle: TextStyle.lerp(valueTextStyle, other.valueTextStyle, t),
      focusColor: Color.lerp(focusColor, other.focusColor, t),
      focusRingWidth: lerpDouble(focusRingWidth, other.focusRingWidth, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  static DSSliderStyle resolve(BuildContext context, [DSSliderStyle? own]) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return resolveStyle(
      context: context,
      specDefaults: DSSliderStyle(
        trackHeight: component.sliderTrackHeight,
        activeColor: palette.primary,
        inactiveColor: palette.muted,
        thumbSize: component.sliderThumbSize,
        pressedThumbSize: component.sliderPressedThumbSize,
        thumbColor: palette.primary,
        thumbShadows: design.elevation.resolve(
          elevation: design.elevation.levelOf(DSElevation.low),
          brightness: palette.brightness,
          shadowColor: palette.overlay,
        ),
        tickSize: component.sliderTickSize,
        // Tabular figures, so the value does not shift the row's width as
        // the thumb moves. A number that jitters while being dragged is the
        // most visible typographic defect a control can have.
        valueTextStyle: text.labelMedium
            ?.copyWith(color: palette.foreground)
            .tabular,
        valuePosition: DSSliderValuePosition.trailing,
        focusColor: palette.primary,
        focusRingWidth: component.focusRingWidth,
        disabledOpacity: 0.38,
      ),
      own: own,
    );
  }

  /// The Material theme this style implies.
  ///
  /// One place, so a slider and a range slider cannot be themed differently,
  /// and so no colour reaches `Slider` as a raw argument — which is what the
  /// three hand-passed `colorScheme` colours this replaces were.
  /// [grab] is how far the thumb under the finger has grown, 0 at rest and 1
  /// at [pressedThumbSize]. It is a parameter rather than a field because it
  /// changes sixty times a second and a style is a value: threading it here
  /// keeps one theme per frame instead of one style object per frame.
  SliderThemeData toSliderTheme(
    BuildContext context, {
    required bool ticks,
    double grab = 0,
  }) {
    final palette = context.palette;
    return SliderThemeData(
      trackHeight: trackHeight,
      activeTrackColor: activeColor,
      inactiveTrackColor: inactiveColor,
      thumbColor: thumbColor,
      disabledActiveTrackColor: activeColor!.withValues(
        alpha: disabledOpacity!,
      ),
      disabledInactiveTrackColor: inactiveColor!.withValues(
        alpha: disabledOpacity!,
      ),
      disabledThumbColor: thumbColor!.withValues(alpha: disabledOpacity!),
      activeTickMarkColor: palette.primaryForeground,
      inactiveTickMarkColor: palette.mutedForeground,
      tickMarkShape: ticks
          ? RoundSliderTickMarkShape(tickMarkRadius: tickSize! / 2)
          : SliderTickMarkShape.noTickMark,
      // The overlay is Material's own hover halo. The kit's press feedback is
      // the thumb's growth and its focus feedback is the ring, both drawn by
      // the thumb shape, so a second translucent disc under them is one signal
      // too many.
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: DSSliderThumb(
        grab: grab,
        size: thumbSize!,
        pressedSize: pressedThumbSize!,
        tapTarget: context.design.component.minTapTarget,
        shadows: thumbShadows ?? const [],
        focusColor: focusColor!,
        focusRingWidth: focusRingWidth!,
      ),
      rangeThumbShape: DSRangeSliderThumb(
        grab: grab,
        size: thumbSize!,
        pressedSize: pressedThumbSize!,
        tapTarget: context.design.component.minTapTarget,
        shadows: thumbShadows ?? const [],
      ),
      showValueIndicator: ShowValueIndicator.never,
    );
  }
}

/// The thumb: a disc that grows under the finger and rings when focused.
///
/// A [SliderComponentShape] rather than a widget because it is the only place
/// Material hands out the activation and the enable animations, which is what
/// makes the growth a state of the control rather than a second gesture
/// recogniser racing the drag.
class DSSliderThumb extends SliderComponentShape {
  const DSSliderThumb({
    required this.size,
    required this.pressedSize,
    required this.tapTarget,
    required this.shadows,
    required this.focusColor,
    required this.focusRingWidth,
    this.grab = 0,
  });

  final double size;
  final double pressedSize;

  /// How far the grab has grown the thumb, driven by the kit's own spring.
  ///
  /// This replaces `activationAnimation` for the growth, and the replacement
  /// is the point. That animation is a fixed 100ms curve on a controller
  /// `Slider` keeps private, so the thumb was the one press in the kit whose
  /// feedback the app's `speed` and `springiness` could not reach, and the one
  /// that restarted from its target when a press was interrupted instead of
  /// continuing from where it had got to. The state behind it — pressed,
  /// hovered or focused — is read by the component, which is also what lets a
  /// range slider grow only the end under the finger.
  ///
  /// `activationAnimation` still draws the focus ring, which is Material's to
  /// time and has not changed.
  ///
  /// Deliberately allowed past 1. A spring that stops dead at its target is a
  /// curve wearing a spring's name.
  final double grab;

  /// The height the shape claims, which is what makes the *control* meet the
  /// platform floor.
  ///
  /// `_RenderSlider` sizes itself to its tallest part and quietly ignores an
  /// incoming `minHeight` — a `ConstrainedBox` around it asserts rather than
  /// growing it. So the target is asked for here, where the slider will
  /// actually honour it, and the disc still draws at [size].
  final double tapTarget;
  final List<BoxShadow> shadows;
  final Color focusColor;
  final double focusRingWidth;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(pressedSize, tapTarget);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final radius = lerpDouble(size, pressedSize, grab)! / 2;
    paintDSThumb(
      context.canvas,
      center,
      radius,
      Color.lerp(
        sliderTheme.disabledThumbColor,
        sliderTheme.thumbColor,
        enableAnimation.value,
      )!,
      shadows,
    );
    if (activationAnimation.value > 0) {
      context.canvas.drawCircle(
        center,
        radius + focusRingWidth,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = focusRingWidth
          ..color = focusColor.withValues(alpha: activationAnimation.value),
      );
    }
  }
}

/// The same thumb, for the two ends of a range.
class DSRangeSliderThumb extends RangeSliderThumbShape {
  const DSRangeSliderThumb({
    required this.size,
    required this.pressedSize,
    required this.tapTarget,
    required this.shadows,
    this.grab = 0,
  });

  final double size;
  final double pressedSize;
  final double tapTarget;
  final List<BoxShadow> shadows;

  /// See [DSSliderThumb.grab].
  ///
  /// It reaches both ends. A range slider draws them from one theme, and the
  /// two grow together exactly as they did under `activationAnimation`.
  final double grab;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(pressedSize, tapTarget);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool isOnTop = false,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final radius = lerpDouble(size, pressedSize, grab)! / 2;
    paintDSThumb(
      context.canvas,
      center,
      radius,
      Color.lerp(
        sliderTheme.disabledThumbColor,
        sliderTheme.thumbColor,
        enableAnimation.value,
      )!,
      shadows,
    );
  }
}

/// One disc, its depth under it. Shared so the single and range thumbs cannot
/// pick up different shadows.
void paintDSThumb(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
  List<BoxShadow> shadows,
) {
  for (final shadow in shadows) {
    canvas.drawCircle(
      center + shadow.offset,
      radius + shadow.spreadRadius,
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
    );
  }
  canvas.drawCircle(center, radius, Paint()..color = color);
}

/// A value on a continuum, where roughly where it sits matters more than the
/// exact number.
///
/// See `docs/plans/23-ds-slider.plan.md`. **Use when** the position is the
/// point. **Instead:** `DSStepper` for an exact small count, a `DSTextField`
/// for an exact large number.
///
/// `label`, `subtitle` and `icon` are gone: they built a row that was
/// character-for-character the one in `ds_switch.dart` at a different vertical
/// padding, so a settings screen with both had two row heights. A labelled
/// slider is a [DSControlTile] with the slider in it.
class DSSlider extends StatefulWidget {
  const DSSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeEnd,
    this.formatter,
    this.showValue = false,
    this.semanticLabel,
    this.valueSlot,
    this.minLabel,
    this.maxLabel,
    this.style,
    this.inTile = false,
  }) : assert(
         semanticLabel != null || inTile,
         'a bare slider must be given a semanticLabel — it is the one control '
         'a screen-reader user operates without looking at it, so an unnamed '
         'one is a number that changes and never says what it belongs to',
       );

  final double value;

  /// Null disables the control, the kit's convention throughout.
  final ValueChanged<double>? onChanged;

  final double min;
  final double max;

  /// With divisions the thumb snaps and the track shows its stops; without,
  /// the track is a continuum and tick marks would be noise.
  final int? divisions;

  final ValueChanged<double>? onChangeEnd;
  final DSSliderFormatter? formatter;
  final bool showValue;
  final String? semanticLabel;

  /// Replaces the formatted value with anything — a unit chip, a currency
  /// pair, an editable field.
  final Widget? valueSlot;

  final String? minLabel;
  final String? maxLabel;
  final DSSliderStyle? style;

  /// Set by [DSControlTile], which supplies the name.
  final bool inTile;

  @override
  State<DSSlider> createState() => _DSSliderState();
}

/// The spring behind the thumb's growth, shared by both sliders so the two
/// cannot end up with different presses.
mixin _ThumbGrab<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  /// Bounds outside `[0, 1]` for the same reason as `DSPressable`'s: an
  /// `AnimationController` clamps its simulation to them, and a spring clamped
  /// at its target arrives dead.
  late final AnimationController grab = AnimationController(
    vsync: this,
    value: 0,
    lowerBound: -0.25,
    upperBound: 1.25,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    grab.duration = context.design.motion.press;
  }

  @override
  void dispose() {
    grab.dispose();
    super.dispose();
  }

  /// The three states that grow a thumb. Kept apart rather than collapsed into
  /// one flag because they overlap: a focused slider that is then dragged must
  /// not shrink when the finger leaves.
  bool _pressing = false;
  bool _hovered = false;
  bool _focused = false;

  void setGrab({bool? pressed, bool? hovered, bool? focused}) {
    _pressing = pressed ?? _pressing;
    _hovered = hovered ?? _hovered;
    _focused = focused ?? _focused;
    driveGrab(_pressing || _hovered || _focused ? 1 : 0);
  }

  /// The same two-branch drive as `DSPressable`, and deliberately the same:
  /// this is the kit's press feedback appearing on the one control where
  /// Material was drawing it, so a thumb that springs on Android and eases on
  /// iOS matches every button and card around it.
  void driveGrab(double target) {
    if (!mounted) return;
    final motion = context.design.motion;
    if (context.springsAvailable) {
      grab.animateWith(motion.simulation(from: grab.value, to: target));
      return;
    }
    grab.animateTo(
      target,
      duration: target == 1 ? motion.press : motion.pressRelease,
      curve: motion.enter,
    );
  }
}

class _DSSliderState extends State<DSSlider>
    with SingleTickerProviderStateMixin, _ThumbGrab {
  bool get _enabled =>
      widget.onChanged != null && (DSScope.enabledOf(context) ?? true);

  /// One division, or one per cent of the span when the track is a continuum.
  double get _step => widget.divisions != null
      ? (widget.max - widget.min) / widget.divisions!
      : (widget.max - widget.min) / 100;

  void _nudge(double by) {
    if (!_enabled) return;
    final next = (widget.value + by).clamp(widget.min, widget.max);
    if (next == widget.value) return;
    AppHaptics.selection();
    widget.onChanged!(next);
    widget.onChangeEnd?.call(next);
  }

  /// The keys Material's own slider does not handle.
  ///
  /// Arrows are handled by [Slider] itself and reach this node only when it
  /// did not want them, so they are deliberately absent here — two handlers
  /// for one key is how a control ends up stepping twice.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.pageUp:
        _nudge(_step * 10);
      case LogicalKeyboardKey.pageDown:
        _nudge(-_step * 10);
      case LogicalKeyboardKey.home:
        _nudge(widget.min - widget.value);
      case LogicalKeyboardKey.end:
        _nudge(widget.max - widget.value);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _format(double value) =>
      (widget.formatter ?? defaultDSSliderFormatter(widget.min, widget.max))(
        value,
      );

  /// The formatted value, plus the ordinal a discrete track owes a screen
  /// reader: "Large, 3 of 7" says both what was chosen and how far along it is.
  String _announce(double value) {
    final formatted = _format(value);
    final divisions = widget.divisions;
    if (divisions == null) return formatted;
    final index = ((value - widget.min) / (widget.max - widget.min) * divisions)
        .round();
    return '$formatted, ${index + 1} of ${divisions + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSliderStyle.resolve(context, widget.style);
    final space = context.design.space;
    final ticks = resolved.showTicks ?? widget.divisions != null;

    // The slider is the builder's `child`, so a frame of the grab rebuilds one
    // theme and repaints the thumb rather than rebuilding the control.
    Widget track = AnimatedBuilder(
      animation: grab,
      child: Slider(
        value: widget.value.clamp(widget.min, widget.max),
        onChanged: _enabled ? widget.onChanged : null,
        onChangeStart: _enabled ? (_) => setGrab(pressed: true) : null,
        onChangeEnd: (value) {
          setGrab(pressed: false);
          widget.onChangeEnd?.call(value);
        },
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: null,
        semanticFormatterCallback: _announce,
      ),
      builder: (context, child) => SliderTheme(
        data: resolved.toSliderTheme(context, ticks: ticks, grab: grab.value),
        child: child!,
      ),
    );

    track = MouseRegion(
      onEnter: (_) => setGrab(hovered: true),
      onExit: (_) => setGrab(hovered: false),
      child: track,
    );

    // `hasFocus`, not `hasPrimaryFocus`: the node that takes focus is the
    // slider's own, below this one.
    track = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setGrab(focused: focused),
      child: track,
    );

    // The name goes onto the track's own node rather than onto a container
    // above it. Material's slider publishes a node that carries the actions
    // and none of the words, and a label on an ancestor leaves that node
    // announced as "adjustable" and nothing else. Merging is what puts the
    // two together. Inside a tile the tile is already doing this, so the
    // slider stays anonymous and lets it.
    if (!widget.inTile) {
      track = MergeSemantics(
        child: Semantics(label: widget.semanticLabel, child: track),
      );
    }

    final Widget? value = !widget.showValue && widget.valueSlot == null
        ? null
        : (widget.valueSlot ??
              Text(_format(widget.value), style: resolved.valueTextStyle));

    Widget body = switch (value == null
        ? DSSliderValuePosition.none
        : resolved.valuePosition!) {
      DSSliderValuePosition.none => track,
      DSSliderValuePosition.trailing => Row(
        children: [
          Expanded(child: track),
          SizedBox(width: space.md),
          value!,
        ],
      ),
      DSSliderValuePosition.above => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: AlignmentDirectional.centerEnd, child: value!),
          track,
        ],
      ),
    };

    // The bounds go under everything, not under the track alone. Under the
    // track they end up inside the row that carries the trailing readout, and
    // three labels of one size then sit on two different lines — which is what
    // `ui-probe`'s `baseline` rule reports, and what it reads as on screen.
    if (widget.minLabel != null || widget.maxLabel != null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.minLabel ?? '', style: resolved.valueTextStyle),
              Text(widget.maxLabel ?? '', style: resolved.valueTextStyle),
            ],
          ),
        ],
      );
    }

    return body;
  }
}

/// The precision a range deserves when the caller gave no formatter.
///
/// Not `toString()`, which is where `0.6299999999` comes from, and not a fixed
/// two places, which turns a 0–100 slider into "62.00".
DSSliderFormatter defaultDSSliderFormatter(double min, double max) {
  final span = (max - min).abs();
  final decimals = span >= 10
      ? 0
      : span >= 1
      ? 1
      : 2;
  return (value) => value.toStringAsFixed(decimals);
}

/// Two thumbs on one track: a price filter, a date window, brightness bounds.
///
/// New in plan 23. Flutter ships a `RangeSlider` and the kit never themed it,
/// so any caller who needed one left the design system.
class DSRangeSlider extends StatefulWidget {
  const DSRangeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.minimumGap,
    this.onChangeEnd,
    this.formatter,
    this.showValue = false,
    this.startSemanticLabel,
    this.endSemanticLabel,
    this.style,
  });

  final DSRange value;
  final ValueChanged<DSRange>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  /// How close the two ends may get. Null is one division, or one per cent of
  /// the span on a continuum — a range whose ends may meet is a range that can
  /// be collapsed to nothing by a slip of the thumb.
  final double? minimumGap;

  final ValueChanged<DSRange>? onChangeEnd;
  final DSSliderFormatter? formatter;
  final bool showValue;
  final String? startSemanticLabel;
  final String? endSemanticLabel;
  final DSSliderStyle? style;

  @override
  State<DSRangeSlider> createState() => _DSRangeSliderState();
}

class _DSRangeSliderState extends State<DSRangeSlider>
    with SingleTickerProviderStateMixin, _ThumbGrab {
  bool get _enabled =>
      widget.onChanged != null && (DSScope.enabledOf(context) ?? true);

  double get _gap =>
      widget.minimumGap ??
      (widget.divisions != null
          ? (widget.max - widget.min) / widget.divisions!
          : (widget.max - widget.min) / 100);

  /// Neither end may cross the other, so whichever thumb moved is the one that
  /// gives way. Pushing the *other* end along instead would let a single drag
  /// silently change a bound the user was not touching.
  void _change(RangeValues next, {required bool end}) {
    var start = next.start;
    var stop = next.end;
    if (stop - start < _gap) {
      if (start != widget.value.start) {
        start = (stop - _gap).clamp(widget.min, widget.max);
      } else {
        stop = (start + _gap).clamp(widget.min, widget.max);
      }
    }
    final value = DSRange(start, stop);
    if (end) {
      widget.onChangeEnd?.call(value);
    } else {
      widget.onChanged!(value);
    }
  }

  String _format(double value) =>
      (widget.formatter ?? defaultDSSliderFormatter(widget.min, widget.max))(
        value,
      );

  /// The thumb's own name, in front of its value.
  ///
  /// Material's `RangeSlider` builds its two semantics nodes itself and offers
  /// no hook for a label on either — only this formatter, which it calls for
  /// both. So the name is carried in the value, and which name is decided by
  /// which end the number is nearer: the formatter is only ever called with a
  /// thumb's value or one step either side of it. Without this a screen reader
  /// announces two identical "adjustable" controls and never says which is the
  /// floor and which is the ceiling.
  String _announce(double value) {
    final nearStart =
        (value - widget.value.start).abs() <= (value - widget.value.end).abs();
    final name = nearStart
        ? widget.startSemanticLabel
        : widget.endSemanticLabel;
    final formatted = _format(value);
    return name == null ? formatted : '$name, $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSliderStyle.resolve(context, widget.style);
    final space = context.design.space;
    final ticks = resolved.showTicks ?? widget.divisions != null;

    Widget track = AnimatedBuilder(
      animation: grab,
      child: RangeSlider(
        values: RangeValues(
          widget.value.start.clamp(widget.min, widget.max),
          widget.value.end.clamp(widget.min, widget.max),
        ),
        onChanged: _enabled ? (v) => _change(v, end: false) : null,
        onChangeStart: _enabled ? (_) => setGrab(pressed: true) : null,
        onChangeEnd: (v) {
          setGrab(pressed: false);
          _change(v, end: true);
        },
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        labels: RangeLabels(
          _format(widget.value.start),
          _format(widget.value.end),
        ),
        semanticFormatterCallback: _announce,
      ),
      builder: (context, child) => SliderTheme(
        data: resolved.toSliderTheme(context, ticks: ticks, grab: grab.value),
        child: child!,
      ),
    );

    track = MouseRegion(
      onEnter: (_) => setGrab(hovered: true),
      onExit: (_) => setGrab(hovered: false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setGrab(focused: focused),
        child: track,
      ),
    );

    if (!widget.showValue) return track;
    return Row(
      children: [
        Expanded(child: track),
        SizedBox(width: space.md),
        Text(
          '${_format(widget.value.start)} – ${_format(widget.value.end)}',
          style: resolved.valueTextStyle,
        ),
      ],
    );
  }
}
