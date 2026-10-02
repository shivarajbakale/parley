import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_icon_button.dart';
import 'package:parley_android/design_system/ds_well.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_menu.dart';
import 'package:parley_android/design_system/ds_metric_bar.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Detail view for a single [LibraryItem] — the **Detail** archetype
/// (`docs/principles/screen-archetypes.md`). Reached from the Library list via
/// a shared-axis forward transition (see `app_router.dart`).
///
/// Three things make it that archetype rather than a page with a title:
///
///   * the large title is the subject's name and collapses into the bar as it
///     scrolls, which is where the platform difference is most visible;
///   * the content is in titled sections, not one wall of text;
///   * the primary action is pinned to the bottom on the chrome layer, over
///     the content, above the safe area — it cannot scroll away, and it is in
///     the thumb's reach on a phone rather than at the end of the page.
///
/// Secondary actions live in the app-bar overflow. Five buttons in a row is
/// the alternative, and it is how a screen ends up with no primary action.
class LibraryDetailPage extends ConsumerStatefulWidget {
  final LibraryItem item;

  const LibraryDetailPage({super.key, required this.item});

  @override
  ConsumerState<LibraryDetailPage> createState() => _LibraryDetailPageState();
}

class _LibraryDetailPageState extends ConsumerState<LibraryDetailPage> {
  bool _saved = false;

  void _toggleSaved() {
    setState(() => _saved = !_saved);
    showDSSnackBar(
      context,
      message: _saved
          ? 'Saved ${widget.item.title}'
          : 'Removed ${widget.item.title} from saved',
      tone: DSTone.success,
    );
  }

  /// The swipe's tap-reachable twin.
  ///
  /// The Library row removes by gesture, and a gesture nobody is told about
  /// is not an affordance — it is a feature for the people who already know.
  /// This is the same action, on a menu item, two taps from the row: the
  /// chevron, then Remove. It leaves the page, because the thing the page is
  /// about is no longer in the library, and it offers the same undo the swipe
  /// does.
  void _remove() {
    final item = widget.item;
    ref.read(removedLibraryItemsProvider.notifier).remove(item.id);
    // The snack bar is raised before the page leaves, and it is an overlay
    // entry on the root navigator — so the undo outlives the screen that
    // offered it, which is the only way an undo on a destructive action is
    // any use. `maybePop` rather than `pop`: this page is also mounted
    // directly by tests and by the catalog, where there is nothing to pop.
    showDSSnackBar(
      context,
      message: 'Removed ${item.title}',
      icon: Icons.delete_outline,
      actionLabel: 'Undo',
      onAction: () =>
          ref.read(removedLibraryItemsProvider.notifier).restore(item.id),
    );
    Navigator.of(context).maybePop();
  }

  void _onMenu(String value) {
    showDSSnackBar(
      context,
      message:
          'Wire "$value" to your own action in '
          'lib/screens/library_detail_page.dart.',
    );
  }

