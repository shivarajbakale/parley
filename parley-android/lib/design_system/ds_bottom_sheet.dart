// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How tall a sheet opens.
///
/// [DSSheetFit.content] is the default because a caller who names a fraction
/// is guessing at text scale, locale length and device height at the same
/// time. Snap points are orthogonal and opt-in: passing them *is* the opt-in,
/// which is what the `useSnapPoints` boolean this replaces got wrong — one
/// flag should never change a surface's physics.
enum DSSheetFit {
  /// What the content needs, capped at [DSBottomSheetStyle.maxHeightFraction].
  content,

  /// Half the screen: a companion panel over a map or a canvas.
  half,

  /// The cap, corners kept: a long list.
  full,

  /// The whole screen, corners animating to zero. Plan 17's `fullScreen`.
  expanded,
}

/// [DSBottomSheet]'s appearance, as data.
@immutable
class DSBottomSheetStyle extends DSComponentStyle<DSBottomSheetStyle> {
  const DSBottomSheetStyle({
    this.headerPadding,
    this.bodyPadding,
    this.footerPadding,
    this.handleBlockHeight,
    this.showHeaderDivider,
    this.showFooterDivider,
    this.maxHeightFraction,
    this.minHeight,
  });

  final EdgeInsetsGeometry? headerPadding;
  final EdgeInsetsGeometry? bodyPadding;
  final EdgeInsetsGeometry? footerPadding;

  /// The height the grabber's block takes. Zero removes the handle app-wide,
  /// which is a real house style and was previously unreachable.
  final double? handleBlockHeight;

  final bool? showHeaderDivider;
  final bool? showFooterDivider;

  /// The tallest a sheet gets before it is [DSSheetFit.expanded].
  final double? maxHeightFraction;

  final double? minHeight;

  @override
  DSBottomSheetStyle merge(DSBottomSheetStyle? other) {
    if (other == null) return this;
    return DSBottomSheetStyle(
      headerPadding: other.headerPadding ?? headerPadding,
      bodyPadding: other.bodyPadding ?? bodyPadding,
      footerPadding: other.footerPadding ?? footerPadding,
      handleBlockHeight: other.handleBlockHeight ?? handleBlockHeight,
      showHeaderDivider: other.showHeaderDivider ?? showHeaderDivider,
      showFooterDivider: other.showFooterDivider ?? showFooterDivider,
      maxHeightFraction: other.maxHeightFraction ?? maxHeightFraction,
      minHeight: other.minHeight ?? minHeight,
    );
  }

  @override
  DSBottomSheetStyle copyWith({
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? bodyPadding,
    EdgeInsetsGeometry? footerPadding,
    double? handleBlockHeight,
    bool? showHeaderDivider,
    bool? showFooterDivider,
    double? maxHeightFraction,
    double? minHeight,
  }) => DSBottomSheetStyle(
    headerPadding: headerPadding ?? this.headerPadding,
    bodyPadding: bodyPadding ?? this.bodyPadding,
    footerPadding: footerPadding ?? this.footerPadding,
    handleBlockHeight: handleBlockHeight ?? this.handleBlockHeight,
    showHeaderDivider: showHeaderDivider ?? this.showHeaderDivider,
    showFooterDivider: showFooterDivider ?? this.showFooterDivider,
    maxHeightFraction: maxHeightFraction ?? this.maxHeightFraction,
    minHeight: minHeight ?? this.minHeight,
  );

  @override
  DSBottomSheetStyle lerp(DSBottomSheetStyle? other, double t) {
    if (other == null) return this;
    return DSBottomSheetStyle(
      headerPadding: EdgeInsetsGeometry.lerp(
        headerPadding,
        other.headerPadding,
        t,
      ),
      bodyPadding: EdgeInsetsGeometry.lerp(bodyPadding, other.bodyPadding, t),
      footerPadding: EdgeInsetsGeometry.lerp(
        footerPadding,
        other.footerPadding,
        t,
      ),
      handleBlockHeight: lerpDouble(
        handleBlockHeight,
        other.handleBlockHeight,
        t,
      ),
      showHeaderDivider: t < 0.5 ? showHeaderDivider : other.showHeaderDivider,
      showFooterDivider: t < 0.5 ? showFooterDivider : other.showFooterDivider,
      maxHeightFraction: lerpDouble(
        maxHeightFraction,
        other.maxHeightFraction,
        t,
      ),
      minHeight: lerpDouble(minHeight, other.minHeight, t),
    );
  }

