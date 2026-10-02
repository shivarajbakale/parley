// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Where a transient surface arrives, and therefore how it leaves.
///
/// Five presentations, one route. Before this the kit had four unrelated
/// mechanisms — `modal_bottom_sheet`, a hand-written `PopupRoute`, a
/// hand-written `PageRouteBuilder`, Flutter's `showDialog` — plus a select
/// popover that was an `OverlayEntry` and therefore not on the navigator
/// stack at all. Four barriers, four curves, four dismissal policies, and one
/// surface the Android back button could not close.
///
/// `docs/plans/17-ds-overlay.plan.md` is the record of why this exists.
enum DSOverlayPresentation {
  /// Rises from the bottom edge. Companion content; the screen behind stays
  /// visible and in place.
  sheet,

  /// Centred, blocking. A decision the task cannot continue without.
  dialog,

  /// Anchored to the control that opened it, and at least as wide as it.
  popover,

  /// Anchored, and narrower: a short list of actions.
  menu,

  /// A sheet whose initial height is the whole screen and whose corners
  /// animate to zero as it gets there. Not a sixth mechanism.
  fullScreen,
}

/// How a surface leaves, when it is dragged rather than dismissed.
///
/// A sheet goes down, a popover goes back toward its anchor, a dialog goes
/// nowhere. Reusing one exit for all three is a large part of what makes a
/// kit feel machine-made.
enum DSOverlayExit { down, up, none }

/// A presentation the kit does not ship.
///
/// A side panel on a tablet, a window-anchored inspector: implement this,
/// hand it to [showDSOverlay], and nothing else in the kit changes.
abstract class DSOverlayPresentationDelegate {
  const DSOverlayPresentationDelegate();

  /// Where the surface sits inside the screen.
  Alignment get alignment;

  /// The room the surface is given. [anchorSize] is null for the
  /// unanchored presentations.
  BoxConstraints constraintsFor(BoxConstraints incoming, Size? anchorSize);

  /// Enter and exit, as one builder. [animation] runs forward on enter and
  /// in reverse on exit.
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  );

  /// Which way a drag dismisses.
  DSOverlayExit get exitDirection;
}

/// The scrim, the shape, the depth and the timing every transient surface
/// shares, as data.
///
/// Every field is nullable and the defaults are read in [resolve], per the
/// contract in [DSComponentStyle].
@immutable
class DSOverlayStyle extends DSComponentStyle<DSOverlayStyle> {
  const DSOverlayStyle({
    this.scrimColor,
    this.scrimOpacity,
    this.scrimBlur,
    this.surfaceColor,
    this.shadows,
    this.sheetShape,
    this.dialogShape,
    this.handleSize,
    this.handleColor,
    this.dialogMinWidth,
    this.dialogMaxWidth,
    this.dialogInset,
    this.menuMinWidth,
    this.menuMaxWidth,
    this.anchorGap,
    this.anchoredMaxHeight,
    this.dismissThreshold,
    this.enterDuration,
    this.exitDuration,
    this.responsiveBreakpoint,
  });

  /// The ink the barrier is painted in, before [scrimOpacity].
  final Color? scrimColor;

  /// How dark the barrier goes. Two values by brightness rather than one:
  /// the same alpha over a dark page is barely a scrim at all.
  final double? scrimOpacity;

  /// Blur behind the scrim. Zero by default — a blurred barrier costs a
  /// full-screen save layer on every frame of the entrance.
  final double? scrimBlur;

  final Color? surfaceColor;
  final List<BoxShadow>? shadows;

  final ShapeBorder? sheetShape;
  final ShapeBorder? dialogShape;

  final Size? handleSize;
  final Color? handleColor;

  final double? dialogMinWidth;
  final double? dialogMaxWidth;

  /// How far a dialog stays from the edges of the screen.
  final double? dialogInset;

  final double? menuMinWidth;
  final double? menuMaxWidth;

  /// Between an anchored surface and the control it is anchored to.
  final double? anchorGap;

  /// The tallest an anchored surface gets before its list scrolls.
  final double? anchoredMaxHeight;

  /// The fraction of its own height a sheet must be dragged past before the
  /// drag commits to a dismissal. On the style object so a surface carrying a
  /// destructive action can raise it.
  final double? dismissThreshold;

  final Duration? enterDuration;
  final Duration? exitDuration;

  /// Below this width, [DSOverlayPresentation.popover] and
  /// [DSOverlayPresentation.menu] become sheets.
  final double? responsiveBreakpoint;

