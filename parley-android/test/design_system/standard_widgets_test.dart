import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/ds_bottom_nav_bar.dart';
import 'package:parley_android/design_system/ds_sidebar.dart';

/// The design system's standing contract, and the reason these tests exist:
///
///   1. **Wrap, don't re-implement.** Every navigation/list primitive resolves
///      to the stock Material widget underneath, so accessibility, text
///      scaling, and platform behaviour come from the framework.
///   2. **Full width.** Chrome and rows span the viewport, insetting only to
///      the page gutter. Elements floating in a narrow column are the single
///      most reliable tell of a substandard app.
///
/// If a component is rewritten by hand, or starts floating inside margins,
/// these fail — which is the point.
void main() {
  group('DSSidebar', () {
    testWidgets('is a Material NavigationDrawer opened by Scaffold', (
      tester,
    ) async {
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: key,
            drawer: DSSidebar(
              header: const DSSidebarHeader(title: 'Rocketship'),
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                DSBottomNavItem(label: 'Home', icon: Icons.dashboard_outlined),
                DSBottomNavItem(
                  label: 'Library',
                  icon: Icons.collections_bookmark_outlined,
                ),
              ],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      key.currentState!.openDrawer();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationDrawer), findsOneWidget);
      expect(find.byType(NavigationDrawerDestination), findsNWidgets(2));
      expect(find.text('Rocketship'), findsOneWidget);
    });
  });
}
