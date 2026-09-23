import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The Demos tab — the **Collection** archetype
/// (`docs/principles/screen-archetypes.md`) applied to the demo surface
/// itself: one row per screen, each opening onto the real thing at real size
/// on a real device.
///
/// Split out of `gallery_page.dart`, which used to carry this list above its
/// own component catalog under one `Featured demo` header. The two lists
/// answer different questions — "what does the kit own?" against "what does
/// a real screen built from it look like?" — and sharing one tab meant a
/// reader who wanted the second had to scroll past the first, or find it, to
/// reach the catalog underneath.
///
/// It is a demo surface. Delete this destination and
/// `lib/screens/design_system/` with it when the app has its own real tab
/// to spend a fifth slot on — nothing outside this directory imports it.
class DemosPage extends StatelessWidget {
  final VoidCallback? onOpenDrawer;

  const DemosPage({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        DSPageHeader.compactSliver(
          title: 'Demos',
          leading: onOpenDrawer != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onOpenDrawer,
                  tooltip: 'Open navigation menu',
                )
              : null,
        ),
        // (lint hint — the DSListTile below is non-const because of onTap)
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.article_outlined),
            title: 'Blog',
            subtitle:
                'A list and an article reading view, built only from DS* '
                'components — the answer to "what would a real screen '
                'look like?".',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.blog),
          ),
        ),
        // (lint hint — same onTap-closure reason as the tile above.)
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.inbox_outlined),
            title: 'Inbox',
            subtitle:
                'Two tab-bar components solving different problems on one '
                'screen: DSTabBar (sections) above DSSegmentedButton (sort).',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.inbox),
          ),
        ),
        // (lint hint — same onTap-closure reason as the two tiles above.)
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.edit_note_outlined),
            title: 'Form',
            subtitle:
                'The Form archetype as a four-step flow: a control per data '
                'type, validation scoped to the step, and a review before '
                'anything is booked.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.form),
          ),
        ),
        // (lint hint — same onTap-closure reason as the three tiles above.)
        // flutter-048 — the moment a new user meets the app. Routes with
        // `?demo=1`: the welcome is one-shot for the first-launch flow,
        // but a demo reader on this tab wants to *see* it regardless of
        // their history. The query parameter is the opt-in; the router's
        // redirect block has a matching short-circuit.
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.waving_hand_outlined),
            title: 'Welcome',
            subtitle:
                'The first screen a new user meets — the moment the app '
                'introduces itself, between splash and the tour.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push('${AppRoutes.welcome}?demo=1'),
          ),
        ),
        // (lint hint — same onTap-closure reason as the four tiles above.)
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.insights_outlined),
            title: 'Recap',
            subtitle:
                'The Insight archetype: one figure with its comparison, one '
                'plot, one written sentence about what they mean — and '
                'nothing pinned.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.insight),
          ),
        ),
        // (lint hint — same onTap-closure reason as the five tiles above.)
        // (lint hint — same onTap-closure reason as the tiles above.)
        // flutter-051 — the Shelf archetype, which is what the media family
        // was built for: rails of DSMediaTile under one DSMediaHero.
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.grid_view_outlined),
            title: 'Browse',
            subtitle:
                'The Shelf archetype: one hero, then rails that name why '
                'they are there — and a next tile that always peeks.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.browse),
          ),
        ),
        // (lint hint — same onTap-closure reason as the tiles above.)
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.receipt_long_outlined),
            title: 'Order placed',
            subtitle:
                'The Confirmation archetype: what happened, a number you can '
                'copy, the receipt, and a next step with a date on it.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.orderPlaced),
          ),
        ),
        // (lint hint — same onTap-closure reason as the tiles above.)
        // flutter-060 — the Canvas archetype, the last of the fifteen to get
        // a screen: a ground under a sheet with three named detents.
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.map_outlined),
            title: 'Places',
            subtitle:
                'The Canvas archetype: a ground you can still pan at every '
                'detent, a sheet that peeks without covering the pin, and '
                'everything the map cannot say written in the sheet.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.place),
          ),
        ),
        SliverToBoxAdapter(
          // ignore: prefer_const_constructors
          child: DSListTile(
            leading: const DSWell(icon: Icons.person_outline),
            title: 'Profile',
            subtitle:
                'The Detail archetype against a person: DSAvatar, a '
                'stat grid, and DSChip read as a badge rather than a '
                'filter.',
            trailing: const DSBadge(label: 'demo'),
            onTap: () => context.push(AppRoutes.profile),
          ),
        ),
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