  @override
  DSOverlayStyle merge(DSOverlayStyle? other) {
    if (other == null) return this;
    return DSOverlayStyle(
      scrimColor: other.scrimColor ?? scrimColor,
      scrimOpacity: other.scrimOpacity ?? scrimOpacity,
      scrimBlur: other.scrimBlur ?? scrimBlur,
      surfaceColor: other.surfaceColor ?? surfaceColor,
      shadows: other.shadows ?? shadows,
      sheetShape: other.sheetShape ?? sheetShape,
      dialogShape: other.dialogShape ?? dialogShape,
      handleSize: other.handleSize ?? handleSize,
      handleColor: other.handleColor ?? handleColor,
      dialogMinWidth: other.dialogMinWidth ?? dialogMinWidth,
      dialogMaxWidth: other.dialogMaxWidth ?? dialogMaxWidth,
      dialogInset: other.dialogInset ?? dialogInset,
      menuMinWidth: other.menuMinWidth ?? menuMinWidth,
      menuMaxWidth: other.menuMaxWidth ?? menuMaxWidth,
      anchorGap: other.anchorGap ?? anchorGap,
      anchoredMaxHeight: other.anchoredMaxHeight ?? anchoredMaxHeight,
      dismissThreshold: other.dismissThreshold ?? dismissThreshold,
      enterDuration: other.enterDuration ?? enterDuration,
      exitDuration: other.exitDuration ?? exitDuration,
      responsiveBreakpoint: other.responsiveBreakpoint ?? responsiveBreakpoint,
    );
  }

  @override
  DSOverlayStyle copyWith({
    Color? scrimColor,
    double? scrimOpacity,
    double? scrimBlur,
    Color? surfaceColor,
    List<BoxShadow>? shadows,
    ShapeBorder? sheetShape,
    ShapeBorder? dialogShape,
    Size? handleSize,
    Color? handleColor,
    double? dialogMinWidth,
    double? dialogMaxWidth,
    double? dialogInset,
    double? menuMinWidth,
    double? menuMaxWidth,
    double? anchorGap,
    double? anchoredMaxHeight,
    double? dismissThreshold,
    Duration? enterDuration,
    Duration? exitDuration,
    double? responsiveBreakpoint,
  }) => DSOverlayStyle(
    scrimColor: scrimColor ?? this.scrimColor,
    scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    scrimBlur: scrimBlur ?? this.scrimBlur,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    shadows: shadows ?? this.shadows,
    sheetShape: sheetShape ?? this.sheetShape,
    dialogShape: dialogShape ?? this.dialogShape,
    handleSize: handleSize ?? this.handleSize,
    handleColor: handleColor ?? this.handleColor,
    dialogMinWidth: dialogMinWidth ?? this.dialogMinWidth,
    dialogMaxWidth: dialogMaxWidth ?? this.dialogMaxWidth,
    dialogInset: dialogInset ?? this.dialogInset,
    menuMinWidth: menuMinWidth ?? this.menuMinWidth,
    menuMaxWidth: menuMaxWidth ?? this.menuMaxWidth,
    anchorGap: anchorGap ?? this.anchorGap,
    anchoredMaxHeight: anchoredMaxHeight ?? this.anchoredMaxHeight,
    dismissThreshold: dismissThreshold ?? this.dismissThreshold,
    enterDuration: enterDuration ?? this.enterDuration,
    exitDuration: exitDuration ?? this.exitDuration,
    responsiveBreakpoint: responsiveBreakpoint ?? this.responsiveBreakpoint,
  );

