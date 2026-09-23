// ds-tier: 2 — molecule

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// What one step of a sequence is.
///
/// A state enum rather than five booleans, because a builder handed booleans
/// grows a sixth parameter the first time a state is added.
enum DSStepState { complete, current, upcoming, error, skipped }

/// How the sequence is drawn.
enum DSSegmentedProgressShape {
  /// Segments in a track. The default, and the only one that scales past five.
  bar,

  /// Dots, for a carousel or a sequence whose steps have no names. Never for
  /// a form: a form's steps have names, and hiding them is a worse
  /// experience rather than a denser one.
  dots,

  /// Numbered nodes joined by a rule, with the step name under each. Capped
  /// at five by assertion.
  labelled,
}

/// [DSSegmentedProgress]'s appearance, as data.
@immutable
class DSSegmentedProgressStyle
    extends DSComponentStyle<DSSegmentedProgressStyle> {
  const DSSegmentedProgressStyle({
    this.segmentHeight,
    this.segmentGap,
    this.currentFlex,
    this.radius,
    this.completeColor,
    this.currentColor,
    this.upcomingColor,
    this.errorColor,
    this.dotSize,
    this.currentDotSize,
    this.nodeSize,
    this.currentNodeSize,
    this.connectorWidth,
    this.labelStyle,
    this.counterStyle,
    this.headerGap,
  });

  final double? segmentHeight;
  final double? segmentGap;

  /// How much wider the current segment is than its neighbours.
  ///
  /// A style field rather than a constant because it is the *non-colour*
  /// channel WCAG 1.4.1 asks for: position and size carry the current step and
  /// colour only reinforces it. It is tunable and it cannot be tuned to
  /// nothing — [resolve] asserts it stays above 1.
  final double? currentFlex;

  final BorderRadius? radius;
  final Color? completeColor;
  final Color? currentColor;
  final Color? upcomingColor;
  final Color? errorColor;

  final double? dotSize;
  final double? currentDotSize;
  final double? nodeSize;

  /// The current node's diameter, under `.labelled`.
  ///
  /// The labelled shape's answer to [currentFlex], and there for the same
  /// reason: size is the non-colour channel WCAG 1.4.1 asks for. It matters
  /// more here than on the bar, because `completeColor` and `currentColor`
  /// default to one hue two lightness steps apart — a tick and a digit were
  /// the only thing telling the two apart before this existed. [resolve]
  /// asserts it stays above [nodeSize].
  final double? currentNodeSize;

  final double? connectorWidth;

  final TextStyle? labelStyle;
  final TextStyle? counterStyle;
  final double? headerGap;

  @override
  DSSegmentedProgressStyle merge(DSSegmentedProgressStyle? other) {
    if (other == null) return this;
    return DSSegmentedProgressStyle(
      segmentHeight: other.segmentHeight ?? segmentHeight,
      segmentGap: other.segmentGap ?? segmentGap,
      currentFlex: other.currentFlex ?? currentFlex,
      radius: other.radius ?? radius,
      completeColor: other.completeColor ?? completeColor,
      currentColor: other.currentColor ?? currentColor,
      upcomingColor: other.upcomingColor ?? upcomingColor,
      errorColor: other.errorColor ?? errorColor,
      dotSize: other.dotSize ?? dotSize,
      currentDotSize: other.currentDotSize ?? currentDotSize,
      nodeSize: other.nodeSize ?? nodeSize,
      currentNodeSize: other.currentNodeSize ?? currentNodeSize,
      connectorWidth: other.connectorWidth ?? connectorWidth,
      labelStyle: other.labelStyle ?? labelStyle,
      counterStyle: other.counterStyle ?? counterStyle,
      headerGap: other.headerGap ?? headerGap,
    );
  }

  @override
  DSSegmentedProgressStyle copyWith({
    double? segmentHeight,
    double? segmentGap,
    double? currentFlex,
    BorderRadius? radius,
    Color? completeColor,
    Color? currentColor,
    Color? upcomingColor,
    Color? errorColor,
    double? dotSize,
    double? currentDotSize,
    double? nodeSize,
    double? currentNodeSize,
    double? connectorWidth,
    TextStyle? labelStyle,
    TextStyle? counterStyle,
    double? headerGap,
  }) => DSSegmentedProgressStyle(
    segmentHeight: segmentHeight ?? this.segmentHeight,
    segmentGap: segmentGap ?? this.segmentGap,
    currentFlex: currentFlex ?? this.currentFlex,
    radius: radius ?? this.radius,
    completeColor: completeColor ?? this.completeColor,
    currentColor: currentColor ?? this.currentColor,
    upcomingColor: upcomingColor ?? this.upcomingColor,
    errorColor: errorColor ?? this.errorColor,
    dotSize: dotSize ?? this.dotSize,
    currentDotSize: currentDotSize ?? this.currentDotSize,
    nodeSize: nodeSize ?? this.nodeSize,
    currentNodeSize: currentNodeSize ?? this.currentNodeSize,
    connectorWidth: connectorWidth ?? this.connectorWidth,
    labelStyle: labelStyle ?? this.labelStyle,
    counterStyle: counterStyle ?? this.counterStyle,
    headerGap: headerGap ?? this.headerGap,
  );

  @override
  DSSegmentedProgressStyle lerp(DSSegmentedProgressStyle? other, double t) {
    if (other == null) return this;
    return DSSegmentedProgressStyle(
      segmentHeight: lerpDouble(segmentHeight, other.segmentHeight, t),
      segmentGap: lerpDouble(segmentGap, other.segmentGap, t),
      currentFlex: lerpDouble(currentFlex, other.currentFlex, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      completeColor: Color.lerp(completeColor, other.completeColor, t),
      currentColor: Color.lerp(currentColor, other.currentColor, t),
      upcomingColor: Color.lerp(upcomingColor, other.upcomingColor, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      dotSize: lerpDouble(dotSize, other.dotSize, t),
      currentDotSize: lerpDouble(currentDotSize, other.currentDotSize, t),
      nodeSize: lerpDouble(nodeSize, other.nodeSize, t),
      currentNodeSize: lerpDouble(currentNodeSize, other.currentNodeSize, t),
      connectorWidth: lerpDouble(connectorWidth, other.connectorWidth, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      counterStyle: TextStyle.lerp(counterStyle, other.counterStyle, t),
      headerGap: lerpDouble(headerGap, other.headerGap, t),
    );
  }

  static DSSegmentedProgressStyle resolve(
    BuildContext context, [
    DSSegmentedProgressStyle? own,
  ]) {
    final palette = context.palette;
    final space = context.design.space;
    final text = Theme.of(context).textTheme;
    final height = space.sm - space.hairline;

    final resolved = resolveStyle(
      context: context,
      specDefaults: DSSegmentedProgressStyle(
        segmentHeight: height,
        segmentGap: space.xs,
        currentFlex: 1.6,
        radius: BorderRadius.circular(height / 2),
        completeColor: palette.chart[0],
        currentColor: palette.primary,
        upcomingColor: palette.border,
        errorColor: palette.destructive,
        dotSize: space.sm - space.hairline,
        currentDotSize: space.md - space.hairline,
        nodeSize: space.xl,
        currentNodeSize: space.xxl,
        connectorWidth: context.design.component.hairlineWidth * 2,
        labelStyle: text.labelSmall,
        counterStyle: text.labelMedium
            ?.copyWith(color: palette.mutedForeground)
            .tabular,
        headerGap: space.xs,
      ),
      own: own,
    );
    assert(
      (resolved.currentNodeSize ?? 0) > (resolved.nodeSize ?? 0),
      'currentNodeSize is what currentFlex is on the bar: under `.labelled` '
      'the current step is marked by diameter as well as tone. Sizing it to '
      'its neighbours leaves colour as the only signal, and complete and '
      'current share a hue by default.',
    );
    assert(
      (resolved.currentFlex ?? 1.6) > 1,
      'currentFlex is the non-colour channel that marks the current step. '
      'Tuning it to 1 leaves colour as the only signal, which is exactly '
      'what WCAG 1.4.1 forbids.',
    );
    return resolved;
  }
}

/// An ordinal position in a fixed, countable sequence: step 3 of 5.
///
/// See `docs/plans/04-ds-segmented-progress.plan.md`. Discrete segments,
/// because the count itself is the information: "60% of the way" is a
/// different and less useful fact than "step 3 of 5, and there are two left",
/// and a continuous fill removes the thing the user is counting.
///
/// The current step is both **larger** and a different tone — a wider
/// segment on the bar, a bigger node under `.labelled`. The size is the
/// point: colour alone would fail SC 1.4.1 on a six-point bar, and it fails
/// it on a node too, where complete and current default to one hue two
/// lightness steps apart.
///
/// Reached segments become interactive only when [onStepTap] is given, and
/// upcoming steps never do — the component does not imply a tap it will not
/// honour.
class DSSegmentedProgress extends StatelessWidget {
  const DSSegmentedProgress({
    super.key,
    required this.currentStep,
    required int totalSteps,
    this.label,
    this.errorSteps = const {},
    this.skippedSteps = const {},
    this.onStepTap,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.labelSlot,
    this.counterSlot,
    this.stepBuilder,
    this.counterFormatter,
  }) : shape = DSSegmentedProgressShape.bar,
       stepLabels = const [],
       stepLabel = null,
       _declaredTotalSteps = totalSteps,
       assert(
         currentStep >= 1 && currentStep <= totalSteps,
         'currentStep is 1-based, like the number the user is reading',
       );

  /// Dots, for a carousel or a sequence whose steps have no names.
  const DSSegmentedProgress.dots({
    super.key,
    required this.currentStep,
    required int totalSteps,
    this.label,
    this.errorSteps = const {},
    this.skippedSteps = const {},
    this.onStepTap,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.labelSlot,
    this.counterSlot,
    this.stepBuilder,
    this.counterFormatter,
  }) : shape = DSSegmentedProgressShape.dots,
       stepLabels = const [],
       stepLabel = null,
       _declaredTotalSteps = totalSteps,
       assert(currentStep >= 1 && currentStep <= totalSteps);

  /// Numbered nodes with the step name under each.
  ///
  /// Capped at five: at six the labels collide at text scale 1 on a 320dp
  /// screen, and a component that silently truncates the name of the step you
  /// are on is worse than one that refuses to build.
  // Not const, and the analyzer's suggestion that it should be is wrong here:
  // the two assertions below read `stepLabels.length`, and a const constructor
  // may only assert on const-evaluable expressions.
  // ignore: prefer_const_constructors_in_immutables
  DSSegmentedProgress.labelled({
    super.key,
    required this.currentStep,
    required this.stepLabels,
    this.label,
    this.errorSteps = const {},
    this.skippedSteps = const {},
    this.onStepTap,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.labelSlot,
    this.counterSlot,
    this.stepBuilder,
    this.stepLabel,
    this.counterFormatter,
  }) : shape = DSSegmentedProgressShape.labelled,
       _declaredTotalSteps = null,
       assert(
         stepLabels.length <= 5,
         'Past five, labelled nodes collide on a phone. Use the bar and a '
         '"3 of 12" counter instead — the `instead` rule in the reference '
         'says the same thing.',
       ),
       assert(currentStep >= 1 && currentStep <= stepLabels.length);

  /// 1-based, because that is the number the user is reading. [errorSteps] and
  /// [skippedSteps] agree with it by construction, so there is no off-by-one
  /// between the two to ship.
  final int currentStep;

  /// Null on `.labelled`, where the names are the count. A getter rather than
  /// a second source of truth: an off-by-one between the labels and the total
  /// is exactly the bug that ships.
  final int? _declaredTotalSteps;

  int get totalSteps => _declaredTotalSteps ?? stepLabels.length;

  final String? label;
  final Set<int> errorSteps;
  final Set<int> skippedSteps;

  /// Null means not interactive — and not *implied* to be.
  final ValueChanged<int>? onStepTap;

  final bool enabled;
  final bool loading;
  final DSSegmentedProgressStyle? style;

  final Widget? labelSlot;

  /// Replaces the generated "3 of 5" — for "Payment · 3 of 5", or a percent.
  final Widget? counterSlot;

  /// Total replacement of one segment's paint, with its state handed in. The
  /// component still owns the layout, the flex exchange, the tap targets and
  /// the semantics, so a caller who needs a per-step avatar or duration keeps
  /// all four.
  final Widget Function(BuildContext context, DSStepState state, int index)?
  stepBuilder;

  /// Labelled only — the text under a node.
  final Widget Function(BuildContext context, int index)? stepLabel;

  final String Function(int current, int total)? counterFormatter;

  final DSSegmentedProgressShape shape;
  final List<String> stepLabels;

  static String countOf(int current, int total) => '$current of $total';

  /// The state of the 1-based step [step].
  DSStepState stateOf(int step) {
    if (errorSteps.contains(step)) return DSStepState.error;
    if (skippedSteps.contains(step)) return DSStepState.skipped;
    // The last step being current *and* complete takes the current tone once,
    // rather than two fills overlaid.
    if (step == currentStep) return DSStepState.current;
    return step < currentStep ? DSStepState.complete : DSStepState.upcoming;
  }

  Color _colorFor(DSStepState state, DSSegmentedProgressStyle s, Palette p) {
    if (!enabled) return s.upcomingColor ?? p.borderSoft;
    return switch (state) {
      DSStepState.complete => s.completeColor ?? p.chart[0],
      DSStepState.current => s.currentColor ?? p.primary,
      DSStepState.error => s.errorColor ?? p.destructive,
      DSStepState.upcoming ||
      DSStepState.skipped => s.upcomingColor ?? p.borderSoft,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final resolved = DSSegmentedProgressStyle.resolve(context, style);
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);

    // Past this scale five labelled nodes with 2x text do not fit any phone,
    // and shrinking the label to make them fit is the failure this avoids.
    final collapsed =
        shape == DSSegmentedProgressShape.labelled &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final effectiveShape = collapsed ? DSSegmentedProgressShape.bar : shape;

    final counter =
        counterSlot ??
        Text(
          (counterFormatter ?? countOf)(currentStep, totalSteps),
          style: resolved.counterStyle,
        );
    final header = (label == null && labelSlot == null)
        ? null
        : Row(
            children: [
              Expanded(
                child:
                    labelSlot ??
                    Text(
                      label!,
                      style: resolved.labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              counter,
            ],
          );

    final Widget track = TweenAnimationBuilder<double>(
      // The exchange runs on one drive rather than two independent tweens:
      // the weights below sum to a constant, so the track never visibly
      // changes total width mid-transition.
      tween: Tween<double>(end: currentStep.toDouble()),
      duration: reduced ? Duration.zero : motion.scaled(motion.normal),
      curve: motion.enter,
      builder: (context, animatedStep, _) => switch (effectiveShape) {
        DSSegmentedProgressShape.bar => _bar(
          context,
          resolved,
          palette,
          animatedStep,
        ),
        DSSegmentedProgressShape.dots => _dots(context, resolved, palette),
        DSSegmentedProgressShape.labelled => _labelled(
          context,
          resolved,
          palette,
          animatedStep,
        ),
      },
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header,
          SizedBox(height: resolved.headerGap ?? context.design.space.xs),
        ],
        // The whole track wears bones at once: five shimmering rectangles
        // read as a list loading rather than as one control.
        DSSkeleton(enabled: loading, child: track),
      ],
    );

    return Semantics(
      container: true,
      label: label,
      value: label == null
          ? 'Step $currentStep of $totalSteps'
          : 'Step $currentStep of $totalSteps, $label',
      // Per-step nodes exist only where a tap does something; otherwise a
      // reader arrows through five rectangles to learn they are on step three.
      child: onStepTap == null ? ExcludeSemantics(child: content) : content,
    );
  }

  /// One segment's weight at [animatedStep].
  ///
  /// A triangle around the current position: at an integer step exactly one
  /// segment carries the extra, and mid-transition the two share it — so the
  /// weights always sum to `totalSteps + (currentFlex - 1)`.
  double _weight(int step, double animatedStep, double currentFlex) {
    final distance = (step - animatedStep).abs();
    final share = distance >= 1 ? 0.0 : 1 - distance;
    return 1 + (currentFlex - 1) * share;
  }

  Widget _bar(
    BuildContext context,
    DSSegmentedProgressStyle s,
    Palette palette,
    double animatedStep,
  ) {
    final height = s.segmentHeight ?? context.design.space.sm;
    final gap = s.segmentGap ?? context.design.space.xs;
    final currentFlex = s.currentFlex ?? 1.6;
    final radius = s.radius ?? BorderRadius.circular(height / 2);

    return Row(
      children: [
        for (var step = 1; step <= totalSteps; step++) ...[
          if (step > 1) SizedBox(width: gap),
          Expanded(
            flex: (_weight(step, animatedStep, currentFlex) * 1000).round(),
            child: _target(
              context,
              step: step,
              cellHeight: _cellHeight(context, height),
              painted: SizedBox(
                height: height,
                child:
                    stepBuilder?.call(context, stateOf(step), step) ??
                    (stateOf(step) == DSStepState.skipped
                        ? CustomPaint(
                            painter: _DashedSegment(
                              color: _colorFor(DSStepState.skipped, s, palette),
                              dash: height,
                            ),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: _colorFor(stateOf(step), s, palette),
                              borderRadius: radius,
                            ),
                          )),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dots(
    BuildContext context,
    DSSegmentedProgressStyle s,
    Palette palette,
  ) {
    final dot = s.dotSize ?? context.design.space.sm;
    final currentDot = s.currentDotSize ?? context.design.space.md;
    final gap = context.design.space.sm;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var step = 1; step <= totalSteps; step++) ...[
          if (step > 1) SizedBox(width: gap),
          _target(
            context,
            step: step,
            cellHeight: _cellHeight(context, currentDot),
            painted:
                stepBuilder?.call(context, stateOf(step), step) ??
                SizedBox(
                  width: stateOf(step) == DSStepState.current
                      ? currentDot
                      : dot,
                  height: stateOf(step) == DSStepState.current
                      ? currentDot
                      : dot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _colorFor(stateOf(step), s, palette),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
          ),
        ],
      ],
    );
  }

  Widget _labelled(
    BuildContext context,
    DSSegmentedProgressStyle s,
    Palette palette,
    double animatedStep,
  ) {
    final space = context.design.space;
    final node = s.nodeSize ?? space.xl;
    final currentNode = s.currentNodeSize ?? space.xxl;
    final connector =
        s.connectorWidth ?? context.design.component.hairlineWidth * 2;
    // Every node is centred in a band as tall as the largest of them, so the
    // rules meet all five on one line and every label starts on one line.
    // Sizing the band to whichever node is current would move the whole row
    // each time the step advanced.
    final band = math.max(node, currentNode);
    // Measured from the *current* node's radius for every gap, current or
    // not, for the same reason. This used to be whatever the label's width
    // left over: the cells were as wide as their names, so "Review" pushed
    // the rules beside it eight points further out than "Pay" did and no two
    // nodes sat on the same pitch.
    final inset = currentNode / 2 + space.xs;

    return Stack(
      children: [
        // The rules run node centre to node centre, which is why this row is
        // half a cell shorter at each end than the row of nodes below it.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: band,
          child: Row(
            children: [
              const Spacer(),
              for (var step = 1; step < totalSteps; step++)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: _Connector(
                      thickness: connector,
                      // The same drive the bar runs on. The labelled shape
                      // ignored `animatedStep` while sitting inside the tween
                      // that computes it, so it was the one shape that
                      // snapped.
                      filled: (animatedStep - step).clamp(0.0, 1.0),
                      completeColor: _colorFor(
                        DSStepState.complete,
                        s,
                        palette,
                      ),
                      upcomingColor: _colorFor(
                        DSStepState.upcoming,
                        s,
                        palette,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var step = 1; step <= totalSteps; step++)
              // Equal cells are the point: a node's position is geometry now
              // rather than a consequence of how long its name is, so bolding
              // the current label cannot shift the row sideways.
              Expanded(
                flex: 2,
                child: _labelledCell(
                  context,
                  s,
                  palette,
                  step: step,
                  band: band,
                  size: stateOf(step) == DSStepState.current
                      ? currentNode
                      : node,
                  borderWidth: connector,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _labelledCell(
    BuildContext context,
    DSSegmentedProgressStyle s,
    Palette palette, {
    required int step,
    required double band,
    required double size,
    required double borderWidth,
  }) {
    final state = stateOf(step);

    return _labelledTarget(
      context,
      step: step,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: band,
            child: Center(
              child:
                  stepBuilder?.call(context, state, step) ??
                  _Node(
                    size: size,
                    state: state,
                    color: _colorFor(state, s, palette),
                    index: step,
                    onColor: palette.primaryForeground,
                    // The ring and the rule that meets it are one weight. A
                    // hairline circle touching a two-point rule reads as an
                    // unfinished drawing.
                    borderWidth: borderWidth,
                  ),
            ),
          ),
          SizedBox(height: context.design.space.xs),
          stepLabel?.call(context, step) ??
              Text(
                stepLabels[step - 1],
                style: _labelStyleFor(context, s, step, palette),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The cell is bounded now, so the ellipsis is reachable. In
                // an unbounded column it never fired and a long name overran
                // the row instead.
                textAlign: TextAlign.center,
              ),
        ],
      ),
    );
  }

  /// The node, its name, and the target that is both of them.
  ///
  /// The bar and the dots grow their *cell* to a finger ([_cellHeight]).
  /// Doing that here centred a 24-point node in a 48-point box and left
  /// twelve points of nothing between the node and the name under it, so the
  /// two read as separate rows. The pair clears the floor together, so the
  /// pair is the target — which also means the name is tappable, and a name
  /// is a larger thing to hit than a 24-point circle.
  Widget _labelledTarget(
    BuildContext context, {
    required int step,
    required Widget child,
  }) {
    final reachable = _interactive && step <= currentStep;
    if (!reachable) return ExcludeSemantics(child: child);

    return Semantics(
      button: true,
      label: 'Step $step${_stateSentence(step)}',
      // Declared here because the subtree below is excluded from semantics,
      // and a node that says "button" with no action is announced and cannot
      // be pressed.
      onTap: () => onStepTap!(step),
      child: ExcludeSemantics(
        child: DSPressable(
          // The cell is a plain rectangle: its InkWell takes no radius, and a
          // rounded ring around a square target is a drawing error.
          focusShape: const RoundedRectangleBorder(),
          // The tap floor is a guarantee rather than an observation: the pair
          // measures about fifty points at text scale 1, and less than that
          // if an identity shrinks the label.
          child: DSInkSurface(onTap: () => onStepTap!(step), child: child),
        ),
      ),
    );
  }

  TextStyle? _labelStyleFor(
    BuildContext context,
    DSSegmentedProgressStyle s,
    int step,
    Palette palette,
  ) => s.labelStyle?.copyWith(
    color: step == currentStep ? palette.foreground : palette.mutedForeground,
    fontWeight: step == currentStep ? context.design.type.emphasisWeight : null,
  );

  /// Whether any step in this instance can be tapped.
  ///
  /// A property of the whole control, never of one step. Reachability varies
  /// step by step — only steps at or behind the current one accept a tap —
  /// but the *cell* every step is drawn in may not, because the cells sit in
  /// one [Row]. A taller cell for the reachable steps left the connectors
  /// drawn through empty space above the nodes they join. So the tap target
  /// sizes the row, and the row sizes every cell in it.
  ///
  /// `.labelled` reaches the same floor without growing anything — see
  /// [_labelledTarget] — because there the name under the node is part of the
  /// target.
  bool get _interactive => onStepTap != null && enabled && !loading;

  /// The height every step's cell occupies.
  ///
  /// [fallback] is what the shape would use on its own — six points of bar, a
  /// 24-point node — and is the answer whenever nothing is tappable, so a
  /// read-only bar is not padded to a finger's height for no reason.
  double _cellHeight(BuildContext context, double fallback) => _interactive
      ? math.max(fallback, context.design.component.minTapTarget)
      : fallback;

  /// The painted segment, plus the target that is not the same size as it.
  ///
  /// SC 2.5.8's spacing exception is exactly this case: the visual is six
  /// points tall and the thing a finger has to hit is `minTapTarget`. The
  /// focus ring draws on the target, so it is visible.
  Widget _target(
    BuildContext context, {
    required int step,
    required Widget painted,
    required double cellHeight,
  }) {
    final reachable = _interactive && step <= currentStep;
    if (!reachable) {
      return ExcludeSemantics(
        child: SizedBox(
          height: cellHeight,
          child: Center(child: painted),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Step $step${_stateSentence(step)}',
      child: ExcludeSemantics(
        child: DSPressable(
          // The cell is a plain rectangle: its InkWell takes no radius, and a
          // rounded ring around a square target is a drawing error.
          focusShape: const RoundedRectangleBorder(),
          child: DSInkSurface(
            onTap: () => onStepTap!(step),
            child: SizedBox(
              height: cellHeight,
              child: Center(child: painted),
            ),
          ),
        ),
      ),
    );
  }

  String _stateSentence(int step) {
    final name = shape == DSSegmentedProgressShape.labelled
        ? ', ${stepLabels[step - 1]}'
        : '';
    return switch (stateOf(step)) {
      DSStepState.error => '$name, has an error',
      DSStepState.skipped => '$name, skipped',
      DSStepState.current => '$name, current',
      DSStepState.complete => '$name, completed',
      DSStepState.upcoming => name,
    };
  }
}

/// A numbered node, or a tick once the step is behind the user.
class _Node extends StatelessWidget {
  const _Node({
    required this.size,
    required this.state,
    required this.color,
    required this.index,
    required this.onColor,
    required this.borderWidth,
  });

  final double size;
  final DSStepState state;
  final Color color;
  final int index;
  final Color onColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final filled =
        state == DSStepState.complete ||
        state == DSStepState.current ||
        state == DSStepState.error;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: borderWidth),
        ),
        child: Center(
          child: switch (state) {
            // The tick is the state's second channel, and at 24dp there is
            // room for it — which there is not on a six-point bar.
            DSStepState.complete => Icon(
              Icons.check_rounded,
              size: size / 2,
              color: onColor,
            ),
            DSStepState.error => Icon(
              Icons.priority_high_rounded,
              size: size / 2,
              color: onColor,
            ),
            _ => Text(
              '$index',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: filled ? onColor : context.palette.mutedForeground,
                fontWeight: context.design.type.emphasisWeight,
              ),
            ),
          },
        ),
      ),
    );
  }
}

/// One rule between two nodes, filled as far as the sequence has reached.
///
/// Two layers rather than one tween of colour: a rule that changes colour all
/// at once tells the user the step is behind them before the node says so.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.thickness,
    required this.filled,
    required this.completeColor,
    required this.upcomingColor,
  });

  final double thickness;

  /// 0 to 1. Fractional mid-transition, which is the whole reason the
  /// labelled shape reads `animatedStep`.
  final double filled;

  final Color completeColor;
  final Color upcomingColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: thickness,
    child: Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(color: upcomingColor)),
        if (filled > 0)
          FractionallySizedBox(
            // Start rather than left: the sequence runs the way the script
            // does.
            alignment: AlignmentDirectional.centerStart,
            widthFactor: filled,
            child: DecoratedBox(
              decoration: BoxDecoration(color: completeColor),
            ),
          ),
      ],
    ),
  );
}

/// A skipped step: present, countable, and visibly not filled.
///
/// Never omitted — dropping it would make the count dishonest, and the count
/// is the whole reason this component exists rather than a bar.
class _DashedSegment extends CustomPainter {
  const _DashedSegment({required this.color, required this.dash});

  final Color color;
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(
        Offset(x + dash / 2, y),
        Offset((x + dash * 1.5).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedSegment old) =>
      old.color != color || old.dash != dash;
}
