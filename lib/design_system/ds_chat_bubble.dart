// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Who said it.
///
/// Two values rather than a `bool isMine`, because the side a bubble takes is
/// read at every call site and `author: DSChatAuthor.them` says at a glance
/// what `mine: false` makes you reason about.
enum DSChatAuthor {
  /// The person holding the phone. Drawn on the trailing edge, in the accent.
  me,

  /// Anyone else — a person, an agent, the system.
  them,
}

/// Where a message is in its life.
///
/// A conversation is the one surface where the network is visible to the
/// user: a message they wrote exists before the server has it, and the gap
/// between those two facts is a state, not a spinner over the whole screen.
/// [failed] is the reason this is an enum and not a `bool sent` — a message
/// that never left is the only thing on the screen the user can act on, and
/// it needs a way back.
enum DSChatStatus {
  /// Written, not yet acknowledged. Drawn at reduced opacity so the
  /// difference from [sent] is visible without a second glyph.
  sending,

  /// Arriving now, token by token. The bubble is the live one.
  streaming,

  /// The server has it. The default, and the quiet one.
  sent,

  /// It did not leave. Carries the tone of an error and a way to retry.
  failed,
}

/// Where a bubble sits in a run of turns from one speaker.
///
/// A transcript is not a list of equal rows. Three messages sent in ten
/// seconds are one utterance, and drawing them as three identical lozenges
/// with the same gap between them as between two speakers throws away the
/// only grouping a thread has. A run is drawn by two things and neither is a
/// label: the corner nearest the speaker stays tight *inside* the run, and
/// the gap before a continuing turn closes to a hairline —
/// [DSChatBubble.gapBefore] is the number.
enum DSChatGroup {
  /// A turn with a different speaker on either side of it. The default, and
  /// the only value a thread that does not group has to know about.
  alone,

  /// The first of two or more from one speaker.
  first,

  /// Neither the first nor the last of a run.
  middle,

  /// The last of a run — the turn that carries the tail, and the one a thread
  /// showing one time per run puts the time on.
  last,
}

/// How a bubble looks, at every layer of the resolution chain.
@immutable
class DSChatBubbleStyle extends DSComponentStyle<DSChatBubbleStyle> {
  const DSChatBubbleStyle({
    this.padding,
    this.radius,
    this.tailRadius,
    this.maxWidthFactor,
    this.mineFill,
    this.mineText,
    this.theirFill,
    this.theirText,
    this.metaStyle,
    this.metaColor,
    this.mineMetaColor,
    this.gap,
    this.sendingOpacity,
    this.entranceScale,
  }) : assert(
         maxWidthFactor == null || (maxWidthFactor > 0 && maxWidthFactor <= 1),
         'maxWidthFactor is the share of the line a bubble may take. Above 1 '
         'it overflows its own thread; at 1 the run of bubbles has no ragged '
         'edge left to tell one speaker from the other',
       );

  final EdgeInsetsGeometry? padding;

  /// The three corners that are not the tail.
  final double? radius;

  /// The corner nearest the speaker, which is tightened so a run of bubbles
  /// from one side reads as one run rather than as a stack of lozenges.
  final double? tailRadius;

  /// The share of the available width a bubble may occupy. The remainder is
  /// what makes the thread legible: a bubble that reaches both edges is a
  /// paragraph, and a column of paragraphs has no speakers.
  final double? maxWidthFactor;

  final Color? mineFill;
  final Color? mineText;
  final Color? theirFill;
  final Color? theirText;

  /// The timestamp and the delivery mark.
  final TextStyle? metaStyle;

  /// On a bubble that sits on the surface — theirs.
  final Color? metaColor;

  /// On a bubble that sits on the accent — mine. A separate field because
  /// [metaColor] is a tertiary grey chosen against `surface`, and the same
  /// grey on the accent fill is a timestamp nobody can read. The first
  /// golden of this component showed exactly that.
  final Color? mineMetaColor;

  /// Between the body and the meta row.
  final double? gap;

