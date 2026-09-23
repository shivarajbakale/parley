// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How pull-to-refresh looks, at every layer of the resolution chain.
@immutable
class DSRefreshStyle extends DSComponentStyle<DSRefreshStyle> {
  const DSRefreshStyle({
    this.color,
    this.background,
    this.displacement,
    this.edgeOffset,
    this.strokeWidth,
    this.triggerDistance,
  });

  /// The arc.
  final Color? color;

  /// The disc the arc turns on. It sits over the content, so it is the raised
  /// surface, not the canvas — on the canvas colour the disc disappears the
  /// moment it is over a card.
  final Color? background;

  /// How far the disc travels from the top of the scrollable before it stops.
  final double? displacement;

  /// How far down the top of the scrollable the gesture starts. A screen whose
  /// first sliver is a pinned app bar wants this set to the bar's height, or
  /// the disc spins underneath it.
  final double? edgeOffset;

  final double? strokeWidth;

  /// How far the finger has to pull before the gesture commits.
  ///
  /// A token because it is the one number in the whole gesture the user can
  /// feel: too short and a scroll that starts at the top refreshes by
  /// accident, too long and the pull feels like it is fighting back. Material
  /// keeps its own answer private and derives it from the viewport, so a
  /// short list and a long one disagreed about what "far enough" meant on the
  /// same screen.
  final double? triggerDistance;

  @override
  DSRefreshStyle merge(DSRefreshStyle? other) {
    if (other == null) return this;
    return DSRefreshStyle(
      color: other.color ?? color,
      background: other.background ?? background,
      displacement: other.displacement ?? displacement,
      edgeOffset: other.edgeOffset ?? edgeOffset,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      triggerDistance: other.triggerDistance ?? triggerDistance,
    );
  }

  @override
  DSRefreshStyle copyWith({
    Color? color,
    Color? background,
    double? displacement,
    double? edgeOffset,
    double? strokeWidth,
    double? triggerDistance,
  }) => DSRefreshStyle(
    color: color ?? this.color,
    background: background ?? this.background,
    displacement: displacement ?? this.displacement,
    edgeOffset: edgeOffset ?? this.edgeOffset,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    triggerDistance: triggerDistance ?? this.triggerDistance,
  );

  @override
  DSRefreshStyle lerp(DSRefreshStyle? other, double t) {
    if (other == null) return this;
    return DSRefreshStyle(
      color: Color.lerp(color, other.color, t),
      background: Color.lerp(background, other.background, t),
      displacement: lerpDouble(displacement, other.displacement, t),
      edgeOffset: lerpDouble(edgeOffset, other.edgeOffset, t),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      triggerDistance: lerpDouble(triggerDistance, other.triggerDistance, t),
    );
  }

  static DSRefreshStyle resolve(BuildContext context, [DSRefreshStyle? own]) {
    final design = context.design;
    final palette = context.palette;

    return resolveStyle(
      context: context,
      specDefaults: DSRefreshStyle(
        color: palette.primary,
        background: palette.card,
        displacement: design.space.xxl,
        edgeOffset: 0,
        strokeWidth: 2.5,
        triggerDistance: design.space.xxxl * 2,
      ),
      own: own,
    );
  }
}

