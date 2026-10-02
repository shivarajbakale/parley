// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_image.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Where a picture comes from, and what it is called out loud.
///
/// One parameter in place of the nine constructors three shapes would
/// otherwise need. `semanticLabel: ''` is the explicit decorative case — a
/// decision rather than an omission — and [DSMediaSource.none] is how an item
/// says it has no picture at all, which the old nullable-image-plus-nullable-
/// label pair could only say inconsistently.
sealed class DSMediaSource {
  const DSMediaSource();

  /// Fetched. Drawn through `DSMediaSurfaceStyle.imageBuilder` when one is
  /// installed, so a CDN resizer or a signed-URL loader is one theme edit.
  const factory DSMediaSource.network(
    String url, {
    required String semanticLabel,
    Color? dominantColor,
  }) = _DSMediaNetwork;

  const factory DSMediaSource.asset(
    String path, {
    required String semanticLabel,
    Color? dominantColor,
  }) = _DSMediaAsset;

  /// The escape hatch, and the important one: a video thumbnail, a stacked
  /// pair, a blurhash, or a caller's own cache package.
  const factory DSMediaSource.widget(
    Widget child, {
    required String semanticLabel,
  }) = _DSMediaWidget;

  const factory DSMediaSource.none() = _DSMediaNone;

  /// What a screen reader says for the picture. Empty means decorative.
  String get semanticLabel;

  /// Painted while the bytes arrive. The difference between a grid that
  /// settles and one that flashes grey.
  Color? get dominantColor;

  /// True only for [DSMediaSource.none] — the item has no picture, so the
  /// shape draws no box rather than an empty one.
  bool get isEmpty;
}

class _DSMediaNetwork extends DSMediaSource {
  const _DSMediaNetwork(
    this.url, {
    required this.semanticLabel,
    this.dominantColor,
  });
  final String url;
  @override
  final String semanticLabel;
  @override
  final Color? dominantColor;
  @override
  bool get isEmpty => false;
}

class _DSMediaAsset extends DSMediaSource {
  const _DSMediaAsset(
    this.path, {
    required this.semanticLabel,
    this.dominantColor,
  });
  final String path;
  @override
  final String semanticLabel;
  @override
  final Color? dominantColor;
  @override
  bool get isEmpty => false;
}

class _DSMediaWidget extends DSMediaSource {
  const _DSMediaWidget(this.child, {required this.semanticLabel});
  final Widget child;
  @override
  final String semanticLabel;
  @override
  Color? get dominantColor => null;
  @override
  bool get isEmpty => false;
}

class _DSMediaNone extends DSMediaSource {
  const _DSMediaNone();
  @override
  String get semanticLabel => '';
  @override
  Color? get dominantColor => null;
  @override
  bool get isEmpty => true;
}

/// The shape of a picture box.
///
/// A class rather than an enum so an app can pass a ratio the kit did not
/// name — a 4:3 archive, a 21:9 trailer — without forking the component.
@immutable
class DSMediaAspect {
  const DSMediaAspect(this.ratio);

  static const DSMediaAspect square = DSMediaAspect(1);
  static const DSMediaAspect portrait = DSMediaAspect(2 / 3);
  static const DSMediaAspect wide = DSMediaAspect(16 / 9);

  /// Width over height.
  final double ratio;

  @override
  bool operator ==(Object other) =>
      other is DSMediaAspect && other.ratio == ratio;

  @override
  int get hashCode => ratio.hashCode;
}

/// Whether an item is playing, and whether it is paused where it stopped.
enum DSMediaPlayback { none, playing, paused }

/// How much of an item is on the device.
enum DSMediaOffline { none, queued, downloading, downloaded }

/// The seven facts every media app is built from, typed once.
///
/// A value class rather than seven parameters spread across three widgets: the
/// same status renders in a row, a tile and a hero without being restated, and
/// every field costs nothing when unset.
///
/// The booleans are named without an `is` prefix because `ui_lint`'s
/// `bool-is-prefix` rule fails a `final bool isX` field.
@immutable
class DSMediaStatus {
  const DSMediaStatus({
    this.duration,
    this.progress,
    this.unread = false,
    this.playback = DSMediaPlayback.none,
    this.offline = DSMediaOffline.none,
    this.live = false,
    this.rank,
  }) : assert(
         progress == null || (progress >= 0 && progress <= 1),
         'progress is a fraction of the whole item, 0..1.',
       );

  /// The item's whole length — the pill, not the part already watched.
  final Duration? duration;

