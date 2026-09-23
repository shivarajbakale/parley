// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/design_system/_tap_target.dart';
import 'package:parley_android/theme/app_choice_label.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How the segments divide the row.
///
/// Three behaviours, where there used to be one boolean. `fillWidth: true`
/// was [equal] and `false` was [content]; [fill] is the third case callers
/// used to fake with an `Expanded` around the whole control.
enum DSSegmentedSizing {
  /// Every segment as wide as the widest. Required when any segment is
  /// icon-only, or the glyphs jitter as the indicator travels.
  equal,

  /// Each segment as wide as its own content.
  content,

  /// Content-sized, then stretched to fill the row.
  fill,
}

/// The three steps of the control's own height.
enum DSSegmentedButtonSize { sm, md, lg }

/// How a segmented control looks, at every layer of the resolution chain.
@immutable
class DSSegmentedButtonStyle extends DSComponentStyle<DSSegmentedButtonStyle> {
  const DSSegmentedButtonStyle({
    this.height,
    this.trackFill,
    this.trackInset,
    this.indicatorFill,
    this.indicatorShadows,
    this.segmentPadding,
    this.labelStyle,
    this.selectedLabelStyle,
    this.iconSize,
    this.countStyle,
    this.showDividers,
    this.dividerColor,
    this.travelSpring,
    this.maxSegments,
    this.disabledOpacity,
  });

  final double? height;
  final Color? trackFill;
  final double? trackInset;

  /// The moving slot. The *raised* role for this theme rather than a fixed
  /// step: in light that is the page's own white and in dark it is the card,
  /// which is what makes the indicator read as lifted in both.
  final Color? indicatorFill;

  final List<BoxShadow>? indicatorShadows;
  final EdgeInsetsGeometry? segmentPadding;
  final TextStyle? labelStyle;

  /// Weight as well as colour. The M-4 rule: a selected state carried by fill
  /// alone is invisible to a third of readers.
  final TextStyle? selectedLabelStyle;

  final double? iconSize;
  final TextStyle? countStyle;

  /// The hairline between two adjacent unselected segments, which fades out as
  /// the indicator approaches. It is what stops three unselected words from
  /// reading as one sentence, and neither platform's control is without it.
  final bool? showDividers;
  final Color? dividerColor;

  final SpringDescription? travelSpring;

  /// Past this the labels truncate on a phone and the control becomes a worse
  /// `DSSelect`. Asserted, as plan 15 asserts the navigation bar's 3–5.
  final int? maxSegments;

  final double? disabledOpacity;

