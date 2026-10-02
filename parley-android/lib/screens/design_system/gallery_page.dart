import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/catalog/catalog.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The Components tab — the **Collection** archetype
/// (`docs/principles/screen-archetypes.md`) applied to the design system
/// itself.
///
/// `ui_lint` fails a screen that hand-rolls a control the kit already owns.
/// That is only a fair rule if the kit is findable, and a generated reference
/// file answers *what exists* without answering *what it looks like*. This tab
/// is the other half: every component, grouped the way the reference groups
/// them, each opening onto its usages at real size on a real device.
///
/// The demo screens built from those components — Blog, Inbox, Form and the
/// rest — used to open above this catalog, under one `Featured demo` header.
/// They have their own tab now (`demos_page.dart`): "what does the kit own?"
/// and "what does a real screen built from it look like?" are different
/// questions, and a reader after the second had to scroll past the first to
/// reach it.
///
/// It is a demo surface. Delete this destination and
/// `lib/screens/design_system/` with it when the app has its own real tab to
/// spend this slot on — nothing else imports the catalog.
class ComponentGalleryPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const ComponentGalleryPage({super.key, this.onOpenDrawer});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

/// The chip strip's "everything" option — both the initial value and what
/// clearing the filter returns to.
const _allCategories = 'All';

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  String _query = '';
  String _category = _allCategories;

  bool get _isFiltered => _query.isNotEmpty || _category != _allCategories;

  /// Matches the component name, its summary, and its story titles — so
  /// "loading" finds `DSSkeleton` even though the word is not in its name.
  bool _matches(DSComponentDemo component) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (component.name.toLowerCase().contains(query)) return true;
    if (component.summary.toLowerCase().contains(query)) return true;
    return component.stories.any(
      (story) => story.title.toLowerCase().contains(query),
    );
  }

  List<DSCatalogCategory> get _visible => [
    for (final category in designSystemCatalog)
      if (_category == _allCategories || _category == category.name)
        if (category.components.any(_matches))
          DSCatalogCategory(
            name: category.name,
            icon: category.icon,
            components: category.components.where(_matches).toList(),
          ),
  ];

  void _clearFilters() {
    setState(() {
      _query = '';
      _category = _allCategories;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _visible;
    final count = categories.fold<int>(
      0,
      (total, category) => total + category.components.length,
    );

    return CustomScrollView(
      slivers: [
        DSPageHeader.compactSliver(
          title: 'Components',
          leading: widget.onOpenDrawer != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: widget.onOpenDrawer,
                  tooltip: 'Open navigation menu',
                )
              : null,
        ),
        // The tokens the components are drawn from. First, because a
        // designer reads the materials before the parts.
        SliverToBoxAdapter(
          child: DSListTile(
            leading: const DSWell(icon: Icons.palette_outlined),
            title: 'Foundations',
            subtitle: 'Colour, elevation, corners, type and spacing tokens',
            trailing: const DSChevron(),
            onTap: () => context.push(AppRoutes.foundations),
          ),
        ),
        // Pinned, the same way the Library's are: a kit of forty-odd
        // components is a list nobody reads without scrolling, and a query
        // that scrolls away is a query that has to be retyped from the top.
        // `DSPinnedHeader` owns the opaque ground both bands need.
        DSPinnedHeader(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DSGutter.of(context),
              0,
              DSGutter.of(context),
              context.design.space.sm,
            ),
            child: DSSearchBar(
              value: _query,
              hintText: 'Search $count components',
              onChanged: (value) => setState(() => _query = value),
              onClear: () => setState(() => _query = ''),
            ),
          ),
        ),
        DSPinnedHeader(
          child: _CategoryStrip(
            selected: _category,
            onSelected: (value) => setState(() => _category = value),
          ),
        ),
        if (categories.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DSEmptyState(
              icon: Icons.search_off,
              title: 'No component matches that filter.',
              actionLabel: _isFiltered ? 'Clear filters' : null,
              onAction: _isFiltered ? _clearFilters : null,
            ),
          )
        else
          for (final category in categories) ...[
            SliverToBoxAdapter(
              child: DSSectionHeader(
                label: '${category.name} (${category.components.length})',
              ),
            ),
            SliverList.builder(
              itemCount: category.components.length,
              itemBuilder: (context, index) {
                final component = category.components[index];
                return DSListTile(
                  leading: DSWell(icon: category.icon),
                  title: component.name,
                  subtitle: component.summary,
                  trailing: DSBadge(label: '${component.stories.length}'),
                  onTap: () =>
                      context.push(AppRoutes.componentAt(component.name)),
                );
              },
            ),
          ],
        SliverToBoxAdapter(
          // Clears the floating nav bar: see `dashboard_page`.
          child: SizedBox(
            height:
                context.design.space.xl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// The category filter, as a scrolling chip strip: which filter is on stays
/// visible, which is the one thing a dropdown would hide.
class _CategoryStrip extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryStrip({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: DSGutter.of(context),
        vertical: context.design.space.xs,
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: context.design.space.sm),
            child: DSChip(
              label: _allCategories,
              role: DSChipRole.filter,
              icon: Icons.apps,
              selected: selected == _allCategories,
              onSelected: (_) => onSelected(_allCategories),
            ),
          ),
          for (final category in designSystemCatalog)
            Padding(
              padding: EdgeInsetsDirectional.only(end: context.design.space.sm),
              child: DSChip(
                label: category.name,
                role: DSChipRole.filter,
                icon: category.icon,
                selected: selected == category.name,
                onSelected: (_) => onSelected(category.name),
              ),
            ),
        ],
      ),
    );
  }
}
