import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/browse_data.dart';
import 'package:parley_android/screens/design_system/demo_photo.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The browse screen — the **Shelf** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// One hero, then named horizontal rails. A Shelf is not a Collection: a
/// Collection is one list the reader *filters*, a Shelf is many rails the app
/// *ranked*, and the ranking is the product. Everything below follows from
/// that.
///
/// What to imitate when you replace it:
///
///   * **every rail names why it is here** — "Continue watching", "Because you
///     read about colour", "Live now". The title is the only part of a ranked
///     row the algorithm did not choose, and a rail whose title is a genre
///     nobody picked is a rail nobody asked for;
///   * **a rail past four tiles owes a "See all"**. The end of a rail is three
///     or four swipes away or it is not reached at all, and the route out is
///     what makes the fifth item reachable. `feature_plan.dart` refuses a plan
///     that breaks this, and [BrowseRail.seeAllLabel] is the same rule in
///     code;
///   * **the next tile peeks.** The rail's padding is the page gutter and its
///     scroll runs past it, so the tile at the edge is cut rather than fitted.
///     A rail whose last visible tile ends flush with the screen reads as a
///     row that stops there — partial visibility is the signifier, and dots
///     are a weak one;
///   * **the title is text under the tile.** Artwork is a guess about the
///     reader, not a name, so `DSMediaTile` draws the title itself and
///     `DSMediaSource` carries the picture's own text alternative;
///   * **one hero, and it does not rotate.** An auto-advancing hero moves the
///     thing the reader was about to tap.
///
/// The rail is a `Row` inside a horizontal scroller rather than a `ListView`,
/// which trades laziness for an *intrinsic* height: a `ListView` needs its
/// cross-axis extent up front, and every formula for "how tall is a tile"
/// is wrong at some text scale — the first one tried here was six points
/// short at 1.0x and clipped the subtitle. A rail is five items in this demo;
/// a rail of forty is a Collection route behind its "See all", which is the
/// archetype's own rule.
///
/// Delete this file and `browse_data.dart` with the rest of the design-system
/// demo surface when the app ships a real browse screen.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const DSLargeAppBar(
            title: 'Browse',
            subtitle: 'One featured item, then the rails that say why.',
          ),
          // The hero applies the page gutter itself — it is a member of the
          // media family, and the family's rule is that exactly one widget
          // owns the gutter. Wrapping this in a `SliverPadding` would pay it
          // twice.
          SliverToBoxAdapter(
            child: DSMediaHero(
              source: DSMediaSource.widget(
                const DemoPhoto(
                  asset: DemoPhotos.flatLay,
                  fallbackHue: 0,
                  fallbackLabel: 'Featured',
                ),
                semanticLabel: featuredItem.artLabel,
              ),
              eyebrow: 'Featured',
              title: featuredItem.title,
              subtitle: featuredItem.subtitle,
              status: DSMediaStatus(duration: featuredItem.duration),
              onTap: () {
                AppHaptics.selection();
                context.push(AppRoutes.blog);
              },
            ),
          ),
          for (final rail in demoBrowseRails)
            SliverToBoxAdapter(child: _Rail(rail: rail)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: space.xl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// One rail: its reason, its route out, and the tiles.
class _Rail extends StatelessWidget {
  const _Rail({required this.rail});

  final BrowseRail rail;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final tileWidth = space.xxxl * 3;
    // Above this the shelf stops being a shelf.
    //
    // A rail is a row of peers, and peers line up: the eye reads across the
    // subtitles. That only holds while every title takes the same number of
    // lines. `DSMediaTile` deliberately drops its two-line cap above 1.6 —
    // "a name that no longer fits two lines is a name the reader still needs
    // to read" — so past that point one title wraps, its neighbours do not,
    // and the subtitles come apart. The probe measured them 37pt (one line)
    // out of line under `baseline`.
    //
    // Capping the title again would answer the alignment by overturning the
    // accessibility decision, at exactly the size where it matters. Turning
    // the row into a column answers it without an argument: a column has no
    // cross-tile line to keep, a tile at full width has room for the name,
    // and a horizontal scroller at doubled type was already the wrong shape
    // — three tiles peeking at 320pt is not a shelf, it is a puzzle.
    // `ds_segmented_progress` makes the same move at 1.3.
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.6;

    return Padding(
      padding: EdgeInsetsDirectional.only(top: space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No gutter padding here: `DSSectionHeader` pays the page gutter
          // itself, and wrapping it paid it twice — the rail's title sat one
          // gutter inside the hero and the tiles it belongs to.
          DSSectionHeader(
            label: rail.title,
            actionLabel: rail.seeAllLabel,
            onAction: rail.seeAllLabel == null
                ? null
                : () {
                    AppHaptics.selection();
                    context.push(AppRoutes.blog);
                  },
          ),
          SizedBox(height: space.sm),
          if (stacked)
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: DSGutter.of(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in rail.items)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        bottom: item == rail.items.last ? 0 : space.md,
                      ),
                      child: _tile(context, item, width: null),
                    ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // The gutter is the rail's padding rather than its parent's, so
              // the scroll itself runs edge to edge and the tile at the right
              // edge is cut. That cut is the peek.
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: DSGutter.of(context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in rail.items)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: item == rail.items.last ? 0 : space.md,
                      ),
                      child: _tile(context, item, width: tileWidth),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// One tile, built the same way in both shapes.
  ///
  /// Extracted so the row and the column cannot drift: the only thing that
  /// differs between them is the width, which is a fixed tile in a shelf and
  /// whatever the gutter leaves in a list.
  Widget _tile(BuildContext context, BrowseItem item, {double? width}) =>
      DSMediaTile(
        width: width,
        aspect: DSMediaAspect.portrait,
        source: DSMediaSource.widget(
          DemoPhoto(
            asset: item.photo,
            fallbackHue: item.hue,
            fallbackLabel: item.title,
          ),
          semanticLabel: item.artLabel,
        ),
        title: item.title,
        subtitle: item.subtitle,
        status: DSMediaStatus(
          duration: item.duration,
          progress: item.progress,
          rank: item.rank,
          live: item.live,
        ),
        onTap: () {
          AppHaptics.selection();
          context.push(AppRoutes.blog);
        },
      );
}