  static DSBottomSheetStyle resolve(
    BuildContext context, [
    DSBottomSheetStyle? own,
  ]) {
    final design = context.design;
    final specDefaults = DSBottomSheetStyle(
      headerPadding: EdgeInsets.symmetric(
        horizontal: design.space.lg,
        vertical: design.space.md,
      ),
      bodyPadding: EdgeInsets.zero,
      footerPadding: EdgeInsets.symmetric(
        horizontal: design.space.lg,
        vertical: design.space.md,
      ),
      handleBlockHeight: design.space.lg,
      showHeaderDivider: true,
      showFooterDivider: true,
      maxHeightFraction: 0.9,
      minHeight: design.component.sheetMinHeight,
    );

    return resolveStyle<DSBottomSheetStyle>(
      context: context,
      specDefaults: specDefaults,
      own: own,
    );
  }
}

/// A surface that rises from the bottom edge carrying content secondary to
/// the screen behind it, which stays visible and in place.
///
/// One sheet. Before this the kit had three — a `modal_bottom_sheet` wrapper,
/// a hand-written snapping sheet and a centred "animated modal" — 1012 lines
/// presenting the same idea three ways, one of which changed physics when a
/// caller added a snap point.
///
/// The snapping path is [DraggableScrollableSheet]. The scroll-aware drag —
/// "does this finger scroll the list or move the sheet?" — is the hardest
/// part of a sheet to get right, and the hand-written answer here was wrong
/// in a way no test caught: it read the body's scroll position with
/// `Scrollable.maybeOf`, which walks *ancestors*, so it never once saw the
/// body it was asking about. The framework's sheet owns the scroll position
/// and hands it down, which makes the question unaskable in the wrong
/// direction. See [DSBottomSheet.child] for what that asks of a body.
///
/// The surface is `DSOverlaySurface`, which resolves a sheet's tint and
/// shadow from `AppMaterials.sheet` — the chrome layer's own material, since
/// a sheet covers content that stays visible behind it. It is opaque on both
/// platforms rather than glass, because a sheet arrives over a scrim and
/// glass composited against a dimmed page lands a different grey per page.
class DSBottomSheet extends StatefulWidget {
  const DSBottomSheet({
    super.key,
    required this.child,
    this.fit = DSSheetFit.content,
    this.header,
    this.footer,
    this.emptySlot,
    this.empty = false,
    this.handleSlot,
    this.showDragHandle = true,
    this.loading = false,
    this.enableDrag = true,
    this.snapPoints,
    this.snapLabels,
    this.initialSnap,
    this.onSnap,
    this.scrollable = true,
    this.style,
  });

  /// The sheet's body.
  ///
  /// When [snapPoints] are given, the sheet drives a
  /// [DraggableScrollableSheet] and publishes its [ScrollController] through
  /// a [PrimaryScrollController]. A vertical scroll view with no controller
  /// of its own is `primary` and attaches to it without being told — which is
  /// every list a caller writes here. A body that passes its own
  /// [ScrollController] opts out of the sheet's drag, deliberately: two
  /// controllers over one list is the defect this replaced.
  final Widget child;

  final DSSheetFit fit;

  /// Pinned above the scroll. Ships [DSSheetHeader].
  final Widget? header;

  /// Pinned below the scroll, above the safe area. Ships [DSSheetFooter].
  final Widget? footer;

  /// Whether the body has anything in it.
  ///
  /// The sheet cannot work this out from a `Widget` — only the caller knows
  /// whether their list came back empty — and a sheet is not permitted to
  /// render as a bare header over blank surface.
  final bool empty;

  /// What an empty body draws instead. [DSEmptyState] stands in when the
  /// caller names nothing.
  final Widget? emptySlot;

  final Widget? handleSlot;
  final bool showDragHandle;
  final bool loading;
  final bool enableDrag;