  @override
  DSOverlayStyle lerp(DSOverlayStyle? other, double t) {
    if (other == null) return this;
    return DSOverlayStyle(
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t),
      scrimOpacity: lerpDouble(scrimOpacity, other.scrimOpacity, t),
      scrimBlur: lerpDouble(scrimBlur, other.scrimBlur, t),
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      shadows: BoxShadow.lerpList(shadows, other.shadows, t),
      sheetShape: ShapeBorder.lerp(sheetShape, other.sheetShape, t),
      dialogShape: ShapeBorder.lerp(dialogShape, other.dialogShape, t),
      handleSize: Size.lerp(handleSize, other.handleSize, t),
      handleColor: Color.lerp(handleColor, other.handleColor, t),
      dialogMinWidth: lerpDouble(dialogMinWidth, other.dialogMinWidth, t),
      dialogMaxWidth: lerpDouble(dialogMaxWidth, other.dialogMaxWidth, t),
      dialogInset: lerpDouble(dialogInset, other.dialogInset, t),
      menuMinWidth: lerpDouble(menuMinWidth, other.menuMinWidth, t),
      menuMaxWidth: lerpDouble(menuMaxWidth, other.menuMaxWidth, t),
      anchorGap: lerpDouble(anchorGap, other.anchorGap, t),
      anchoredMaxHeight: lerpDouble(
        anchoredMaxHeight,
        other.anchoredMaxHeight,
        t,
      ),
      dismissThreshold: lerpDouble(dismissThreshold, other.dismissThreshold, t),
      enterDuration: t < 0.5 ? enterDuration : other.enterDuration,
      exitDuration: t < 0.5 ? exitDuration : other.exitDuration,
      responsiveBreakpoint: lerpDouble(
        responsiveBreakpoint,
        other.responsiveBreakpoint,
        t,
      ),
    );
  }

  /// The four layers, in order, and the only place an overlay's defaults are
  /// read.
  ///
  /// [presentation] is a parameter rather than a field for the reason
  /// `DSCardStyle.resolve` takes a variant: it selects *which* defaults layer
  /// 1 supplies. A sheet is chrome — it covers content that stays visible
  /// behind it — so it takes `AppMaterials.sheet`, which is the tint and the
  /// upward-falling shadow the chrome layer decided on. A dialog is not: it
  /// arrives over its own scrim, and `docs/principles/depth-and-materials.md`
  /// keeps it off the material deliberately.
  static DSOverlayStyle resolve(
    BuildContext context, [
    DSOverlayPresentation presentation = DSOverlayPresentation.sheet,
    DSOverlayStyle? own,
  ]) {
    final design = context.design;
    final palette = context.palette;
    final light = palette.brightness == Brightness.light;
    final sheetLike =
        presentation == DSOverlayPresentation.sheet ||
        presentation == DSOverlayPresentation.fullScreen;
    final AppMaterial? material = sheetLike
        ? AppMaterials.sheet(context)
        : null;

    final specDefaults = DSOverlayStyle(
      scrimColor: palette.overlay,
      // Darker in dark. The same alpha over a near-black page reads as a
      // slightly dirty screen rather than as a barrier.
      scrimOpacity: light ? 0.42 : 0.62,
      scrimBlur: 0,
      // A dialog is the one surface the ladder's light-theme rule does not
      // describe. `surface` steps *down* from the page because in light the
      // page is white and there is nothing above it — but a dialog does not
      // sit on the page, it sits on a scrim. Over darkened ground the step
      // down reads as dirty rather than as raised, so in light a dialog
      // takes the page's own white and the scrim carries the separation.
      // Dark is unchanged: there the ladder already rises toward light, and
      // `canvas` is the darkest thing on screen.
      surfaceColor:
          material?.tint ??
          (!sheetLike && light ? palette.background : palette.card),
      shadows:
          material?.shadow ??
          design.elevation.resolve(
            elevation: design.elevation.levelOf(DSElevation.high),
            brightness: palette.brightness,
            shadowColor: palette.overlay,
          ),
      sheetShape: context.shapeOf(AppShape.sheet),
      dialogShape: context.shapeOf(AppShape.dialog),
      handleSize: Size(
        design.component.grabberWidth,
        design.component.grabberHeight,
      ),
      handleColor: palette.border,
      dialogMinWidth: design.component.dialogMinWidth,
      // A fraction of the screen, clamped by the ceiling. A dialog that
      // hugs its own text measures a different width for every message it
      // carries; on a tablet, 90% of the screen is a banner. Both numbers
      // are the identity's, and until this line one of them was unread.
      // ...and never below the floor. The fraction is of the *screen*, so on
      // a narrow one — a 300-point window, a split-screen pane — it lands
      // under `dialogMinWidth`, and a `BoxConstraints` whose min exceeds its
      // max is not a clamp, it is a non-normalized-constraints crash. The
      // floor wins; a dialog wider than its window is the better failure.
      dialogMaxWidth: math.max(
        design.component.dialogMinWidth,
        math.min(
          design.component.overlayMaxWidth,
          MediaQuery.sizeOf(context).width *
              design.component.overlayWidthFactor,
        ),
      ),
      dialogInset: design.space.lg,
      menuMinWidth: design.component.menuMinWidth,
      menuMaxWidth: design.component.menuMaxWidth,
      anchorGap: design.space.hairline * 2,
      // Six rows of a comfortable list row, which is what the anchored
      // surfaces show before they scroll. The `240` literal this replaces
      // clipped a row in half at text scale 2.0, because a fixed pixel
      // ceiling cannot know how tall a row grew.
      anchoredMaxHeight: design.component.minTapTarget * 6,
      dismissThreshold: 0.4,
      enterDuration: design.motion.normal,
      exitDuration: design.motion.fast,
      responsiveBreakpoint: 600,
    );

    return resolveStyle<DSOverlayStyle>(
      context: context,
      specDefaults: specDefaults,
      own: own,
    );
  }
}

/// The presentation a surface will actually get, once the width has had its
/// say.
///
/// A popover is a regular-width idiom: below [DSOverlayStyle.
/// responsiveBreakpoint] the same content is a sheet. Encoding it here rather
/// than at each call site is the point — one call, one behaviour on both form
/// factors, which is the rule the HIG states and nobody remembers to write.
DSOverlayPresentation resolveDSPresentation(
  BuildContext context,
  DSOverlayPresentation requested, {
  bool responsive = true,
  DSOverlayStyle? style,
}) {
  if (!responsive) return requested;
  final anchored =
      requested == DSOverlayPresentation.popover ||
      requested == DSOverlayPresentation.menu;
  if (!anchored) return requested;
  final breakpoint = DSOverlayStyle.resolve(
    context,
    requested,
    style,
  ).responsiveBreakpoint!;
  return MediaQuery.sizeOf(context).width < breakpoint
      ? DSOverlayPresentation.sheet
      : requested;
}