  /// How much of a [DSChatStatus.sending] bubble survives.
  final double? sendingOpacity;

  /// How small a bubble starts when it animates in, as a share of its final
  /// size. It grows from the corner nearest its speaker, so the message
  /// leaves the composer rather than appearing over it.
  final double? entranceScale;

  @override
  DSChatBubbleStyle merge(DSChatBubbleStyle? other) {
    if (other == null) return this;
    return DSChatBubbleStyle(
      padding: other.padding ?? padding,
      radius: other.radius ?? radius,
      tailRadius: other.tailRadius ?? tailRadius,
      maxWidthFactor: other.maxWidthFactor ?? maxWidthFactor,
      mineFill: other.mineFill ?? mineFill,
      mineText: other.mineText ?? mineText,
      theirFill: other.theirFill ?? theirFill,
      theirText: other.theirText ?? theirText,
      metaStyle: other.metaStyle ?? metaStyle,
      metaColor: other.metaColor ?? metaColor,
      mineMetaColor: other.mineMetaColor ?? mineMetaColor,
      gap: other.gap ?? gap,
      sendingOpacity: other.sendingOpacity ?? sendingOpacity,
      entranceScale: other.entranceScale ?? entranceScale,
    );
  }

  @override
  DSChatBubbleStyle copyWith({
    EdgeInsetsGeometry? padding,
    double? radius,
    double? tailRadius,
    double? maxWidthFactor,
    Color? mineFill,
    Color? mineText,
    Color? theirFill,
    Color? theirText,
    TextStyle? metaStyle,
    Color? metaColor,
    Color? mineMetaColor,
    double? gap,
    double? sendingOpacity,
    double? entranceScale,
  }) => DSChatBubbleStyle(
    padding: padding ?? this.padding,
    radius: radius ?? this.radius,
    tailRadius: tailRadius ?? this.tailRadius,
    maxWidthFactor: maxWidthFactor ?? this.maxWidthFactor,
    mineFill: mineFill ?? this.mineFill,
    mineText: mineText ?? this.mineText,
    theirFill: theirFill ?? this.theirFill,
    theirText: theirText ?? this.theirText,
    metaStyle: metaStyle ?? this.metaStyle,
    metaColor: metaColor ?? this.metaColor,
    mineMetaColor: mineMetaColor ?? this.mineMetaColor,
    gap: gap ?? this.gap,
    sendingOpacity: sendingOpacity ?? this.sendingOpacity,
    entranceScale: entranceScale ?? this.entranceScale,
  );

