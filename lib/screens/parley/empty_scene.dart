import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:parley_android/screens/parley/aurora_orb.dart';
import 'package:parley_android/theme/parley_modes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

enum _Kind { dictate, asleep, noMatch, progress }

/// The drawn, looping art that stands in for words on Parley's empty states.
///
/// Each scene shows what the screen is waiting for rather than describing it:
/// the orb talking a line into a field, the orb dozing because it cannot run,
/// a magnifier finding nothing, a ring filling as setup completes. The empty
/// state around it keeps to one line and one action.
///
/// One loop per [OrbMotion.breathe], so the scenes and the orb keep the same
/// clock. With reduced motion — and under `flutter test`, for the same
/// reason [AuroraOrb] gives — each holds a single frame chosen to tell the
/// whole story at once. Decorative: it carries no semantics.
class EmptyScene extends StatefulWidget {
  /// History before the first dictation.
  const EmptyScene.dictate({super.key})
    : _kind = _Kind.dictate,
      done = 0,
      total = 0;

  /// Parley cannot run yet — the service is off, a grant or the key missing.
  const EmptyScene.asleep({super.key})
    : _kind = _Kind.asleep,
      done = 0,
      total = 0;

  /// A search or filter that matched nothing.
  const EmptyScene.noMatch({super.key})
    : _kind = _Kind.noMatch,
      done = 0,
      total = 0;

  /// Setup progress: one lit segment per step [done] out of [total].
  const EmptyScene.progress({
    super.key,
    required this.done,
    required this.total,
  }) : _kind = _Kind.progress,
       assert(total > 0 && done >= 0 && done <= total);

  final _Kind _kind;
  final int done;
  final int total;

  @override
  State<EmptyScene> createState() => _EmptySceneState();
}

class _EmptySceneState extends State<EmptyScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: OrbMotion.breathe,
  );

  bool _reduceMotion = false;

  static final bool _underTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// The frame each scene holds when it cannot move.
  double get _still => switch (widget._kind) {
    _Kind.dictate => 0.85,
    _Kind.asleep => 0.3,
    _Kind.noMatch => 0.25,
    _Kind.progress => 0.5,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  void _sync() {
    final run = !_reduceMotion && !_underTest;
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run) {
      _loop
        ..stop()
        ..value = _still;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final colors = _SceneColors(
      ink: context.palette.foreground,
      brightness: Theme.of(context).brightness,
      pop: context.design.motion.emphasize,
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: space.xxxl * 3.5,
        height: space.xxxl * 2.5,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) => CustomPaint(
            painter: switch (widget._kind) {
              _Kind.dictate => _DictatePainter(_loop.value, colors),
              _Kind.asleep => _AsleepPainter(_loop.value, colors),
              _Kind.noMatch => _NoMatchPainter(_loop.value, colors),
              _Kind.progress => _ProgressPainter(
                _loop.value,
                colors,
                widget.done,
                widget.total,
              ),
            },
          ),
        ),
      ),
    );
  }
}

@immutable
class _SceneColors {
  const _SceneColors({
    required this.ink,
    required this.brightness,
    required this.pop,
  });

  final Color ink;
  final Brightness brightness;

  /// The curve a mark pops in on — the identity's emphasis curve.
  final Curve pop;

  Color ghost([double alpha = 0.12]) => ink.withValues(alpha: alpha);
  Color dot(OrbMode mode) => OrbPalette.of(mode).dotFor(brightness);
  bool get dark => brightness == Brightness.dark;

  @override
  bool operator ==(Object other) =>
      other is _SceneColors &&
      other.ink == ink &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(ink, brightness, pop);
}

/// Where [t] is between [a] and [b], clamped to 0..1.
double _span(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

abstract class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t, this.colors);

  final double t;
  final _SceneColors colors;

  void halo(Canvas canvas, Offset c, double r, OrbPalette palette, double k) {
    final strength = (colors.dark ? 0.38 : 0.2) * k;
    canvas.drawCircle(
      c,
      r * 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.glow.withValues(alpha: strength),
            palette.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2)),
    );
  }

  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t || old.colors != colors;
}

