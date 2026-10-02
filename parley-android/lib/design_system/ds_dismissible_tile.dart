// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One swipe action: what is revealed under a row, and what happens when the
/// row is let go past the threshold.
///
/// A value class rather than a slot, because it configures a background rather
/// than composing one: the label, the glyph and the tone are all needed by the
/// semantics action as well as by the painted panel, and a `Widget` here would
/// give the screen reader nothing to announce.
@immutable
class DSSwipeAction {
  const DSSwipeAction({
    required this.icon,
    required this.label,
    this.tone = DSTone.neutral,
    required this.onInvoke,
  });

  final IconData icon;

  /// Shown under the row and announced as a custom action. "Delete", not
  /// "Swipe to delete" — the semantics tree says how it is invoked.
  final String label;

  final DSTone tone;
  final VoidCallback onInvoke;
}

/// How a swipe background looks, at every layer of the chain.
@immutable
class DSSwipeActionStyle extends DSComponentStyle<DSSwipeActionStyle> {
  const DSSwipeActionStyle({
    this.threshold,
    this.backgroundFill,
    this.foreground,
    this.iconSize,
    this.labelStyle,
    this.iconLabelGap,
    this.padding,
  });

  /// How far a row travels before the swipe commits, as a fraction of its own
  /// width.
  final double? threshold;

  /// Null takes the action's tone. A colour here overrides every action's.
  final Color? backgroundFill;

  final Color? foreground;
  final double? iconSize;
  final TextStyle? labelStyle;
  final double? iconLabelGap;
  final EdgeInsetsGeometry? padding;

  @override
  DSSwipeActionStyle merge(DSSwipeActionStyle? other) {
    if (other == null) return this;
    return DSSwipeActionStyle(
      threshold: other.threshold ?? threshold,
      backgroundFill: other.backgroundFill ?? backgroundFill,
      foreground: other.foreground ?? foreground,
      iconSize: other.iconSize ?? iconSize,
      labelStyle: other.labelStyle ?? labelStyle,
      iconLabelGap: other.iconLabelGap ?? iconLabelGap,
      padding: other.padding ?? padding,
    );
  }

  @override
  DSSwipeActionStyle copyWith({
    double? threshold,
    Color? backgroundFill,
    Color? foreground,
    double? iconSize,
    TextStyle? labelStyle,
    double? iconLabelGap,
    EdgeInsetsGeometry? padding,
  }) => DSSwipeActionStyle(
    threshold: threshold ?? this.threshold,
    backgroundFill: backgroundFill ?? this.backgroundFill,
    foreground: foreground ?? this.foreground,
    iconSize: iconSize ?? this.iconSize,
    labelStyle: labelStyle ?? this.labelStyle,
    iconLabelGap: iconLabelGap ?? this.iconLabelGap,
    padding: padding ?? this.padding,
  );