  @override
  DSChatBubbleStyle lerp(DSChatBubbleStyle? other, double t) {
    if (other == null) return this;
    return DSChatBubbleStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      radius: lerpDouble(radius, other.radius, t),
      tailRadius: lerpDouble(tailRadius, other.tailRadius, t),
      maxWidthFactor: lerpDouble(maxWidthFactor, other.maxWidthFactor, t),
      mineFill: Color.lerp(mineFill, other.mineFill, t),
      mineText: Color.lerp(mineText, other.mineText, t),
      theirFill: Color.lerp(theirFill, other.theirFill, t),
      theirText: Color.lerp(theirText, other.theirText, t),
      metaStyle: TextStyle.lerp(metaStyle, other.metaStyle, t),
      metaColor: Color.lerp(metaColor, other.metaColor, t),
      mineMetaColor: Color.lerp(mineMetaColor, other.mineMetaColor, t),
      gap: lerpDouble(gap, other.gap, t),
      sendingOpacity: lerpDouble(sendingOpacity, other.sendingOpacity, t),
      entranceScale: lerpDouble(entranceScale, other.entranceScale, t),
    );
  }

  static DSChatBubbleStyle resolve(
    BuildContext context, [
    DSChatBubbleStyle? own,
  ]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSChatBubbleStyle(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: space.md,
          vertical: space.sm,
        ),
        // Half the height of a one-line bubble — one line of body copy plus
        // the padding above and below it — so a short message is a capsule
        // and a long one keeps the same corner. A role radius cannot answer
        // this: `card` is a number chosen for a box whose height nobody
        // knows, and at 20 against a 39-point bubble it drew a lozenge with
        // flats top and bottom, which is the shape that reads as a tag.
        radius: (_lineHeight(text.bodyMedium) + space.sm * 2) / 2,
        tailRadius: space.xs,
        maxWidthFactor: _defaultMaxWidthFactor,
        mineFill: palette.primary,
        mineText: palette.primaryForeground,
        theirFill: palette.muted,
        theirText: palette.foreground,
        // The one role below `caption`. A timestamp set at the same size as
        // the label above it is a second sentence competing with the message
        // it dates; at `micro` it is a fact you can find and never read.
        metaStyle: DSTextRole.timestamp.styleOf(context),
        // `textSecondary`, not `textTertiary`. The tertiary grey is graded
        // against `canvas`; on the bubble's `well` fill `ui-probe` measured
        // the timestamp at 2.72:1 against a 4.5 floor.
        metaColor: palette.mutedForeground,
        mineMetaColor: palette.primaryForeground,
        gap: space.hairline,
        sendingOpacity: _defaultSendingOpacity,
        entranceScale: _defaultEntranceScale,
      ),
      own: own,
    );
  }

  /// Roughly three quarters of the line. Enough for a paragraph, short enough
  /// that the ragged edge on the other side stays visible at every width.
  static const double _defaultMaxWidthFactor = 0.78;

  /// Legible, and clearly not yet the same thing as a delivered message.
  static const double _defaultSendingOpacity = 0.6;

  /// Small enough to read as a growth, large enough that nothing about the
  /// message is unreadable on the way. Under this the text inside reflows
  /// visibly as it scales, which reads as a glitch rather than as an entrance.
  static const double _defaultEntranceScale = 0.8;

  /// One line of a step, in points. `TextStyle.height` is a multiple of the
  /// size, and a null one means the face decides — 1.2 is the engine's own
  /// fallback and the only honest guess available before layout.
  static double _lineHeight(TextStyle? step) =>
      (step?.fontSize ?? 16) * (step?.height ?? 1.2);
}

/// One turn in a conversation, on the side of whoever said it.
///
/// **Use when** the screen is a thread: messages accumulate, the newest is at
/// the bottom, and who spoke is part of the content. **Instead:** `DSMessage`
/// for a banner the app says *about* the screen — a message from the system
/// to the user is not a turn in a conversation, and giving it a bubble puts
/// the app's voice inside the transcript. `DSListTile` when the rows are
/// records rather than speech.
///
/// The bubble carries [status] because a conversation is the surface where
/// the network is visible: a message exists in the transcript before the
/// server acknowledges it, and a message that failed to send is the one thing
/// on the screen the user can still act on. A thread that draws every bubble
/// identically has to report that failure somewhere else, and the somewhere
/// else is always a snackbar that has already gone by the time they look.
///
/// [DSChatStatus.streaming] draws a caret and no animation. The caret is the
/// signal; animating it here would make every golden of a streaming bubble a
/// coin flip, and the app that wants a blink owns a controller already.
class DSChatBubble extends StatefulWidget {
  const DSChatBubble({
    super.key,
    required this.author,
    this.text,
    this.child,
    this.status = DSChatStatus.sent,
    this.group = DSChatGroup.alone,
    this.animateIn = false,
    this.timeLabel,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.failedLabel = 'Not sent',
    this.style,
  }) : assert(
         (text == null) != (child == null),
         'a bubble carries text or a child, not both and not neither',
       );

  final DSChatAuthor author;

  /// The message, when it is prose. The common case by a wide margin.
  final String? text;

  /// The message, when it is not prose — an image, a quoted card, a map
  /// still. The bubble supplies the ground and the width cap; what sits on it
  /// is the caller's.
  final Widget? child;

  final DSChatStatus status;