/// Pull-to-refresh, with the three things every hand-written one forgets.
///
/// **Use when** a screen shows data the server can change and the user has no
/// other way to ask for it again. **Instead:** a `DSButton` labelled Retry
/// inside `DSStatusState` when the *last* load failed — a pull is the gesture
/// for "this is stale", not for "this is broken", and a screen showing an
/// error has nothing to pull.
///
/// The three forgotten things:
///
/// 1. **The gesture is dead on a short list.** A `ListView` whose content fits
///    does not scroll, so it never reports the overscroll that starts a
///    refresh. Every call site that got this right wrote
///    `physics: const AlwaysScrollableScrollPhysics()` by hand and every one
///    that did not shipped a screen where the pull does nothing until enough
///    rows arrive — which is exactly the screen a user pulls on. This sets the
///    physics through `ScrollConfiguration` for the whole subtree, so the
///    child does not have to know.
/// 2. **The pull is silent.** The disc appearing is the only confirmation the
///    gesture was taken, and it is under the thumb. One light tick at the
///    moment the refresh commits is what makes the gesture feel caught.
/// 3. **The release throws away the gesture.** Material's `RefreshIndicator`
///    settles the disc on a fixed private timer, so a slow pull and a hard
///    flick end identically and the hand-off — the one thing that makes a
///    surface feel attached to the finger — is not merely unavailable, it is
///    unreachable: every duration in that widget is a private constant. This
///    component reads the pull off the scroll notifications itself and settles
///    it on a spring seeded with the velocity the drag ended at, so a flick
///    overshoots and a crawl glides in. The disc, its arc and its screen
///    reader announcement are still Material's — the physics are what changed
///    hands, not the pixels.
///
/// A child that sets its own `physics` still wins — an explicit argument beats
/// an inherited behaviour — so a scrollable that genuinely must not overscroll
/// keeps its say.
class DSRefresh extends StatefulWidget {
  const DSRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
    this.enabled = true,
    this.semanticsLabel,
    this.style,
  });

  /// Runs when the pull commits. The disc spins until the future completes, so
  /// return the work itself — a future that resolves before the data arrives
  /// tells the user the refresh finished when it has not.
  final Future<void> Function() onRefresh;

  /// The scrollable. Not a slot: a refresh with nothing under it is a spinner
  /// with no content, so this is the component's subject.
  final Widget child;

  /// Whether the gesture is live.
  ///
  /// `false` returns [child] untouched — no indicator, no physics override.
  /// Use it for a screen whose data is local and cannot go stale, rather than
  /// leaving a pull that resolves instantly and teaches the user the gesture
  /// does nothing here.
  final bool enabled;

  /// What a screen reader announces for the gesture. Defaults to Flutter's
  /// "Refresh".
  final String? semanticsLabel;

  final DSRefreshStyle? style;

  /// How far above the top of the scrollable the disc waits.
  ///
  /// Public because the resting position is what makes the disc invisible at
  /// rest, and a golden that starts showing an arc on an untouched screen is
  /// asserting against this number.
  static const double parkedAbove = 48;

  /// The disc's own box, so a test can read where the pull put it without
  /// measuring through the scale transform that grows it on the way in.
  static const Key discKey = Key('ds-refresh-disc');

  /// How much of a pull past the commit point still moves the disc. The rest
  /// of the travel is absorbed, which is what a rubber band is.
  static const double overpullFactor = 0.35;

  /// How far past its target a settle is allowed to carry, in units of the
  /// reveal, before the hand-off velocity is capped.
  ///
  /// A spring seeded with a real flick's velocity overshoots by roughly
  /// `velocity / (ω·e)`, and a hard flick is fast enough to throw the disc
  /// most of the way down the screen. Capping the velocity rather than the
  /// position is what keeps the overshoot a spring rather than a wall: a
  /// clamped position stops dead at the limit and then waits there, which is
  /// the freeze this number exists to prevent.
  static const double settleOvershoot = 0.35;

  @override
  State<DSRefresh> createState() => _DSRefreshState();
}

