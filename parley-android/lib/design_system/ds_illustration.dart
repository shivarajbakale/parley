// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The six drawings the kit ships.
///
/// Six, not sixteen: these are the states a *generic* app reaches. A kind a
/// caller cannot map onto is a signal they want their own
/// [DSIllustrationDelegate], not a seventh drawing in the kit.
enum DSIllustrationKind {
  /// An open container — nothing has been put here yet.
  empty,

  /// A lens over a flat field — the search or the filter matched nothing.
  search,

  /// A broken link between two nodes — the device cannot reach the backend.
  offline,

  /// A checked mark completing a stack — the queue is finished.
  done,

  /// A closed form with a keyed seam — the content needs a permission the
  /// user has not granted.
  locked,

  /// A tilted, interrupted shape — something failed.
  error,
}

/// The three boxes a drawing occupies: 96, 144 and 200 by default.
enum DSIllustrationSize { small, medium, large }

/// How an illustration is drawn, at every layer of the resolution chain.
///
/// There is no `Color` parameter on [DSIllustration] itself. Every colour a
/// drawing uses is one of these four, each read from the palette in [resolve],
/// so an app that changes its brand hue changes its illustrations with it —
/// which a shipped raster or a baked Lottie cannot do.
@immutable
class DSIllustrationStyle extends DSComponentStyle<DSIllustrationStyle> {
  const DSIllustrationStyle({
    this.size,
    this.strokeWidth,
    this.groundColor,
    this.bodyColor,
    this.accentColor,
    this.lineColor,
    this.duration,
    this.curve,
    this.crossFadeDuration,
  });

  /// The side of the square the drawing is painted into. Square and fixed:
  /// the box is reserved before the drawing arrives, so a slow first frame
  /// cannot push the title under it down the screen.
  final double? size;

  /// Stated at [ComponentSpec.illustrationSize] and scaled linearly with
  /// [size], so a small drawing is a smaller drawing rather than the same
  /// drawing with heavier lines.
  final double? strokeWidth;

  /// The plate every scene is built on — the recess, so the drawing reads on
  /// the page and on a card.
  final Color? groundColor;

  /// The tone's derived container: the one part of the drawing that carries
  /// the meaning of [DSIllustration.tone].
  final Color? bodyColor;

  /// The single emphatic mark — the check, the keyhole, the interruption.
  final Color? accentColor;

  /// Boundaries. Held at 3:1 against [groundColor] in both themes by
  /// `test/design_system/ds_illustration_test.dart` (WCAG 1.4.11), which is
  /// what stops a drawing from dissolving into the dark ground.
  final Color? lineColor;

  /// One pass, then still. There is no way to ask for a second.
  final Duration? duration;
  final Curve? curve;

  /// How long the drawing takes to swap when [DSIllustration.kind] changes.
  final Duration? crossFadeDuration;

  @override
  DSIllustrationStyle merge(DSIllustrationStyle? other) {
    if (other == null) return this;
    return DSIllustrationStyle(
      size: other.size ?? size,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      groundColor: other.groundColor ?? groundColor,
      bodyColor: other.bodyColor ?? bodyColor,
      accentColor: other.accentColor ?? accentColor,
      lineColor: other.lineColor ?? lineColor,
      duration: other.duration ?? duration,
      curve: other.curve ?? curve,
      crossFadeDuration: other.crossFadeDuration ?? crossFadeDuration,
    );
  }

  @override
  DSIllustrationStyle copyWith({
    double? size,
    double? strokeWidth,
    Color? groundColor,
    Color? bodyColor,
    Color? accentColor,
    Color? lineColor,
    Duration? duration,
    Curve? curve,
    Duration? crossFadeDuration,
  }) => DSIllustrationStyle(
    size: size ?? this.size,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    groundColor: groundColor ?? this.groundColor,
    bodyColor: bodyColor ?? this.bodyColor,
    accentColor: accentColor ?? this.accentColor,
    lineColor: lineColor ?? this.lineColor,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    crossFadeDuration: crossFadeDuration ?? this.crossFadeDuration,
  );

