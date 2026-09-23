import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Timing, easing and physics, as data.
///
/// [speed] multiplies every duration at once. It is the knob that decides
/// whether an app feels brisk or considered, and it is the one people reach
/// for after using the build rather than while designing it.
@immutable
class MotionSpec {
  final Duration instant;
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Duration press;
  final Duration pressRelease;
  final Duration routeEnter;
  final Duration routeExit;
  final Duration shimmer;
  final Duration revealStep;

  /// How long a press is held before a control starts repeating, and how fast
  /// it repeats once it does. On the spec because a build for a slow-motor
  /// audience has to slow both, and the alternative to a knob is a fork.
  final Duration repeatDelay;
  final Duration repeatInterval;

  final Curve enter;
  final Curve exit;
  final Curve emphasize;
  final Curve standard;

  final SpringDescription snappy;
  final SpringDescription gentle;
  final SpringDescription bouncy;

  /// The spring a paged sequence settles on.
  ///
  /// [gentle] is critically damped and is the right character — it glides in
  /// and stops — but it is tuned for a control coming to rest. Four slides
  /// being read is the opposite case: heavier and softer reads as a considered
  /// object settling rather than a card snapping into a slot. It reads heavier
  /// although mass is lower (0.7 vs 1.0) because stiffness falls further
  /// (90 vs 200). The ratio stays at 1, because an overshoot here wobbles the
  /// illustration the slide just carried.
  final SpringDescription pageSettle;

  /// Multiplies every duration. 0.8 is brisk; 1.3 is languid.
  final double speed;

  /// Scales spring stiffness. Above 1 the app gets tighter and faster to
  /// settle; below 1 it gets looser and more playful. Damping moves with it so
  /// the damping ratio — which is what decides whether a spring overshoots —
  /// is preserved.
  final double springiness;

  const MotionSpec({
    this.instant = const Duration(milliseconds: 100),
    this.fast = const Duration(milliseconds: 200),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.press = const Duration(milliseconds: 120),
    this.pressRelease = const Duration(milliseconds: 180),
    this.routeEnter = const Duration(milliseconds: 280),
    this.routeExit = const Duration(milliseconds: 220),
    this.shimmer = const Duration(milliseconds: 1200),
    this.revealStep = const Duration(milliseconds: 45),
    this.repeatDelay = const Duration(milliseconds: 400),
    this.repeatInterval = const Duration(milliseconds: 80),
    this.enter = Curves.easeOutCubic,
    this.exit = Curves.easeInCubic,
    this.emphasize = Curves.easeInOutCubicEmphasized,
    this.standard = Curves.easeInOut,
    this.snappy = const SpringDescription(
      mass: 1,
      stiffness: 500,
      damping: 40.25,
    ),
    this.gentle = const SpringDescription(
      mass: 1,
      stiffness: 200,
      damping: 28.28,
    ),
    this.bouncy = const SpringDescription(
      mass: 1,
      stiffness: 380,
      damping: 23.39,
    ),
    this.pageSettle = const SpringDescription(
      mass: 0.7,
      stiffness: 90,
      // 2 * sqrt(0.7 * 90) — critically damped.
      damping: 15.8745,
    ),
    this.speed = 1,
    this.springiness = 1,
  });

  Duration scaled(Duration d) =>
      Duration(microseconds: (d.inMicroseconds * speed).round());

  /// A spring with [springiness] applied, damping ratio held.
  ///
  /// Stiffness scales linearly and damping by its square root, because the
  /// damping ratio is `damping / 2√(mass · stiffness)`. Scaling both linearly
  /// would over-damp a stiffened spring into something that no longer springs.
  SpringDescription tuned(SpringDescription spring) {
    if (springiness == 1) return spring;
    return SpringDescription(
      mass: spring.mass,
      stiffness: spring.stiffness * springiness,
      damping: spring.damping * math.sqrt(springiness),
    );
  }

  /// The damping ratio a description works out to: 1.0 is critically damped,
  /// below 1.0 overshoots, above 1.0 crawls in.
  ///
  /// Exposed because a hand-typed damping coefficient is otherwise unreadable
  /// — one typo turns a settle into a wobble that only shows up on a device —
  /// and a test asserts each of the three against the ratio it claims.
  static double dampingRatio(SpringDescription spring) =>
      spring.damping / (2.0 * math.sqrt(spring.mass * spring.stiffness));

  /// A simulation an [AnimationController.animateWith] can drive.
  ///
  /// [velocity] is in units of the animation's value per second, so a drag
  /// hand-off passes the gesture's velocity straight through and the surface
  /// keeps moving at the speed the finger left it at. That hand-off is most
  /// of the reason to use a spring at all.
  ///
  /// The spring is [tuned] on the way through, which is what makes
  /// [springiness] reach the springs a widget actually runs. The constants
  /// this replaces were read straight off a namespace, so the knob moved
  /// nothing.
  SpringSimulation simulation({
    SpringDescription? spring,
    double from = 0,
    double to = 1,
    double velocity = 0,
  }) => SpringSimulation(tuned(spring ?? snappy), from, to, velocity);

  MotionSpec copyWith({
    double? speed,
    double? springiness,
    Curve? enter,
    Curve? emphasize,
  }) => MotionSpec(
    instant: instant,
    fast: fast,
    normal: normal,
    slow: slow,
    press: press,
    pressRelease: pressRelease,
    routeEnter: routeEnter,
    routeExit: routeExit,
    shimmer: shimmer,
    revealStep: revealStep,
    repeatDelay: repeatDelay,
    repeatInterval: repeatInterval,
    enter: enter ?? this.enter,
    exit: exit,
    emphasize: emphasize ?? this.emphasize,
    standard: standard,
    snappy: snappy,
    gentle: gentle,
    bouncy: bouncy,
    pageSettle: pageSettle,
    speed: speed ?? this.speed,
    springiness: springiness ?? this.springiness,
  );
}
