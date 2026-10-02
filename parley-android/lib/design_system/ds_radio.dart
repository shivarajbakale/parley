// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_checkbox.dart' show DSControlPaint;
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a radio looks, at every layer of the resolution chain.
@immutable
class DSRadioStyle extends DSComponentStyle<DSRadioStyle> {
  const DSRadioStyle({
    this.size,
    this.strokeColor,
    this.selectedStrokeColor,
    this.strokeWidth,
    this.dotColor,
    this.dotFraction,
    this.errorColor,
    this.disabledOpacity,
  });

  /// The drawn circle. The gesture area is [ComponentSpec.minTapTarget].
  final double? size;

  final Color? strokeColor;

  /// The ring once chosen. Separate from [strokeColor] because the selected
  /// ring is the accent and the unselected one is a hairline, and a house that
  /// changes one rarely means the other.
  final Color? selectedStrokeColor;

  final double? strokeWidth;
  final Color? dotColor;

  /// How much of the circle the dot fills, as a fraction of the diameter.
  final double? dotFraction;

  final Color? errorColor;
  final double? disabledOpacity;

  @override
  DSRadioStyle merge(DSRadioStyle? other) {
    if (other == null) return this;
    return DSRadioStyle(
      size: other.size ?? size,
      strokeColor: other.strokeColor ?? strokeColor,
      selectedStrokeColor: other.selectedStrokeColor ?? selectedStrokeColor,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      dotColor: other.dotColor ?? dotColor,
      dotFraction: other.dotFraction ?? dotFraction,
      errorColor: other.errorColor ?? errorColor,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSRadioStyle copyWith({
    double? size,
    Color? strokeColor,
    Color? selectedStrokeColor,
    double? strokeWidth,
    Color? dotColor,
    double? dotFraction,
    Color? errorColor,
    double? disabledOpacity,
  }) => DSRadioStyle(
    size: size ?? this.size,
    strokeColor: strokeColor ?? this.strokeColor,
    selectedStrokeColor: selectedStrokeColor ?? this.selectedStrokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    dotColor: dotColor ?? this.dotColor,
    dotFraction: dotFraction ?? this.dotFraction,
    errorColor: errorColor ?? this.errorColor,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSRadioStyle lerp(DSRadioStyle? other, double t) {
    if (other == null) return this;
    return DSRadioStyle(
      size: lerpDouble(size, other.size, t),
      strokeColor: Color.lerp(strokeColor, other.strokeColor, t),
      selectedStrokeColor: Color.lerp(
        selectedStrokeColor,
        other.selectedStrokeColor,
        t,
      ),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      dotColor: Color.lerp(dotColor, other.dotColor, t),
      dotFraction: lerpDouble(dotFraction, other.dotFraction, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  static DSRadioStyle resolve(BuildContext context, [DSRadioStyle? own]) {
    final component = context.design.component;
    final palette = context.palette;
    return resolveStyle(
      context: context,
      specDefaults: DSRadioStyle(
        size: component.radioSize,
        strokeColor: palette.border,
        selectedStrokeColor: palette.primary,
        strokeWidth: component.controlStroke,
        dotColor: palette.primary,
        dotFraction: 0.5,
        errorColor: palette.destructive,
        disabledOpacity: DSControlPaint.disabledOpacity,
      ),
      own: own,
    );
  }
}

/// What a [DSRadioGroup] tells the radios inside it.
///
/// Its own inherited widget rather than [DSScope], because the four things a
/// scope may carry are deliberately closed (`ds_scope.dart`) and a group's
/// selected value is not one of them — it is the group's state, not a
/// container's suggestion.
@immutable
class _DSRadioGroupScope<T> extends InheritedWidget {
  const _DSRadioGroupScope({
    required this.value,
    required this.onChanged,
    required this.enabled,
    required super.child,
  });

  final T? value;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  static _DSRadioGroupScope<T>? maybeOf<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DSRadioGroupScope<T>>();

  @override
  bool updateShouldNotify(_DSRadioGroupScope<T> old) =>
      value != old.value || enabled != old.enabled;
}

/// What the enclosing [DSRadioGroup] holds, read by a row that draws its own
/// radio.
///
/// The scope itself stays private — it is the group's state, and nothing
/// outside this file may set it. This is the read side, and it exists so
/// `DSRadioTile` can report the row's selected state and exclusivity on the
/// row's own semantics node rather than on the radio buried inside it.
@immutable
class DSRadioGroupBinding<T> {
  const DSRadioGroupBinding._(this.value, this.onChanged, this.enabled);

  final T? value;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  static DSRadioGroupBinding<T>? of<T>(BuildContext context) {
    final scope = _DSRadioGroupScope.maybeOf<T>(context);
    return scope == null
        ? null
        : DSRadioGroupBinding<T>._(scope.value, scope.onChanged, scope.enabled);
  }
}

/// One of a set of options, exactly one of which is chosen.
///
/// New in `docs/plans/22-ds-selection-controls.plan.md`: the kit had no radio
/// at all, so callers reached for a [DSSegmentedButton] past the four options
/// it holds, a `DSSelect` where the options should stay visible, or Material's
/// unthemed `Radio`.
///
/// **It belongs to a group.** A radio outside a [DSRadioGroup] asserts, and
/// not for tidiness: exclusivity is a property of the *set*, so a lone radio
/// is a control that cannot be unselected by anything and announces itself to
/// a screen reader as an unrelated checkbox. The group is also what supplies
/// [groupValue] and [onChanged], so a caller normally passes neither.
///
/// **Use when** two to five options must all stay visible while one is picked.
/// **Instead:** [DSSegmentedButton] when the options are short enough to sit
/// in one row and the choice changes what is displayed, `DSSelect` past five.
class DSRadio<T> extends StatefulWidget {
  const DSRadio({
    super.key,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.semanticLabel,
    this.error = false,
    this.enabled = true,
    this.style,
    this.inTile = false,
  });

  /// What choosing this radio selects.
  final T value;

  /// The set's current choice. Supplied by the enclosing [DSRadioGroup]; pass
  /// it only when driving a radio outside one, which is what the group's own
  /// assertion is there to discourage.
  final T? groupValue;

  final ValueChanged<T?>? onChanged;
  final String? semanticLabel;
  final bool error;
  final bool enabled;
  final DSRadioStyle? style;

  /// Set by [DSControlTile], which owns the row's name and its gesture.
  final bool inTile;

  @override
  State<DSRadio<T>> createState() => _DSRadioState<T>();
}

class _DSRadioState<T> extends State<DSRadio<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dot = AnimationController(vsync: this);

  _DSRadioGroupScope<T>? _group;
  bool _selected = false;
  bool _scopeEnabled = true;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = _DSRadioGroupScope.maybeOf<T>(context);
    _scopeEnabled = DSScope.enabledOf(context) ?? true;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _dot.duration = context.design.motion.scaled(context.design.motion.fast);
    assert(
      _group != null || widget.onChanged != null || !widget.enabled,
      'a DSRadio outside a DSRadioGroup — exclusivity is a property of the '
      'set, so a lone radio can never be unselected and is announced to a '
      'screen reader as an unrelated checkbox. Wrap the options in a '
      'DSRadioGroup, which also supplies groupValue and onChanged',
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant DSRadio<T> old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final selected = _effectiveGroupValue == widget.value;
    if (selected == _selected) return;
    _selected = selected;
    if (_reducedMotion) {
      _dot.value = selected ? 1 : 0;
    } else {
      _dot.animateTo(selected ? 1 : 0);
    }
  }

  T? get _effectiveGroupValue => widget.groupValue ?? _group?.value;

  bool get _enabled =>
      widget.enabled &&
      (_group?.enabled ?? true) &&
      _scopeEnabled &&
      (widget.onChanged != null || _group != null);

  void _choose() {
    if (!_enabled || _selected) return;
    AppHaptics.selection();
    (widget.onChanged ?? _group!.onChanged)(widget.value);
  }

  @override
  void dispose() {
    _dot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSRadioStyle.resolve(context, widget.style);
    final component = context.design.component;
    final size = resolved.size!;

    final Widget circle = DSPressable(
      enabled: _enabled,
      focusShape: const CircleBorder(),
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _choose();
              return null;
            },
          ),
        },
        child: AnimatedBuilder(
          animation: _dot,
          builder: (context, _) => CustomPaint(
            size: Size.square(size),
            painter: _RadioPainter(
              progress: context.design.motion.enter.transform(_dot.value),
              strokeColor: widget.error
                  ? resolved.errorColor!
                  : resolved.strokeColor!,
              selectedStrokeColor: widget.error
                  ? resolved.errorColor!
                  : resolved.selectedStrokeColor!,
              strokeWidth: resolved.strokeWidth!,
              dotColor: widget.error
                  ? resolved.errorColor!
                  : resolved.dotColor!,
              dotFraction: resolved.dotFraction!,
            ),
          ),
        ),
      ),
    );

    final Widget target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? _choose : null,
      child: SizedBox(
        width: component.minTapTarget,
        height: component.minTapTarget,
        child: Center(child: circle),
      ),
    );

    final Widget faded = _enabled
        ? target
        : Opacity(opacity: resolved.disabledOpacity!, child: target);

    if (widget.inTile) return ExcludeSemantics(child: faded);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      checked: _selected,
      // What makes a screen reader say "2 of 5" rather than reading five
      // unrelated boxes. It is set only inside a group, because outside one
      // the claim would be false.
      inMutuallyExclusiveGroup: _group != null ? true : null,
      enabled: _enabled,
      onTap: _enabled ? _choose : null,
      child: ExcludeSemantics(child: faded),
    );
  }
}