  @override
  DSIllustrationStyle lerp(DSIllustrationStyle? other, double t) {
    if (other == null) return this;
    return DSIllustrationStyle(
      size: lerpDouble(size, other.size, t),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      groundColor: Color.lerp(groundColor, other.groundColor, t),
      bodyColor: Color.lerp(bodyColor, other.bodyColor, t),
      accentColor: Color.lerp(accentColor, other.accentColor, t),
      lineColor: Color.lerp(lineColor, other.lineColor, t),
      // Two durations and a curve, none of which has a midpoint worth
      // painting: a drawing halfway between a 500ms reveal and a 300ms one is
      // not a thing anybody asked for.
      duration: t < 0.5 ? duration : other.duration,
      curve: t < 0.5 ? curve : other.curve,
      crossFadeDuration: t < 0.5 ? crossFadeDuration : other.crossFadeDuration,
    );
  }

  static DSIllustrationStyle resolve(
    BuildContext context, {
    DSTone tone = DSTone.neutral,
    DSIllustrationSize size = DSIllustrationSize.medium,
    DSIllustrationStyle? own,
  }) {
    final design = context.design;
    final component = design.component;
    final palette = context.palette;

    final box = switch (size) {
      DSIllustrationSize.small => component.illustrationSizeSm,
      DSIllustrationSize.medium => component.illustrationSize,
      DSIllustrationSize.large => component.illustrationSizeLg,
    };

    // The same derived pair a well uses, so a drawing and the glyph it
    // replaces carry the tone the same way.
    final (Color body, Color accent) = switch (tone) {
      DSTone.neutral => (palette.secondary, palette.primary),
      DSTone.info => (palette.tint(palette.primary), palette.primary),
      DSTone.success => (palette.tint(palette.success), palette.success),
      DSTone.warning => (palette.tint(palette.warning), palette.warning),
      DSTone.error => (palette.tint(palette.destructive), palette.destructive),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSIllustrationStyle(
        size: box,
        strokeWidth:
            component.illustrationStroke * (box / component.illustrationSize),
        groundColor: palette.muted,
        bodyColor: body,
        accentColor: accent,
        // The ink, not the hairline. `outline` is tuned to separate a card
        // from a page at one pixel; a drawing is read as a shape, and the
        // hairline misses the 3:1 graphical floor on the light recess.
        lineColor: palette.mutedForeground,
        duration: design.motion.scaled(design.motion.slow),
        curve: design.motion.enter,
        crossFadeDuration: design.motion.scaled(design.motion.fast),
      ),
      own: own,
    );
  }
}

/// Where the drawing itself comes from.
///
/// The point of the plan this component implements. The kit paints its six
/// kinds with a [CustomPainter], which costs no dependency and no asset and
/// recolours with the palette by construction — and whose ceiling is low: it
/// will never be a designer's character art.
///
/// An app that has real art writes one delegate returning `Lottie.asset(...)`
/// or a `RiveAnimation`, installs it once with [DSIllustrationScope], and
/// every illustration in the app changes — without the kit depending on
/// either package and without a single call site being touched.
///
/// [progress] runs 0 → 1 exactly once and is already 1 under reduced motion,
/// so a delegate never has to ask about `MediaQuery`: paint the frame it is
/// given.
///
/// A delegate's drawing carries no text. Words baked into art cannot be
/// translated, cannot be scaled by the text-scale setting and are invisible to
/// a screen reader; the words belong in the title beneath the box.
abstract class DSIllustrationDelegate {
  const DSIllustrationDelegate();

  Widget build(
    BuildContext context,
    DSIllustrationKind kind,
    double progress,
    DSIllustrationStyle style,
  );
}

/// The kit's default: the six kinds, drawn from the resolved style.
class DSIllustrationPainterDelegate extends DSIllustrationDelegate {
  const DSIllustrationPainterDelegate();