  /// How far in, 0..1. Drawn on the picture's bottom edge, because moved to
  /// the text column it stops reading as "how far into this".
  final double? progress;

  final bool unread;
  final DSMediaPlayback playback;
  final DSMediaOffline offline;
  final bool live;

  /// A chart position. Leading in a row, a stamp on a tile.
  final int? rank;

  /// True when there is nothing to draw, so a shape can skip the whole
  /// overlay rather than build an empty stack per item in a long list.
  bool get isEmpty =>
      duration == null &&
      progress == null &&
      !unread &&
      playback == DSMediaPlayback.none &&
      offline == DSMediaOffline.none &&
      !live &&
      rank == null;

  /// The duration as it is printed on the pill: `12:04`, `1:02:03`.
  String? get durationLabel {
    final Duration? value = duration;
    if (value == null) return null;
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    final String mm = hours > 0
        ? minutes.toString().padLeft(2, '0')
        : minutes.toString();
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// The status, as phrases, in the one order the family speaks them.
  ///
  /// Fixed order rather than the order the fields were set: a reader who hears
  /// three items in a row has to be able to hear the same fact in the same
  /// place each time.
  List<String> semanticPhrases() {
    final List<String> out = <String>[];
    if (duration != null) out.add(_spokenDuration(duration!));
    switch (playback) {
      case DSMediaPlayback.playing:
        out.add('Playing');
      case DSMediaPlayback.paused:
        out.add('Paused');
      case DSMediaPlayback.none:
        break;
    }
    if (progress != null) {
      out.add('${(progress! * 100).round()} percent played');
    }
    switch (offline) {
      case DSMediaOffline.queued:
        out.add('Queued for download');
      case DSMediaOffline.downloading:
        out.add('Downloading');
      case DSMediaOffline.downloaded:
        out.add('Downloaded');
      case DSMediaOffline.none:
        break;
    }
    if (live) out.add('Live');
    if (unread) out.add('Unread');
    return out;
  }

  /// Words, not a clock face. `12:04` is read out as "twelve oh four" by some
  /// engines and as "twelve colon zero four" by others.
  static String _spokenDuration(Duration value) {
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    final List<String> parts = <String>[];
    if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
    if (minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
    if (seconds > 0) parts.add('$seconds second${seconds == 1 ? '' : 's'}');
    return parts.isEmpty ? '0 seconds' : parts.join(' ');
  }
}

/// How a media box and its status look, at every layer of the chain.
///
/// The whole point of the family having one surface: an app that wants its
/// duration pill somewhere else, or its progress bar thicker, sets it here and
/// the row, the tile and the hero all follow.
@immutable
class DSMediaSurfaceStyle extends DSComponentStyle<DSMediaSurfaceStyle> {
  const DSMediaSurfaceStyle({
    this.radius,
    this.fit,
    this.groundColor,
    this.scrimColor,
    this.badgeColor,
    this.badgeTextStyle,
    this.badgePadding,
    this.progressThickness,
    this.progressTrackColor,
    this.progressColor,
    this.selectionColor,
    this.rankTextStyle,
    this.imageBuilder,
  });

  final BorderRadius? radius;
  final BoxFit? fit;

  /// What the box is before the bytes arrive, when the source named no
  /// dominant colour of its own.
  final Color? groundColor;

  /// Under a badge, under a selection tick, under a hero's overlaid text.
  final Color? scrimColor;

  final Color? badgeColor;
  final TextStyle? badgeTextStyle;
  final EdgeInsetsGeometry? badgePadding;

  final double? progressThickness;
  final Color? progressTrackColor;
  final Color? progressColor;

  final Color? selectionColor;
  final TextStyle? rankTextStyle;

  /// How a URL becomes a widget — the one dependency this family would
  /// otherwise take, inverted. Set it once on a `ThemeData` extension and
  /// every network source in the app goes through `cached_network_image`, a
  /// CDN resizer or a signed-URL loader, with no call site edited.
  final Widget Function(BuildContext context, String url)? imageBuilder;

  @override
  DSMediaSurfaceStyle merge(DSMediaSurfaceStyle? other) {
    if (other == null) return this;
    return DSMediaSurfaceStyle(
      radius: other.radius ?? radius,
      fit: other.fit ?? fit,
      groundColor: other.groundColor ?? groundColor,
      scrimColor: other.scrimColor ?? scrimColor,
      badgeColor: other.badgeColor ?? badgeColor,
      badgeTextStyle: other.badgeTextStyle ?? badgeTextStyle,
      badgePadding: other.badgePadding ?? badgePadding,
      progressThickness: other.progressThickness ?? progressThickness,
      progressTrackColor: other.progressTrackColor ?? progressTrackColor,
      progressColor: other.progressColor ?? progressColor,
      selectionColor: other.selectionColor ?? selectionColor,
      rankTextStyle: other.rankTextStyle ?? rankTextStyle,
      imageBuilder: other.imageBuilder ?? imageBuilder,
    );
  }

  @override
  DSMediaSurfaceStyle copyWith({
    BorderRadius? radius,
    BoxFit? fit,
    Color? groundColor,
    Color? scrimColor,
    Color? badgeColor,
    TextStyle? badgeTextStyle,
    EdgeInsetsGeometry? badgePadding,
    double? progressThickness,
    Color? progressTrackColor,
    Color? progressColor,
    Color? selectionColor,
    TextStyle? rankTextStyle,
    Widget Function(BuildContext, String)? imageBuilder,
  }) => DSMediaSurfaceStyle(
    radius: radius ?? this.radius,
    fit: fit ?? this.fit,
    groundColor: groundColor ?? this.groundColor,
    scrimColor: scrimColor ?? this.scrimColor,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextStyle: badgeTextStyle ?? this.badgeTextStyle,
    badgePadding: badgePadding ?? this.badgePadding,
    progressThickness: progressThickness ?? this.progressThickness,
    progressTrackColor: progressTrackColor ?? this.progressTrackColor,
    progressColor: progressColor ?? this.progressColor,
    selectionColor: selectionColor ?? this.selectionColor,
    rankTextStyle: rankTextStyle ?? this.rankTextStyle,
    imageBuilder: imageBuilder ?? this.imageBuilder,
  );

  @override
  DSMediaSurfaceStyle lerp(DSMediaSurfaceStyle? other, double t) {
    if (other == null) return this;
    return DSMediaSurfaceStyle(
      radius: BorderRadius.lerp(radius, other.radius, t),
      // A fit is a rule, not a place on a ladder: half of `cover` is nothing.
      fit: t < 0.5 ? fit : other.fit,
      groundColor: Color.lerp(groundColor, other.groundColor, t),
      scrimColor: Color.lerp(scrimColor, other.scrimColor, t),
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t),
      badgeTextStyle: TextStyle.lerp(badgeTextStyle, other.badgeTextStyle, t),
      badgePadding: EdgeInsetsGeometry.lerp(
        badgePadding,
        other.badgePadding,
        t,
      ),
      progressThickness: lerpDouble(
        progressThickness,
        other.progressThickness,
        t,
      ),
      progressTrackColor: Color.lerp(
        progressTrackColor,
        other.progressTrackColor,
        t,
      ),
      progressColor: Color.lerp(progressColor, other.progressColor, t),
      selectionColor: Color.lerp(selectionColor, other.selectionColor, t),
      rankTextStyle: TextStyle.lerp(rankTextStyle, other.rankTextStyle, t),
      imageBuilder: t < 0.5 ? imageBuilder : other.imageBuilder,
    );
  }

  static DSMediaSurfaceStyle resolve(
    BuildContext context, [
    DSMediaSurfaceStyle? own,
  ]) {
    final Palette palette = context.palette;
    final SpaceSpec space = context.design.space;
    final TextTheme text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSMediaSurfaceStyle(
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.tile)),
        ),
        fit: BoxFit.cover,
        groundColor: palette.muted,
        scrimColor: palette.overlay,
        badgeColor: palette.overlay,
        badgeTextStyle: text.labelSmall?.copyWith(color: palette.sheen),
        badgePadding: EdgeInsets.symmetric(
          horizontal: space.xs,
          vertical: space.hairline,
        ),
        // A hairline, because the bar sits inside the picture and a heavier
        // one starts reading as a crop rather than as progress.
        progressThickness: space.hairline,
        progressTrackColor: palette.muted,
        progressColor: palette.primary,
        selectionColor: palette.primary,
        rankTextStyle: text.titleMedium?.copyWith(
          color: palette.sheen,
          fontWeight: context.design.type.emphasisWeight,
        ),
      ),
      own: own,
    );
  }
}