/// Presents [builder] over the current screen and returns what it pops.
///
/// This is the kit's only presentation entry point. A surface presented any
/// other way is off the navigator, which costs the back button, the focus
/// trap, the barrier's localised dismiss label, `Navigator.pop(result)` and
/// route observation — all of which arrive here for free and none of which is
/// worth reimplementing per surface.
Future<T?> showDSOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  DSOverlayPresentation presentation = DSOverlayPresentation.sheet,
  GlobalKey? anchor,
  bool responsive = true,
  bool barrierDismissible = true,
  bool enableDrag = true,
  double? maxHeight,
  String? semanticLabel,
  DSOverlayExit? exitOverride,
  DSOverlayStyle? style,
  DSOverlayPresentationDelegate? delegate,
}) {
  final resolved = resolveDSPresentation(
    context,
    presentation,
    responsive: responsive,
    style: style,
  );

  assert(
    delegate != null ||
        anchor != null ||
        (resolved != DSOverlayPresentation.popover &&
            resolved != DSOverlayPresentation.menu),
    'An anchored presentation needs the key of the control it is anchored '
    'to. Pass `anchor:`, or let `responsive` degrade it to a sheet.',
  );

  return Navigator.of(context, rootNavigator: true).push<T>(
    DSOverlayRoute<T>(
      builder: builder,
      presentation: resolved,
      anchorRect: anchor == null ? null : _rectOf(anchor),
      barrierDismissibleFlag: barrierDismissible,
      enableDrag: enableDrag,
      maxHeight: maxHeight,
      semanticLabel: semanticLabel,
      exitOverride: exitOverride,
      style: style,
      delegate: delegate,
      barrierLabelText: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
    ),
  );
}

/// Where [key]'s control is, in global coordinates.
Rect? _rectOf(GlobalKey key) {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderBox || !object.hasSize) return null;
  return object.localToGlobal(Offset.zero) & object.size;
}

/// The one route every transient surface in the kit is presented through.
///
/// Public and subclassable: a caller whose surface needs something no
/// presentation covers extends this rather than writing a fifth mechanism.
class DSOverlayRoute<T> extends PopupRoute<T> {
  DSOverlayRoute({
    required this.builder,
    required this.presentation,
    required this.barrierLabelText,
    this.anchorRect,
    this.barrierDismissibleFlag = true,
    this.enableDrag = true,
    this.maxHeight,
    this.semanticLabel,
    this.exitOverride,
    this.style,
    this.delegate,
  });

  final WidgetBuilder builder;
  final DSOverlayPresentation presentation;

  /// Where the anchoring control was when the surface was opened, in global
  /// coordinates. Null for the unanchored presentations.
  final Rect? anchorRect;

  bool barrierDismissibleFlag;
  final bool enableDrag;
  final double? maxHeight;
  final String? semanticLabel;

  /// Which way a drag takes this surface off screen, when the presentation's
  /// own answer is not the one wanted — a dialog that opts into the drag it
  /// otherwise refuses.
  final DSOverlayExit? exitOverride;

  final DSOverlayStyle? style;
  final DSOverlayPresentationDelegate? delegate;
  final String barrierLabelText;

  @override
  bool get barrierDismissible => barrierDismissibleFlag;

  /// Locks the barrier while work the surface started is in flight.
  ///
  /// A dialog that disappears under the user's own scrim tap while its
  /// confirming action is still running is how somebody ends up not knowing
  /// whether the thing happened.
  void setBarrierDismissible(bool value) {
    if (barrierDismissibleFlag == value) return;
    barrierDismissibleFlag = value;
    changedInternalState();
  }

  /// A barrier that does nothing must not be offered to a screen reader as a
  /// control. This is the same decision as [barrierDismissible] and has to be
  /// made in the same place, or one of the two is forgotten.
  @override
  bool get semanticsDismissible => barrierDismissibleFlag;

  /// Null: the scrim is painted inside [buildPage] instead, so that a drag
  /// can fade it as the surface leaves. A `barrierColor` is painted by the
  /// navigator and cannot be reached from the surface's own gesture.
  @override
  Color? get barrierColor => null;

  @override
  String get barrierLabel => barrierLabelText;

  @override
  Duration get transitionDuration => _enter;

  @override
  Duration get reverseTransitionDuration => _exit;

  // Placeholders until the first build reads the style. The navigator asks
  // for these before there is a context to resolve a spec from.
  Duration _enter = const MotionSpec().normal;
  Duration _exit = const MotionSpec().fast;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final resolved = DSOverlayStyle.resolve(context, presentation, style);
    // Read on the first build, so the durations the navigator was given and
    // the ones the style names are the same value.
    _enter = resolved.enterDuration!;
    _exit = resolved.exitDuration!;

    return _DSOverlayScaffold(
      route: this,
      style: resolved,
      animation: animation,
      child: Builder(builder: builder),
    );
  }

  /// The transitions are built by [_DSOverlayScaffold] rather than here,
  /// because the drag has to compose with them and only the surface knows how
  /// far it has been dragged.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// The scrim, the position and the entrance, around one surface.
///
/// Split out of [DSOverlayRoute] so that the whole arrangement can be mounted
/// in a widget test without a navigator, and so that the drag gesture and the
/// route animation are composed in one place rather than two.
class _DSOverlayScaffold extends StatefulWidget {
  const _DSOverlayScaffold({
    required this.route,
    required this.style,
    required this.animation,
    required this.child,
  });

  final DSOverlayRoute<Object?> route;
  final DSOverlayStyle style;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_DSOverlayScaffold> createState() => __DSOverlayScaffoldState();
}

