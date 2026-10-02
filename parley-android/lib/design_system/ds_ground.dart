// ds-tier: 1 — atom

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The page ground: a soft wash of colour at the top of the page that fades
/// into the palette background, with white cards sitting on it.
///
/// Wraps a page's scaffold. Inside it a scaffold paints no fill of its own, so
/// the wash shows through; the ground itself is opaque at every stop, so a
/// route transition never shows the page underneath.
///
/// A plain [DecoratedBox] gradient on purpose: the UI probe reads a gradient's
/// stops and grades text on the page against every one of them.
///
/// An identity with no [ChromeSpec.groundWash] gets its child back untouched,
/// and a ground inside a ground is a no-op.
class DSGround extends StatefulWidget {
  const DSGround({super.key, required this.child});

  final Widget child;

  @override
  State<DSGround> createState() => _DSGroundState();
}

class _DSGroundState extends State<DSGround> {
  final GlobalKey _groundKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final chrome = context.design.chrome;
    final theme = Theme.of(context);
    final wash = chrome.groundWashFor(theme.brightness);
    if (wash.isEmpty) return widget.child;
    if (context.dependOnInheritedWidgetOfExactType<_GroundScope>() != null) {
      return widget.child;
    }
    final background = context.palette.background;
    final extent = chrome.groundWashExtent;
    final gradient = LinearGradient(
      begin: const Alignment(-0.5, -1),
      end: const Alignment(0.5, 1),
      colors: <Color>[...wash, background, background],
      stops: <double>[
        for (var i = 0; i < wash.length; i++) extent * i / wash.length,
        extent,
        1,
      ],
    );
    return DecoratedBox(
      key: _groundKey,
      decoration: BoxDecoration(gradient: gradient),
      child: _GroundScope(
        groundKey: _groundKey,
        gradient: gradient,
        child: Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: background.withValues(alpha: 0),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GroundScope extends InheritedWidget {
  const _GroundScope({
    required this.groundKey,
    required this.gradient,
    required super.child,
  });

  final GlobalKey groundKey;
  final LinearGradient gradient;

  @override
  bool updateShouldNotify(_GroundScope oldWidget) =>
      oldWidget.gradient != gradient;
}

/// An opaque band that paints the slice of the page's wash behind it — a
/// pinned header the rows scroll under, with no edge where it meets the page.
///
/// With no wash in scope it is a plain [fallback] fill, which is what the band
/// was before the wash existed.
///
/// The slice is painted by hand rather than as a decoration, and that is
/// deliberate: the UI probe walks past a render object it cannot read, so text
/// in the band is graded against the ground's own gradient stops — the colours
/// it actually sits on.
class DSGroundSlice extends StatelessWidget {
  const DSGroundSlice({super.key, required this.fallback, this.child});

  final Color fallback;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_GroundScope>();
    if (scope == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: fallback),
        child: child,
      );
    }
    return _Slice(
      groundKey: scope.groundKey,
      gradient: scope.gradient,
      fallback: fallback,
      child: child,
    );
  }
}

class _Slice extends SingleChildRenderObjectWidget {
  const _Slice({
    required this.groundKey,
    required this.gradient,
    required this.fallback,
    super.child,
  });

  final GlobalKey groundKey;
  final LinearGradient gradient;
  final Color fallback;

  @override
  _RenderSlice createRenderObject(BuildContext context) =>
      _RenderSlice(groundKey, gradient, fallback);

  @override
  void updateRenderObject(BuildContext context, _RenderSlice renderObject) {
    renderObject
      ..groundKey = groundKey
      ..gradient = gradient
      ..fallback = fallback;
  }
}

class _RenderSlice extends RenderProxyBox {
  _RenderSlice(this._groundKey, this._gradient, this._fallback);

  GlobalKey _groundKey;
  set groundKey(GlobalKey value) {
    if (value == _groundKey) return;
    _groundKey = value;
    markNeedsPaint();
  }

  LinearGradient _gradient;
  set gradient(LinearGradient value) {
    if (value == _gradient) return;
    _gradient = value;
    markNeedsPaint();
  }

  Color _fallback;
  set fallback(Color value) {
    if (value == _fallback) return;
    _fallback = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final band = offset & size;
    final paint = Paint()..color = _fallback;
    final ground = _groundKey.currentContext?.findRenderObject();
    if (ground is RenderBox && ground.hasSize) {
      // The ground's rect, in this band's canvas coordinates. The gradient is
      // laid out across that rect, so the band shows exactly its own slice.
      final origin = localToGlobal(Offset.zero, ancestor: ground);
      final groundRect = (offset - origin) & ground.size;
      paint.shader = ui.Gradient.linear(
        _gradient.begin.resolve(TextDirection.ltr).withinRect(groundRect),
        _gradient.end.resolve(TextDirection.ltr).withinRect(groundRect),
        _gradient.colors,
        _gradient.stops,
      );
    }
    context.canvas.drawRect(band, paint);
    super.paint(context, offset);
  }
}