/// One picture box, with the family's status vocabulary drawn on it.
///
/// **Use when** you are building a media shape the kit does not ship — a
/// fourth layout beside [DSMediaRow], [DSMediaTile] and [DSMediaHero] — and
/// want its picture to carry duration, progress, playback, live, offline,
/// selection and rank exactly as theirs do. **Instead:** one of those three
/// first; they are this box plus a text budget, and a fourth shape composed in
/// `lib/screens/` is what `ui_lint` fails. `DSImage` when the picture carries
/// no status at all.
///
/// This is the reason the three shapes cannot drift: the duration pill lives
/// here once, so moving it moves it everywhere. The box is laid out at its
/// final size before a byte is fetched, so a list never reflows as pictures
/// arrive — the single largest contributor to whether a scrolling list feels
/// stable.
/// The unread mark the media family draws beside a title.
///
/// A function rather than a component: it is six points of paint that only
/// [DSMediaStatus.unread] ever asks for, and the three shapes must draw it
/// identically or the vocabulary is not one vocabulary.
Widget dsMediaUnreadDot(BuildContext context, {bool enabled = true}) {
  final palette = context.palette;
  final size = context.design.space.sm;
  return Padding(
    padding: EdgeInsetsDirectional.only(top: context.design.space.xs),
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? palette.primary : palette.mutedForeground,
        ),
      ),
    ),
  );
}