class __DSOverlayScaffoldState extends State<_DSOverlayScaffold>
    with SingleTickerProviderStateMixin {
  // No duration on the field: a `late final` is evaluated on first read, and
  // that read can be `dispose`, where the inherited spec is already gone.
  late final AnimationController _springBack = AnimationController(vsync: this)
    ..addListener(_onSpringTick);

  double _drag = 0;
  double _springFrom = 0;
  double _surfaceHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _springBack.duration = context.design.motion.fast;
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onSpringTick() =>
      setState(() => _drag = _springFrom * (1 - _springBack.value));

  DSOverlayPresentation get _presentation => widget.route.presentation;

  DSOverlayExit get _exit =>
      widget.route.exitOverride ??
      widget.route.delegate?.exitDirection ??
      switch (_presentation) {
        DSOverlayPresentation.sheet ||
        DSOverlayPresentation.fullScreen => DSOverlayExit.down,
        DSOverlayPresentation.dialog ||
        DSOverlayPresentation.popover ||
        DSOverlayPresentation.menu => DSOverlayExit.none,
      };

  bool get _draggable => widget.route.enableDrag && _exit != DSOverlayExit.none;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_springBack.isAnimating) return;
    setState(() {
      _drag = (_drag + (details.primaryDelta ?? 0)).clamp(0.0, double.infinity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final threshold =
        (_surfaceHeight <= 0 ? 400.0 : _surfaceHeight) *
        widget.style.dismissThreshold!;
    // A fling commits regardless of where the surface currently is: the user
    // has already said what they meant with the speed.
    if (_drag > threshold || velocity > 700) {
      Navigator.of(context).maybePop();
      return;
    }
    _springFrom = _drag;
    _springBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final media = MediaQuery.of(context);

    // How far through the dismissal the drag has taken the scrim. The scrim
    // starts fading before the finger lifts, which is what makes a drag feel
    // like it is dismissing rather than merely moving something.
    final dragFraction = _surfaceHeight <= 0
        ? 0.0
        : (_drag / _surfaceHeight).clamp(0.0, 1.0);

    final Widget surface = _Measured(
      onSize: (size) => _surfaceHeight = size.height,
      child: _draggable
          // ui-lint: allow pressable-floor — a drag is direct manipulation,
          // not a press: there is nothing to dip, and the affordance a screen
          // reader is offered is DSDragHandle, which has its own action.
          ? GestureDetector(
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: widget.child,
            )
          : widget.child,
    );

    Widget positioned = _DSOverlayPosition(
      presentation: _presentation,
      style: style,
      anchorRect: widget.route.anchorRect,
      maxHeight: widget.route.maxHeight,
      delegate: widget.route.delegate,
      child: Transform.translate(offset: Offset(0, _drag), child: surface),
    );

    positioned = _transition(context, positioned, reduced: reduced);

    if (widget.route.semanticLabel != null) {
      positioned = Semantics(
        label: widget.route.semanticLabel,
        explicitChildNodes: true,
        child: positioned,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _Scrim(
          animation: widget.animation,
          style: style,
          fade: 1 - dragFraction,
          onTap: widget.route.barrierDismissible
              ? () => Navigator.of(context).maybePop()
              : null,
        ),
        // The keyboard inset is applied to the whole positioned surface, and
        // it is isolated in its own widget: only that widget rebuilds over
        // the keyboard's ~15 frames, and `Element.updateChild` sees the same
        // child instance and skips the subtree. The alternative rebuilds a
        // whole form fifteen times to move it up by 291 points.
        _KeyboardAware(
          enabled:
              _presentation != DSOverlayPresentation.popover &&
              _presentation != DSOverlayPresentation.menu,
          viewInsets: media.viewInsets,
          child: positioned,
        ),
      ],
    );
  }

  /// Enter and exit, by presentation.
  ///
  /// Under `disableAnimations` every one of them collapses to a cross-fade
  /// with zero translation and zero scale. Doing it here rather than in each
  /// surface is what makes that claim checkable in one test instead of five.
  Widget _transition(
    BuildContext context,
    Widget child, {
    required bool reduced,
  }) {
    final delegate = widget.route.delegate;
    if (delegate != null) {
      return delegate.buildTransition(context, widget.animation, child);
    }

    final motion = context.design.motion;
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: motion.enter,
      reverseCurve: motion.exit,
    );

    if (reduced) return FadeTransition(opacity: curved, child: child);

    return switch (_presentation) {
      DSOverlayPresentation.sheet ||
      DSOverlayPresentation.fullScreen => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
      // The scale is an *entrance*. Run in reverse it shrinks the dialog
      // back into itself before it fades, which reads as the surface
      // recoiling from the tap that dismissed it rather than leaving. A
      // `Threshold(0)` reverse curve holds the scale at 1 for the whole
      // exit, so a dismissal is the fade alone — the same asymmetry both
      // platforms use, and the reason a dismissed dialog feels let go of.
      DSOverlayPresentation.dialog => FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(
              parent: widget.animation,
              curve: motion.enter,
              reverseCurve: const Threshold(0),
            ),
          ),
          child: child,
        ),
      ),
      // Grows from the edge it is anchored to. Scaling about its own centre
      // would make a menu look like it arrived from nowhere rather than from
      // the control that was tapped.
      DSOverlayPresentation.popover ||
      DSOverlayPresentation.menu => FadeTransition(
        opacity: curved,
        child: _AnchoredScale(animation: curved, child: child),
      ),
    };
  }
}