class _RadioPainter extends CustomPainter {
  const _RadioPainter({
    required this.progress,
    required this.strokeColor,
    required this.selectedStrokeColor,
    required this.strokeWidth,
    required this.dotColor,
    required this.dotFraction,
  });

  final double progress;
  final Color strokeColor;
  final Color selectedStrokeColor;
  final double strokeWidth;
  final Color dotColor;
  final double dotFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      (size.width - strokeWidth) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Color.lerp(strokeColor, selectedStrokeColor, progress)!,
    );
    if (progress <= 0) return;
    canvas.drawCircle(
      centre,
      size.width * dotFraction / 2 * progress,
      Paint()..color = dotColor,
    );
  }

  @override
  bool shouldRepaint(_RadioPainter old) =>
      old.progress != progress ||
      old.strokeColor != strokeColor ||
      old.selectedStrokeColor != selectedStrokeColor ||
      old.strokeWidth != strokeWidth ||
      old.dotColor != dotColor ||
      old.dotFraction != dotFraction;
}

/// The set a [DSRadio] belongs to.
///
/// It owns the value, installs the exclusivity semantics, and lays the options
/// out. `children` is `List<Widget>` rather than `List<DSRadio>` for the
/// reason plan 02 Section 8 gives: a caller's own row that happens to contain
/// a radio is still a legal child, and a narrowed list makes that unreachable.
class DSRadioGroup<T> extends StatelessWidget {
  const DSRadioGroup({
    super.key,
    required this.children,
    required this.value,
    required this.onChanged,
    this.direction = Axis.vertical,
    this.label,
    this.errorText,
    this.enabled = true,
  });

  final List<Widget> children;
  final T? value;
  final ValueChanged<T?> onChanged;
  final Axis direction;

  /// What the set is asking. Rendered above the options and announced as the
  /// group's name, so the options are heard as answers to a question rather
  /// than as five unrelated controls.
  final String? label;

  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;

    final Widget options = direction == Axis.vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          )
        : Row(mainAxisSize: MainAxisSize.min, children: children);

    return _DSRadioGroupScope<T>(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      child: Semantics(
        container: true,
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.pageGutter),
                child: Text(
                  label!,
                  style: text.labelLarge?.copyWith(color: palette.foreground),
                ),
              ),
              SizedBox(height: space.xs),
            ],
            options,
            if (errorText != null) ...[
              SizedBox(height: space.xs),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: space.pageGutter),
                child: Text(
                  errorText!,
                  style: DSTextRole.fieldError.styleOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
