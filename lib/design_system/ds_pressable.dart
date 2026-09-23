// ds-tier: 0 — foundation

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Press feedback, as one component.
///
/// See `docs/principles/motion.md`. A button that dips 3% under the finger and
/// springs back is the cheapest thing in a kit that reads as expensive, and it
/// is also the thing most likely to be re-implemented fifteen times: one widget
/// at 0.97 over 120ms, the next at 0.95 with a different curve, a third that
/// forgets to release when the finger drags away. This is the one
/// implementation, and the widgets in the kit wrap it rather than writing their
/// own.
///
/// **It observes the press; it does not own the tap.** The scale is driven from
/// a [Listener], which sees pointer events without entering the gesture arena,
/// so the [InkWell], [TextButton] or [GestureDetector] underneath keeps its own
/// callback, its own semantics and its own ink. Wrapping something tappable can
/// therefore never change what tapping it does.
///
/// **What it does on each platform**, from `context.springsAvailable`:
///
/// - Android springs, because a spring interrupted mid-press continues from
///   where it is, and that is the Material 3 Expressive motion model.
/// - Apple uses the curve, because the platform's own animations are
///   curve-based and a bouncing button on iOS reads as a bug.
/// - Under reduced motion there is no scale at all — not a faster one. The
///   scale, its controller and its listener are all gone, and the press still
///   shows through the colour change that every control already has. A colour
///   is not motion.
///
/// **It observes the focus too, and does not own that either.** The kit's
/// floor is documented as target sizing, press feedback, focus, haptics and
/// disabled semantics, and `ui_lint`'s `pressable-floor` rule has been telling
/// people for several plans that a control which skips this widget "has no
/// press feedback, no focus ring and no haptic" — while this widget had no
/// focus ring to give. It does now. A [Focus] that cannot request focus and is
/// skipped by traversal reports when anything beneath it is focused, exactly
/// as the [Listener] reports pointers without entering the gesture arena, so
/// the [InkWell] or [TextButton] underneath still owns its own node and
/// tabbing to a wrapped control still does what it did.
///
/// The ring is drawn only when the platform's focus highlight mode is
/// [FocusHighlightMode.traditional] — that is, when focus is being moved by a
/// keyboard rather than by a finger. A touch user never sees it, which is why
/// [DSFocusRing] can be unconditional in the tree.
class DSPressable extends StatefulWidget {
  const DSPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = pressScale,
    this.focusShape,
  });

  final Widget child;

  /// False for a disabled control: pressing something that cannot respond
  /// should not look like it responded.
  final bool enabled;

  /// The scale at full press. One value for the kit; a card that dips further
  /// than a button is a kit with two opinions about how hard a press is.
  final double scale;

  /// The outline the focus ring follows, which is the child's own silhouette.
  ///
  /// Nullable rather than required: an app that wraps its own widget gets the
  /// control radius and a sensible ring. Every component in the kit passes its
  /// own — a pill chip ringed as a rounded rectangle, or a circular icon button
  /// ringed as a square, is worse than no ring, because it reads as a drawing
  /// error rather than as focus.
  final OutlinedBorder? focusShape;

  static const double pressScale = 0.97;

  @override
  State<DSPressable> createState() => _DSPressableState();
}

