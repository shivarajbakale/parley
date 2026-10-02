import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/data/library_repository.dart';
import 'package:parley_android/design_system/ds_chip.dart';
import 'package:parley_android/design_system/ds_dismissible_tile.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_refresh.dart';
import 'package:parley_android/design_system/ds_pinned_header.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_well.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_search_bar.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/models/library_item.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/utils/error_copy.dart';

/// The Library tab — the **Collection** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// Every part of that archetype is here because a list screen without it is a
/// list screen someone will have to finish later:
///
///   * **search in place**, filtering what is already on screen rather than
///     opening a second one;
///   * **filters as a chip strip**, not a dropdown — a dropdown hides which
///     filter is active, which is the one thing the user needs to see;
///   * **pull-to-refresh**, always, through `DSRefresh` — which forces the
///     always-scrollable physics, so the gesture still works when the list is
///     short enough to fit;
///   * **swipe for the destructive action**, with the same action on a tap
///     target too, because a swipe is not discoverable on its own;
///   * **three different empty screens** — nothing here yet, nothing matched,
///     and the fetch failed are three different problems with three different
///     things to do about them.
///
/// The loading state is the same rows rendered as bones, so it cannot drift
/// out of shape with the content it stands in for.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

/// The chip strip's "everything" option. A named constant because it is both
/// the initial value and the thing "Clear filters" returns to.
const _allCategories = 'All';

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';
  String _category = _allCategories;

  bool get _isFiltered => _query.isNotEmpty || _category != _allCategories;

  /// Removed by id, from `removedLibraryItemsProvider` — shared with the
  /// detail page, which carries the swipe's tap-reachable twin.
  Set<String> get _removed => ref.watch(removedLibraryItemsProvider);

  List<LibraryItem> _visible(List<LibraryItem> items) {
    final query = _query.trim().toLowerCase();
    return [
      for (final item in items)
        if (!_removed.contains(item.id) &&
            (_category == _allCategories || item.category == _category) &&
            (query.isEmpty ||
                item.title.toLowerCase().contains(query) ||
                item.subtitle.toLowerCase().contains(query)))
          item,
    ];
  }

  void _remove(LibraryItem item) {
    ref.read(removedLibraryItemsProvider.notifier).remove(item.id);
    showDSSnackBar(
      context,
      message: 'Removed ${item.title}',
      icon: Icons.delete_outline,
      // An undo, not a confirm dialog. The row is already gone, which is what
      // makes the gesture feel decisive; the way back is one tap and it does
      // not stand between the user and the action they asked for.
      actionLabel: 'Undo',
      onAction: () =>
          ref.read(removedLibraryItemsProvider.notifier).restore(item.id),
    );
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _category = _allCategories;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryItemsProvider);

    return DSRefresh(
      onRefresh: () => ref.refresh(libraryItemsProvider.future),
      child: CustomScrollView(
        slivers: [
          const DSPageHeader.compactSliver(title: 'Library'),
          // Both bands are pinned, and `DSPinnedHeader` is what makes them
          // so: the field stacks under the app bar, the strip under the
          // field, each the height of what it holds. Losing sight of what
          // filtered a list is the failure the pinning exists to prevent, and
          // it is the same failure for the query as for the chips.
          DSPinnedHeader(
            child: _SearchRow(
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
            ),
          ),
          DSPinnedHeader(
            child: _CategoryStrip(
              category: _category,
              categories: _categoriesOf(items.valueOrNull ?? const []),
              onCategoryChanged: (value) => setState(() => _category = value),
            ),
          ),
          ...switch (items) {
            // The copy is `errorCopyFor`'s, not this screen's. What was here
            // put `'$error'` into the message, which is how a dropped
            // connection reaches a person as `ClientException with
            // SocketException: Failed host lookup` — a sentence that names
            // the library that failed and nothing the reader can do.
            AsyncError(:final error) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(libraryItemsProvider),
                ),
              ),
            ],
            AsyncValue(:final value?) => _content(value),
            _ => const [
              SliverToBoxAdapter(
                child: DSSkeletonList(itemCount: 6, shrinkWrap: true),
              ),
            ],
          },
        ],
      ),
    );
  }

  /// The loaded states, which are three and not one.
  List<Widget> _content(List<LibraryItem> items) {
    final visible = _visible(items);

    if (visible.isEmpty) {
      // Nothing matched is a different screen from nothing exists: one is
      // fixed by clearing a filter and the other cannot be fixed from here.
      final filtered = _isFiltered || _removed.isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: filtered
              ? DSEmptyState(
                  icon: Icons.search_off_outlined,
                  title: _query.isEmpty
                      ? 'Nothing in $_category.'
                      : 'No results for "$_query".',
                  actionLabel: 'Clear filters',
                  onAction: _clearFilters,
                )
              : const DSEmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Nothing in the library yet.',
                ),
        ),
      ];
    }

    return [
      SliverPadding(
        // Clears the floating nav bar: see `dashboard_page`.
        padding: EdgeInsets.only(
          bottom:
              context.design.space.xl + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: SliverList.separated(
          itemCount: visible.length,
          // The identity's divider rule, the same one every kit list reads.
          separatorBuilder: (context, _) =>
              switch (context.design.component.dividerPolicy) {
                DividerPolicy.none => const SizedBox.shrink(),
                DividerPolicy.full => DSDivider(
                  indent: DSGutter.of(context),
                  endIndent: DSGutter.of(context),
                ),
                DividerPolicy.inset => DSDivider(
                  indent:
                      context.design.component.leadingSlotSize +
                      DSGutter.of(context),
                  endIndent: DSGutter.of(context),
                ),
              },
          itemBuilder: (context, index) {
            final item = visible[index];
            return DSDismissibleTile(
              key: ValueKey<String>(item.id),
              trailingAction: DSSwipeAction(
                icon: Icons.delete_outline,
                label: 'Remove',
                tone: DSTone.error,
                onInvoke: () => _remove(item),
              ),
              child: _LibraryRow(
                item: item,
                // The route indexes into the *unfiltered* collection, so a
                // filtered row still opens the item it names rather than
                // whatever happens to sit at that position today.
                onOpen: () => context.push(
                  AppRoutes.libraryDetailAt(items.indexOf(item)),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  /// The shelves the data has, in a stable order.
  ///
  /// Derived rather than hard-coded, so a new category cannot leave a row
  /// unreachable behind a strip that does not mention it.
  static List<String> _shelvesOf(List<LibraryItem> items) {
    final seen = <String>{for (final item in items) item.category};
    return seen.toList()..sort();
  }

  /// The strip's options: everything, then the shelves.
  static List<String> _categoriesOf(List<LibraryItem> items) => [
    _allCategories,
    ..._shelvesOf(items),
  ];
}

/// The fetch failed, in words.
///
/// A widget rather than a call inlined in the `switch` so the screen reads as
/// three named states, and so the same three lines are not retyped on the
/// next screen that needs them.
class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final copy = errorCopyFor(error);

    return DSErrorState(
      icon: copy.icon,
      title: copy.message,
      actionLabel: copy.actionLabel,
      onRetry: onRetry,
    );
  }
}

/// The search field, in the page's own gutter.
///
/// The gutter is applied once, here. [DSSearchBar] used to add a second one of
/// its own, which put the pill at 32 while the chips and rows beside it sat at
/// 16 — a field visibly not lined up with the list it filters.
class _SearchRow extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _SearchRow({required this.query, required this.onQueryChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      DSGutter.of(context),
      0,
      DSGutter.of(context),
      context.design.space.sm,
    ),
    child: DSSearchBar(
      value: query,
      hintText: 'Search the library',
      onChanged: onQueryChanged,
      onClear: () => onQueryChanged(''),
    ),
  );
}

class _CategoryStrip extends StatelessWidget {
  final String category;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;

  const _CategoryStrip({
    required this.category,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    // The ground is `DSPinnedHeader`'s: every band it pins is opaque, so no
    // strip has to remember to be.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontally scrolling rather than wrapped: a strip that wraps
        // changes the list's starting position every time a filter is
        // added, and the row under it moves for no reason the user can see.
        //
        // A `Row` in a scroll view rather than a horizontal `ListView`: a
        // `ListView` on the cross axis has to be told its height, and the
        // formula that told it added a chip's padding a second time — 60
        // points reserved for a 36-point chip, 24 of them dead, at every
        // text size. A row measures the chips it actually holds. There are
        // four of them; laziness was never the point.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: DSGutter.of(context)),
          child: Row(
            spacing: context.design.space.sm,
            children: [
              // No glyph. A filter chip already says what it filters, in
              // the word on it; the icon beside it repeated the word in a
              // picture, cost a third of the chip's width, and made four
              // chips look like four different kinds of thing. The
              // selection is carried by the fill, the outline and the tick
              // the kit draws for a selected filter — three channels
              // without adding a fourth that says nothing new.
              for (final option in categories)
                DSChip(
                  label: option,
                  role: DSChipRole.filter,
                  selected: option == category,
                  onSelected: (_) => onCategoryChanged(option),
                ),
            ],
          ),
        ),
        context.design.space.verticalSm,
      ],
    );
  }
}

/// One row: a well carrying the item's icon, the identity, the metadata, a
/// chevron.
///
/// **The well takes the palette's secondary pair, not a per-shelf hue.** The
/// 15-role palette has no category ramp; the category the row can be filtered
/// by already names the shelf.
///
/// **The trailing control is a chevron, not a menu.** A per-row overflow put
/// a button in every row for two items, one of which ("Open") was the row's
/// own tap target. What is left is the mark that says the row leads
/// somewhere. Remove keeps two ways in that are not the swipe: the custom
/// semantics action `DSDismissibleTile` registers, and "Remove from library"
/// on the page the chevron opens.
class _LibraryRow extends StatelessWidget {
  final LibraryItem item;

  final VoidCallback onOpen;

  const _LibraryRow({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return DSListTile(
      leading: DSWell(icon: item.icon),
      // The row's title is the item's own words, not a label the app chose,
      // so it is allowed the lines it needs: a library where three entries all
      // read "Designing for the platform without desig…" is a library the
      // reader has to open three times to tell apart.
      wrap: true,
      title: item.title,
      subtitle: item.subtitle,
      onTap: onOpen,
      trailing: const DSChevron(),
    );
  }
}
