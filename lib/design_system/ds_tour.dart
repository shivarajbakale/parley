// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_tour_dots.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One stop of a tour: a picture of the product, a claim, and the sentence
/// that backs the claim up.
///
/// [art] takes whether this stop is the one on screen, because a [PageView]
/// builds its pages before they are looked at — an illustration that played
/// its entrance on build would be finished by the time the slide arrived.
@immutable
class DSTourStop {
  const DSTourStop({
    required this.art,
    required this.headline,
    required this.body,
  });

  final Widget Function(bool active) art;
  final String headline;
  final String body;
}

/// How a tour moves.
@immutable
class DSTourStyle extends DSComponentStyle<DSTourStyle> {
  const DSTourStyle({
    this.artLag,
    this.wordLead,
    this.artRecede,
    this.wordFall,
    this.tintAlpha,
  });

  /// How far the illustration lags its page, in logical pixels at a full page
  /// of travel. Enough to read as depth, not enough to notice as a separate
  /// moving part.
  final double? artLag;

  /// The words lead by this fraction of [artLag] instead of lagging. Negative
  /// on purpose: the picture sits behind the page and the type in front of it,
  /// so the planes pull apart under the finger and close again on arrival.
  final double? wordLead;

  /// How far the picture falls back as its slide leaves, as a fraction of its
  /// size. Translation alone reads as a flat card pushed sideways; receding is
  /// what makes it read as going away.
  final double? artRecede;

  /// How far the words drop on their way out, in logical pixels.
  final double? wordFall;

  /// How much of the brand hue the background carries at the start of the
  /// sequence.
  final double? tintAlpha;

  @override
  DSTourStyle merge(DSTourStyle? other) {
    if (other == null) return this;
    return DSTourStyle(
      artLag: other.artLag ?? artLag,
      wordLead: other.wordLead ?? wordLead,
      artRecede: other.artRecede ?? artRecede,
      wordFall: other.wordFall ?? wordFall,
      tintAlpha: other.tintAlpha ?? tintAlpha,
    );
  }

  @override
  DSTourStyle copyWith({
    double? artLag,
    double? wordLead,
    double? artRecede,
    double? wordFall,
    double? tintAlpha,
  }) => DSTourStyle(
    artLag: artLag ?? this.artLag,
    wordLead: wordLead ?? this.wordLead,
    artRecede: artRecede ?? this.artRecede,
    wordFall: wordFall ?? this.wordFall,
    tintAlpha: tintAlpha ?? this.tintAlpha,
  );

  @override
  DSTourStyle lerp(DSTourStyle? other, double t) {
    if (other == null) return this;
    return DSTourStyle(
      artLag: lerpDouble(artLag, other.artLag, t),
      wordLead: lerpDouble(wordLead, other.wordLead, t),
      artRecede: lerpDouble(artRecede, other.artRecede, t),
      wordFall: lerpDouble(wordFall, other.wordFall, t),
      tintAlpha: lerpDouble(tintAlpha, other.tintAlpha, t),
    );
  }

  static DSTourStyle resolve(BuildContext context, {DSTourStyle? own}) =>
      resolveStyle(
        context: context,
        specDefaults: const DSTourStyle(
          artLag: 72,
          wordLead: -0.42,
          artRecede: 0.14,
          wordFall: 16,
          tintAlpha: 0.14,
        ),
        own: own,
      );
}

/// A first-run sequence: a handful of slides, ending in a commitment.
///
/// **Use when** a new user has to be told what the app does before they can
/// use it, and the telling is worth the taps — which is to say, when the last
/// slide hands over to something rather than merely getting out of the way.
///
/// **Instead:** an empty state on the screen itself, which introduces a
/// feature at the moment it is wanted rather than four screens early. A tour
/// whose slides only advertise is a run of taps that produces nothing.
///
/// Full-bleed on purpose: no header, no back button, because there is nowhere
/// behind it. Back within the sequence is a swipe.
///
/// [onSkip] is nullable. Passing null removes the control, which is only
/// honest when the last stop is a handover — a tour with no way out that ends
/// at "Get started" is the advert without the payoff.
class DSTour extends StatefulWidget {
  const DSTour({
    super.key,
    required this.stops,
    required this.onFinish,
    required this.finishLabel,
    this.onSkip,
    this.nextLabel = 'Next',
    this.skipLabel = 'Skip',
    this.finishCaption,
    this.header,
    this.initialStop = 0,
    this.style,
  });

  final List<DSTourStop> stops;

  /// What the last stop hands over to.
  final VoidCallback onFinish;

  final String finishLabel;

  /// Null removes the control entirely.
  final VoidCallback? onSkip;