  /// Where this turn sits in a run from one speaker. The thread knows its
  /// neighbours and the bubble does not, so the thread answers.
  final DSChatGroup group;

  /// Whether this bubble grows in from the speaker's corner on its first
  /// build.
  ///
  /// False by default, and that default is the whole design: a list builds
  /// its rows as they are scrolled to, so a bubble that animates whenever it
  /// is built pops every time the reader scrolls back through the history. A
  /// thread turns it on for the turn that *just arrived* and off again once
  /// it has landed — see `thread_page.dart`.
  final bool animateIn;

  /// Short and local — `09:41`, not a full date. The thread's date belongs to
  /// a separator between days, not to every bubble in it.
  final String? timeLabel;

  /// What to do about [DSChatStatus.failed]. A failed bubble with no callback
  /// still says it failed; it just cannot offer the way out.
  final VoidCallback? onRetry;

  final String retryLabel;
  final String failedLabel;

  final DSChatBubbleStyle? style;

  /// The space above a bubble in [group].
  ///
  /// A hairline inside a run and a full step between speakers. The number
  /// lives here rather than in the thread because it is the other half of the
  /// tightened corner: a run drawn with tight corners and a full gap reads as
  /// bubbles that have lost their corners rather than as one utterance.
  static double gapBefore(BuildContext context, DSChatGroup group) {
    final space = context.design.space;
    return switch (group) {
      DSChatGroup.alone || DSChatGroup.first => space.sm,
      DSChatGroup.middle || DSChatGroup.last => space.hairline,
    };
  }

  @override
  State<DSChatBubble> createState() => _DSChatBubbleState();
}