  @override
  DSSegmentedButtonStyle merge(DSSegmentedButtonStyle? other) {
    if (other == null) return this;
    return DSSegmentedButtonStyle(
      height: other.height ?? height,
      trackFill: other.trackFill ?? trackFill,
      trackInset: other.trackInset ?? trackInset,
      indicatorFill: other.indicatorFill ?? indicatorFill,
      indicatorShadows: other.indicatorShadows ?? indicatorShadows,
      segmentPadding: other.segmentPadding ?? segmentPadding,
      labelStyle: other.labelStyle ?? labelStyle,
      selectedLabelStyle: other.selectedLabelStyle ?? selectedLabelStyle,
      iconSize: other.iconSize ?? iconSize,
      countStyle: other.countStyle ?? countStyle,
      showDividers: other.showDividers ?? showDividers,
      dividerColor: other.dividerColor ?? dividerColor,
      travelSpring: other.travelSpring ?? travelSpring,
      maxSegments: other.maxSegments ?? maxSegments,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSSegmentedButtonStyle copyWith({
    double? height,
    Color? trackFill,
    double? trackInset,
    Color? indicatorFill,
    List<BoxShadow>? indicatorShadows,
    EdgeInsetsGeometry? segmentPadding,
    TextStyle? labelStyle,
    TextStyle? selectedLabelStyle,
    double? iconSize,
    TextStyle? countStyle,
    bool? showDividers,
    Color? dividerColor,
    SpringDescription? travelSpring,
    int? maxSegments,
    double? disabledOpacity,
  }) => DSSegmentedButtonStyle(
    height: height ?? this.height,
    trackFill: trackFill ?? this.trackFill,
    trackInset: trackInset ?? this.trackInset,
    indicatorFill: indicatorFill ?? this.indicatorFill,
    indicatorShadows: indicatorShadows ?? this.indicatorShadows,
    segmentPadding: segmentPadding ?? this.segmentPadding,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedLabelStyle: selectedLabelStyle ?? this.selectedLabelStyle,
    iconSize: iconSize ?? this.iconSize,
    countStyle: countStyle ?? this.countStyle,
    showDividers: showDividers ?? this.showDividers,
    dividerColor: dividerColor ?? this.dividerColor,
    travelSpring: travelSpring ?? this.travelSpring,
    maxSegments: maxSegments ?? this.maxSegments,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSSegmentedButtonStyle lerp(DSSegmentedButtonStyle? other, double t) {
    if (other == null) return this;
    return DSSegmentedButtonStyle(
      // Three fields with no midpoint: a flag, a spring and a count.
      showDividers: t < 0.5 ? showDividers : other.showDividers,
      travelSpring: t < 0.5 ? travelSpring : other.travelSpring,
      maxSegments: t < 0.5 ? maxSegments : other.maxSegments,
      height: lerpDouble(height, other.height, t),
      trackFill: Color.lerp(trackFill, other.trackFill, t),
      trackInset: lerpDouble(trackInset, other.trackInset, t),
      indicatorFill: Color.lerp(indicatorFill, other.indicatorFill, t),
      indicatorShadows: BoxShadow.lerpList(
        indicatorShadows,
        other.indicatorShadows,
        t,
      ),
      segmentPadding: EdgeInsetsGeometry.lerp(
        segmentPadding,
        other.segmentPadding,
        t,
      ),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      selectedLabelStyle: TextStyle.lerp(
        selectedLabelStyle,
        other.selectedLabelStyle,
        t,
      ),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      countStyle: TextStyle.lerp(countStyle, other.countStyle, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  static DSSegmentedButtonStyle resolve(
    BuildContext context, [
    DSSegmentedButtonSize size = DSSegmentedButtonSize.md,
    DSSegmentedButtonStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    final (double height, double padding) = switch (size) {
      DSSegmentedButtonSize.sm => (component.controlHeightSm, space.sm),
      DSSegmentedButtonSize.md => (component.controlHeight, space.md),
      DSSegmentedButtonSize.lg => (component.controlHeightLg, space.lg),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSSegmentedButtonStyle(
        height: height,
        trackFill: palette.muted,
        trackInset: component.trackInset,
        indicatorFill: palette.chrome,
        indicatorShadows: design.elevation.resolve(
          elevation: design.elevation.levelOf(DSElevation.low),
          brightness: palette.brightness,
          shadowColor: palette.overlay,
        ),
        segmentPadding: EdgeInsets.symmetric(horizontal: padding),
        labelStyle: text.labelLarge?.copyWith(color: palette.mutedForeground),
        selectedLabelStyle: text.labelLarge?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        iconSize: component.iconSizeSmall,
        countStyle: DSTextRole.caption.styleOf(context),
        showDividers: true,
        dividerColor: palette.borderSoft,
        travelSpring: design.motion.gentle,
        maxSegments: 5,
        disabledOpacity: 0.38,
      ),
      scope: null,
      own: own,
    );
  }
}

/// What the control tells the segments inside it.
///
/// [DSScope] carries the size and the enabled state, because those are two of
/// the four things a container is allowed to impose. The rest — which segment
/// this is, how much of the indicator is under it, what tapping it does — is
/// the control's own state and lives here, which is what replaces the
/// `paintsBackground` flag the old implementation threaded by hand.
@immutable
class _DSSegmentedScope extends InheritedWidget {
  const _DSSegmentedScope({
    required this.style,
    required this.selectedness,
    required this.chosen,
    required this.onSelect,
    required this.enabled,
    required this.multiple,
    required this.hugContent,
    required this.dividerBefore,
    required super.child,
  });

  final DSSegmentedButtonStyle style;

  /// How much of the indicator is over each segment: 1 arrived, 0 a whole
  /// segment away, fractional in between. Colours are read off this so they
  /// travel with the indicator rather than beside it.
  final List<double> selectedness;

  final Set<Object?> chosen;
  final void Function(Object? value) onSelect;
  final bool enabled;
  final bool multiple;

  /// True under [DSSegmentedSizing.content], where a segment must be as wide
  /// as its own content. A `Center` under loose constraints expands to the
  /// space it is offered, so a content-sized control would quietly take the
  /// whole row — which is how a compact picker in a list row's trailing slot
  /// came to consume the tile.
  final bool hugContent;

  final List<double> dividerBefore;

  static _DSSegmentedScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DSSegmentedScope>();
    assert(
      scope != null,
      'a DSSegment outside a DSSegmentedButton — a segment is a slot in a '
      'track, and on its own it has no track to sit in, no neighbours to be '
      'exclusive with, and nothing to tell it what tapping it means',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_DSSegmentedScope old) => true;
}

/// A flat set of two to five options, all visible, where choosing one changes
/// what is displayed rather than performing an action.
///
/// See `docs/plans/24-ds-segmented-button.plan.md`.
///
/// **Use when** the choice changes a value in place. **Instead:** `DSTabBar`
/// to navigate between panels, `DSChipGroup` for filters that may be multiple
/// or many, `DSSelect` past five options. Those three are the most confused
/// trio in any kit, which is why each names the others.
///
/// The travelling indicator is kept from the implementation this replaces:
/// one slot moves from where it was to where it is going, rather than two
/// fills cross-fading. A sliding slot says *the same thing moved*; a
/// cross-fade says *one thing ended and another began*.
class DSSegmentedButton<T> extends StatefulWidget {
  const DSSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required ValueChanged<T> onChanged,
    this.sizing = DSSegmentedSizing.equal,
    this.size = DSSegmentedButtonSize.md,
    this.enabled = true,
    this.loading = false,
    this.style,
  }) : onSingleChanged = onChanged,
       onMultipleChanged = null,
       chosen = null,
       minSelection = null,
       maxSelection = null;

  /// Two or three options that toggle independently — bold, italic,
  /// underline. A normal form of this control, and unreachable before.
  const DSSegmentedButton.multiple({
    super.key,
    required this.segments,
    required Set<T> selected,
    required ValueChanged<Set<T>> onChanged,
    this.minSelection,
    this.maxSelection,
    this.sizing = DSSegmentedSizing.equal,
    this.size = DSSegmentedButtonSize.md,
    this.enabled = true,
    this.loading = false,
    this.style,
  }) : chosen = selected,
       onMultipleChanged = onChanged,
       onSingleChanged = null,
       selected = null;

  /// `List<Widget>`, not `List<DSSegment<T>>`: a caller's own subclass of a
  /// segment is still a legal child, which a narrowed list makes unreachable
  /// (plan 02 Section 8).
  final List<Widget> segments;

  /// Nullable now. "Nothing selected" is a real state — a filter row that
  /// starts with nothing chosen — and the old `T extends Object` bound existed
  /// only to work around not modelling it.
  final T? selected;

  final ValueChanged<T>? onSingleChanged;
  final Set<T>? chosen;
  final ValueChanged<Set<T>>? onMultipleChanged;
  final int? minSelection;
  final int? maxSelection;

  final DSSegmentedSizing sizing;
  final DSSegmentedButtonSize size;
  final bool enabled;
  final bool loading;
  final DSSegmentedButtonStyle? style;

  bool get _multiple => onMultipleChanged != null;

  @override
  State<DSSegmentedButton<T>> createState() => _DSSegmentedButtonState<T>();
}

class _DSSegmentedButtonState<T> extends State<DSSegmentedButton<T>>
    with SingleTickerProviderStateMixin {
  /// Bounds outside [0, 1] so a spring can overshoot its slot and settle back.
  /// Clamped at the target it would arrive dead, and the overshoot is the part
  /// that reads as a physical object being thrown rather than moved.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    value: 0,
    lowerBound: -0.2,
    upperBound: 1.2,
  );

  /// Each segment's laid-out width, in order, filled in on the frame after
  /// layout. What the indicator is positioned from.
  final List<double> _widths = [];

  /// Each segment's *intrinsic* width — how wide its own content wants to be,
  /// independent of what the row handed it. [DSSegmentedSizing.fill] weights
  /// its flexes by this, and could not use [_widths]: under an `Expanded` a
  /// segment's laid-out width is the width the flex already gave it, so
  /// feeding that back in is a loop with only one fixed point — every segment
  /// an equal third. `fill` rendered identically to `equal` for that reason.
  final List<double> _intrinsics = [];

  late double _from = (_index < 0 ? 0 : _index).toDouble();
  late double _to = _from;

  bool _reducedMotion = false;

  /// The slot the current selection occupies, or `-1` for no selection.
  ///
  /// `-1` rather than the old `0`: "nothing selected" and "the first one" are
  /// different states, and collapsing them is what made the indicator slide
  /// in from segment one the first time a filter row was given a value.
  int get _index => _values.indexOf(widget.selected);

  /// The value each segment carries, in order. Read from the widgets rather
  /// than from a parallel model, which is the whole point of the segment
  /// having become a widget.
  List<Object?> get _values => [
    for (final segment in widget.segments)
      segment is DSSegment ? segment.value : null,
  ];

  double get _slot => lerpDouble(_from, _to, _travel.value)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _travel.duration = context.design.motion.scaled(context.design.motion.fast);
  }

  @override
  void didUpdateWidget(covariant DSSegmentedButton<T> old) {
    super.didUpdateWidget(old);
    if (widget._multiple) return;
    final index = _index;
    // Nothing selected: the indicator fades out where it stands rather than
    // travelling to a slot that is not the answer to anything.
    if (index < 0) return;
    final target = index.toDouble();
    // Arriving from nothing selected. There is no journey to animate — the
    // indicator was not on the track a frame ago — so it appears at its slot
    // and fades in, which is what both platforms do for a first selection.
    if (old.selected == null) {
      _from = target;
      _to = target;
      _travel.value = 1;
      return;
    }
    if (target == _to) return;
    // From where the indicator actually is, which is what makes an interrupted
    // travel continue rather than jump back and start again.
    _from = _slot;
    _to = target;
    _travel.value = 0;
    if (_reducedMotion) {
      _travel.value = 1;
    } else if (context.springsAvailable) {
      _travel.animateWith(context.design.motion.simulation(from: 0, to: 1));
    } else {
      _travel.animateTo(1, curve: context.design.motion.emphasize);
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  void _select(Object? value) {
    if (widget._multiple) {
      final next = Set<T>.of(widget.chosen!);
      if (next.contains(value)) {
        if (next.length <= (widget.minSelection ?? 0)) return;
        next.remove(value);
      } else {
        if (widget.maxSelection != null &&
            next.length >= widget.maxSelection!) {
          return;
        }
        next.add(value as T);
      }
      AppHaptics.selection();
      widget.onMultipleChanged!(next);
      return;
    }
    if (value == widget.selected) return;
    AppHaptics.selection();
    widget.onSingleChanged!(value as T);
  }

  /// Left and right move the selection, which is the platform behaviour for a
  /// radio group and the model this control shares with one.
  void _step(int by) {
    if (widget._multiple) return;
    final values = _values;
    final next = (_index + by).clamp(0, values.length - 1);
    if (next != _index) _select(values[next]);
  }

  void _report(int index, double width, double intrinsic) {
    while (_widths.length <= index) {
      _widths.add(0);
      _intrinsics.add(0);
    }
    if (_widths[index] == width && _intrinsics[index] == intrinsic) return;
    _widths[index] = width;
    _intrinsics[index] = intrinsic;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSegmentedButtonStyle.resolve(
      context,
      DSScope.sizeOf(context) == null
          ? widget.size
          : switch (DSScope.sizeOf(context)!) {
              DSSize.sm => DSSegmentedButtonSize.sm,
              DSSize.md => DSSegmentedButtonSize.md,
              DSSize.lg => DSSegmentedButtonSize.lg,
            },
      widget.style,
    );
    final count = widget.segments.length;
    assert(
      count <= resolved.maxSegments!,
      'a segmented control with $count segments — past '
      '${resolved.maxSegments} the labels truncate on a phone and the control '
      'is a worse DSSelect. Use DSSelect, or DSChipGroup if the choice may be '
      'multiple',
    );

    if (widget.loading) {
      return DSSegmentedButtonSkeleton(segments: count, size: widget.size);
    }

    final enabled = widget.enabled && (DSScope.enabledOf(context) ?? true);
    final shape = context.shapeOf(AppShape.control);

    return AnimatedBuilder(
      animation: _travel,
      builder: (context, _) {
        final slot = _slot;
        final selectedness = <double>[
          for (var i = 0; i < count; i++)
            if (widget._multiple)
              widget.chosen!.contains(_values[i]) ? 1.0 : 0.0
            else if (widget.selected == null)
              0.0
            else
              (1 - (slot - i).abs()).clamp(0.0, 1.0),
        ];
        // A divider is drawn before a segment only while neither it nor its
        // neighbour is under the indicator.
        final dividers = <double>[
          for (var i = 0; i < count; i++)
            i == 0
                ? 0.0
                : (1 - selectedness[i]).clamp(0.0, 1.0) *
                      (1 - selectedness[i - 1]).clamp(0.0, 1.0),
        ];

        final row = Row(
          mainAxisSize: widget.sizing == DSSegmentedSizing.content
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: [
            for (var i = 0; i < count; i++)
              _sized(
                i,
                _MeasuredSegment(
                  onMeasured: (width, intrinsic) =>
                      _report(i, width, intrinsic),
                  child: widget.segments[i],
                ),
              ),
          ],
        );

        return Opacity(
          opacity: enabled ? 1 : resolved.disabledOpacity!,
          child: _DSSegmentedValues(
            values: _values,
            child: _DSSegmentedScope(
              style: resolved,
              selectedness: selectedness,
              chosen: widget._multiple
                  ? widget.chosen!
                  : <Object?>{if (widget.selected != null) widget.selected},
              onSelect: _select,
              enabled: enabled,
              multiple: widget._multiple,
              hugContent: widget.sizing == DSSegmentedSizing.content,
              dividerBefore: dividers,
              child: FocusableActionDetector(
                enabled: enabled,
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(
                    -1,
                  ),
                  SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(
                    1,
                  ),
                },
                actions: <Type, Action<Intent>>{
                  _StepIntent: CallbackAction<_StepIntent>(
                    onInvoke: (intent) {
                      _step(intent.by);
                      return null;
                    },
                  ),
                },
                // The track is painted behind the segments rather than
                // around them. The spec is explicit that it is shorter than
                // its own targets — "a button is a target, and a segmented
                // control is a track with targets inside it, so the track is
                // shorter than the 48 its segments still have to clear" —
                // and while the track was the parent, no segment could clear
                // anything: a 36-point box hands its children a 36-point
                // constraint, and the probe measured 30.
                child: DSShortTrack(
                  height: resolved.height!,
                  background: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: resolved.trackFill,
                      shape: shape,
                    ),
                    // `SizedBox.expand`, and it is load-bearing. `DSShortTrack`
                    // centres the background under loose constraints, so this
                    // box was sized by whatever was inside it — and what was
                    // inside it, for a control with nothing selected or one in
                    // multiple mode, was `SizedBox.shrink`. The track simply
                    // did not paint: three labels floating on the page with a
                    // hairline where the whole background should have been.
                    child: SizedBox.expand(
                      child: Padding(
                        padding: EdgeInsets.all(resolved.trackInset!),
                        child: _Slots(
                          slot: slot,
                          selectedness: selectedness,
                          // A single selection has one travelling slot; a
                          // multiple one paints a static fill under each
                          // chosen segment. Both are the same geometry, which
                          // is why they are the same widget — the multiple
                          // case used to paint nothing at all, leaving bold
                          // text as the only mark of what was on.
                          multiple: widget._multiple,
                          present: widget._multiple || widget.selected != null,
                          widths: List<double>.of(_widths.take(count)),
                          count: count,
                          fill: resolved.indicatorFill!,
                          shadows: resolved.indicatorShadows!,
                          shape: _deflate(
                            shape,
                            resolved.trackInset!,
                            resolved.height!,
                          ),
                          duration: context.design.motion.scaled(
                            context.design.motion.fast,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The same inset horizontally, so a segment's measured
                  // width still starts where the indicator's slot does.
                  child: Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: resolved.trackInset!,
                    ),
                    child: row,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sized(int index, Widget child) => switch (widget.sizing) {
    DSSegmentedSizing.equal => Expanded(child: child),
    DSSegmentedSizing.content => Flexible(child: child),
    // Stretched *proportionally*, which is the case a caller used to fake with
    // an `Expanded` around the whole control and could not get right: the flex
    // weight is the segment's own intrinsic width, so a long label keeps more
    // of the row than a short one instead of every segment being a third.
    DSSegmentedSizing.fill => Expanded(
      flex: _fillFlexes()[index],
      child: child,
    ),
  };

  /// The flex weight of each segment under [DSSegmentedSizing.fill].
  ///
  /// Proportional to content, but never below the tap-target floor. A share
  /// taken straight from the intrinsic widths starves the short segment: on a
  /// 320-point screen a three-word row put "Day" in 47 points, one under the
  /// floor every other control in the kit clears. So the starved segments are
  /// raised to the floor and the difference comes out of the ones with room,
  /// repeatedly, until nothing is under it — the same water-filling a flex
  /// layout with minimums has to do anywhere.
  List<int> _fillFlexes() {
    final count = widget.segments.length;
    if (_intrinsics.length < count ||
        _intrinsics.take(count).any((double w) => w <= 0)) {
      return List<int>.filled(count, 1);
    }
    final weights = _intrinsics.take(count).toList();
    final available = _widths
        .take(count)
        .fold<double>(0, (double a, double b) => a + b);
    final floor = context.design.component.minTapTarget;

    // Not laid out yet, or a row too narrow for every segment to clear the
    // floor: proportional is the best answer available.
    if (available <= 0 || available < floor * count) {
      return <int>[for (final double w in weights) w.round().clamp(1, 1 << 20)];
    }

    final pinned = <int>{};
    while (true) {
      final free = available - floor * pinned.length;
      final freeWeight = <double>[
        for (var i = 0; i < count; i++)
          if (!pinned.contains(i)) weights[i],
      ].fold<double>(0, (double a, double b) => a + b);
      final starved = <int>[
        for (var i = 0; i < count; i++)
          if (!pinned.contains(i) &&
              (freeWeight <= 0 || weights[i] * free / freeWeight < floor))
            i,
      ];
      if (starved.isEmpty) {
        return <int>[
          for (var i = 0; i < count; i++)
            pinned.contains(i)
                ? floor.round().clamp(1, 1 << 20)
                : (weights[i] * free / freeWeight).round().clamp(1, 1 << 20),
        ];
      }
      pinned.addAll(starved);
    }
  }
}

/// The indicator's own outline, concentric with the track's.
///
/// A slot inset by `n` inside a corner of radius `r` reads as a corner of
/// radius `r - n`; drawn at `r` the two arcs are not parallel and the gap
/// between them pinches at the corners.
///
/// With one floor, and it is the case this identity is in. A track whose
/// radius is already past half its own height is a stadium — the painter
/// clamps it — and the slot inside a stadium is a stadium too. Subtracting
/// the inset there would square the corners of a capsule for no reason, which
/// is exactly what it did: the `actions` baseline came back with a visibly
/// less round thumb in a track that had not changed at all.
OutlinedBorder _deflate(OutlinedBorder shape, double inset, double height) {
  final inner = height - inset * 2;
  BorderRadiusGeometry deflated(BorderRadiusGeometry radius) {
    if (radius is! BorderRadius) return radius;
    Radius shrink(Radius r) => Radius.elliptical(
      _step(r.x, inset, height, inner),
      _step(r.y, inset, height, inner),
    );
    return BorderRadius.only(
      topLeft: shrink(radius.topLeft),
      topRight: shrink(radius.topRight),
      bottomLeft: shrink(radius.bottomLeft),
      bottomRight: shrink(radius.bottomRight),
    );
  }

  return switch (shape) {
    StadiumBorder() => shape,
    RoundedRectangleBorder(:final borderRadius) => RoundedRectangleBorder(
      borderRadius: deflated(borderRadius),
    ),
    RoundedSuperellipseBorder(:final borderRadius) => RoundedSuperellipseBorder(
      borderRadius: deflated(borderRadius),
    ),
    BeveledRectangleBorder(:final borderRadius) => BeveledRectangleBorder(
      borderRadius: deflated(borderRadius),
    ),
    _ => shape,
  };
}

double _step(double radius, double inset, double height, double inner) {
  // The track was a capsule, so the slot is one too — at its own half-height,
  // not at the track's radius and not at that radius minus the inset. Neither
  // of those is a capsule in a shorter box, and both were tried.
  if (radius >= height / 2) return inner / 2;
  return (radius - inset).clamp(0.0, radius);
}

/// Moving the selection with the arrow keys.
class _StepIntent extends Intent {
  const _StepIntent(this.by);

  final int by;
}

/// The raised slot, or slots.
///
/// Positioned from the measured segment widths rather than by fraction, so it
/// lands correctly under all three sizings instead of only under equal ones —
/// which is what the boolean it replaces could not do.
///
/// In [multiple] mode there is one static fill per chosen segment, because an
/// indicator cannot travel to two places at once. That case previously painted
/// nothing: a multi-select control's only mark of what was on was the label's
/// weight, which is the failure the M-4 rule about colour-alone applies to in
/// reverse.
class _Slots extends StatelessWidget {
  const _Slots({
    required this.slot,
    required this.selectedness,
    required this.multiple,
    required this.present,
    required this.widths,
    required this.count,
    required this.fill,
    required this.shadows,
    required this.shape,
    required this.duration,
  });

  final double slot;
  final List<double> selectedness;
  final bool multiple;

  /// Whether anything is selected at all. Drives a fade rather than a mount,
  /// so the slot leaves and returns where it stands.
  final bool present;

  final List<double> widths;
  final int count;
  final Color fill;
  final List<BoxShadow> shadows;
  final OutlinedBorder shape;
  final Duration duration;

  /// The x of segment [index]'s leading edge, continuous in [index] and
  /// *extrapolated* outside the row.
  ///
  /// Extrapolation is what the spring's overshoot needs: the controller runs
  /// to 1.2 and back, and a position function that clamped at the last edge
  /// threw that away — the overshoot the bounds exist for never reached a
  /// pixel. Past the ends the edge keeps going and the opposite edge is
  /// clamped to the track, so the slot squashes against the wall instead of
  /// sliding out of the control.
  double _edge(double index) {
    if (index <= 0) return index * widths.first;
    if (index >= count) {
      final total = widths.reduce((a, b) => a + b);
      return total + (index - count) * widths.last;
    }
    final lower = index.floor();
    var x = 0.0;
    for (var i = 0; i < lower; i++) {
      x += widths[i];
    }
    return x + (index - lower) * widths[lower];
  }

  @override
  Widget build(BuildContext context) {
    if (widths.length < count || widths.any((w) => w <= 0)) {
      return const SizedBox.shrink();
    }
    final total = widths.reduce((a, b) => a + b);

    // `Positioned` inside an `AnimatedOpacity` would not be positioned at all
    // — the opacity is what the stack sees — so the fade always wraps the
    // decoration and the positioning stays on the outside.
    Widget slotAt(double start, double width, double opacity) =>
        PositionedDirectional(
          start: start,
          top: 0,
          bottom: 0,
          width: width,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: duration,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: shape,
                shadows: shadows,
              ),
            ),
          ),
        );

    if (multiple) {
      // Every slot is built, on or off, so a toggle fades rather than
      // appearing: an `Opacity` at zero paints nothing, so the ones that are
      // off cost a widget and no pixels.
      return Stack(
        children: <Widget>[
          for (var i = 0; i < count; i++)
            slotAt(_edge(i.toDouble()), widths[i], selectedness[i]),
        ],
      );
    }

    final leading = _edge(slot).clamp(0.0, total);
    final trailing = _edge(slot + 1).clamp(0.0, total);

    return Stack(
      children: <Widget>[
        slotAt(
          leading,
          (trailing - leading).clamp(0.0, total),
          present ? 1 : 0,
        ),
      ],
    );
  }
}

/// Reports its own width without changing it.
///
/// Two numbers, not one. The laid-out width is what the indicator is placed
/// from; the intrinsic width is what the segment's content wants, and is the
/// only one [DSSegmentedSizing.fill] can weight a flex by without measuring
/// the answer it is trying to produce.
class _MeasuredSegment extends SingleChildRenderObjectWidget {
  const _MeasuredSegment({required this.onMeasured, required super.child});

  final void Function(double laidOut, double intrinsic) onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onMeasured);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onMeasured);

  void Function(double laidOut, double intrinsic) onMeasured;

  @override
  void performLayout() {
    super.performLayout();
    final child = this.child;
    onMeasured(
      size.width,
      child == null ? size.width : child.getMaxIntrinsicWidth(size.height),
    );
  }
}

/// One option in a [DSSegmentedButton].
///
/// A widget rather than the closed three-field model it was, so a segment can
/// carry a count, be disabled, be icon-only with a tooltip, or hold whatever
/// the caller puts in its slots.
class DSSegment<T> extends StatelessWidget {
  const DSSegment({
    super.key,
    required this.value,
    this.label,
    this.icon,
    this.count,
    this.tooltip,
    this.enabled = true,
    this.leading,
    this.trailing,
    this.labelSlot,
  }) : assert(
         label != null || tooltip != null,
         'a segment with no visible label must be given a tooltip — an '
         'icon-only cell has no text for a screen reader to read, and the '
         'tooltip is what names it for both a pointer and a screen reader',
       );

  final T value;
  final String? label;
  final IconData? icon;

  /// The number beside the label — "All 12", "Unread 3". The commonest thing
  /// a segmented control holds, and the closed model had nowhere to put it.
  final int? count;

  final String? tooltip;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;

  @override
  Widget build(BuildContext context) {
    final scope = _DSSegmentedScope.of(context);
    final style = scope.style;
    final index = _indexOfSelf(context);
    final selectedness = index == null ? 0.0 : scope.selectedness[index];
    final chosen = scope.chosen.contains(value);
    final on = enabled && scope.enabled;

    final labelStyle = TextStyle.lerp(
      style.labelStyle,
      style.selectedLabelStyle,
      // Weight steps rather than interpolating: a fractional font weight snaps
      // to the nearest available one anyway, and half a segment is where the
      // label reads as arrived.
      selectedness > 0.5 ? 1 : 0,
    );
    final color = Color.lerp(
      style.labelStyle?.color,
      style.selectedLabelStyle?.color,
      selectedness,
    );

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          leading!
        else if (icon != null)
          Icon(icon, size: style.iconSize, color: color),
        if ((leading != null || icon != null) &&
            (label != null || labelSlot != null))
          SizedBox(width: context.design.space.xs),
        if (labelSlot != null)
          Flexible(child: labelSlot!)
        else if (label != null)
          Flexible(
            child: Text(
              label!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: labelStyle?.copyWith(color: color),
            ),
          ),
        if (trailing != null)
          trailing!
        else if (count != null) ...[
          SizedBox(width: context.design.space.xs),
          DSSegmentCount(count: count!),
        ],
      ],
    );

    content = Padding(padding: style.segmentPadding!, child: content);

    // Only when *this* segment is the disabled one. The control already dims
    // itself as a whole, and a segment that dimmed again inside it multiplied
    // the two — 0.38 of 0.38 is 0.14, and a disabled control at fourteen per
    // cent is not a disabled control, it is a control that vanished.
    if (scope.enabled && !enabled) {
      content = Opacity(opacity: style.disabledOpacity!, child: content);
    }

    // The hairline before this segment, faded out near the indicator.
    if ((style.showDividers ?? false) &&
        index != null &&
        scope.dividerBefore[index] > 0) {
      content = Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: context.design.space.xs,
            bottom: context.design.space.xs,
            child: ColoredBox(
              color: style.dividerColor!.withValues(
                alpha: scope.dividerBefore[index],
              ),
              child: SizedBox(width: context.design.component.hairlineWidth),
            ),
          ),
          content,
        ],
      );
    }

    content = AppChoiceLabel(child: content);

    final Widget tile = Semantics(
      container: true,
      button: true,
      // In single mode the group is exclusive and says so; in multiple mode
      // each segment is a toggle reporting its own state, and claiming
      // exclusivity there would be a lie a screen reader repeats.
      inMutuallyExclusiveGroup: scope.multiple ? null : true,
      selected: chosen,
      label: label ?? tooltip,
      tooltip: label == null ? tooltip : null,
      enabled: on,
      onTap: on ? () => scope.onSelect(value) : null,
      excludeSemantics: true,
      // The segment paints at the track's height and is a target at the
      // floor. Outside the ink, inside the semantics: the node a screen
      // reader and the probe both read is this box, and the ripple still
      // stops at the pill.
      child: DSTapTarget(
        child: DSPressable(
          // The control does not scale. A segmented control that shrinks under
          // the finger detaches from the track it sits in; the label dims
          // instead, which is what both platforms do.
          enabled: false,
          focusShape: context.shapeOf(AppShape.control),
          child: _PressDim(
            enabled: on,
            onTap: on ? () => scope.onSelect(value) : null,
            duration: context.design.motion.press,
            child: Center(
              widthFactor: scope.hugContent ? 1 : null,
              child: content,
            ),
          ),
        ),
      ),
    );

    return tooltip != null && label != null
        ? Tooltip(message: tooltip!, child: tile)
        : tile;
  }

  /// Which slot this segment occupies.
  ///
  /// By value rather than by position in the child list, so a caller who wraps
  /// a segment in their own widget still lands in the right slot. The control
  /// publishes the values it laid out, which is what lets the segment find
  /// itself without an index being threaded through a `List<Widget>` whose
  /// shape the control does not own.
  int? _indexOfSelf(BuildContext context) {
    final values = _DSSegmentedValues.of(context);
    final found = values?.indexOf(value) ?? -1;
    return found >= 0 ? found : null;
  }
}

/// Press feedback for a segment: the content dims and springs back.
///
/// The control deliberately does not scale — a segmented control that shrinks
/// under the finger detaches from the track it sits in — which left it with no
/// press feedback at all, in a kit whose documented floor includes it. Both
/// platforms dim the label instead, and this is that: a [Listener]-free
/// gesture recogniser that owns the tap it is already wrapping, and an opacity
/// on the content only, so the raised slot underneath does not flicker.
class _PressDim extends StatefulWidget {
  const _PressDim({
    required this.child,
    required this.enabled,
    required this.onTap,
    required this.duration,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;
  final Duration duration;

  /// Deep enough to read as a press, well short of the disabled step: a
  /// pressed segment that looks disabled is a control reporting the wrong
  /// state for the length of a tap.
  static const double pressedOpacity = 0.6;

  @override
  State<_PressDim> createState() => _PressDimState();
}

class _PressDimState extends State<_PressDim> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.enabled ? (_) => _set(true) : null,
      onTapUp: widget.enabled ? (_) => _set(false) : null,
      onTapCancel: widget.enabled ? () => _set(false) : null,
      child: AnimatedOpacity(
        opacity: _pressed ? _PressDim.pressedOpacity : 1,
        duration: widget.duration,
        child: widget.child,
      ),
    );
  }
}

/// The values the control laid out, in order.
///
/// Separate from [_DSSegmentedScope] only so a segment can find its own slot
/// without the parent passing an index through a `List<Widget>` it does not
/// control the shape of.
@immutable
class _DSSegmentedValues extends InheritedWidget {
  const _DSSegmentedValues({required this.values, required super.child});

  final List<Object?> values;

  static List<Object?>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DSSegmentedValues>()?.values;

  @override
  bool updateShouldNotify(_DSSegmentedValues old) => true;
}

/// The count pill a segment carries.
// ds-tier: 1 — atom — A number beside a segment label.
class DSSegmentCount extends StatelessWidget {
  const DSSegmentCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scope = _DSSegmentedScope.of(context);
    return Text('$count', style: scope.style.countStyle);
  }
}

/// The control's shape while its labels are still arriving.
///
/// The same segment count at the same height, so the row does not resize when
/// the words land — a segmented control that changes width on load pushes
/// everything beside it.
class DSSegmentedButtonSkeleton extends StatelessWidget {
  const DSSegmentedButtonSkeleton({
    super.key,
    this.segments = 3,
    this.size = DSSegmentedButtonSize.md,
  });

  final int segments;
  final DSSegmentedButtonSize size;

  @override
  Widget build(BuildContext context) {
    final style = DSSegmentedButtonStyle.resolve(context, size);
    return Container(
      height: style.height,
      padding: EdgeInsets.all(style.trackInset!),
      decoration: ShapeDecoration(
        color: style.trackFill,
        shape: context.shapeOf(AppShape.control),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments; i++)
            Expanded(
              child: Padding(
                padding: style.segmentPadding!,
                // A word, not five spaces. `Skeletonizer` draws a text bone at
                // the width the string lays out to, and whitespace lays out to
                // nothing — the loading state was an empty pill with no bones
                // in it at all, which reads as a control that failed rather
                // than one that is waiting.
                //
                // And the bones are drawn in the raised role rather than the
                // kit's default inert one, which is the defect the skeleton's
                // own doc comment describes happening on a card: `inert` and
                // `well` are neighbours on the ramp, so a bone at the default
                // colour on this control's track is a bone nobody can see.
                child: Center(
                  child: DSSkeleton(
                    style: DSSkeletonStyle(
                      boneColor: style.indicatorFill,
                      highlightColor: Color.alphaBlend(
                        context.palette.sheen.withValues(alpha: 0.10),
                        style.indicatorFill!,
                      ),
                    ),
                    child: Text('Label', style: style.labelStyle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