  final String nextLabel;
  final String skipLabel;

  /// One line under the final button — what the user is agreeing to.
  final String? finishCaption;

  /// A brand mark, or anything else that belongs above the sequence.
  final Widget? header;

  /// Which stop to open on. Exists so each stop can be a graded surface: a
  /// paged flow the gates only ever see the first page of is a flow whose
  /// other pages are measured by nothing.
  final int initialStop;

  final DSTourStyle? style;

  @override
  State<DSTour> createState() => _DSTourState();
}

class _DSTourState extends State<DSTour> {
  late final PageController _controller = PageController(
    initialPage: widget.initialStop,
  );

  /// The settled page — what the button and the caption answer to. The
  /// fractional position during a drag is read off the controller instead, so
  /// the button label never flickers mid-swipe.
  late int _index = widget.initialStop;

  /// The page the finger is closest to, which is not the page it will land on
  /// until it lets go. Kept so the detent tick fires once per crossing rather
  /// than once per frame.
  late int _detent = widget.initialStop;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// The tick under the finger.
  ///
  /// Firing on `onPageChanged` instead would put the feedback at the end of
  /// the settle animation, a few hundred milliseconds after the gesture that
  /// earned it — late enough to read as a separate event. Here it lands at the
  /// moment the next slide takes over, which is the moment the eye sees it.
  void _onScroll() {
    final int detent = _position.round().clamp(0, widget.stops.length - 1);
    if (detent == _detent) return;
    _detent = detent;
    AppHaptics.selection();
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  /// Fractional scroll position, safe to read before the first layout.
  double get _position {
    if (!_controller.hasClients || !_controller.position.haveDimensions) {
      return _index.toDouble();
    }
    return _controller.page ?? _index.toDouble();
  }

  void _advance(MotionSpec motion) {
    if (_index == widget.stops.length - 1) {
      widget.onFinish();
      return;
    }
    _controller.nextPage(
      duration: motion.scaled(motion.slow),
      curve: motion.enter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Palette palette = context.palette;
    final space = context.design.space;
    final MotionSpec motion = context.design.motion;
    final DSTourStyle resolved = DSTourStyle.resolve(
      context,
      own: widget.style,
    );
    final bool atLastStop = _index == widget.stops.length - 1;
    final VoidCallback? onSkip = widget.onSkip;

    return Scaffold(
      body: AnimatedBuilder(
        // The tint travels with the sequence, so the stops read as one room
        // being walked through rather than three screens shown in turn.
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double progress = widget.stops.length > 1
              ? (_position / (widget.stops.length - 1)).clamp(0.0, 1.0)
              : 1.0;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + progress * 2, -1),
                end: Alignment(1 - progress * 2, 1),
                colors: <Color>[
                  Color.alphaBlend(
                    palette.primary.withValues(alpha: resolved.tintAlpha),
                    palette.background,
                  ),
                  palette.background,
                  palette.background,
                ],
                stops: const <double>[0, 0.55, 1],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: <Widget>[
              if (widget.header != null || onSkip != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    space.pageGutter,
                    space.lg,
                    space.pageGutter,
                    0,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (widget.header != null) widget.header!,
                      const Spacer(),
                      if (onSkip != null)
                        DSButton(
                          variant: DSButtonVariant.ghost,
                          label: widget.skipLabel,
                          onPressed: onSkip,
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? _) {
                    final double position = _position;

                    return PageView.builder(
                      controller: _controller,
                      // Bouncing under the page physics on both platforms: a
                      // sequence has a first stop and a last one, and a pull
                      // that gives a little and comes back says so without a
                      // dialog or a disabled-looking edge.
                      physics: _DSTourPhysics(
                        settle: motion.tuned(motion.pageSettle),
                        parent: const BouncingScrollPhysics(),
                      ),
                      onPageChanged: _onPageChanged,
                      itemCount: widget.stops.length,
                      itemBuilder: (BuildContext context, int index) {
                        final DSTourStop stop = widget.stops[index];
                        return DSTourSlide(
                          art: stop.art(index == _index),
                          headline: stop.headline,
                          body: stop.body,
                          offset: position - index,
                          style: widget.style,
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(space.pageGutter),
                child: Column(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? _) => DSTourDots(
                        count: widget.stops.length,
                        position: _position,
                      ),
                    ),
                    SizedBox(height: space.lg),
                    DSButton(
                      // The label changes exactly once: a run of Nexts, then
                      // the commitment.
                      label: atLastStop ? widget.finishLabel : widget.nextLabel,
                      icon: Icons.arrow_forward,
                      fullWidth: true,
                      onPressed: () => _advance(motion),
                    ),
                    // A fixed slot, so the button does not move when the line
                    // under it appears on the last stop.
                    SizedBox(
                      height: space.xl,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: motion.scaled(motion.fast),
                          opacity: atLastStop && widget.finishCaption != null
                              ? 1
                              : 0,
                          child: Text(
                            widget.finishCaption ?? '',
                            style: DSTextRole.bodyDetail.styleOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a tour settles after a swipe.
///
/// [PageView] wraps whatever it is given in a [PageScrollPhysics], which takes
/// its spring from its parent. That is this.
class _DSTourPhysics extends ScrollPhysics {
  const _DSTourPhysics({required this.settle, super.parent});

  final SpringDescription settle;

  @override
  _DSTourPhysics applyTo(ScrollPhysics? ancestor) =>
      _DSTourPhysics(settle: settle, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => settle;
}

/// One stop of a [DSTour]: a picture, a claim, and the sentence behind it.
///
/// **Use when** composing a tour by hand — a sequence that is not a
/// [PageView], or one stop shown on its own in a gallery.
///
/// **Instead:** [DSTour], which builds these for you from a list of
/// [DSTourStop]s and drives the offset. Reach for the slide directly only when
/// you own the paging.
///
/// The illustration is drawn at its own composed size and scaled into whatever
/// room the words leave over, so the type — which is real content and does
/// honour the platform text scale — always gets the space it asks for first.
/// On a small phone at a large text size the picture shrinks; nothing
/// overflows and no line is cut.
///
/// The art is hidden from screen readers. It says what the headline and body
/// already say, and read aloud it is a list of sample figures.
class DSTourSlide extends StatelessWidget {
  const DSTourSlide({
    super.key,
    required this.art,
    required this.headline,
    required this.body,
    required this.offset,
    this.style,
  });

  final Widget art;
  final String headline;
  final String body;

  /// Where this slide sits relative to the one on screen: 0 when it is the
  /// current page, ±1 when it is a full page away. Drives the parallax.
  final double offset;

  final DSTourStyle? style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Palette palette = context.palette;
    final space = context.design.space;
    final MotionSpec motion = context.design.motion;
    final DSTourStyle resolved = DSTourStyle.resolve(context, own: style);
    final bool reduced = MediaQuery.disableAnimationsOf(context);

    // How far gone this slide is, eased. A linear fade spends its first frames
    // doing nothing the eye can see and then dumps the rest at the end.
    final double travel = offset.abs().clamp(0.0, 1.0);
    final double away = reduced ? 0.0 : motion.enter.transform(travel);

    // The two planes do not leave together. Type is the foreground and goes
    // first, so the picture is still there behind it when the next slide's
    // words arrive — which is what keeps a swipe reading as one room being
    // walked through rather than three screens shown in turn.
    final double artPresence = 1 - away * 0.72;
    final double wordPresence = (1 - away * 1.35).clamp(0.0, 1.0);
    final double lag = reduced ? 0.0 : offset * resolved.artLag!;

    final Widget artwork = Transform.translate(
      offset: Offset(lag, 0),
      child: Transform.scale(
        scale: 1 - away * resolved.artRecede!,
        child: Opacity(
          opacity: artPresence,
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.contain,
              // A picture of type, not type: the illustration keeps its
              // proportions at every text scale, and the slide scales the
              // whole board instead.
              child: MediaQuery.withNoTextScaling(child: art),
            ),
          ),
        ),
      ),
    );

    final Widget words = Opacity(
      opacity: wordPresence,
      child: Transform.translate(
        offset: Offset(lag * resolved.wordLead!, away * resolved.wordFall!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              headline,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: context.design.type.emphasisWeight,
              ),
            ),
            SizedBox(height: space.sm),
            Text(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Fill the slide, or scroll. The words take the height they need and
        // sit at the same place on every stop — a headline that moved between
        // them would read as three different screens — and the picture takes
        // everything left over. When a large accessibility text size leaves
        // nothing over, the slide scrolls instead of clipping a line.
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: space.pageGutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Expanded gives the picture a tight box, which is what
                  // makes the FittedBox inside it scale: left loose, it would
                  // draw at its composed width and float in the space. The
                  // width is stretched separately rather than with
                  // `SizedBox.expand`, whose intrinsic height is infinite —
                  // inside the `IntrinsicHeight` below, that made every slide
                  // taller than any screen and so made every tour scroll
                  // vertically inside its own horizontal pager, which is the
                  // two-axis page `ui-probe`'s `dual-axis` rule exists to
                  // catch.
                  Expanded(
                    child: SizedBox(width: double.infinity, child: artwork),
                  ),
                  SizedBox(height: space.xl),
                  words,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