  @override
  Widget build(BuildContext context) {
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.
    return DSBottomInsetsHost(
      child: Scaffold(
        // The content runs under the pinned bar rather than stopping above it.
        // That is the whole reason the bar is glass on Apple: a bar with an
        // opaque strip of nothing behind it is a footer, not chrome. It also
        // means the body's MediaQuery carries the bar's height as bottom
        // padding, which is what `_DetailBody` spends its last inset on.
        extendBody: true,
        body: _DetailBody(
          item: widget.item,
          onMenu: _onMenu,
          onRemove: _remove,
        ),
        // `spread`: the save toggle takes what it needs and the primary action
        // takes the rest, which is the arrangement the bar now owns rather than
        // each screen building its own Row.
        bottomNavigationBar: DSPinnedActionBar(
          layout: DSActionBarLayout.spread,
          children: [
            DSIconButton(
              icon: Icons.bookmark_border,
              selectedIcon: Icons.bookmark,
              selected: _saved,
              // The glyph swaps as well as the fill, so the state survives
              // greyscale — and the label says which way the press goes.
              semanticLabel: _saved ? 'Remove from saved' : 'Save for later',
              onPressed: _toggleSaved,
            ),
            DSButton(
              variant: DSButtonVariant.primary,
              label: 'Continue',
              fullWidth: true,
              onPressed: () => _onMenu('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling half, in its own widget so its `context` sits *below* the
/// [Scaffold] — which is the only place `MediaQuery` carries the pinned bar's
/// height. Read from the page's own build method it would be the bare safe
/// area, and the last row would sit under the bar.
class _DetailBody extends StatelessWidget {
  final LibraryItem item;
  final ValueChanged<String> onMenu;
  final VoidCallback onRemove;

  const _DetailBody({
    required this.item,
    required this.onMenu,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schemePalette = context.palette;
    // Four rows, not three.
    //
    // The count is what the tail of the page is made of, so it moved when the
    // rows did: at 16pt body copy three related rows carried the page down to
    // its pinned bar, and at 12.8 they stop 173 points short — which the probe
    // grades as `dead-band` above a floor of 140. A fourth row is 48 of those
    // points back and keeps the section what the note below says it is: a few
    // rows and a way through to the real list, rather than the Collection a
    // Detail screen must not grow inside itself.
    final related = [
      for (final other in demoLibraryItems)
        if (other.id != item.id) other,
    ].take(4).toList();

    return CustomScrollView(
      slivers: [
        DSLargeAppBar(
          // The *category*, not the item's title. A headline set at display
          // size in a phone-width bar is ellipsised before it is read — the
          // probe found "Designing for the platform" cut at 320 points — and
          // the blog article page already draws the same conclusion. The title
          // is below, in the content, where it wraps.
          title: item.category,
          leading: const BackButton(),
          actions: [
            DSMenu(
              semanticLabel: 'More actions',
              tooltip: 'More actions',
              items: [
                DSMenuItem(
                  label: 'Share',
                  icon: Icons.ios_share,
                  onPressed: () => onMenu('Share'),
                ),
                DSMenuItem(
                  label: 'Copy link',
                  icon: Icons.link,
                  onPressed: () => onMenu('Copy link'),
                ),
                const DSMenuSeparator(),
                DSMenuItem(
                  label: 'Remove from library',
                  icon: Icons.delete_outline,
                  tone: DSTone.error,
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
        SliverPadding(
          // A step of air under the large title. Flush against the bar the
          // subject's icon reads as part of the chrome rather than as the
          // first thing on the page.
          padding: EdgeInsets.fromLTRB(
            DSGutter.of(context),
            context.design.space.lg,
            DSGutter.of(context),
            context.design.space.xl,
          ),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  DSWell(icon: item.icon, size: DSWellSize.lg),
                  context.design.space.horizontalLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The headline, in the content and unbounded, so a
                        // long title takes a second line instead of an
                        // ellipsis.
                        Text(item.title, style: theme.textTheme.titleLarge),
                        context.design.space.verticalXs,
                        Text(
                          item.subtitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: schemePalette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // The reader's own place in the subject, above the blurb about it.
        //
        // A detail screen that says what a guide *is* and never where the
        // reader got to is missing the one fact only this screen can give
        // them. `flutter-085` gave every row its declared height, and the
        // 231pt of nothing that appeared under this page when the rows stopped
        // claiming space they were not using is where that question had been
        // sitting — `ui-probe`'s `dead-band` rule, `flutter-087`.
        SliverToBoxAdapter(
          child: DSSection(
            label: 'Where you are',
            contentPadding: context.design.space.pageHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSMetricBar(
                  value: item.progress,
                  label: _progressLabel(item),
                  // Never left to default: `DSMetricBar` draws its own
                  // percentage when this is null, and "0.0%" beside the words
                  // "Not started" is the same fact twice, badly the second
                  // time.
                  valueText: _progressValue(item),
                ),
                context.design.space.verticalXs,
                DSText(_shelfLine(), role: DSTextRole.bodySupport),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: DSSection(
            label: 'Overview',
            // The section header is already on the page gutter; the default
            // content inset is not, and body text 12pt further left than the
            // title above it reads as a mistake nobody can name.
            contentPadding: context.design.space.pageHorizontal,
            child: Text(
              item.detail,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: DSSection(
            label: 'Related',
            // A Detail screen that grew a Collection inside it is two
            // screens. Three rows and a way through to the real list is the
            // version that stays one.
            trailing: DSButton(
              variant: DSButtonVariant.ghost,
              label: 'See all',
              size: DSButtonSize.sm,
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
            contentPadding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final other in related)
                  DSListTile(
                    leading: Icon(other.icon),
                    title: other.title,
                    subtitle: other.subtitle,
                    trailing: Icon(chevronIconFor(context)),
                    onTap: () => context.push(
                      AppRoutes.libraryDetailAt(
                        demoLibraryItems.indexOf(other),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The pinned bar's height, handed down by the Scaffold because the
        // body extends behind it. Without this the last related row is
        // permanently under the button.
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  /// What the bar is called. Three states, because "0% read" and "100% read"
  /// are both facts a percentage states badly.
  static String _progressLabel(LibraryItem item) {
    if (item.progress >= 1) return 'Finished';
    if (item.progress <= 0) return 'Not started';
    return '${(item.progress * 100).round()}% read';
  }

  /// The figure on the bar's trailing edge: what this still costs the reader.
  ///
  /// The subtitle above already says the total, so repeating it here would be
  /// the page saying one thing twice. What is not up there is how much of it
  /// is left.
  static String _progressValue(LibraryItem item) {
    if (item.minutes <= 0) return '${(item.progress * 100).round()}%';
    if (item.progress >= 1) return 'Done';
    if (item.progress <= 0) return '${item.minutes} min';
    return '${(item.minutes * (1 - item.progress)).round()} min left';
  }

  /// The line under the bar, and the only place on this screen that says
  /// anything about the shelf rather than the subject. A detail page that can
  /// tell the reader where they are in *one* guide and not where they are in
  /// the set has answered the smaller half of the question.
  static String _shelfLine() {
    final done = demoLibraryItems.where((i) => i.progress >= 1).length;
    return '$done of ${demoLibraryItems.length} guides finished.';
  }
}