/// The orb listens, a line of text lands in a field, and a tick confirms it.
class _DictatePainter extends _ScenePainter {
  _DictatePainter(super.t, super.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.3);
    final listening = _span(t, 0.05, 0.45);
    final live = listening > 0 && listening < 1;
    final envelope = math.sin(math.pi * listening);
    final r =
        h * 0.14 * (1 + 0.06 * envelope * math.sin(listening * 8 * math.pi));

    halo(canvas, c, r, OrbPalette.dictation, 0.6 + 0.4 * envelope);

    // The listening ring, expanding off the orb while it hears.
    if (live) {
      final frac = (listening * 2.5) % 1;
      canvas.drawCircle(
        c,
        r * (1 + 0.9 * frac),
        stroke(
          colors.dot(OrbMode.dictation).withValues(alpha: 0.5 * (1 - frac)),
          h * 0.015,
        ),
      );
    }
    paintAuroraSphere(canvas, c, r, OrbPalette.dictation);

    // Sound bars either side, loud only while listening.
    final barPaint = stroke(colors.dot(OrbMode.dictation), h * 0.035);
    for (var i = 0; i < 3; i++) {
      final level =
          0.15 + 0.85 * envelope * math.sin(t * 6 * math.pi + i * 1.3).abs();
      final bh = h * (0.04 + 0.12 * level);
      barPaint.color = colors
          .dot(OrbMode.dictation)
          .withValues(alpha: 0.25 + 0.6 * level);
      for (final side in [-1.0, 1.0]) {
        final x = c.dx + side * (h * 0.26 + i * h * 0.085);
        canvas.drawLine(
          Offset(x, c.dy - bh / 2),
          Offset(x, c.dy + bh / 2),
          barPaint,
        );
      }
    }

    // The field the words land in.
    final field = RRect.fromLTRBR(
      w * 0.08,
      h * 0.64,
      w * 0.92,
      h * 0.9,
      Radius.circular(h * 0.13),
    );
    canvas.drawRRect(field, Paint()..color = colors.ghost(0.06));
    canvas.drawRRect(field, stroke(colors.ghost(0.16), h * 0.012));

    final fade = 1 - _span(t, 0.9, 1);
    final typing = _span(t, 0.45, 0.72);
    final lineY = field.center.dy;
    final barH = field.height * 0.24;
    var x = field.left + field.height * 0.5;
    for (final (i, share) in const [0.3, 0.2, 0.16].indexed) {
      final full = field.width * share;
      final grown = full * _span(typing, i / 3, (i + 1) / 3);
      if (grown > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            x,
            lineY - barH / 2,
            x + grown,
            lineY + barH / 2,
            Radius.circular(barH / 2),
          ),
          Paint()..color = colors.ghost(0.55 * fade),
        );
      }
      x += full + field.height * 0.18;
    }

    // The tick pops in once the line has landed.
    final pop = _span(t, 0.72, 0.8);
    if (pop > 0 && fade > 0) {
      final scale = colors.pop.transform(pop);
      final tc = Offset(field.right - field.height * 0.5, lineY);
      final tr = field.height * 0.28 * scale;
      canvas.drawCircle(
        tc,
        tr,
        Paint()..color = colors.dot(OrbMode.done).withValues(alpha: fade),
      );
      final check = Path()
        ..moveTo(tc.dx - tr * 0.45, tc.dy + tr * 0.02)
        ..lineTo(tc.dx - tr * 0.1, tc.dy + tr * 0.35)
        ..lineTo(tc.dx + tr * 0.48, tc.dy - tr * 0.32);
      canvas.drawPath(
        check,
        stroke(OrbPalette.sheen.withValues(alpha: fade), tr * 0.24)
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }
}

/// The orb, grey and dozing inside a slow dashed ring, stirring once a loop.
class _AsleepPainter extends _ScenePainter {
  _AsleepPainter(super.t, super.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.54);
    final r = h * 0.2;
    final stir = math.exp(-math.pow((t - 0.55) / 0.05, 2).toDouble());