class _DSChatBubbleState extends State<DSChatBubble>
    with SingleTickerProviderStateMixin {
  /// Unbounded on purpose: the entrance is a spring, a bouncy simulation
  /// passes 1 on its way to rest, and a controller clamped at 1 flattens
  /// exactly the overshoot that makes a sent message feel like it left the
  /// thumb.
  ///
  /// It rests at 1 and is wound back to 0 by [_playEntrance] at the moment the
  /// entrance actually starts. Starting it at 0 instead cost a message: the
  /// value was read the first time the bubble was *built*, a transcript reuses
  /// a row's element when the list grows under it, and a bubble that became
  /// the newly-sent one after its own first build parked at zero opacity —
  /// blank until the send landed, then there all at once.
  late final AnimationController _entrance = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool _played = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not `initState`: the spec, the platform and the reader's reduced-motion
    // setting are all inherited, and none of them can be read before this.
    _playEntrance();
  }

  @override
  void didUpdateWidget(covariant DSChatBubble old) {
    super.didUpdateWidget(old);
    // A bubble can *become* the one that just arrived without being built
    // fresh, which is the case the mount alone does not cover.
    if (!old.animateIn && widget.animateIn) _playEntrance();
  }

  /// Once per bubble, and never on a frame where it cannot finish.
  ///
  /// Reduced motion returns before the wind-back, so the failure mode of this
  /// whole mechanism is a message that does not animate — never a message
  /// that is not there.
  void _playEntrance() {
    if (_played || !widget.animateIn) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _played = true;

    final motion = context.design.motion;
    _entrance.value = 0;
    // A spring on both platforms, which is a deliberate exception to
    // `springsAvailable`. That rule says Apple's own animations are
    // curve-based and a bouncing control reads as a bug — true of chrome, and
    // not true here: sending a message is the one gesture iOS itself answers
    // with a spring, and a bubble that eases into place at a constant rate is
    // the thing that reads as a rebuild rather than as an arrival. Reduced
    // motion still wins, above.
    _entrance.animateWith(motion.simulation(spring: motion.bouncy, to: 1));
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  bool get _mine => widget.author == DSChatAuthor.me;

  /// The corner the bubble grows from, and the one its tail is on.
  AlignmentGeometry get _speakerCorner =>
      _mine ? AlignmentDirectional.bottomEnd : AlignmentDirectional.bottomStart;

  @override
  Widget build(BuildContext context) {
    final resolved = DSChatBubbleStyle.resolve(context, widget.style);
    final palette = context.palette;

    final failed = widget.status == DSChatStatus.failed;
    final fill = failed
        ? DSToneWash.fill(
            container: palette.tint(palette.destructive),
            surface: palette.card,
          )
        : (_mine ? resolved.mineFill : resolved.theirFill);
    final onFill = failed
        ? palette.foreground
        : (_mine ? resolved.mineText : resolved.theirText);

    final body = widget.child ?? _body(context, onFill);
    final meta = _meta(context, resolved, failed: failed);

    Widget bubble = Container(
      padding: resolved.padding,
      decoration: ShapeDecoration(
        color: fill,
        // The identity's corner style, not a circular arc. A bubble drawn
        // with `BoxDecoration.borderRadius` is the one shape on an Apple
        // screen that is not a squircle, and a transcript is the surface with
        // the most corners on it.
        shape: context.design.shape.borderFor(
          _corners(resolved),
          isApple: context.isApplePlatform,
          side: failed
              ? BorderSide(
                  color: DSToneWash.border(
                    accent: palette.destructive,
                    fill: fill ?? palette.card,
                    brightness: palette.brightness,
                  ),
                )
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          if (meta != null) ...[SizedBox(height: resolved.gap), meta],
        ],
      ),
    );

    bubble = _dimmedWhileSending(context, bubble, resolved);
    bubble = _growingIn(bubble, resolved);

    // The container's label already carries the speaker, the message and the
    // state in one utterance. Left readable, the text under it is read a
    // second time, so a thread of ten messages is twenty. The retry button
    // stays outside this: it is an action, not a reading of the message.
    bubble = ExcludeSemantics(child: bubble);

    return Semantics(
      container: true,
      label: _semanticsLabel(context),
      child: Row(
        mainAxisAlignment: _mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: FractionallySizedBox(
              alignment: _mine
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              widthFactor: resolved.maxWidthFactor,
              child: Column(
                crossAxisAlignment: _mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [bubble],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Three corners at the full radius and one tightened, plus whatever the
  /// run does to the corner above it.
  ///
  /// The corner nearest the speaker is always tight at the bottom — that is
  /// the tail. Inside a run the *top* one tightens as well, so the bubbles
  /// stack against each other instead of each closing itself off.
  BorderRadiusDirectional _corners(DSChatBubbleStyle resolved) {
    final radius = Radius.circular(resolved.radius ?? 0);
    final tail = Radius.circular(resolved.tailRadius ?? 0);
    final continuing =
        widget.group == DSChatGroup.middle || widget.group == DSChatGroup.last;
    final speakerTop = continuing ? tail : radius;

    return BorderRadiusDirectional.only(
      topStart: _mine ? radius : speakerTop,
      topEnd: _mine ? speakerTop : radius,
      bottomStart: _mine ? radius : tail,
      bottomEnd: _mine ? tail : radius,
    );
  }

  /// A message that has not left yet, drawn as one that has not left yet.
  ///
  /// The dim fades rather than switching, because the frame a message lands
  /// on is the one the reader is watching for, and a step change there is
  /// indistinguishable from a rebuild.
  Widget _dimmedWhileSending(
    BuildContext context,
    Widget child,
    DSChatBubbleStyle resolved,
  ) {
    final motion = context.design.motion;
    final target = widget.status == DSChatStatus.sending
        ? (resolved.sendingOpacity ?? 1)
        : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.scaled(motion.fast),
      curve: motion.standard,
      // At rest and fully opaque there is nothing to compose: a delivered
      // bubble draws no opacity layer at all.
      builder: (context, value, inner) =>
          value >= 1 ? inner! : Opacity(opacity: value, child: inner),
      child: child,
    );
  }

  /// The entrance: up from the speaker's own corner, never from the middle.
  Widget _growingIn(Widget child, DSChatBubbleStyle resolved) {
    if (!widget.animateIn) return child;
    final from = resolved.entranceScale ?? 1;
    final rise = context.design.space.sm;

    return AnimatedBuilder(
      animation: _entrance,
      child: child,
      builder: (context, inner) {
        final t = _entrance.value;
        if (t == 1) return inner!;
        // Up as well as out: the bubble travels the last few points into
        // place, so it reads as a message leaving the composer rather than as
        // one growing where it already was.
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, lerpDouble(rise, 0, t)!),
            child: Transform.scale(
              scale: lerpDouble(from, 1, t)!,
              alignment: _speakerCorner,
              child: inner,
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, Color? color) {
    // The role, not a bare `TextStyle`: a bubble's message is running copy,
    // and running copy grows with the reader's text size and wraps without a
    // line limit. The colour is the bubble's, because a message on the accent
    // fill is `onAccent` and no role can know that.
    final style = DSTextRole.body.styleOf(context).copyWith(color: color);
    final content = Text(widget.text!, style: style);
    if (widget.status != DSChatStatus.streaming) return content;

    final space = context.design.space;
    // The caret sits on the text baseline as a run-in box rather than beside
    // the paragraph, so a streaming message reads as one growing sentence.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.text!),
          const WidgetSpan(child: SizedBox.shrink()),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: space.xs),
              child: SizedBox(
                width: space.xs,
                height: space.md,
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              ),
            ),
          ),
        ],
      ),
      style: style,
    );
  }

  Widget? _meta(
    BuildContext context,
    DSChatBubbleStyle resolved, {
    required bool failed,
  }) {
    final palette = context.palette;
    final space = context.design.space;
    final label = failed ? widget.failedLabel : widget.timeLabel;
    if (label == null) return null;

    // The failed tone stays on the icon; the text sits on a destructive tint
    // and reads in `foreground` — the same icon/text split ruled for
    // `DSMessage`. `metaColor`/`mineMetaColor` stay for the non-failed case.
    final iconColor = palette.destructive;
    final textColor = failed
        ? palette.foreground
        : (_mine ? resolved.mineMetaColor : resolved.metaColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          Icon(
            Icons.error_outline,
            size: context.design.component.iconSizeMicro,
            color: iconColor,
          ),
          SizedBox(width: space.xs),
        ],
        Text(label, style: resolved.metaStyle?.copyWith(color: textColor)),
        if (failed && widget.onRetry != null) ...[
          SizedBox(width: space.xs),
          // Inside the bubble and on the meta line, because the way out of a
          // failure belongs to the message that failed: under the bubble it
          // was a full-sized control floating in the transcript, reading as
          // the thread's next action rather than as this turn's repair.
          //
          // `ghost` paints no fill, so what shows is the word at the
          // timestamp's size. The box around it stays the kit's 48-point tap
          // floor — invisible, and not negotiable: a control small enough to
          // look right is a control nobody can hit.
          DSButton(
            label: widget.retryLabel,
            onPressed: widget.onRetry,
            variant: DSButtonVariant.ghost,
            size: DSButtonSize.sm,
            style: DSButtonStyle(
              labelStyle: resolved.metaStyle,
              labelColor: palette.foreground,
              padding: EdgeInsetsDirectional.symmetric(horizontal: space.xs),
            ),
          ),
        ],
      ],
    );
  }

  /// A screen reader gets the speaker and the state in one utterance. Without
  /// the speaker, a thread is a wall of sentences with no turns in it.
  String _semanticsLabel(BuildContext context) {
    final who = _mine ? 'You said' : 'They said';
    final what = widget.text ?? '';
    final state = switch (widget.status) {
      DSChatStatus.sending => ', sending',
      DSChatStatus.streaming => ', still arriving',
      DSChatStatus.failed => ', ${widget.failedLabel}',
      DSChatStatus.sent => '',
    };
    final when = widget.timeLabel == null ? '' : ', ${widget.timeLabel}';
    return '$who $what$state$when'.trim();
  }
}
