// ds-tier: 0 — foundation

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:parley_android/theme/spec/design_spec.dart';

/// Drives a 0..1 ratio toward its target and rebuilds on every frame of it.
///
/// Private to the design system — the leading underscore is the kit's marker
/// for a file that is machinery rather than a component, so it is not
/// exported, not in the reference and not in the catalog.
///
/// It exists because every determinate meter in the kit — the ring, the bar,
/// the segmented bar — has to answer the same three questions the same way,
/// and three copies of the answer is how a kit ends up with one meter that
/// springs, one that eases and one that snaps:
///
///  * **first paint** animates 0 → value once, on enter, and a rebuild with an
///    unchanged value does not re-animate;
///  * **an interruption** continues from where the meter actually is rather
///    than restarting from zero, which is the whole reason for a spring;
///  * **reduced motion** creates no controller at all and paints the final
///    value — the value is information and the sweep is decoration.
///
/// The spec's `gentle` spring rather than `snappy`: gentle is critically damped, and
/// an overshooting meter shows a value the user does not have. On a quota bar
/// or a countdown that is a lie the widget tells on its own.
class DSRatioTransition extends StatefulWidget {
  const DSRatioTransition({
    super.key,
    required this.value,
    required this.builder,
  });

  /// The target, in the 0..1 the meter paints. Callers clamp before passing.
  final double value;

  final Widget Function(BuildContext context, double ratio) builder;

  @override
  State<DSRatioTransition> createState() => _DSRatioTransitionState();
}

class _DSRatioTransitionState extends State<DSRatioTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  double _from = 0;
  double _to = 0;
  bool _entered = false;

  double get _ratio {
    final controller = _controller;
    if (controller == null) return _to;
    return lerpDouble(_from, _to, controller.value) ?? _to;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    _drive(from: 0, to: widget.value);
  }

  @override
  void didUpdateWidget(DSRatioTransition old) {
    super.didUpdateWidget(old);
    if (widget.value == _to) return;
    _drive(from: _ratio, to: widget.value);
  }

  void _drive({required double from, required double to}) {
    _from = from;
    _to = to;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    final motion = context.design.motion;
    // No listener and no setState here: this runs from
    // didChangeDependencies, and a setState there lands inside a build. The
    // AnimatedBuilder in build() is what rebuilds per frame.
    final controller = _controller ??= AnimationController(vsync: this);
    controller.value = 0;
    if (context.springsAvailable) {
      controller.animateWith(
        SpringSimulation(motion.tuned(motion.gentle), 0, 1, 0),
      );
      return;
    }
    controller.animateTo(
      1,
      duration: motion.scaled(motion.normal),
      curve: motion.enter,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.builder(context, _ratio);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => widget.builder(context, _ratio),
    );
  }
}
