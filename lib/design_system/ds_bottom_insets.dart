// ds-tier: 0 — foundation

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// What currently occupies the bottom of the screen.
///
/// See `docs/plans/30-ds-snackbar-fab-action-bar.plan.md`. The kit has three
/// layers that float over a screen's content — a snack bar, a floating action
/// button and a pinned action bar — and until this existed none of them knew
/// the others were there. A snack bar covered the action bar; the button sat
/// on the action bar's primary control. That cannot be fixed inside any one of
/// them, because each is placed by a different part of the tree.
///
/// This is the same mechanism as `DSScope` — a parent stating a fact its
/// descendants need — applied to layout rather than to style. Install it with
/// [DSBottomInsetsHost] above the screen's scaffold; the three components then
/// report their own heights into it and read the sum back out.
///
/// ```dart
/// DSBottomInsetsHost(
///   child: Scaffold(
///     bottomNavigationBar: DSPinnedActionBar(children: [...]),
///     floatingActionButton: DSFab(icon: Icons.add, semanticLabel: 'New'),
///     body: ListView(padding: DSBottomInsets.of(context).scrollPadding),
///   ),
/// )
/// ```
class DSBottomInsets extends InheritedWidget {
  const DSBottomInsets({
    super.key,
    this.actionBarHeight = 0,
    this.fabHeight = 0,
    this.navBarHeight = 0,
    this.safeArea = 0,
    required super.child,
  });

  /// The pinned action bar's height, 0 when there is none.
  final double actionBarHeight;

  /// The floating action button's height plus the margin it keeps from the
  /// edge, 0 when there is none.
  final double fabHeight;

  /// The bottom navigation bar's height, 0 when there is none.
  final double navBarHeight;

  /// `MediaQuery.viewPadding.bottom` — the home indicator.
  final double safeArea;

  /// Everything a widget pinned to the bottom edge has to clear, measured
  /// from the screen's edge.
  ///
  /// The home indicator is a *floor*, not another storey. A bar draws its own
  /// safe area — `DSPinnedActionBar` wraps its content in one, `DSBottomNavBar`
  /// reads `viewPadding` itself — so a reported height already contains the
  /// indicator, and adding [safeArea] on top of it counted the same 34 points
  /// twice, then a third time when both bars were on screen. That is what
  /// parked the snack bar a finger's width up the screen.
  ///
  /// The floating action button is not in the sum: it is *placed* at this
  /// height rather than stacked above it, and content is allowed to pass under
  /// it, which is what makes it a floating button rather than a fourth bar.
  double get total => math.max(actionBarHeight + navBarHeight, safeArea);

  /// Where the snack bar's bottom edge goes — above the button as well, since
  /// a message the button covers is a message nobody reads. Already clear of
  /// the home indicator, so whoever places the bar must not add a second
  /// `SafeArea` under it.
  double get snackOffset => total + fabHeight;

  /// Bottom padding for the screen's scroll view, so its last row is reachable
  /// above everything pinned under it.
  EdgeInsets get scrollPadding => EdgeInsets.only(bottom: total);

  /// How far a *scrolling* page has to end above the bottom edge.
  ///
  /// [total] plus the button, for the same reason [snackOffset] adds it: a row
  /// the button covers is a row nobody can tap, and unlike a snack bar the
  /// last row of a list has nowhere else to go. Content is still allowed to
  /// pass *under* the button while it scrolls — that is what makes it a
  /// floating button rather than a fourth bar — and this only decides where
  /// the content runs out.
  ///
  /// [scrollPadding] is the other answer to a different question: what a
  /// widget pinned inside the viewport has to clear, which the button is not.
  double get scrollClearance => total + fabHeight;

  /// The insets in scope, or zero-with-a-safe-area when no host is installed.
  ///
  /// Never null: a component that has to ask "is there a host?" at every read
  /// is a component whose call sites each answer it differently.
  static DSBottomInsets of(BuildContext context) {
    final found = context.dependOnInheritedWidgetOfExactType<DSBottomInsets>();
    if (found != null) return found;
    return DSBottomInsets(
      safeArea: MediaQuery.maybeViewPaddingOf(context)?.bottom ?? 0,
      child: const SizedBox.shrink(),
    );
  }

  @override
  bool updateShouldNotify(DSBottomInsets old) =>
      old.actionBarHeight != actionBarHeight ||
      old.fabHeight != fabHeight ||
      old.navBarHeight != navBarHeight ||
      old.safeArea != safeArea;
}

/// Which way the screen's content is currently moving.
///
/// Published beside [DSBottomInsets] and by the same host, because the one
/// widget that needs it is the floating action button, which is a sibling of
/// the scroll view and therefore never sees its notifications. A separate
/// class rather than two more fields on [DSBottomInsets]: that one answers
/// "what is at the bottom of the screen", and a scroll direction is not an
/// answer to it.
class DSScrollRetreat extends InheritedWidget {
  const DSScrollRetreat({
    super.key,
    required this.retreating,
    required super.child,
  });

  /// True while the user is scrolling forward through the content, which is
  /// when a floating control is most in the way and least likely to be wanted.
  final bool retreating;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DSScrollRetreat>()
          ?.retreating ??
      false;

  @override
  bool updateShouldNotify(DSScrollRetreat old) => old.retreating != retreating;
}

/// The slot a widget occupies at the bottom of the screen.
enum DSBottomSlot { actionBar, fab, navBar }