class _DSPressableState extends State<DSPressable>
    with SingleTickerProviderStateMixin {
  // The bounds are deliberately outside [0, 1]. An AnimationController clamps
  // its simulation to them, and a spring clamped at its target arrives dead —
  // the overshoot is the part that reads as physical, so there has to be room
  // on both sides of rest for it to happen in.
  late final AnimationController _press = AnimationController(
    vsync: this,
    // `value` is not optional here. An AnimationController starts at its
    // lowerBound, so leaving it out would rest the widget at -0.25 — every
    // card and button in the app drawn very slightly *larger* than it should
    // be, permanently, which is precisely the kind of defect that ships.
    value: 0,
    lowerBound: -0.25,
    upperBound: 1.25,
  );

  Offset? _downAt;

  /// Focus, and whether this platform is in a state where focus is worth
  /// drawing. Both are needed: a phone that has never seen a key press keeps
  /// [FocusHighlightMode.touch], and a control that has been tapped may well
  /// hold focus without the user having any idea what focus is.
  bool _focused = false;
  FocusHighlightMode _highlight = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  // The duration is set here rather than on the controller's field
  // initialiser: a `late final` field is evaluated on first *read*, and for a
  // pressable that was never pressed that read is `dispose`, where the
  // inherited spec is already gone.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _press.duration = context.design.motion.press;
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (!mounted || mode == _highlight) return;
    setState(() => _highlight = mode);
  }

  void _onFocusChanged(bool focused) {
    if (focused == _focused) return;
    setState(() => _focused = focused);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    _press.dispose();
    super.dispose();
  }

  void _drive(double target) {
    if (!mounted) return;
    final motion = context.design.motion;
    if (context.springsAvailable) {
      _press.animateWith(motion.simulation(from: _press.value, to: target));
      return;
    }
    _press.animateTo(
      target,
      duration: target == 1 ? motion.press : motion.pressRelease,
      curve: motion.enter,
    );
  }

  void _down(PointerDownEvent event) {
    _downAt = event.position;
    _drive(1);
  }

  void _move(PointerMoveEvent event) {
    // A finger that has travelled past the slop is scrolling, not pressing.
    // Without this every row of a list dips as the list is flung, which is the
    // single most common way press feedback goes wrong.
    final origin = _downAt;
    if (origin == null) return;
    if ((event.position - origin).distance > kTouchSlop) {
      _downAt = null;
      _drive(0);
    }
  }

  void _up([PointerEvent? _]) {
    _downAt = null;
    _drive(0);
  }

  @override
  Widget build(BuildContext context) {
    var child = widget.child;

    // The dip is conditional; the ring is not. `enabled` is how a caller
    // switches off the scale — a control docked at a row's trailing edge
    // detaches from the row if it shrinks — and two components in the kit pass
    // `enabled: false` for exactly that while still being fully tappable. A
    // focus ring gated on it would be missing from them.
    if (widget.enabled && !MediaQuery.disableAnimationsOf(context)) {
      child = Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedBuilder(
          animation: _press,
          // The child is built once and reused across every frame of the press.
          child: child,
          builder: (context, child) => Transform.scale(
            scale: 1 + (widget.scale - 1) * _press.value,
            child: child,
          ),
        ),
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      // The node is an observer. Letting it publish semantics would put a
      // second focusable-looking node over controls that have already been
      // given a deliberate `Semantics` wrapper by their component.
      includeSemantics: false,
      onFocusChange: _onFocusChanged,
      child: DSFocusRing(
        visible: _focused && _highlight == FocusHighlightMode.traditional,
        shape: widget.focusShape,
        child: child,
      ),
    );
  }
}

/// The focus ring, drawn outside the thing it rings.
///
/// Separate from [DSPressable] and public because focus is not only a property
/// of pressables: a field, a slider or an app's own composite control needs the
/// same ring, and a second ring drawn a second way is how a kit ends up with
/// two focus states that do not match.
///
/// **Outside the bounds, with a gap.** A ring painted on a control's own edge
/// is invisible on a filled button — accent stroke on accent fill — and a ring
/// with no gap reads as a thicker border rather than as a state. Both numbers
/// are [ComponentSpec] tokens. Painting outside means the ring is not part of
/// layout: focusing a control never moves anything, which is the property that
/// lets the ring be unconditional in a list.
class DSFocusRing extends StatelessWidget {
  const DSFocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.shape,
    this.color,
    this.width,
    this.gap,
  });

  final bool visible;
  final Widget child;

  /// The child's silhouette. Defaults to the control shape for the platform.
  final OutlinedBorder? shape;

  /// Defaults to the palette accent, which `palette_lint`'s K8 holds at 3:1
  /// against all three surface roles — the contrast WCAG 2.2 SC 1.4.11 asks of
  /// a non-text indicator.
  final Color? color;

  final double? width;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final component = context.design.component;
    // The [CustomPaint] is unconditional and only its painter comes and goes.
    // Returning the bare child when unfocused reads as the cheaper branch and
    // is a trap: adding and removing an element level rebuilds everything
    // below it, which destroys the very [FocusNode] that had just been focused
    // — tab moved focus, the ring appeared, the node it belonged to was gone,
    // and the ring stayed lit on a control nothing was pointing at.
    return CustomPaint(
      foregroundPainter: visible
          ? _FocusRingPainter(
              shape: shape ?? context.shapeOf(AppShape.control),
              color: color ?? context.palette.primary,
              width: width ?? component.focusRingWidth,
              gap: gap ?? component.focusRingGap,
            )
          : null,
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.shape,
    required this.color,
    required this.width,
    required this.gap,
  });

  final OutlinedBorder shape;
  final Color color;
  final double width;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke straddles the path, so the path sits at the gap plus half the
    // stroke: the ring's inner edge is then exactly `gap` from the control.
    final rect = (Offset.zero & size).inflate(gap + width / 2);
    canvas.drawPath(
      shape.getOuterPath(rect, textDirection: TextDirection.ltr),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.width != width ||
      old.gap != gap;
}