class DSMediaSurface extends StatelessWidget {
  const DSMediaSurface({
    super.key,
    required this.source,
    required this.aspect,
    this.width,
    this.height,
    this.status = const DSMediaStatus(),
    this.showRank = false,
    this.selected = false,
    this.enabled = true,
    this.overlay,
    this.style,
  });

  /// Keys the tests and the probe find the parts by. A `find.byType` on a
  /// private widget is not available outside this library, and grading the
  /// overlay by pixel colour is how a gate starts failing on a palette change.
  static const Key progressKey = Key('ds-media-progress');
  static const Key equalizerKey = Key('ds-media-equalizer');
  static const Key selectionKey = Key('ds-media-selection');

  final DSMediaSource source;
  final DSMediaAspect aspect;

  /// See the sizing contract: a height sizes the width, a width sizes the
  /// height, and neither fills the column at [aspect].
  final double? width;
  final double? height;

  final DSMediaStatus status;

  /// A row draws the rank beside the box; a tile stamps it on the picture.
  /// The surface does not guess which.
  final bool showRank;

  final bool selected;
  final bool enabled;

  /// Drawn above the status — the unanticipated-content hatch, kept from the
  /// component this family replaces.
  final Widget? overlay;

  final DSMediaSurfaceStyle? style;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return const SizedBox.shrink();

    final DSMediaSurfaceStyle resolved = DSMediaSurfaceStyle.resolve(
      context,
      style,
    );
    final SpaceSpec space = context.design.space;

    Widget picture = switch (source) {
      _DSMediaWidget(:final Widget child) => child,
      _DSMediaNetwork(:final String url) =>
        resolved.imageBuilder?.call(context, url) ??
            DSImage.network(
              url,
              fit: resolved.fit ?? BoxFit.cover,
              decorative: true,
              style: const DSImageStyle(radius: BorderRadius.zero),
            ),
      _DSMediaAsset(:final String path) => Image.asset(
        path,
        fit: resolved.fit ?? BoxFit.cover,
        errorBuilder: (BuildContext context, _, _) => _failed(context),
      ),
      _DSMediaNone() => const SizedBox.shrink(),
    };

    // Opacity only. The box never changes size, so there is nothing else to
    // animate — no scale, no blur-up.
    if (!enabled) picture = Opacity(opacity: 0.38, child: picture);