    halo(canvas, c, r, OrbPalette.idle, 0.25 + 0.5 * stir);

    // A dashed ring, turning a quarter each loop.
    final ring = r * 1.5;
    const dashes = 16;
    final dashPaint = stroke(colors.ghost(0.22), h * 0.018);
    final turn = t * math.pi / 2;
    for (var i = 0; i < dashes; i++) {
      final a = turn + i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ring),
        a,
        math.pi / dashes * 0.9,
        false,
        dashPaint,
      );
    }

    paintAuroraSphere(canvas, c, r, OrbPalette.idle, opacity: 0.5 + 0.4 * stir);

    // Two small bubbles drifting up and away, the way a sleeper breathes.
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1;
      final alpha = math.sin(math.pi * phase) * 0.45;
      canvas.drawCircle(
        Offset(c.dx + r * (0.9 + 0.5 * phase), c.dy - r * (1.1 + 1.2 * phase)),
        h * (0.018 + 0.022 * phase),
        Paint()..color = colors.ghost(alpha),
      );
    }
  }
}

/// A magnifier sweeps over three ghost rows and finds nothing in them.
class _NoMatchPainter extends _ScenePainter {
  _NoMatchPainter(super.t, super.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final u = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final lens = Offset(
      w * (0.28 + 0.44 * u),
      h * 0.5 + math.sin(u * 2 * math.pi) * h * 0.14,
    );
    final lr = h * 0.17;

    for (var i = 0; i < 3; i++) {
      final y = h * (0.2 + i * 0.27);
      final near = (1 - ((lens.dy - y).abs() / (h * 0.3))).clamp(0.0, 1.0);
      final alpha = 0.12 - 0.05 * near;
      canvas.drawCircle(
        Offset(w * 0.14, y),
        h * 0.045,
        Paint()..color = colors.ghost(alpha),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(
          w * 0.22,
          y - h * 0.035,
          w * (0.86 - i * 0.12),
          y + h * 0.035,
          Radius.circular(h * 0.035),
        ),
        Paint()..color = colors.ghost(alpha),
      );
    }

    canvas.drawCircle(
      lens,
      lr,
      Paint()..color = OrbPalette.dictation.glow.withValues(alpha: 0.1),
    );
    final rim = colors.dot(OrbMode.dictation);
    canvas.drawCircle(lens, lr, stroke(rim, h * 0.035));
    final handle = Offset(math.cos(math.pi / 4), math.sin(math.pi / 4));
    canvas.drawLine(
      lens + handle * lr,
      lens + handle * lr * 1.9,
      stroke(rim, h * 0.05),
    );
  }
}

/// A segmented ring around a soft glow: one lit segment per setup step done,
/// and the next one breathing to say where to go.
class _ProgressPainter extends _ScenePainter {
  _ProgressPainter(super.t, super.colors, this.done, this.total);

  final int done;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final h = size.height;
    final r = h * 0.2;
    final complete = done == total;
    final palette = complete ? OrbPalette.dictation : OrbPalette.idle;
    final breath = 0.5 - 0.5 * math.cos(2 * math.pi * t);

    // Inside the ring, only a soft glow: the hero above already shows the
    // orb, and a second sphere on one screen reads as two objects.
    halo(canvas, c, r * 0.8, palette, complete ? 0.6 + 0.4 * breath : 0.3);

    final ring = Rect.fromCircle(center: c, radius: r * 1.75);
    const gap = 0.22;
    final sweep = 2 * math.pi / total;
    for (var i = 0; i < total; i++) {
      final color = i < done
          ? colors.dot(OrbMode.done)
          : i == done
          ? colors.dot(OrbMode.dictation).withValues(alpha: 0.25 + 0.6 * breath)
          : colors.ghost(0.14);
      canvas.drawArc(
        ring,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        stroke(color, h * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      super.shouldRepaint(old) || old.done != done || old.total != total;
}
