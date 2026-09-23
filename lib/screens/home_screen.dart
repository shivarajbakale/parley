import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_ground.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_bottom_nav_bar.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_sidebar.dart';
import 'package:parley_android/screens/design_system/demos_page.dart';
import 'package:parley_android/screens/design_system/gallery_page.dart';
import 'package:parley_android/screens/home/dashboard_page.dart';
import 'package:parley_android/screens/home/library_page.dart';
import 'package:parley_android/screens/settings_page.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The app shell: five destinations (Home / Library / Components / Demos /
/// Settings) inside a swipeable [PageView], surfaced by a Material
/// [NavigationBar] at the bottom and a Material [NavigationDrawer] behind the
/// menu button.
///
/// Components and Demos are both demo destinations: the design system
/// browsing itself, and the screens built from it. Drop their entries from
/// [_destinations], their pages from the [PageView] and
/// `lib/screens/design_system/` when the app has real tabs to spend those
/// slots on.
///
/// Both nav surfaces are driven from [_destinations], so adding a tab is one
/// list entry plus one page — and the drawer, the bottom bar, and the swipe
/// order can never disagree. Replace the page bodies with your own features;
/// the shell itself is the pattern you're inheriting.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// One entry per destination — rendered into both nav surfaces and the
/// [PageView], in this order.
const _destinations = [
  (
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  (
    label: 'Library',
    icon: Icons.collections_bookmark_outlined,
    selectedIcon: Icons.collections_bookmark,
  ),
  (
    label: 'Components',
    icon: Icons.widgets_outlined,
    selectedIcon: Icons.widgets,
  ),
  (
    label: 'Demos',
    icon: Icons.play_circle_outline,
    selectedIcon: Icons.play_circle,
  ),
  (
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageController = PageController();
  int _index = 0;
  bool _isTapNavigation = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _index) return;
    _isTapNavigation = true;
    AppHaptics.selection();
    final motion = context.design.motion;
    // An adjacent tab is a short move and a jump across the strip is a long
    // one; one duration for both makes the short move feel slow or the long
    // one feel abrupt.
    final distance = (index - _index).abs();
    final duration = motion.scaled(distance == 1 ? motion.fast : motion.normal);
    _pageController
        .animateToPage(index, duration: duration, curve: motion.emphasize)
        .then((_) => _isTapNavigation = false);
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return DSGround(
      child: PopScope(
        // Back on a secondary tab returns to Home rather than leaving the app.
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _switchTab(0);
        },
        // The nav bar reports its height here, so every page inside the shell
        // clears the pill and a snack bar lands above it rather than on it.
        // The host wraps the scaffold rather than sitting in its body: the bar
        // is the body's sibling, and an inherited widget installed by one could
        // never be read by the other.
        child: DSBottomInsetsHost(
          child: Scaffold(
            // The nav bar floats, so the pages run under it and the glass has
            // something moving behind it. Scaffold adds the bar's height back to
            // the body's bottom padding, so a scroll view that respects the
            // padding still ends above the pill rather than behind it.
            extendBody: true,
            key: _scaffoldKey,
            drawer: DSSidebar(
              header: const DSSidebarHeader(
                title: 'Rocketship',
                caption: 'Version 0.1.0',
              ),
              selectedIndex: _index,
              onDestinationSelected: (index) {
                Navigator.of(context).pop();
                _switchTab(index);
              },
              destinations: [
                for (final d in _destinations)
                  DSBottomNavItem(
                    label: d.label,
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                  ),
              ],
              footer: DSListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: 'Upgrade to Pro',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/paywall');
                },
              ),
            ),
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _index = index);
                if (!_isTapNavigation) AppHaptics.selection();
              },
              children: [
                DashboardPage(onOpenDrawer: _openDrawer),
                const LibraryPage(),
                const ComponentGalleryPage(),
                DemosPage(onOpenDrawer: _openDrawer),
                SettingsPage(onOpenDrawer: _openDrawer),
              ],
            ),
            bottomNavigationBar: DSBottomNavBar(
              currentIndex: _index,
              onTap: _switchTab,
              items: [
                for (final d in _destinations)
                  DSBottomNavItem(
                    label: d.label,
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
