import 'package:parley_android/screens/design_system/demo_photo.dart';

/// The fixtures the Browse demo is drawn from.
///
/// A rail is a *reason*, not a genre: the title says why these items are in
/// front of this reader, which is the one part of a ranked row that an
/// algorithm did not choose. See `docs/principles/screen-archetypes.md`,
/// "Shelf".
///
/// Delete this file with `browse_page.dart` when the app ships a real browse
/// screen.
class BrowseItem {
  const BrowseItem({
    required this.title,
    required this.subtitle,
    required this.photo,
    required this.hue,
    required this.artLabel,
    this.minutes,
    this.progress,
    this.rank,
    this.live = false,
  });

  final String title;

  /// The line under the title — a series and an episode, a section and a date.
  final String subtitle;

  final String photo;

  /// Which of the palette's category hues the art falls back to while the
  /// photograph loads, so a rail is legible before a byte arrives.
  final int hue;

  /// What the picture is, for a reader who never sees it.
  final String artLabel;

  final int? minutes;

  /// How much of it has been watched, 0..1. Only the "Continue" rail has it,
  /// because a progress bar on something nobody started is a lie.
  final double? progress;

  /// The chart position, when the rail is a chart. Drawn on the art.
  final int? rank;

  final bool live;

  Duration? get duration =>
      minutes == null ? null : Duration(minutes: minutes!);
}

/// One horizontal rail: its reason, its items, and the route its "See all"
/// opens when it has more than the four the archetype lets a rail hold.
class BrowseRail {
  const BrowseRail({
    required this.title,
    required this.items,
    this.seeAllLabel,
  });

  final String title;
  final List<BrowseItem> items;

  /// Null when the rail is short enough to be read to its end by swiping.
  /// `feature_plan.dart` refuses a rail of more than four tiles that has no
  /// route out, and the screen honours the same rule.
  final String? seeAllLabel;
}

/// The featured item, which is the only thing on the screen the app is
/// allowed to shout about.
const featuredItem = BrowseItem(
  title: 'The desk, and everything on it',
  subtitle: 'A photo essay · 12 min',
  photo: DemoPhotos.flatLay,
  hue: 0,
  artLabel: 'A flat lay of desk objects',
  minutes: 12,
);

const demoBrowseRails = <BrowseRail>[
  BrowseRail(
    title: 'Continue watching',
    items: [
      BrowseItem(
        title: 'Release 4.2',
        subtitle: 'Changelog',
        photo: DemoPhotos.crossing,
        hue: 2,
        artLabel: 'A pedestrian crossing from above',
        minutes: 4,
        progress: 0.4,
      ),
      BrowseItem(
        title: 'Design tokens',
        subtitle: 'Foundations',
        photo: DemoPhotos.openBook,
        hue: 1,
        artLabel: 'An open book on a table',
        minutes: 9,
        progress: 0.7,
      ),
      BrowseItem(
        title: 'Taking it apart',
        subtitle: 'Season 2',
        photo: DemoPhotos.explodedView,
        hue: 4,
        artLabel: 'An exploded diagram of a device',
        minutes: 21,
        progress: 0.15,
      ),
    ],
  ),
  BrowseRail(
    title: 'Because you read about colour',
    seeAllLabel: 'See all',
    items: [
      BrowseItem(
        title: 'Colour',
        subtitle: 'Episode 1',
        photo: DemoPhotos.paletteWall,
        hue: 3,
        artLabel: 'A wall of paint swatches',
        minutes: 18,
        rank: 1,
      ),
      BrowseItem(
        title: 'Contrast',
        subtitle: 'Episode 2',
        photo: DemoPhotos.crossing,
        hue: 2,
        artLabel: 'A pedestrian crossing from above',
        minutes: 15,
        rank: 2,
      ),
      BrowseItem(
        title: 'Type',
        subtitle: 'Episode 3',
        photo: DemoPhotos.openBook,
        hue: 1,
        artLabel: 'An open book on a table',
        minutes: 11,
        rank: 3,
      ),
      BrowseItem(
        title: 'Motion',
        subtitle: 'Episode 4',
        photo: DemoPhotos.flatLay,
        hue: 0,
        artLabel: 'A flat lay of desk objects',
        minutes: 13,
        rank: 4,
      ),
      BrowseItem(
        title: 'Depth',
        subtitle: 'Episode 5',
        photo: DemoPhotos.explodedView,
        hue: 4,
        artLabel: 'An exploded diagram of a device',
        minutes: 16,
        rank: 5,
      ),
    ],
  ),
  BrowseRail(
    title: 'Live now',
    items: [
      BrowseItem(
        title: 'Office hours',
        subtitle: 'Design systems',
        photo: DemoPhotos.openBook,
        hue: 1,
        artLabel: 'An open book on a table',
        live: true,
      ),
      BrowseItem(
        title: 'Build along',
        subtitle: 'Flutter',
        photo: DemoPhotos.explodedView,
        hue: 4,
        artLabel: 'An exploded diagram of a device',
        live: true,
      ),
    ],
  ),
];