/// Fades the barrier with the route, and with the drag.
class _Scrim extends StatelessWidget {
  const _Scrim({
    required this.animation,
    required this.style,
    required this.fade,
    required this.onTap,
  });

  final Animation<double> animation;
  final DSOverlayStyle style;
  final double fade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Linear, always. The surface may be spring-driven; a scrim that
    // overshoots its own opacity reads as a flicker rather than as physics.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: style.scrimColor!.withValues(
            alpha: style.scrimOpacity! * animation.value * fade,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Scales about the anchored edge rather than about the middle.
class _AnchoredScale extends StatelessWidget {
  const _AnchoredScale({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, inner) => Transform.scale(
      scaleY: 0.92 + 0.08 * animation.value,
      alignment: Alignment.topCenter,
      child: inner,
    ),
  );
}

/// Isolates keyboard-inset tracking to a single lightweight widget.
///
/// Only this widget rebuilds when the keyboard animates (~15 frames / 250ms).
/// Its [child] is the same widget instance every rebuild, so
/// `Element.updateChild` skips the child subtree entirely — zero form
/// reconstructions, zero layout cascades beyond the [Padding] offset.
class _KeyboardAware extends StatelessWidget {
  const _KeyboardAware({
    required this.enabled,
    required this.viewInsets,
    required this.child,
  });

  final bool enabled;
  final EdgeInsets viewInsets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: child,
    );
  }
}

/// Reports the laid-out size of its child without rebuilding it.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, required Widget child})
    : super(child: child);

  final ValueChanged<Size> onSize;

  @override
  _MeasuredBox createRenderObject(BuildContext context) => _MeasuredBox(onSize);

  @override
  void updateRenderObject(BuildContext context, _MeasuredBox renderObject) =>
      renderObject.onSize = onSize;
}

class _MeasuredBox extends RenderProxyBox {
  _MeasuredBox(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

/// Where the surface sits, and how much room it gets.
class _DSOverlayPosition extends StatelessWidget {
  const _DSOverlayPosition({
    required this.presentation,
    required this.style,
    required this.anchorRect,
    required this.maxHeight,
    required this.delegate,
    required this.child,
  });

  final DSOverlayPresentation presentation;
  final DSOverlayStyle style;
  final Rect? anchorRect;
  final double? maxHeight;
  final DSOverlayPresentationDelegate? delegate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final delegate = this.delegate;

    if (delegate != null) {
      return Align(
        alignment: delegate.alignment,
        child: LayoutBuilder(
          builder: (context, incoming) => ConstrainedBox(
            constraints: delegate.constraintsFor(incoming, anchorRect?.size),
            child: child,
          ),
        ),
      );
    }

    switch (presentation) {
      case DSOverlayPresentation.sheet:
      case DSOverlayPresentation.fullScreen:
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight ?? media.size.height,
            ),
            child: child,
          ),
        );
      case DSOverlayPresentation.dialog:
        final inset = style.dialogInset!;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: media.viewPadding.vertical + inset,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: style.dialogMinWidth!,
                maxWidth: style.dialogMaxWidth!,
                maxHeight: maxHeight ?? double.infinity,
              ),
              child: child,
            ),
          ),
        );
      case DSOverlayPresentation.popover:
      case DSOverlayPresentation.menu:
        final anchor = anchorRect ?? Rect.zero;
        return CustomSingleChildLayout(
          delegate: _AnchoredLayout(
            anchor: anchor,
            gap: style.anchorGap!,
            padding: media.viewPadding,
            minWidth: presentation == DSOverlayPresentation.menu
                ? style.menuMinWidth!
                : anchor.width,
            maxWidth: presentation == DSOverlayPresentation.menu
                ? style.menuMaxWidth!
                : double.infinity,
            maxHeight: maxHeight ?? style.anchoredMaxHeight!,
          ),
          child: child,
        );
    }
  }
}