/// Installs [DSBottomInsets] and [DSScrollRetreat] over a screen.
///
/// Wraps the scaffold rather than sitting inside it, because a pinned action
/// bar and a bottom navigation bar are the scaffold's siblings, not its body's
/// children: an inherited widget installed in the body could never be read by
/// them, and one installed by them could never be read by the body.
///
/// Heights are measured rather than declared. A bar's height depends on its
/// text scale, its helper line and the device's home indicator, so a caller
/// asked to state it would state it wrongly on the first phone that disagreed.
class DSBottomInsetsHost extends StatefulWidget {
  const DSBottomInsetsHost({super.key, required this.child});

  final Widget child;

  @override
  State<DSBottomInsetsHost> createState() => DSBottomInsetsHostState();

  /// The nearest host, for a component reporting its own height. Null when
  /// there is none, which is the case the kit's components treat as "nobody is
  /// arranging this screen" and quietly accept.
  static DSBottomInsetsHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<DSBottomInsetsHostState>();
}

class DSBottomInsetsHostState extends State<DSBottomInsetsHost> {
  final Map<DSBottomSlot, double> _heights = <DSBottomSlot, double>{};
  bool _retreating = false;

  void report(DSBottomSlot slot, double height) {
    if (_heights[slot] == height) return;
    // Measurement happens during layout, and a rebuild cannot be requested
    // from inside one. The frame that measures is therefore one frame behind
    // the frame that places, which nobody can see and every alternative pays
    // for with a second layout pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _heights[slot] = height);
    });
  }

  void retract(DSBottomSlot slot) {
    if (!_heights.containsKey(slot)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _heights.remove(slot));
    });
  }

  bool _onScroll(UserScrollNotification notification) {
    final retreating = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _retreating,
    };
    if (retreating != _retreating) setState(() => _retreating = retreating);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // A host inside a host is the ordinary shape of a tabbed app, not a
    // mistake: the shell installs one for its navigation bar, and each tab's
    // screen installs its own because `floating-chrome-host` asks every screen
    // that floats something to own a host — a screen has to work when it is
    // mounted alone, in a gate or on a route of its own.
    //
    // Starting the inner one at zero is what put the vault's floating action
    // button *underneath* the shell's navigation bar. The button reported its
    // height into the inner host, the inner host had never heard of the bar,
    // and the first thing that noticed was a tap on the device landing on the
    // Settings tab. So a slot this host carries no reporter for falls through
    // to the host above it.
    //
    // A slot it *does* carry wins outright rather than adding: a screen that
    // pins its own action bar has replaced the shell's, not stacked a second
    // one on top of it.
    final outer = DSBottomInsets.of(context);
    final actionBarHeight =
        _heights[DSBottomSlot.actionBar] ?? outer.actionBarHeight;
    final navBarHeight = _heights[DSBottomSlot.navBar] ?? outer.navBarHeight;

    // Chrome that belongs to an ancestor, which is the part the screen's own
    // `Scaffold` cannot see.
    //
    // Reading it back out of the insets is only half the job. `Scaffold`
    // places a floating action button above its *own* bottom widgets, using
    // `viewPadding.bottom` as the floor to keep it clear of the home
    // indicator, and a screen inside a tabbed shell has no bottom widgets of
    // its own — so it placed the vault's button exactly where the shell's
    // navigation bar is drawn, and the "New login" tap opened Settings.
    //
    // Raising that floor is the fix, rather than moving the button after the
    // fact. Two earlier attempts moved it from inside `DSFab` — a `Padding`
    // grew the button's box downward, and a `Transform` moved its paint and
    // its hit test while leaving the box where it was. Both left the box
    // wrong, and the box is what a test taps, what the probe measures and what
    // a tooltip anchors to. This way the scaffold does the placing, which is
    // the one thing that gets the button, its box and its hit test to agree.
    final inherited =
        (_heights.containsKey(DSBottomSlot.navBar) ? 0.0 : outer.navBarHeight) +
        (_heights.containsKey(DSBottomSlot.actionBar)
            ? 0.0
            : outer.actionBarHeight);

    final media = MediaQuery.of(context);
    final floor = math.max(media.viewPadding.bottom, inherited);

    Widget child = DSScrollRetreat(
      retreating: _retreating,
      child: widget.child,
    );
    if (floor > media.viewPadding.bottom) {
      child = MediaQuery(
        data: media.copyWith(
          viewPadding: media.viewPadding.copyWith(bottom: floor),
        ),
        child: child,
      );
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: _onScroll,
      child: DSBottomInsets(
        actionBarHeight: actionBarHeight,
        fabHeight: _heights[DSBottomSlot.fab] ?? outer.fabHeight,
        navBarHeight: navBarHeight,
        safeArea: media.viewPadding.bottom,
        child: child,
      ),
    );
  }
}

/// Reports [child]'s laid-out height to the nearest [DSBottomInsetsHost].
///
/// Private to the kit's three floating components — a screen never writes one,
/// because a screen never knows a height either.
class DSBottomSlotReporter extends StatefulWidget {
  const DSBottomSlotReporter({
    super.key,
    required this.slot,
    required this.child,
    this.extra = 0,
  });

  final DSBottomSlot slot;

  /// Added to the measured height. The floating action button's margin: the
  /// space under it is as occupied as the button is.
  final double extra;

  final Widget child;

  @override
  State<DSBottomSlotReporter> createState() => _DSBottomSlotReporterState();
}

class _DSBottomSlotReporterState extends State<DSBottomSlotReporter> {
  DSBottomInsetsHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _host = DSBottomInsetsHost.maybeOf(context);
  }

  @override
  void dispose() {
    _host?.retract(widget.slot);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = _host;
    if (host == null) return widget.child;
    return _Measured(
      onSize: (size) => host.report(widget.slot, size.height + widget.extra),
      child: widget.child,
    );
  }
}

class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  _RenderMeasured createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