  @override
  Widget build(
    BuildContext context,
    DSIllustrationKind kind,
    double progress,
    DSIllustrationStyle style,
  ) => CustomPaint(
    painter: DSIllustrationPainter(
      kind: kind,
      progress: progress,
      style: style,
    ),
    size: Size.square(style.size!),
  );
}

/// The delegate in force for a subtree.
///
/// A separate [InheritedWidget] rather than a field on [DSScope], which is
/// closed to size, density, tone and enabled, and rather than a field on the
/// style object, which is data and may not carry behaviour. Install one above
/// `MaterialApp` for the whole app; nest another to change one screen.
class DSIllustrationScope extends InheritedWidget {
  const DSIllustrationScope({
    super.key,
    required this.delegate,
    required super.child,
  });

  final DSIllustrationDelegate delegate;

  static DSIllustrationDelegate? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DSIllustrationScope>()
      ?.delegate;

  @override
  bool updateShouldNotify(DSIllustrationScope oldWidget) =>
      delegate != oldWidget.delegate;
}

/// A drawing, for the moments where a picture is the content.
///
/// See `docs/plans/32-ds-illustration.plan.md`. **Use when** the moment
/// happens once or rarely: first run, onboarding, a full-screen failure, a
/// permission ask, a paywall. **Instead:** a glyph in a `DSWell` — which is
/// what `DSEmptyState` draws by default — for an ordinary empty state, and
/// nothing at all for an empty filter result inside a list, where a drawing
/// above every result is noise.
///
/// The drawing plays once per mount and then holds its last frame. There is
/// no `repeat`, no `autoplay` and no way to ask for either: a looping drawing
/// above a button re-attracts attention forever, competes with the action the
/// screen is asking for, and is the WCAG 2.2.2 (Pause, Stop, Hide) failure
/// this component is partly written to avoid.
///
/// Under reduced motion the drawing is painted at the last frame rather than
/// replaced with an empty box, and no controller is created at all: the user
/// asked for less movement, not for less information.
class DSIllustration extends StatefulWidget {
  const DSIllustration({
    super.key,
    required this.kind,
    this.size = DSIllustrationSize.medium,
    this.tone = DSTone.neutral,
    this.semanticLabel,
    this.delegate,
    this.style,
  });

  final DSIllustrationKind kind;
  final DSIllustrationSize size;
  final DSTone tone;

  /// Null means decorative, which is the default and almost always right: the
  /// meaning is in the title beneath the drawing, and that title is already a
  /// header. Passing a label puts exactly one node in the semantics tree and
  /// removes the exclusion — one parameter rather than a label and a boolean
  /// that can disagree.
  final String? semanticLabel;

  /// Overrides whatever [DSIllustrationScope] is in force, for one call site.
  final DSIllustrationDelegate? delegate;

  final DSIllustrationStyle? style;

  @override
  State<DSIllustration> createState() => _DSIllustrationState();
}