/// The ink layer, as one component.
///
/// `Material(type: MaterialType.transparency)` wrapped around an [InkWell]
/// appeared thirteen times in this kit and no two spellings agreed. Four of
/// them derived a radius for the ink and then derived the same radius again
/// for the focus ring, and two of those read it from a different token the
/// second time. Three set a minimum tap target inside the ink and three did
/// not, so a control that painted below the floor answered below it too. One
/// reached for [InkResponse] because a circular button wants an unbounded
/// splash, which is a fourth spelling of the same three widgets.
///
/// This is the one spelling. The `raw-ink` rule in `ui_lint` keeps it that
/// way: [InkWell], [InkResponse] and a transparent [Material] live in this
/// file and nowhere else.
///
/// **It does not dip.** Press feedback is [DSPressable]'s and stays there.
/// Half the call sites already own the dip at a different level — the card
/// scales its whole surface, the FAB scales above its glass — so an ink layer
/// that wrapped its own [DSPressable] would scale those twice. A component
/// that wants both stacks them in that order:
///
/// ```dart
/// DSPressable(
///   focusShape: shape,
///   child: DSInkSurface(onTap: ..., shape: shape, child: ...),
/// )
/// ```
///
/// **One [shape], two jobs.** It clips the splash and it is the silhouette
/// the ring outside follows, which is why it is passed once rather than
/// spelled out at both layers.
///
/// **The tap floor is on by default.** `ComponentSpec.minTapTarget` is a
/// promise the kit makes about every control, and every site here that
/// skipped it was skipping it by accident. A control that paints deliberately
/// below the floor — a segment, a chip's remove glyph — says `minTapTarget:
/// false` and grows its box with `DSTapTarget` outside the ink, so the ripple
/// stays the size of the visual.
class DSInkSurface extends StatelessWidget {
  const DSInkSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onHighlightChanged,
    this.shape,
    this.tint,
    this.highlightColor,
    this.minTapTarget = true,
    this.unbounded = false,
    this.unboundedRadius,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;

  /// Null disables the surface: no splash, no highlight, no semantics action.
  /// Callers pass `enabled ? callback : null` rather than a separate flag,
  /// which is the same shape [InkWell] itself uses.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;
  final ValueChanged<TapDownDetails>? onTapDown;
  final ValueChanged<TapUpDetails>? onTapUp;
  final VoidCallback? onTapCancel;

  /// Reported when the highlight comes and goes, for a component that paints
  /// its own pressed state as well as taking the ripple.
  final ValueChanged<bool>? onHighlightChanged;

  /// The silhouette: the splash is clipped to it, [tint] is filled to it, and
  /// it is what a surrounding [DSPressable] should ring.
  final OutlinedBorder? shape;

  /// A colour painted *into* the material under the splash, for a row that is
  /// active or keyboard-highlighted. An ordinary `DecoratedBox` above the ink
  /// would cover the ripple; [Ink] is drawn by the material itself.
  final Color? tint;

  final Color? highlightColor;

  /// Whether the ink box is held to `ComponentSpec.minTapTarget` on the
  /// vertical axis. See the class comment for when to turn it off.
  final bool minTapTarget;

  /// An unbounded circular splash ([InkResponse]) instead of a clipped one.
  /// A round icon button's ripple is wider than the glyph it surrounds.
  final bool unbounded;

  /// The splash radius when [unbounded]. Null takes Material's own default.
  final double? unboundedRadius;

  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    var content = child;
    if (minTapTarget) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.design.component.minTapTarget,
        ),
        child: content,
      );
    }
    if (tint != null) {
      // A `ShapeDecoration` rather than `Ink(color:)`: the colour has to stop
      // where the splash stops, and a plain colour box under a rounded clip
      // paints its corners outside the shape.
      content = Ink(
        decoration: ShapeDecoration(
          color: tint,
          shape: shape ?? const RoundedRectangleBorder(),
        ),
        child: content,
      );
    }

    final Widget ink = unbounded
        ? InkResponse(
            onTap: onTap,
            onLongPress: onLongPress,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            onTapCancel: onTapCancel,
            onHighlightChanged: onHighlightChanged,
            customBorder: shape,
            highlightColor: highlightColor,
            radius: unboundedRadius,
            containedInkWell: false,
            autofocus: autofocus,
            focusNode: focusNode,
            child: content,
          )
        : InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            onTapCancel: onTapCancel,
            onHighlightChanged: onHighlightChanged,
            customBorder: shape,
            highlightColor: highlightColor,
            autofocus: autofocus,
            focusNode: focusNode,
            child: content,
          );

    // Transparent, always. The ink needs a material to paint into and this is
    // the cheapest one there is; a surface that wants a colour paints it
    // itself, above, where its own shape and shadow already live.
    return Material(type: MaterialType.transparency, child: ink);
  }
}