/// Places an anchored surface under its trigger, and above it when the room
/// below is short.
///
/// A menu that runs off the bottom of the screen is the commonest anchored
/// defect, and it is invisible in a story rendered at the top of a page.
class _AnchoredLayout extends SingleChildLayoutDelegate {
  _AnchoredLayout({
    required this.anchor,
    required this.gap,
    required this.padding,
    required this.minWidth,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Rect anchor;
  final double gap;
  final EdgeInsets padding;
  final double minWidth;
  final double maxWidth;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = constraints.maxHeight - anchor.bottom - gap - padding.bottom;
    final above = anchor.top - gap - padding.top;
    final room = below >= above ? below : above;
    return BoxConstraints(
      minWidth: minWidth.clamp(0.0, constraints.maxWidth),
      maxWidth: maxWidth.clamp(minWidth, constraints.maxWidth),
      maxHeight: maxHeight < room ? maxHeight : room.clamp(0.0, maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = size.height - anchor.bottom - gap;
    // Flips rather than shrinks: a menu squeezed into 30 points below the
    // trigger is a scrolling list two rows tall, which is worse than the same
    // menu opening upward.
    final flip =
        childSize.height > below && anchor.top - gap >= childSize.height;
    final top = flip
        ? anchor.top - gap - childSize.height
        : anchor.bottom + gap;
    final left = anchor.left.clamp(
      0.0,
      (size.width - childSize.width).clamp(0.0, size.width),
    );
    return Offset(
      left,
      top.clamp(0.0, (size.height - childSize.height).clamp(0.0, size.height)),
    );
  }

  @override
  bool shouldRelayout(_AnchoredLayout old) =>
      old.anchor != anchor ||
      old.gap != gap ||
      old.minWidth != minWidth ||
      old.maxWidth != maxWidth ||
      old.maxHeight != maxHeight;
}

/// The shape, the colour and the depth of a floating surface, with no route
/// around it.
///
/// The escape hatch for a caller presenting a surface through their own route,
/// and the widget the catalog renders inline — a story that pushed a route
/// would be a picture of a button rather than of the surface.
class DSOverlaySurface extends StatelessWidget {
  const DSOverlaySurface({
    super.key,
    required this.child,
    this.presentation = DSOverlayPresentation.sheet,
    this.header,
    this.footer,
    this.showDragHandle = true,
    this.handleSlot,
    this.expandedProgress = 0,
    this.style,
  });

  final Widget child;
  final DSOverlayPresentation presentation;
  final Widget? header;
  final Widget? footer;
  final bool showDragHandle;
  final Widget? handleSlot;

  /// How far a sheet has grown toward the top of the screen, 0 to 1. At 1 the
  /// corners are square: a surface touching the status bar with rounded
  /// corners shows the page behind it in two small triangles.
  final double expandedProgress;

  final DSOverlayStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSOverlayStyle.resolve(context, presentation, style);
    final sheetLike =
        presentation == DSOverlayPresentation.sheet ||
        presentation == DSOverlayPresentation.fullScreen;

    ShapeBorder shape = sheetLike
        ? resolved.sheetShape!
        : resolved.dialogShape!;
    if (sheetLike && expandedProgress > 0) {
      shape = ShapeBorder.lerp(
        shape,
        const RoundedRectangleBorder(),
        expandedProgress.clamp(0.0, 1.0),
      )!;
    }

    // A sheet is chrome: it covers content that stays visible behind it, and
    // this widget's own `resolve` says so in as many words. `ui-probe`'s
    // `overlap` rule reads the marker rather than guessing at paint order —
    // without it, a map pin under a sheet's top edge was reported as a pin
    // drawn *through* the sheet's title. A rendering no-op.
    final Widget surface = DecoratedBox(
      decoration: ShapeDecoration(
        color: resolved.surfaceColor,
        shape: shape,
        shadows: resolved.shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          bottom: sheetLike,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sheetLike && showDragHandle)
                handleSlot ?? const DSDragHandle(),
              if (header != null) header!,
              Flexible(child: child),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );

    return sheetLike ? AppChromeOcclusion(child: surface) : surface;
  }
}

/// The grabber at the top edge of a sheet.
///
/// A real semantics node with a dismiss action, not a decorative [Container]:
/// the handle is the affordance a screen reader user is told about, and three
/// sheets drew it as an unlabelled box.
class DSDragHandle extends StatelessWidget {
  const DSDragHandle({super.key, this.semanticLabel, this.onTap, this.style});

  final String? semanticLabel;

  /// What a tap does. Null dismisses the route, which is right for a modal
  /// sheet and wrong for a sheet with detents living over a screen the reader
  /// is still using — there, the handle is the control that cycles the
  /// detents, and popping the route would take the ground away with it.
  final VoidCallback? onTap;

  final DSOverlayStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSOverlayStyle.resolve(
      context,
      DSOverlayPresentation.sheet,
      style,
    );
    final size = resolved.handleSize!;
    final space = context.design.space;
    final label =
        semanticLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel;

    return Semantics(
      label: label,
      button: true,
      onDismiss: onTap == null ? () => Navigator.of(context).maybePop() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Center(
          child: Padding(
            // Tighter below than above: the handle belongs to the sheet's top
            // edge, not to the content, and the content's own first element
            // brings its leading space with it.
            padding: EdgeInsets.only(top: space.sm, bottom: space.xs),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: resolved.handleColor!.withValues(alpha: 0.4),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How a header lines its title up.
enum DSOverlayHeaderAlign { start, center }

/// The pinned block at the top of a surface: what it is, and the way out.
///
/// Ships `DSScope(size: sm)` around its trailing actions, so a header's
/// buttons size themselves rather than each call site saying so.
class DSOverlayHeader extends StatelessWidget {
  const DSOverlayHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleSlot,
    this.subtitleSlot,
    this.showClose = true,
    this.align = DSOverlayHeaderAlign.start,
    this.showDivider = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleSlot;
  final Widget? subtitleSlot;
  final bool showClose;
  final DSOverlayHeaderAlign align;

  /// Drawn only once the body below has scrolled. A divider that is always
  /// there is a line; a divider that appears when content passes under it is
  /// information.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final palette = context.palette;
    final type = Theme.of(context).textTheme;

    final labels = Column(
      crossAxisAlignment: align == DSOverlayHeaderAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `namesRoute` so a screen reader announces "Choose a folder" rather
        // than "dialog" — the surface is named by what it is for.
        Semantics(
          namesRoute: true,
          header: true,
          child: titleSlot ?? Text(title, style: type.titleMedium),
        ),
        if (subtitleSlot != null || subtitle != null) ...[
          SizedBox(height: design.space.hairline),
          subtitleSlot ??
              Text(
                subtitle!,
                style: type.bodySmall?.copyWith(color: palette.mutedForeground),
              ),
        ],
      ],
    );

    // A tap target is a hit area, not a visual edge.
    //
    // The close button is a `minTapTarget`-wide box around an
    // `iconSizeInline` glyph, and laying that box flush against the header's
    // padding leaves the glyph half the difference further in — 14 points at
    // the shipped 48/20 pair. Every row beneath the header is a bare icon
    // whose glyph edge *is* its layout edge, so the header's × measured 30
    // points from the sheet edge while the check marks under it measured 12.
    //
    // `padding: EdgeInsets.zero` reads like it prevents this and does not:
    // it removes padding inside the button, but the tight constraints hold
    // the box at 48 regardless, and the glyph has nowhere to sit but the
    // middle. So the box is translated outward by exactly that half-
    // difference instead — the glyph lands on the padding line and the hit
    // area overhangs into the gutter, which is where a hit area belongs.
    // `Transform` moves the hit test with the box; an `OverflowBox` would
    // not, because a `RenderBox` refuses a hit outside its own bounds and
    // the overhanging half of the target would be dead.
    final closeOverhang =
        (design.component.minTapTarget - design.component.iconSizeInline) / 2;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    final actions = <Widget>[
      if (trailing != null) trailing!,
      if (showClose)
        Transform.translate(
          offset: Offset(rtl ? -closeOverhang : closeOverhang, 0),
          child: IconButton(
            icon: const Icon(Icons.close),
            iconSize: design.component.iconSizeInline,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            constraints: BoxConstraints.tightFor(
              width: design.component.minTapTarget,
              height: design.component.minTapTarget,
            ),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
    ];

    return Container(
      // `sm` vertically, not `md`.
      //
      // The header's height is not set by its title — it is set by the close
      // button's `minTapTarget`, so a 26-point title already sits in a
      // 48-point row with 11 points of air above and below it. Adding 12
      // more on each side made a one-line sheet header 72 points tall and
      // pushed the first option 32 points below the title it belongs to,
      // while the options themselves were flush against each other. The
      // floor the target sets is the generous part; the padding does not
      // have to be generous as well. The footer below keeps `md`: its
      // buttons are its content, and nothing else sets its height.
      // The page gutter, not `lg`: the rows under this header pay the gutter
      // themselves, and at `lg` the title sat four points left of every one
      // of them. `ui-probe`'s `gutter` rule found it the first time a sheet
      // was mounted on a screen rather than over one.
      padding: EdgeInsets.symmetric(
        horizontal: design.space.pageGutter,
        vertical: design.space.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider ? palette.borderSoft : Colors.transparent,
            width: design.component.hairlineWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: design.space.md)],
          Expanded(child: labels),
          if (actions.isNotEmpty)
            DSScope.merge(
              context,
              size: DSSize.sm,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
        ],
      ),
    );
  }
}

/// How a footer lines its actions up.
enum DSOverlayFooterAlign { start, center, end, fill }

/// The pinned block at the bottom of a surface, below the scroll and above
/// the safe area.
///
/// Ships `DSScope(size: md)`: a sheet's primary action is full size even when
/// the header's controls are small.
class DSOverlayFooter extends StatelessWidget {
  const DSOverlayFooter({
    super.key,
    this.actions,
    this.helper,
    this.align = DSOverlayFooterAlign.end,
    this.showDivider = true,
  });

  final Widget? actions;
  final Widget? helper;
  final DSOverlayFooterAlign align;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final palette = context.palette;

    final Widget? row = actions == null
        ? null
        : switch (align) {
            DSOverlayFooterAlign.fill => actions!,
            DSOverlayFooterAlign.start => Align(
              alignment: AlignmentDirectional.centerStart,
              child: actions,
            ),
            DSOverlayFooterAlign.center => Center(child: actions),
            DSOverlayFooterAlign.end => Align(
              alignment: AlignmentDirectional.centerEnd,
              child: actions,
            ),
          };

    return Container(
      // The gutter, for the reason the header above gives: a footer's buttons
      // line up with the rows they follow.
      padding: EdgeInsets.symmetric(
        horizontal: design.space.pageGutter,
        vertical: design.space.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: showDivider ? palette.borderSoft : Colors.transparent,
            width: design.component.hairlineWidth,
          ),
        ),
      ),
      child: DSScope.merge(
        context,
        size: DSSize.md,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (helper != null) ...[helper!, SizedBox(height: design.space.sm)],
            if (row != null) row,
          ],
        ),
      ),
    );
  }
}

/// Locks or unlocks the barrier of the overlay the caller is inside.
///
/// A no-op outside a [DSOverlayRoute], so a surface rendered inline in the
/// catalog behaves the same as one that was presented.
void setDSOverlayBarrierDismissible(BuildContext context, bool value) {
  final route = ModalRoute.of(context);
  if (route is DSOverlayRoute) route.setBarrierDismissible(value);
}