class _DSRefreshState extends State<DSRefresh>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 at the commit point. Unbounded because a pull past the
  /// commit point and a spring that overshoots on the way back both leave the
  /// range, and clamping them is the flatness this component is removing.
  late final AnimationController _reveal = AnimationController.unbounded(
    vsync: this,
  );

  /// Raw pull in pixels, before the rubber band. Kept separately from
  /// [_reveal] because the band is not invertible past the commit point.
  double _drag = 0;
  bool _dragging = false;
  bool _refreshing = false;

  /// The pull's own speed, in pixels per second, measured from the pointer
  /// timestamps the drag carries.
  ///
  /// Measured here rather than read off [ScrollEndNotification] because that
  /// notification is not the end of the gesture. A drag that ends with the
  /// position out of range — which on iOS is every pull, since bouncing
  /// physics lets `pixels` go negative — hands straight over to a ballistic
  /// activity, and the end notification is not dispatched until that ballistic
  /// settle finishes several hundred milliseconds later, with no drag details
  /// left on it. Waiting for it froze the disc for the whole bounce and then
  /// settled it from a standstill.
  double _pullVelocity = 0;
  Duration? _pullAt;

  /// Weight of the newest sample in the running average. One frame where the
  /// finger paused would otherwise report a dead stop and swallow the flick.
  static const double _velocityWeight = 0.6;

  /// Last resolved commit distance. Read on every drag frame, so it is cached
  /// in [build] rather than resolved through the theme sixty times a second.
  double _trigger = 1;

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_refreshing) return false;

    if (notification is ScrollStartNotification) {
      // Only a drag, and only one that starts already at the top. A fling
      // that coasts into the top edge is the scroll finishing, not a pull.
      if (notification.dragDetails != null &&
          notification.metrics.extentBefore == 0) {
        _dragging = true;
        _drag = 0;
        _pullVelocity = 0;
        _pullAt = null;
      }
      return false;
    }

    if (!_dragging) return false;

    if (notification is ScrollEndNotification) {
      _release();
    } else if (notification is OverscrollNotification) {
      // Clamping physics, which is Android: the position refuses to move and
      // reports the whole delta as overscroll instead.
      final drag = notification.dragDetails;
      if (drag == null) {
        _release();
      } else {
        _pullTo(_drag - notification.overscroll, drag.sourceTimeStamp);
      }
    } else if (notification is ScrollUpdateNotification) {
      // Bouncing physics, which is iOS: there is no overscroll to report
      // because the position itself goes negative.
      final drag = notification.dragDetails;
      if (drag == null) {
        // The finger is off. On bouncing physics this is the first frame of
        // the list's own bounce back, and it arrives long before the scroll
        // activity ends — so this, not the end notification, is where the
        // component takes the pull over.
        _release();
      } else {
        final delta = notification.scrollDelta;
        if (delta != null) _pullTo(_drag - delta, drag.sourceTimeStamp);
      }
    }
    return false;
  }

  void _pullTo(double raw, Duration? at) {
    final next = math.max(0.0, raw);
    final last = _pullAt;
    if (at != null) {
      if (last != null) {
        final dt = (at - last).inMicroseconds / Duration.microsecondsPerSecond;
        if (dt > 0) {
          final sample = (next - _drag) / dt;
          _pullVelocity =
              _pullVelocity * (1 - _velocityWeight) + sample * _velocityWeight;
        }
      }
      _pullAt = at;
    }
    _drag = next;
    final t = _drag / _trigger;
    _reveal
      ..stop()
      // Past the commit point the pull gets heavy. Without this the disc runs
      // off down the screen and the gesture stops telling the user anything,
      // because every further millimetre looks the same as the last.
      ..value = math.min(
        t <= 1 ? t : 1 + (t - 1) * DSRefresh.overpullFactor,
        1.6,
      );
  }

  void _release() {
    _dragging = false;
    _drag = 0;
    final velocity = _pullVelocity;
    _pullVelocity = 0;
    _pullAt = null;
    if (_reveal.value >= 1) {
      _refresh(velocity);
    } else {
      _settleTo(0, velocity);
    }
  }

  /// [velocity] arrives in pixels per second, which is what the drag reports,
  /// and leaves in units of [_reveal] per second, which is what the spring
  /// wants. A downward drag is positive in both, so no sign flips here.
  void _settleTo(double target, double velocity) {
    _reveal.stop();
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = target;
      return;
    }
    final motion = context.design.motion;
    // The cap, not a clamp on the drawn position: for a spring released at its
    // target with speed v the peak carry is v / (ω·e), so bounding v bounds
    // the overshoot while leaving the motion continuous. A start already past
    // the target adds to that peak, which is why this is a bound on the
    // hand-off rather than a promise about the pixels.
    final spring = motion.tuned(motion.gentle);
    final omega = math.sqrt(spring.stiffness / spring.mass);
    final cap = DSRefresh.settleOvershoot * omega * math.e;
    _reveal.animateWith(
      motion.simulation(
        spring: motion.gentle,
        from: _reveal.value,
        to: target,
        velocity: (velocity / _trigger).clamp(-cap, cap),
      ),
    );
  }

  Future<void> _refresh(double velocity) async {
    setState(() => _refreshing = true);
    // Before the await, not after: the tick confirms the gesture was taken,
    // and a tick that lands when the data does is a tick about something else.
    AppHaptics.light();
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.semanticsLabel ??
          MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      Directionality.of(context),
    );
    // Settling *to* the commit point rather than jumping there: a hard flick
    // arrives with speed left over, and swallowing it is the flatness the
    // whole feature is about.
    _settleTo(1, velocity);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        _settleTo(0, 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final resolved = DSRefreshStyle.resolve(context, widget.style);
    final behavior = ScrollConfiguration.of(context);
    _trigger = math.max(1, resolved.triggerDistance ?? 96);
    final travel = resolved.displacement ?? 40;
    final edge = resolved.edgeOffset ?? 0;

    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      // Clips, which is what parks the disc: at rest it sits a disc's height
      // above the top edge and is simply not drawn.
      child: Stack(
        children: [
          ScrollConfiguration(
            // `parent:`, not a bare `AlwaysScrollableScrollPhysics()`. Physics
            // are a chain, and the bare one has nothing under it:
            // `ScrollPhysics` itself clamps nothing and simulates nothing, so
            // a list under it can be dragged past its own end and stays there
            // — no spring back, no fling deceleration, no boundary at all. The
            // screen looks stuck because it is. Wrapping the behaviour's own
            // physics keeps the platform's edge — bouncing on iOS, clamping on
            // Android — and adds only the one thing this component is for: the
            // drag is accepted even when the content fits.
            behavior: behavior.copyWith(
              physics: AlwaysScrollableScrollPhysics(
                parent: behavior.getScrollPhysics(context),
              ),
            ),
            child: widget.child,
          ),
          AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) {
              // Drawn as the spring leaves it. The ceiling in [_pullTo] is
              // the rubber band's, and it belongs to the finger; clamping the
              // settle too parked the disc at the limit for as long as the
              // overshoot lasted, which read as the disc having jammed.
              final t = _reveal.value;
              final seen = t.clamp(0.0, 1.0);
              return PositionedDirectional(
                start: 0,
                end: 0,
                top:
                    edge -
                    DSRefresh.parkedAbove +
                    t * (travel + DSRefresh.parkedAbove),
                child: Opacity(
                  key: DSRefresh.discKey,
                  opacity: seen,
                  child: Transform.scale(
                    scale: lerpDouble(0.6, 1, seen)!,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RefreshProgressIndicator(
                          // Determinate while the finger decides, so the arc
                          // is a readout of how far is left; indeterminate
                          // once the work starts, because nothing knows.
                          value: _refreshing ? null : seen,
                          color: resolved.color,
                          backgroundColor: resolved.background,
                          strokeWidth: resolved.strokeWidth ?? 2.5,
                          semanticsLabel: widget.semanticsLabel,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
