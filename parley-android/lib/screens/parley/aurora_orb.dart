import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:parley_android/theme/parley_modes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The Aurora orb, drawn in Flutter — the same figure the Kotlin overlay
/// draws over other apps, used inside the app for the Overview hero and the
/// Setup steps so the app and the overlay read as one object.
///
/// It breathes while [animate] is on and the platform has not asked for
/// reduced motion; with motion off it keeps its colour and stops moving.
/// Decorative: it carries no semantics, and every screen that shows it states
/// the same thing in words beside it.
class AuroraOrb extends StatefulWidget {
  const AuroraOrb({
    super.key,
    required this.diameter,
    this.mode = OrbMode.dictation,
    this.animate = true,
    this.halo = true,
  });

  final double diameter;
  final OrbMode mode;
  final bool animate;

  /// The soft glow around it. Off where the orb sits inside something small.
  final bool halo;

  @override
  State<AuroraOrb> createState() => _AuroraOrbState();
}

class _AuroraOrbState extends State<AuroraOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: OrbMotion.breathe,
  );

  bool _reduceMotion = false;

  /// A breathing orb never settles, and every widget test, golden and probe
  /// frame in this repo waits for the tree to settle. Under `flutter test`
  /// the orb holds still at the bottom of its breath, which is also what
  /// makes its golden deterministic.
  static final bool _underTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(AuroraOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun = widget.animate && !_reduceMotion && !_underTest;
    if (shouldRun && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!shouldRun && _breath.isAnimating) {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrbPalette.of(widget.mode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final curve = context.design.motion.standard;
    final haloExtent = widget.halo ? widget.diameter * 0.5 : 0.0;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.diameter + haloExtent,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, _) {
            final t = curve.transform(_breath.value);
            return CustomPaint(
              painter: _OrbPainter(
                palette: palette,
                diameter: widget.diameter * (1 + OrbMotion.breatheScale * t),
                haloStrength: widget.halo
                    ? (isDark ? 0.42 : 0.24) * (0.7 + 0.3 * t)
                    : 0,
                dim: widget.mode == OrbMode.idle,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.palette,
    required this.diameter,
    required this.haloStrength,
    required this.dim,
  });

  final OrbPalette palette;
  final double diameter;
  final double haloStrength;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = diameter / 2;

    if (haloStrength > 0) {
      final haloRadius = size.shortestSide / 2;
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              palette.glow.withValues(alpha: haloStrength),
              palette.glow.withValues(alpha: haloStrength * 0.28),
              palette.glow.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
      );
    }

    paintAuroraSphere(
      canvas,
      center,
      radius,
      palette,
      opacity: dim ? 0.7 : 1.0,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.diameter != diameter ||
      old.haloStrength != haloStrength ||
      old.palette != palette ||
      old.dim != dim;
}

/// The orb's sphere without its halo: four radial stops from the highlight
/// out, then a white rim light that makes it read as a sphere rather than a
/// gradient disc. Shared with the empty-state scenes so every orb in the app
/// is the same object.
void paintAuroraSphere(
  Canvas canvas,
  Offset center,
  double radius,
  OrbPalette palette, {
  double opacity = 1,
}) {
  final orbRect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: OrbMotion.highlight,
        radius: 0.95,
        colors: [for (final c in palette.stops) c.withValues(alpha: opacity)],
        stops: const [0, 0.24, 0.6, 1],
      ).createShader(orbRect),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          OrbPalette.sheen.withValues(alpha: 0),
          OrbPalette.sheen.withValues(alpha: 0),
          OrbPalette.sheen.withValues(alpha: 0.22 * opacity),
        ],
        stops: const [0, 0.78, 1],
      ).createShader(orbRect),
  );
}

/// A small dot in a mode's colour — the status chips, the history rows.
class ModeDot extends StatelessWidget {
  const ModeDot({super.key, required this.mode});

  final OrbMode mode;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final size = context.design.space.xs;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OrbPalette.of(mode).dotFor(brightness),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}
