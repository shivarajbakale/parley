// ds-tier: 0 — foundation

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Grows a control's hit box to the tap floor without growing what it paints.
///
/// Private to the design system — the leading underscore is the kit's marker
/// for a file that is machinery rather than a component, so it is not
/// exported, not in the reference and not in the catalog.
///
/// The kit deliberately paints several controls below
/// [ComponentSpec.minTapTarget]: a small button is 36 tall, a segment of a
/// segmented control is 30, a chip's remove glyph is 18. That is a drawing
/// decision, and the spec says so in as many words — "a button is a target,
/// and a segmented control is a track with targets inside it, so the track is
/// shorter than the 48 its segments still have to clear". What was missing was
/// the second half: nothing made the target clear it.
///
/// The obvious trick does not work. Wrapping the small visual in an
/// [OverflowBox] that spills to 48 looks like it enlarges the target and does
/// not: [RenderBox.hitTest] refuses a position outside its own `size` before
/// it ever reaches the child, so a pointer landing in the spill is tested
/// against the parent, misses, and stops. The kit shipped exactly that on the
/// chip's remove control, where it read as a 48-point target in the source and
/// measured 18 in the tree.
///
/// What does work is what Material does for its own controls: a box that lays
/// out at least [minSize], centres the painted child inside it, and forwards
/// any hit inside its own bounds to the centre of that child. The target grows
/// in *layout* — that is the cost, and it is the honest one, because a target
/// nothing can collide with is not a target.
class DSTapTarget extends SingleChildRenderObjectWidget {
  const DSTapTarget({super.key, this.minSize, super.child});

  /// The floor. Defaults to [ComponentSpec.minTapTarget] on both axes.
  final Size? minSize;

  Size _resolve(BuildContext context) {
    final double floor = context.design.component.minTapTarget;
    return minSize ?? Size.square(floor);
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTapTarget(_resolve(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTapTarget).minSize = _resolve(context);
  }
}

class _RenderTapTarget extends RenderShiftedBox {
  _RenderTapTarget(this._minSize, [RenderBox? child]) : super(child);

  Size get minSize => _minSize;
  Size _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    child == null ? 0.0 : child!.getMinIntrinsicWidth(height),
    minSize.width,
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    child == null ? 0.0 : child!.getMaxIntrinsicWidth(height),
    minSize.width,
  );

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    child == null ? 0.0 : child!.getMinIntrinsicHeight(width),
    minSize.height,
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    child == null ? 0.0 : child!.getMaxIntrinsicHeight(width),
    minSize.height,
  );

  Size _sizeFor(BoxConstraints constraints, ChildLayouter layoutChild) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.constrain(minSize);
    final Size childSize = layoutChild(child, constraints.loosen());
    return constraints.constrain(
      Size(
        math.max(childSize.width, minSize.width),
        math.max(childSize.height, minSize.height),
      ),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _sizeFor(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _sizeFor(constraints, ChildLayoutHelper.layoutChild);
    final RenderBox? child = this.child;
    if (child == null) return;
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The child first, so a hit on the paint keeps its own local coordinates —
    // an ink splash centred on the pointer rather than on the control.
    if (super.hitTest(result, position: position)) return true;
    final RenderBox? child = this.child;
    if (child == null || !size.contains(position)) return false;
    // A hit in the grown margin is delivered to the centre of the child. Not
    // the nearest point on it: the centre is the one position guaranteed to be
    // inside every shape a control paints, including a circle.
    final Offset centre = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(centre),
      position: centre,
      hitTest: (BoxHitTestResult result, Offset position) =>
          child.hitTest(result, position: centre),
    );
  }
}

/// Lays a control out at the tap floor while it paints a shorter track.
///
/// The other half of [DSTapTarget], and the reason that one is not enough on
/// its own. A segmented control, a pill tab bar and a compact stepper are all
/// the same shape: a painted track with targets *inside* it. Growing a target
/// inside a track that is 36 points tall does nothing — the track's own height
/// arrives as a tight constraint, and [DSTapTarget] cannot exceed what it is
/// given.
///
/// So the track stops being the parent. [background] is painted at [height],
/// centred, behind [child]; [child] is laid out at the full box, which is the
/// floor. The control occupies the floor in layout and still draws the shorter
/// track the spec asks for.
class DSShortTrack extends StatelessWidget {
  const DSShortTrack({
    super.key,
    required this.height,
    required this.background,
    required this.child,
  });

  /// What the track paints. The box is [ComponentSpec.minTapTarget] when this
  /// is shorter than it, and this when it is not.
  final double height;

  /// The painted track. Stretched to the width [child] resolves to and to
  /// [height], never taller.
  final Widget background;

  /// The targets. Given the full height of the box.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double floor = context.design.component.minTapTarget;
    return SizedBox(
      height: math.max(height, floor),
      child: Stack(
        // Passthrough, not the stack's default. The child is the control: it
        // has to receive the constraints the control was given, or a row of
        // segments handed a tight width by its parent suddenly hugs its
        // content and floats in the middle of the track it belongs to. The
        // stack still sizes itself to the child, so a control that hugs when
        // it is given room keeps doing that.
        fit: StackFit.passthrough,
        // And centred for a child that is shorter than the box, which is the
        // chip: twenty points of content in a forty-eight point target.
        alignment: Alignment.center,
        children: <Widget>[
          // Positioned rather than ordinary: a stack sizes itself to its
          // non-positioned children, and a background that voted would make
          // the width of the track a function of the track rather than of the
          // row of targets it sits behind.
          Positioned.fill(
            child: Center(
              child: SizedBox(height: height, child: background),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