  /// The fractions of the screen this sheet settles at. Presence is the
  /// opt-in; absence is a single-height sheet that drags only to dismiss.
  final List<double>? snapPoints;

  /// What each snap point is called. Announced on settle, which is the use
  /// the old `SnapPoint.label` field was written for and never wired to.
  final List<String>? snapLabels;

  final double? initialSnap;
  final ValueChanged<double>? onSnap;

  /// Whether the sheet scrolls a body that is taller than the room it has.
  ///
  /// On by default, because a body is written at one device height and one
  /// text scale and read at all of them: a `Column` of radio tiles that fits
  /// a 6.7-inch phone overflows a 4-inch one at 1.3x text, and without this
  /// the rows past the cap were painted off the sheet with nothing to reach
  /// them by. Pass `false` only when the body is its own scroll view (a
  /// `ListView`, a `CustomScrollView`) — a scroll view inside a scroll view
  /// has no height to lay out at. Applies to [DSSheetFit.content] only: a
  /// fixed fit gives its body a fixed region to fill, and a snapping sheet's
  /// body must already be a list attached to the sheet's controller.
  final bool scrollable;

  final DSBottomSheetStyle? style;

  @override
  State<DSBottomSheet> createState() => _DSBottomSheetState();
}

class _DSBottomSheetState extends State<DSBottomSheet>
    with SingleTickerProviderStateMixin {
  /// Owned by the sheet, handed to [DraggableScrollableSheet], and published
  /// to the body through [PrimaryScrollController] so that the list the caller
  /// wrote scrolls *the sheet's* position rather than one of its own.
  ///
  /// This is the whole fix. The `Listener` this replaces asked
  /// `Scrollable.maybeOf(context)` for the body's scroll offset from a context
  /// *above* the body — `maybeOf` walks ancestors and the body is a
  /// descendant — so it always got null, always concluded "the list is at the
  /// top", and moved the sheet one-for-one with the finger from any offset.
  /// Two drags dismissed a sheet the user was reading. The comment above it
  /// described behaviour the code could not have.
  ///
  /// Handing the controller *down* removes the question. There is one scroll
  /// position; the list and the sheet both read it, and the handoff between
  /// "scroll the list" and "move the sheet" is the framework's to make.
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Drives the sheet's extent when a drag ends, so that the settle continues
  /// at the speed the finger left at.
  ///
  /// The `animateTo` this replaces took a duration and a curve, which means a
  /// flick and a nudge arriving at the same detent took the same 200ms and
  /// started from rest. The velocity the gesture reported was read once, to
  /// choose *which* detent, and then thrown away — so the fastest possible
  /// fling and the slowest possible drag looked identical after the finger
  /// lifted, which is the single clearest way a sheet reads as software
  /// rather than as an object.
  ///
  /// A spring takes that velocity as its initial condition. It is also
  /// interruptible: a second drag mid-settle continues from where the sheet
  /// is, because [_chromeDragBy] stops this controller rather than racing it.
  ///
  /// Unbounded, because the simulation's value is an extent fraction that the
  /// tick clamps to the sheet's own range — a bounded controller would clamp
  /// it to 0..1 first and quietly change what the spring is solving.
  ///
  /// **This is not gated on `context.springsAvailable`,** which every other
  /// spring in the kit is. That gate exists because Apple's own state changes
  /// are curve-based and a bouncing tab bar reads as a bug — but a sheet
  /// detent is the one place where the platform itself is spring-driven, and
  /// the fallback for a hand-off is not "a curve" but "the velocity is
  /// discarded". [MotionSpec.gentle] is critically damped, so nothing here
  /// overshoots on any platform; reduced motion still skips the movement
  /// entirely. See DECISIONS.md.
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onSettleTick);

  /// Where the sheet is, as a fraction of the screen. Mirrors the controller
  /// so that `build` has a value before the first extent notification lands.
  late double _fraction = widget.initialSnap ?? _sorted.first;

  /// The detent the user was last told about. A sheet passes through a snap
  /// point on the way to another one, and announcing every frame that happens
  /// to land on one talks over the screen reader. Seeded with the opening
  /// position so that merely opening the sheet is not an announcement.
  late double? _announced = widget.initialSnap ?? _sorted.first;

  /// Whether the body has been scrolled away from its top. The header's
  /// divider is drawn from this, never from the scroll offset itself — a
  /// divider animated with the offset flickers on every small movement.
  bool _scrolled = false;

  List<double> get _sorted =>
      widget.snapPoints == null || widget.snapPoints!.isEmpty
      ? const <double>[0.5]
      : (List<double>.of(widget.snapPoints!)..sort());

  bool get _snaps => widget.snapPoints != null;

  double get _screenHeight => MediaQuery.sizeOf(context).height;

  @override
  void dispose() {
    _settle.dispose();
    _sheet.dispose();
    super.dispose();
  }

  /// A drag that did not land on a [Scrollable].
  ///
  /// The header, the grab handle, the footer and the space between rows have
  /// no scroll view under them, so [DraggableScrollableSheet] — which moves
  /// only through its scroll position — never sees those gestures. A
  /// [GestureDetector] at the default `HitTestBehavior.deferToChild` picks up
  /// exactly those pointers and no others: where the body's list is under the
  /// finger, the list's recognizer wins the arena and this never fires.
  ///
  /// That arena fight is the one the old `Listener` was written to sidestep,
  /// and sidestepping it was the defect — a widget that does not compete in
  /// the arena also cannot be told it lost.
  void _chromeDragBy(double delta) {
    if (!_sheet.isAttached) return;
    // A finger back on the sheet owns it. Without this the spring keeps
    // driving `jumpTo` under the drag and the two fight for the extent.
    _settle.stop();
    _sheet.jumpTo(
      (_sheet.size - delta / _screenHeight).clamp(0.0, _sorted.last),
    );
  }

  void _chromeDragEnd(double velocity) {
    if (!_sheet.isAttached) return;
    final at = _sheet.size;
    // Below 15% of the screen, or flung down hard: the sheet is leaving. The
    // fling wins regardless of position because the speed already said so.
    if (at < 0.15 || velocity > 800) {
      Navigator.of(context).maybePop();
      return;
    }
    final target = velocity < -500 ? _nextAbove(at) : _nearest(at);
    _settleTo(target, velocity: velocity);
  }

  /// Ticks the spring into the sheet.
  ///
  /// Clamped to the sheet's own range rather than to 0..1: the largest detent
  /// is the top of travel, and a spring allowed past it would drive `jumpTo`
  /// into a value [DraggableScrollableController] rejects.
  void _onSettleTick() {
    if (!_sheet.isAttached) return;
    _sheet.jumpTo(_settle.value.clamp(0.0, _sorted.last));
  }

  /// Moves the sheet to [target], carrying [velocity] — the gesture's, in
  /// logical pixels per second, downward positive — into the settle.
  ///
  /// The sign flips on the way in because the two axes disagree: a finger
  /// moving *down* the screen is a *falling* extent fraction. Dividing by the
  /// screen height converts pixels per second into fraction per second, which
  /// is the unit the simulation's value is in.
  void _settleTo(double target, {double velocity = 0}) {
    if (!_sheet.isAttached) return;
    _settle.stop();
    final at = _sheet.size;
    if (MediaQuery.disableAnimationsOf(context)) {
      // The user asked for less movement, not for a slower spring.
      _sheet.jumpTo(target.clamp(0.0, _sorted.last));
      return;
    }
    final motion = context.design.motion;
    _settle.value = at;
    _settle.animateWith(
      motion.simulation(
        spring: motion.gentle,
        from: at,
        to: target,
        velocity: -velocity / _screenHeight,
      ),
    );
  }

  /// The next detent above the one the sheet is at, wrapping to the smallest
  /// after the largest.
  ///
  /// This is what the handle does when the sheet has detents. The Canvas
  /// archetype's rule — "the handle is the affordance, and it is also the tap
  /// target that cycles the detents" — has nowhere else to live: the default
  /// handle dismisses the route, which over a ground the reader is still
  /// using takes the ground away with the sheet.
  double get _nextDetent {
    final at = _sheet.isAttached ? _sheet.size : _fraction;
    const tolerance = 0.005;
    for (final double point in _sorted) {
      if (point > at + tolerance) return point;
    }
    return _sorted.first;
  }

  void _cycleDetent() {
    if (!_sheet.isAttached) return;
    AppHaptics.selection();
    _settleTo(_nextDetent);
  }

  /// What the handle says it will do, for a screen reader. Falls back to the
  /// fraction when the caller named no detents.
  String get _handleLabel {
    final next = _nextDetent;
    final index = _sorted.indexOf(next);
    final labels = widget.snapLabels;
    final name = labels != null && index >= 0 && index < labels.length
        ? labels[index]
        : '${(next * 100).round()}%';
    return next > (_sheet.isAttached ? _sheet.size : _fraction)
        ? 'Expand the sheet to $name'
        : 'Collapse the sheet to $name';
  }

  /// The sheet's height changed — by a body scroll, a chrome drag or the
  /// controller's own settle. One place reads it, so `onSnap`, the haptic and
  /// the announcement cannot disagree about where the sheet came to rest.
  bool _onExtent(DraggableScrollableNotification notification) {
    final extent = notification.extent;
    if (extent != _fraction) setState(() => _fraction = extent);

    const tolerance = 0.005;
    final settled = _sorted
        .where((p) => (p - extent).abs() < tolerance)
        .firstOrNull;
    if (settled == null) {
      // Away from every detent: the next arrival is news again.
      _announced = null;
      return false;
    }
    if (_announced == settled) return false;
    _announced = settled;
    widget.onSnap?.call(settled);
    AppHaptics.medium();
    _announce(settled);
    return false;
  }

  /// Says where the sheet came to rest, in the words the caller chose.
  void _announce(double fraction) {
    final labels = widget.snapLabels;
    final points = _sorted;
    if (labels == null || labels.isEmpty) return;
    final index = points.indexWhere((p) => (p - fraction).abs() < 0.01);
    if (index < 0 || index >= labels.length) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      labels[index],
      Directionality.of(context),
    );
  }

  double _nextAbove(double current) {
    for (final point in _sorted) {
      if (point > current + 0.05) return point;
    }
    return _sorted.last;
  }

  double _nearest(double current) {
    // The dismiss point is skipped: a sheet that settles at zero has been
    // dismissed, and a nearest-point search that can return it snaps the
    // sheet shut on a small drag.
    final valid = _sorted.where((p) => p > 0.05).toList();
    if (valid.isEmpty) return 0.5;
    var nearest = valid.first;
    var best = (current - nearest).abs();
    for (final point in valid) {
      final distance = (current - point).abs();
      if (distance < best) {
        best = distance;
        nearest = point;
      }
    }
    return nearest;
  }

  /// Tracks whether the body has left its top, which is the only thing the
  /// header's divider is drawn from.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth > 0) return false;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final atTop = notification.metrics.extentBefore <= 0;
      if (atTop == _scrolled) setState(() => _scrolled = !atTop);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final style = DSBottomSheetStyle.resolve(context, widget.style);
    final screen = MediaQuery.sizeOf(context).height;
    final cap = style.maxHeightFraction!;

    final double? height = switch (widget.fit) {
      // A snapping sheet's height is the controller's business.
      _ when _snaps => null,
      DSSheetFit.content => null,
      DSSheetFit.half => (0.5 * screen).clamp(style.minHeight!, screen),
      DSSheetFit.full => cap * screen,
      DSSheetFit.expanded => screen,
    };

    // At `expanded` the corners are square; between 90% and 100% they
    // interpolate with the sheet's own height rather than on a curve of their
    // own, so the radius and the movement are one gesture.
    final expandedProgress = switch (widget.fit) {
      DSSheetFit.expanded => 1.0,
      _ when _snaps => ((_fraction - cap) / (1 - cap)).clamp(0.0, 1.0),
      _ => 0.0,
    };

    // The skeleton and the empty state draw themselves at a size the sheet
    // did not choose, so the parent column is the one that handles overflow.
    // Wrapping them in a `SingleChildScrollView` made the placeholder fill
    // the body region and left a half-screen of empty scrollable space below
    // three short rows — exactly the gap the caller was looking at. The
    // placeholders are short by design; if a future slot grows past the
    // cap, that is the placeholder's own problem to solve (the skeleton
    // already sizes itself to the rows it draws).
    final Widget body = switch ((widget.loading, widget.empty)) {
      (true, _) => DSSheetSkeleton(
        showHeader: widget.header != null,
        showFooter: widget.footer != null,
      ),
      (_, true) =>
        widget.emptySlot ?? const DSEmptyState(title: 'Nothing here yet.'),
      // The body scrolls, not the sheet: the header and footer stay pinned
      // while whatever sits between them is reachable at any height.
      // Only a `content` sheet: a fixed fit hands its body a fixed region to
      // fill (a `SizedBox.expand`, a list), which a scroll view would unbound.
      _ when widget.scrollable && !_snaps && widget.fit == DSSheetFit.content =>
        SingleChildScrollView(primary: true, child: widget.child),
      _ => widget.child,
    };

    Widget surface = DSOverlaySurface(
      presentation: widget.fit == DSSheetFit.expanded
          ? DSOverlayPresentation.fullScreen
          : DSOverlayPresentation.sheet,
      showDragHandle: widget.showDragHandle && style.handleBlockHeight! > 0,
      // A sheet with detents hands its handle a job. Without one the default
      // handle pops the route, which is right for a modal and wrong for a
      // sheet the reader cycles over a map.
      handleSlot:
          widget.handleSlot ??
          (_snaps
              ? DSDragHandle(semanticLabel: _handleLabel, onTap: _cycleDetent)
              : null),
      expandedProgress: expandedProgress,
      header: widget.header == null
          ? null
          : _SheetDividerScope(scrolled: _scrolled, child: widget.header!),
      footer: widget.footer,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Padding(padding: style.bodyPadding!, child: body),
      ),
    );

    if (_snaps) {
      if (widget.enableDrag) {
        // ui-lint: allow pressable-floor — a sheet's chrome drag is direct
        // manipulation rather than a press; the dip and the haptic belong to
        // the controls inside it, and the drag affordance is DSDragHandle.
        surface = GestureDetector(
          onVerticalDragUpdate: (details) => _chromeDragBy(details.delta.dy),
          onVerticalDragEnd: (details) =>
              _chromeDragEnd(details.primaryVelocity ?? 0),
          child: surface,
        );
      }
      return NotificationListener<DraggableScrollableNotification>(
        onNotification: _onExtent,
        child: DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: widget.initialSnap ?? _sorted.first,
          // Zero rather than the smallest detent: dragging a sheet off the
          // bottom edge is how a sheet is dismissed, and `minChildSize: 0`
          // with the default `shouldCloseOnMinExtent` makes that one
          // mechanism instead of two that can disagree.
          minChildSize: 0,
          maxChildSize: _sorted.last,
          snap: true,
          snapSizes: _sorted,
          // The body's list finds this without being handed it: a vertical
          // `ListView` with no controller of its own is `primary`, so it
          // attaches here. A body that insists on its own controller opts out
          // of the sheet's drag — which is the honest outcome, because two
          // controllers over one list is the bug this replaces.
          builder: (context, scrollController) => PrimaryScrollController(
            controller: scrollController,
            child: surface,
          ),
        ),
      );
    }

    // The cap is a fraction of the screen, but the room is what the route
    // has left after the keyboard and the status bar. Capping at 90% of the
    // screen with the keyboard up asked for more height than existed, and the
    // footer is what got pushed past the bottom edge.
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screen;
        if (height != null) {
          return SizedBox(height: height.clamp(0.0, room), child: surface);
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (cap * screen).clamp(0.0, room),
          ),
          child: surface,
        );
      },
    );
  }
}