  @override
  DSSwipeActionStyle lerp(DSSwipeActionStyle? other, double t) {
    if (other == null) return this;
    return DSSwipeActionStyle(
      threshold: lerpDouble(threshold, other.threshold, t),
      backgroundFill: Color.lerp(backgroundFill, other.backgroundFill, t),
      foreground: Color.lerp(foreground, other.foreground, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      iconLabelGap: lerpDouble(iconLabelGap, other.iconLabelGap, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
    );
  }

  static DSSwipeActionStyle resolve(
    BuildContext context, {
    DSSwipeActionStyle? own,
  }) {
    final design = context.design;
    return resolveStyle(
      context: context,
      specDefaults: DSSwipeActionStyle(
        threshold: design.component.swipeThreshold,
        iconSize: design.component.iconSize,
        labelStyle: Theme.of(context).textTheme.labelSmall,
        iconLabelGap: design.space.xs,
        padding: EdgeInsets.symmetric(horizontal: design.space.xl),
      ),
      own: own,
    );
  }

  /// The panel colours for a tone.
  static (Color, Color) toneColors(BuildContext context, DSTone tone) {
    final palette = context.palette;
    return switch (tone) {
      DSTone.neutral => (palette.primary, palette.primaryForeground),
      DSTone.info => (palette.primary, palette.primaryForeground),
      DSTone.success => (palette.success, palette.onSuccess),
      DSTone.warning => (palette.warning, palette.onWarning),
      DSTone.error => (palette.destructive, palette.onDestructive),
    };
  }
}

/// A row that can be swiped away, with the panel that says what the swipe will
/// do.
///
/// See `docs/plans/31-ds-compositions.plan.md`. The wrapper used to hand
/// [Dismissible] a key, a direction and a confirm callback and nothing else,
/// so every caller built the red panel themselves, only one direction was
/// reachable, and the swipe was invisible to a screen reader — a hidden
/// feature on every dismissible row in the app.
///
/// Each action registers a custom semantics action as well as painting its
/// panel, so the same thing a swipe does is reachable from the screen
/// reader's action menu without any gesture at all.
///
/// **The threshold is the moment worth animating.** A swipe has one decision
/// in it — far enough, or not — and until this widget was stateful the row
/// gave no sign of which side of it the finger was on. The user found out by
/// letting go. The panel's glyph now springs up as the swipe arms and settles
/// back if the finger retreats, and a selection tick fires at the same
/// instant, so the answer arrives in the hand while the thumb is still on the
/// row and covering the glyph.
///
/// The movement itself still belongs to [Dismissible] — its slide and its
/// collapse are not ours to spring — but their durations are now the app's
/// rather than the framework's defaults, which is what puts them behind the
/// `speed` knob with everything else.
class DSDismissibleTile extends StatefulWidget {
  const DSDismissibleTile({
    required Key key,
    required this.child,
    this.leadingAction,
    this.trailingAction,
    this.onConfirmDismiss,
    this.onDismissed,
    this.style,
  }) : assert(
         leadingAction != null || trailingAction != null,
         'a dismissible row with no action slides off a blank surface and '
         'tells the user nothing about what is about to happen',
       ),
       super(key: key);

  final Widget child;

  /// Revealed by a swipe from the leading edge — archive, in the common pair.
  final DSSwipeAction? leadingAction;

  /// Revealed by a swipe from the trailing edge — delete, in the common pair.
  final DSSwipeAction? trailingAction;

  final ConfirmDismissCallback? onConfirmDismiss;
  final DismissDirectionCallback? onDismissed;

  final DSSwipeActionStyle? style;

  /// How far the revealed glyph grows once the swipe is past its threshold.
  ///
  /// A constant on the widget rather than a spec token, for the same reason
  /// `DSPressable.pressScale` is: it is one number for the whole kit, and a
  /// build where an armed swipe pops harder than a pressed button is a kit
  /// with two opinions about how emphatic a confirmation is. The spring
  /// overshoots past it, so the peak the eye sees is larger.
  static const double armedScale = 1.18;

  DismissDirection get _direction {
    if (leadingAction != null && trailingAction != null) {
      return DismissDirection.horizontal;
    }
    return leadingAction != null
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;
  }

  @override
  State<DSDismissibleTile> createState() => _DSDismissibleTileState();
}

class _DSDismissibleTileState extends State<DSDismissibleTile>
    with SingleTickerProviderStateMixin {
  /// How armed the swipe is: 0 before the threshold, 1 past it, and above 1
  /// while the spring overshoots.
  ///
  /// Unbounded, because that overshoot *is* the pop — a bounded controller
  /// would clip the peak of a `bouncy` spring to 1 and leave a rise with no
  /// snap at the top of it.
  late final AnimationController _armed = AnimationController.unbounded(
    vsync: this,
  );

  /// Which edge the live swipe came from, so that only the panel actually
  /// under the finger reacts. Without it a two-action row pops both glyphs,
  /// and the one the user cannot see is the one that is wrong.
  DismissDirection? _armedDirection;

  @override
  void dispose() {
    _armed.dispose();
    super.dispose();
  }

  /// Called on every frame of the drag; acts only on the frame that crosses
  /// the threshold.
  ///
  /// `reached == previousReached` is most of them. Springing on each one would
  /// restart the animation sixty times a second, and ticking on each one is a
  /// buzz for the length of the gesture rather than a confirmation of it.
  void _onUpdate(DismissUpdateDetails details) {
    if (details.reached == details.previousReached) return;

    if (_armedDirection != details.direction) {
      // The finger has crossed the centre and the *other* panel is being
      // built now. Its glyph must start from rest: carrying the value over
      // would show the new panel already popped, at whatever scale the panel
      // the user just abandoned had reached.
      _armed.stop();
      _armed.value = 0;
      setState(() => _armedDirection = details.direction);
    }

    // Only on the way in. A tick as the finger retreats reports a decision
    // the user has just un-made, and back-and-forth across the threshold
    // would rattle.
    if (details.reached) AppHaptics.selection();

    final motion = context.design.motion;
    final target = details.reached ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _armed.value = target;
      return;
    }
    _armed.animateWith(
      motion.simulation(
        // Arming overshoots — that is the whole signal. Disarming does not:
        // a glyph that bounces on the way back down draws the eye to the
        // decision the user just abandoned.
        spring: details.reached ? motion.bouncy : motion.snappy,
        from: _armed.value,
        to: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSwipeActionStyle.resolve(context, own: widget.style);
    final motion = context.design.motion;

    Widget? panel(
      DSSwipeAction? action,
      AlignmentGeometry alignment,
      DismissDirection from,
    ) {
      if (action == null) return null;
      final (fill, foreground) = DSSwipeActionStyle.toneColors(
        context,
        action.tone,
      );
      return Container(
        alignment: alignment,
        padding: resolved.padding,
        color: resolved.backgroundFill ?? fill,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The glyph is what grows, not the panel and not the label. The
            // panel is the full height of the row and cannot grow anywhere;
            // scaling the label with it would make the word the swipe is
            // announcing briefly unreadable.
            AnimatedBuilder(
              animation: _armed,
              builder: (context, child) => Transform.scale(
                scale: lerpDouble(
                  1,
                  DSDismissibleTile.armedScale,
                  _armedDirection == from ? _armed.value : 0,
                )!,
                child: child,
              ),
              child: Icon(
                action.icon,
                size: resolved.iconSize,
                color: resolved.foreground ?? foreground,
              ),
            ),
            SizedBox(height: resolved.iconLabelGap),
            Text(
              action.label,
              style: resolved.labelStyle?.copyWith(
                color: resolved.foreground ?? foreground,
              ),
            ),
          ],
        ),
      );
    }

    final row = Dismissible(
      key: ValueKey<Key>(widget.key!),
      direction: widget._direction,
      dismissThresholds: <DismissDirection, double>{
        DismissDirection.startToEnd: resolved.threshold!,
        DismissDirection.endToStart: resolved.threshold!,
      },
      // The framework's own defaults are 200ms and 300ms, which happen to be
      // `fast` and `normal` today — and were outside the scale, so a build
      // that set `speed` moved every other animation in the app and left the
      // swipe behind.
      movementDuration: motion.scaled(motion.fast),
      resizeDuration: motion.scaled(motion.normal),
      onUpdate: _onUpdate,
      // With one action the panel is the `background`, whichever edge it is
      // revealed from: Dismissible asserts on a secondary background with no
      // primary one, because it reads the pair as leading-then-trailing.
      background: widget.leadingAction != null
          ? panel(
              widget.leadingAction,
              AlignmentDirectional.centerStart,
              DismissDirection.startToEnd,
            )
          : panel(
              widget.trailingAction,
              AlignmentDirectional.centerEnd,
              DismissDirection.endToStart,
            ),
      secondaryBackground: widget.leadingAction == null
          ? null
          : panel(
              widget.trailingAction,
              AlignmentDirectional.centerEnd,
              DismissDirection.endToStart,
            ),
      confirmDismiss: widget.onConfirmDismiss,
      onDismissed: (direction) {
        final action = direction == DismissDirection.startToEnd
            ? widget.leadingAction
            : widget.trailingAction;
        // The row is gone: `medium` is the kit's weight for a committed
        // action, and it is a different thing from the `selection` tick that
        // said the swipe *would* commit.
        AppHaptics.medium();
        action?.onInvoke();
        widget.onDismissed?.call(direction);
      },
      child: widget.child,
    );

    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (final action in [widget.leadingAction, widget.trailingAction])
          if (action != null)
            CustomSemanticsAction(label: action.label): action.onInvoke,
      },
      child: row,
    );
  }
}