class _DSIllustrationState extends State<DSIllustration>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  /// Created once, in the first `didChangeDependencies` — not in `initState`,
  /// which cannot read `MediaQuery`, and not in `build`, which runs again
  /// every time anything above this widget rebuilds. That distinction is the
  /// difference between a drawing that plays once and one that flickers back
  /// to its first frame whenever the list above it updates.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final resolved = DSIllustrationStyle.resolve(
      context,
      tone: widget.tone,
      size: widget.size,
    );
    _controller = AnimationController(vsync: this, duration: resolved.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSIllustrationStyle.resolve(
      context,
      tone: widget.tone,
      size: widget.size,
      own: widget.style,
    );
    final delegate =
        widget.delegate ??
        DSIllustrationScope.maybeOf(context) ??
        const DSIllustrationPainterDelegate();

    final controller = _controller;
    Widget drawing = SizedBox.square(
      dimension: resolved.size!,
      child: controller == null
          ? delegate.build(context, widget.kind, 1, resolved)
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => delegate.build(
                context,
                widget.kind,
                resolved.curve!.transform(controller.value),
                resolved,
              ),
            ),
    );

    // Keyed by kind so a change cross-fades. The progress is not reset: the
    // box is already occupied, and replaying the reveal on a swap draws the
    // eye to the box a second time for a change the user made themselves.
    drawing = AnimatedSwitcher(
      // Zero under reduced motion, so a kind swap replaces rather than fades
      // — and so nothing in this widget schedules a frame when the user has
      // asked for no movement.
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : resolved.crossFadeDuration!,
      child: KeyedSubtree(
        key: ValueKey<DSIllustrationKind>(widget.kind),
        child: drawing,
      ),
    );

    return widget.semanticLabel == null
        ? ExcludeSemantics(child: drawing)
        : Semantics(
            label: widget.semanticLabel,
            image: true,
            container: true,
            child: ExcludeSemantics(child: drawing),
          );
  }
}

/// The kit's six drawings.
///
/// Every value here is a fraction of the box, and every colour comes from the
/// resolved style — so one painter draws all three sizes and both themes, and
/// an identity that moves its brand hue moves the art with it.
class DSIllustrationPainter extends CustomPainter {
  const DSIllustrationPainter({
    required this.kind,
    required this.progress,
    required this.style,
  });

  final DSIllustrationKind kind;

  /// 0 → 1, already eased, and already 1 under reduced motion.
  final double progress;

  final DSIllustrationStyle style;

  /// The four layers, back to front: the plate, the tone, the boundaries, the
  /// one emphatic mark.
  static const int layerCount = 4;

  /// What each layer's opacity is at [progress].
  ///
  /// Public because it is the assertion WCAG 2.3.1 needs: every layer is
  /// non-decreasing across the pass, so the reveal cannot flash. A test walks
  /// it rather than sampling pixels, which is the difference between a check
  /// that names the defect and one that says a golden moved.
  static List<double> layerOpacities(double progress) {
    const overlap = 0.18;
    const span = 1 - overlap * (layerCount - 1);
    return <double>[
      for (var i = 0; i < layerCount; i++)
        ((progress - i * overlap) / span).clamp(0.0, 1.0),
    ];
  }

