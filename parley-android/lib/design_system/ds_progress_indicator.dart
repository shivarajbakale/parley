// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

enum DSProgressVariant { linear, circular }

/// How a progress indicator looks, at every layer of the chain.
@immutable
class DSProgressStyle extends DSComponentStyle<DSProgressStyle> {
  const DSProgressStyle({
    this.height,
    this.strokeWidth,
    this.trackColor,
    this.indicatorColor,
    this.labelStyle,
  });

  final double? height;
  final double? strokeWidth;

  /// What the bar is drawn on. Reads `palette.muted` by default — a
  /// surface-coloured track disappears the moment the bar is put on a card,
  /// which is where a progress bar usually goes.
  final Color? trackColor;

  final Color? indicatorColor;
  final TextStyle? labelStyle;

  @override
  DSProgressStyle merge(DSProgressStyle? other) {
    if (other == null) return this;
    return DSProgressStyle(
      height: other.height ?? height,
      strokeWidth: other.strokeWidth ?? strokeWidth,
      trackColor: other.trackColor ?? trackColor,
      indicatorColor: other.indicatorColor ?? indicatorColor,
      labelStyle: other.labelStyle ?? labelStyle,
    );
  }

  @override
  DSProgressStyle copyWith({
    double? height,
    double? strokeWidth,
    Color? trackColor,
    Color? indicatorColor,
    TextStyle? labelStyle,
  }) => DSProgressStyle(
    height: height ?? this.height,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    trackColor: trackColor ?? this.trackColor,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    labelStyle: labelStyle ?? this.labelStyle,
  );

  @override
  DSProgressStyle lerp(DSProgressStyle? other, double t) {
    if (other == null) return this;
    return DSProgressStyle(
      height: lerpDouble(height, other.height, t),
      strokeWidth: lerpDouble(strokeWidth, other.strokeWidth, t),
      trackColor: Color.lerp(trackColor, other.trackColor, t),
      indicatorColor: Color.lerp(indicatorColor, other.indicatorColor, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
    );
  }

  static DSProgressStyle resolve(
    BuildContext context, {
    DSTone tone = DSTone.neutral,
    DSProgressStyle? own,
  }) {
    final design = context.design;
    final palette = context.palette;
    final indicator = switch (tone) {
      DSTone.neutral => palette.primary,
      DSTone.info => palette.primary,
      DSTone.success => palette.success,
      DSTone.warning => palette.warning,
      DSTone.error => palette.destructive,
    };

    return resolveStyle(
      context: context,
      specDefaults: DSProgressStyle(
        height: design.component.progressHeight,
        strokeWidth: design.component.progressStroke,
        trackColor: palette.muted,
        indicatorColor: indicator,
        labelStyle: DSTextRole.caption.styleOf(context),
      ),
      own: own,
    );
  }
}

/// A design-system progress indicator with linear and circular variants.
///
/// The linear variant renders with rounded corners at the spec's height, on
/// `palette.muted`. `Color? color` and `Color? backgroundColor` are
/// gone (`docs/plans/31-ds-compositions.plan.md`): they were the last two
/// unconstrained colour parameters in the kit, and the default they fell back
/// to — a surface — made a bar on a card invisible.
///
/// The circular variant is [CircularProgressIndicator.adaptive], which is a
/// [CupertinoActivityIndicator] on Apple and a Material ring elsewhere. A
/// spinning arc on iOS is one of the two or three details that identify an app
/// as a port, and it costs one word to get right.
class DSProgressIndicator extends StatelessWidget {
  const DSProgressIndicator({
    super.key,
    this.variant = DSProgressVariant.linear,
    this.value,
    this.tone = DSTone.neutral,
    this.label,
    this.labelSlot,
    this.semanticLabel,
    this.style,
  });

  const DSProgressIndicator.linear({
    super.key,
    this.value,
    this.tone = DSTone.neutral,
    this.label,
    this.labelSlot,
    this.semanticLabel,
    this.style,
  }) : variant = DSProgressVariant.linear;

  const DSProgressIndicator.circular({
    super.key,
    this.value,
    this.tone = DSTone.neutral,
    this.label,
    this.labelSlot,
    this.semanticLabel,
    this.style,
  }) : variant = DSProgressVariant.circular;

  final DSProgressVariant variant;

  /// Null is indeterminate — the work has started and nobody knows how far it
  /// has got.
  final double? value;

  final DSTone tone;

  /// The percentage, or whatever the number means here. Placed by the
  /// component rather than by the caller, which is where it used to live.
  final String? label;
  final Widget? labelSlot;

  final String? semanticLabel;

  final DSProgressStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSProgressStyle.resolve(context, tone: tone, own: style);

    if (variant == DSProgressVariant.circular) {
      final ring = CircularProgressIndicator.adaptive(
        value: value,
        // Cupertino's indicator ignores both of these and draws the system
        // spinner, which is the point of asking for it.
        valueColor: AlwaysStoppedAnimation<Color>(resolved.indicatorColor!),
        strokeWidth: resolved.strokeWidth!,
      );
      return _labelled(context, ring, resolved, vertical: true);
    }

    final bar = ClipRRect(
      // The bar is a pill on both platforms — a track this thin has no room
      // for the difference between a continuous curve and an arc.
      borderRadius: BorderRadius.circular(resolved.height! / 2),
      // The brand gradient only stands in for the flat fill at the neutral
      // tone — a status colour (success/warning/error) still means what it
      // says, and a gradient over it would blur that signal.
      child: tone == DSTone.neutral
          ? Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: resolved.trackColor!)),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  // `ShaderMask` calls this with only the bounds — it does
                  // not resolve `AlignmentDirectional` itself the way a
                  // `BoxDecoration` does — so the ambient text direction is
                  // read explicitly rather than left for `createShader` to
                  // find an inherited `Directionality` that its render
                  // object never asks for.
                  shaderCallback: (rect) =>
                      context.palette.primaryGradient.createShader(
                        rect,
                        textDirection: Directionality.of(context),
                      ),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: resolved.height,
                    color: Palette.sheenInk,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            )
          : LinearProgressIndicator(
              value: value,
              minHeight: resolved.height,
              color: resolved.indicatorColor,
              backgroundColor: resolved.trackColor,
            ),
    );
    return _labelled(context, bar, resolved, vertical: false);
  }

  Widget _labelled(
    BuildContext context,
    Widget indicator,
    DSProgressStyle resolved, {
    required bool vertical,
  }) {
    final text =
        labelSlot ??
        (label == null ? null : Text(label!, style: resolved.labelStyle));

    Widget body = indicator;
    if (text != null) {
      final gap = context.design.space.xs;
      body = vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator,
                SizedBox(height: gap),
                text,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator,
                SizedBox(height: gap),
                text,
              ],
            );
    }

    return semanticLabel == null
        ? body
        : Semantics(label: semanticLabel, child: body);
  }
}