/// Carries "the body has scrolled" down to the header, which is the only
/// thing that draws a divider from it.
class _SheetDividerScope extends InheritedWidget {
  const _SheetDividerScope({required this.scrolled, required super.child});

  final bool scrolled;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SheetDividerScope>()
          ?.scrolled ??
      false;

  @override
  bool updateShouldNotify(_SheetDividerScope old) => old.scrolled != scrolled;
}

/// The sheet's pinned title block.
class DSSheetHeader extends StatelessWidget {
  const DSSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleSlot,
    this.subtitleSlot,
    this.showClose = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleSlot;
  final Widget? subtitleSlot;
  final bool showClose;

  @override
  Widget build(BuildContext context) => DSOverlayHeader(
    title: title,
    subtitle: subtitle,
    leading: leading,
    trailing: trailing,
    titleSlot: titleSlot,
    subtitleSlot: subtitleSlot,
    showClose: showClose,
    showDivider: _SheetDividerScope.of(context),
  );
}

/// The sheet's pinned action block.
class DSSheetFooter extends StatelessWidget {
  const DSSheetFooter({
    super.key,
    this.actions,
    this.helper,
    this.align = DSOverlayFooterAlign.end,
  });

  final Widget? actions;
  final Widget? helper;
  final DSOverlayFooterAlign align;