  Paint _fill(Color color, double opacity) => Paint()
    ..color = color.withValues(alpha: color.a * opacity)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Paint _stroke(Color color, double opacity, double width) => Paint()
    ..color = color.withValues(alpha: color.a * opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final o = layerOpacities(progress);
    final w = style.strokeWidth!;
    final ground = _fill(style.groundColor!, o[0]);
    final body = _fill(style.bodyColor!, o[1]);
    final line = _stroke(style.lineColor!, o[2], w);
    final accentLine = _stroke(style.accentColor!, o[3], w * 1.5);
    final accentFill = _fill(style.accentColor!, o[3]);

    Rect box(double l, double t, double r, double b) =>
        Rect.fromLTRB(l * u, t * u, r * u, b * u);
    RRect round(Rect rect, double radius) =>
        RRect.fromRectAndRadius(rect, Radius.circular(radius * u));
    Offset at(double x, double y) => Offset(x * u, y * u);

    switch (kind) {
      case DSIllustrationKind.empty:
        // An open container: a lid across the top, a body, and nothing in it.
        final container = round(box(0.20, 0.40, 0.80, 0.80), 0.06);
        canvas.drawRRect(container, ground);
        canvas.drawRRect(round(box(0.28, 0.52, 0.72, 0.68), 0.04), body);
        canvas.drawRRect(container, line);
        canvas.drawRRect(round(box(0.16, 0.30, 0.84, 0.40), 0.03), accentFill);

      case DSIllustrationKind.search:
        // A lens over a flat field: three rows, and nothing on them.
        for (final (double y, double right) in <(double, double)>[
          (0.62, 0.82),
          (0.72, 0.74),
          (0.82, 0.62),
        ]) {
          canvas.drawRRect(round(box(0.18, y, right, y + 0.06), 0.03), ground);
        }
        canvas.drawCircle(at(0.44, 0.38), 0.19 * u, body);
        canvas.drawCircle(at(0.44, 0.38), 0.19 * u, line);
        canvas.drawLine(at(0.58, 0.52), at(0.74, 0.68), accentLine);

      case DSIllustrationKind.offline:
        // Two nodes and the link between them, interrupted in the middle.
        for (final Offset centre in <Offset>[at(0.24, 0.32), at(0.76, 0.68)]) {
          canvas.drawCircle(centre, 0.13 * u, ground);
          canvas.drawCircle(centre, 0.07 * u, body);
          canvas.drawCircle(centre, 0.13 * u, line);
        }
        canvas.drawLine(at(0.34, 0.42), at(0.44, 0.52), line);
        canvas.drawLine(at(0.56, 0.58), at(0.66, 0.68), line);
        canvas.drawLine(at(0.46, 0.60), at(0.54, 0.50), accentLine);

      case DSIllustrationKind.done:
        // A stack, and the mark that finished it.
        for (final double y in <double>[0.24, 0.40, 0.56]) {
          canvas.drawRRect(round(box(0.16, y, 0.72, y + 0.10), 0.04), ground);
        }
        canvas.drawRRect(round(box(0.16, 0.24, 0.72, 0.34), 0.04), line);
        canvas.drawCircle(at(0.68, 0.70), 0.20 * u, body);
        canvas.drawCircle(at(0.68, 0.70), 0.20 * u, line);
        canvas.drawPath(
          Path()
            ..moveTo(0.59 * u, 0.70 * u)
            ..lineTo(0.66 * u, 0.77 * u)
            ..lineTo(0.78 * u, 0.63 * u),
          accentLine,
        );

      case DSIllustrationKind.locked:
        // A closed form, and the seam that opens it.
        final shackle = Rect.fromCircle(
          center: at(0.50, 0.44),
          radius: 0.15 * u,
        );
        canvas.drawArc(shackle, math.pi, math.pi, false, line);
        final lock = round(box(0.28, 0.44, 0.72, 0.80), 0.06);
        canvas.drawRRect(lock, ground);
        canvas.drawRRect(round(box(0.28, 0.44, 0.72, 0.56), 0.06), body);
        canvas.drawRRect(lock, line);
        canvas.drawCircle(at(0.50, 0.62), 0.045 * u, accentFill);
        canvas.drawLine(at(0.50, 0.64), at(0.50, 0.72), accentLine);

      case DSIllustrationKind.error:
        // A tilted shape, interrupted: three of its four sides are drawn.
        canvas.save();
        canvas.translate(0.50 * u, 0.52 * u);
        canvas.rotate(-0.18);
        canvas.translate(-0.50 * u, -0.52 * u);
        final shape = round(box(0.26, 0.28, 0.74, 0.76), 0.08);
        canvas.drawRRect(shape, ground);
        canvas.drawRRect(round(box(0.26, 0.28, 0.74, 0.42), 0.08), body);
        canvas.drawPath(
          Path()
            ..moveTo(0.26 * u, 0.62 * u)
            ..lineTo(0.26 * u, 0.36 * u)
            ..arcToPoint(at(0.36, 0.28), radius: Radius.circular(0.08 * u))
            ..lineTo(0.64 * u, 0.28 * u)
            ..arcToPoint(at(0.74, 0.38), radius: Radius.circular(0.08 * u))
            ..lineTo(0.74 * u, 0.62 * u),
          line,
        );
        canvas.drawLine(at(0.50, 0.40), at(0.50, 0.58), accentLine);
        canvas.drawCircle(at(0.50, 0.67), 0.035 * u, accentFill);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DSIllustrationPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.progress != progress ||
      oldDelegate.style != style;
}
