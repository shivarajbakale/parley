import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_bottom_nav_bar.dart';
import 'package:parley_android/design_system/ds_ground.dart';
import 'package:parley_android/providers/parley_providers.dart';
import 'package:parley_android/screens/parley/history_page.dart';
import 'package:parley_android/screens/parley/overview_page.dart';
import 'package:parley_android/screens/parley/parley_settings_page.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Parley's shell: Overview, History and Settings in a swipeable
/// [PageView] under one floating nav bar, driven by [_destinations] so the
/// bar and the swipe order cannot disagree.
///
/// It also re-reads the service status whenever the app returns to the
/// front, which is how a grant given in system Settings shows up without a
/// pull-to-refresh.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

const _destinations = [
  (
    label: 'Overview',
    icon: Icons.radio_button_checked_outlined,
    selectedIcon: Icons.radio_button_checked,
  ),
  (label: 'History', icon: Icons.history, selectedIcon: Icons.history),
  (label: 'Settings', icon: Icons.tune_outlined, selectedIcon: Icons.tune),
];

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  int _index = 0;
  bool _isTapNavigation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(parleyStatusProvider.notifier).refresh();
      ref.invalidate(usageSummaryProvider);
    }
  }

  void _switchTab(int index) {
    if (index == _index) return;
    _isTapNavigation = true;
    AppHaptics.selection();
    final motion = context.design.motion;
    final distance = (index - _index).abs();
    final duration = motion.scaled(distance == 1 ? motion.fast : motion.normal);
    _pageController
        .animateToPage(index, duration: duration, curve: motion.emphasize)
        .then((_) => _isTapNavigation = false);
  }

  @override
  Widget build(BuildContext context) {
    return DSGround(
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _switchTab(0);
        },
        child: DSBottomInsetsHost(
          child: Scaffold(
            extendBody: true,
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _index = index);
                if (!_isTapNavigation) AppHaptics.selection();
              },
              children: const [
                OverviewPage(),
                HistoryPage(),
                ParleySettingsPage(),
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