  @override
  Widget build(BuildContext context) =>
      DSOverlayFooter(actions: actions, helper: helper, align: align);
}

/// The sheet while its content is in flight, shaped by the slots present.
///
/// A skeleton built separately from the thing it stands in for stops matching
/// it on the first edit, so this is shaped by the same three questions the
/// sheet asks: is there a header, is there a footer, how many rows.
class DSSheetSkeleton extends StatelessWidget {
  const DSSheetSkeleton({
    super.key,
    this.showHeader = false,
    this.showFooter = false,
    this.contentLines = 3,
  });

  final bool showHeader;
  final bool showFooter;
  final int contentLines;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return DSSkeleton(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: design.space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) ...[
              const Text('Loading'),
              SizedBox(height: design.space.md),
            ],
            for (var i = 0; i < contentLines; i++) ...[
              SizedBox(
                height: design.component.listRowMinHeight,
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('A row of content'),
                ),
              ),
            ],
            if (showFooter) ...[
              SizedBox(height: design.space.md),
              SizedBox(
                height: design.component.buttonHeight,
                child: const Center(child: Text('Action')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Presents a bottom sheet and returns what it pops.
///
/// The `expand` and `bounce` parameters this replaces were `modal_bottom_sheet`
/// parameters passed through by name — they documented a dependency rather
/// than a design decision, and the dependency is gone.
Future<T?> showDSBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  DSSheetFit fit = DSSheetFit.content,
  Widget? header,
  Widget? footer,
  Widget? emptySlot,
  bool empty = false,
  List<double>? snapPoints,
  List<String>? snapLabels,
  double? initialSnap,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool barrierDismissible = true,
  bool loading = false,
  ValueChanged<double>? onSnap,
  bool scrollable = true,
  DSBottomSheetStyle? style,
}) {
  // Both asserts live here rather than on the widget: a `List<double>?`
  // cannot be narrowed inside a `const` constructor's assert, and a sheet
  // that cannot be built as a const is a sheet every story pays for.
  assert(
    snapPoints == null || snapPoints.isNotEmpty,
    'An empty snapPoints list is a sheet with no heights to settle at. Omit '
    'it instead — the absence is the single-height sheet.',
  );
  assert(
    initialSnap == null ||
        snapPoints == null ||
        snapPoints.contains(initialSnap),
    'initialSnap must be one of the snapPoints — a sheet that opens between '
    'two detents settles the first time it is touched, which reads as the '
    'sheet correcting the developer in front of the user.',
  );

  return showDSOverlay<T>(
    context: context,
    presentation: fit == DSSheetFit.expanded
        ? DSOverlayPresentation.fullScreen
        : DSOverlayPresentation.sheet,
    barrierDismissible: barrierDismissible,
    // A sheet with detents owns its own vertical gesture: the route's
    // drag-to-dismiss and the sheet's drag-to-snap cannot both read the same
    // finger.
    enableDrag: enableDrag && snapPoints == null,
    builder: (context) => DSBottomSheet(
      fit: fit,
      header: header,
      footer: footer,
      empty: empty,
      emptySlot: emptySlot,
      snapPoints: snapPoints,
      snapLabels: snapLabels,
      initialSnap: initialSnap,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      loading: loading,
      onSnap: onSnap,
      scrollable: scrollable,
      style: style,
      child: Builder(builder: builder),
    ),
  );
}