    Widget box = ClipRRect(
      borderRadius: resolved.radius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: source.dominantColor ?? resolved.groundColor,
            ),
          ),
          picture,
          ..._statusLayers(context, resolved, space),
          if (overlay != null) overlay!,
        ],
      ),
    );

    if (height != null) {
      box = SizedBox(width: height! * aspect.ratio, height: height, child: box);
    } else if (width != null) {
      box = SizedBox(width: width, height: width! / aspect.ratio, child: box);
    } else {
      box = AspectRatio(aspectRatio: aspect.ratio, child: box);
    }

    // '' is the decorative case: the caller decided, and said so. The label
    // survives here rather than being discarded by an ancestor
    // `ExcludeSemantics`, which is the defect this family was built to close.
    return source.semanticLabel.isEmpty
        ? ExcludeSemantics(child: box)
        : Semantics(image: true, label: source.semanticLabel, child: box);
  }

  List<Widget> _statusLayers(
    BuildContext context,
    DSMediaSurfaceStyle resolved,
    SpaceSpec space,
  ) {
    if (status.isEmpty && !selected) return const <Widget>[];
    final List<Widget> layers = <Widget>[];
    final bool playing = status.playback == DSMediaPlayback.playing;

    if (playing || selected) {
      layers.add(
        DecoratedBox(
          decoration: BoxDecoration(
            color: (resolved.scrimColor ?? context.palette.overlay).withValues(
              alpha: 0.32,
            ),
          ),
        ),
      );
    }

    final bool showLive = status.live;
    final bool showStampedRank = showRank && status.rank != null;
    if (showLive || showStampedRank) {
      layers.add(
        Align(
          alignment: AlignmentDirectional.topStart,
          child: Padding(
            padding: EdgeInsets.all(space.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showLive)
                  _Badge(
                    label: 'LIVE',
                    color: context.palette.destructive,
                    style: resolved,
                  ),
                if (showLive && showStampedRank) SizedBox(height: space.xs),
                if (showStampedRank)
                  Text('${status.rank}', style: resolved.rankTextStyle),
              ],
            ),
          ),
        ),
      );
    }

    if (playing) {
      layers.add(
        Center(
          child: _Equalizer(key: equalizerKey, color: resolved.progressColor),
        ),
      );
    } else if (status.durationLabel != null) {
      // Bottom-right and lifted clear of the progress bar, because a
      // partly-watched item shows both at once and they must not collide.
      layers.add(
        Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: space.xs,
              start: space.xs,
              bottom: space.xs + (resolved.progressThickness ?? 0),
            ),
            child: _Badge(
              label: status.durationLabel!,
              color: resolved.badgeColor,
              style: resolved,
            ),
          ),
        ),
      );
    }

    if (status.offline == DSMediaOffline.downloaded) {
      layers.add(
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: EdgeInsets.all(space.xs),
            child: Icon(
              Icons.download_done_rounded,
              size: context.design.component.iconSizeSmall,
              color: context.palette.sheen,
            ),
          ),
        ),
      );
    }

    if (selected) {
      layers.add(
        Center(
          child: Icon(
            Icons.check_circle_rounded,
            key: selectionKey,
            color: resolved.selectionColor,
            size: context.design.component.iconSize,
          ),
        ),
      );
    }

    if (status.progress != null) {
      layers.add(
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: progressKey,
            height: resolved.progressThickness,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(color: resolved.progressTrackColor),
                ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: status.progress,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: resolved.progressColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return layers;
  }

  Widget _failed(BuildContext context) => Center(
    child: Icon(
      Icons.broken_image_outlined,
      color: context.palette.mutedForeground,
      size: context.design.component.iconSize,
    ),
  );
}

/// A pill on a scrim — the duration, and the live flag.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.style});

  final String label;
  final Color? color;
  final DSMediaSurfaceStyle style;

  /// The ceiling the pill's own text is drawn at.
  ///
  /// The picture box is a fixed size the caller chose, and a pill that keeps
  /// scaling past this is a pill drawn outside it — at 2.0x "4:12" was cut to
  /// "4:1" inside a 64-point thumbnail. Capping is safe here and only here:
  /// every word the pill carries is also in the sentence the item speaks, so
  /// a reader who needs the larger type is not reading this glyph.
  static const _labelScaleCeiling = 1.3;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: _labelScaleCeiling);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (color ?? context.palette.overlay).withValues(alpha: 0.72),
        borderRadius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
      ),
      child: Padding(
        padding: style.badgePadding ?? EdgeInsets.zero,
        // Excluded because the sentence the item speaks already carries the
        // duration in words; a reader should not hear "12:04" twice.
        child: ExcludeSemantics(
          child: Text(
            label,
            style: style.badgeTextStyle,
            textScaler: scaler,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// Three bars that move while something plays.
///
/// It reads the reduce-motion flag rather than merely honouring it as taste:
/// a looping controller under `disableAnimations` makes `pumpAndSettle` time
/// out in every widget test that mounts a playing item, which is a hang rather
/// than a failure and is far worse to diagnose.
class _Equalizer extends StatefulWidget {
  const _Equalizer({super.key, this.color});

  final Color? color;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    _controller ??= AnimationController(
      vsync: this,
      duration: context.design.motion.slow,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SpaceSpec space = context.design.space;
    final Color color = widget.color ?? context.palette.primary;
    const List<double> phases = <double>[0.2, 0.7, 0.45];

    Widget bars(double t) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final double phase in phases) ...<Widget>[
          SizedBox(
            width: space.hairline,
            height: space.md * (0.4 + 0.6 * ((t + phase) % 1)),
            child: DecoratedBox(decoration: BoxDecoration(color: color)),
          ),
          SizedBox(width: space.hairline),
        ],
      ],
    );

    final AnimationController? controller = _controller;
    if (controller == null) return bars(0.5);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) => bars(controller.value),
    );
  }
}
