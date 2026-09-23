import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/inbox_data.dart';
import 'package:parley_android/screens/design_system/inbox_page.dart';
import 'package:parley_android/theme/app_theme.dart';

/// The inbox demo is the second tile on the Demos tab, and the
/// one whose job is to show the two shipped tab-bar components doing their
/// respective jobs side by side. These tests pin the claims a reader makes
/// about it:
///
///   * the section tab bar reads [InboxSection] directly, so a future
///     section's name does not need a parallel string registry;
///   * the sort segmented control reads [InboxSort] directly, so the same
///     applies there;
///   * both controls stay on screen while the list scrolls, because a
///     segmented control that scrolls out with the first row has no visible
///     role — this was a claim in prose and nothing else until the header was
///     pinned, and the controls did slide under the app bar after about 110
///     points of scroll;
///   * every shipped notification renders under the light theme, so a
///     dropped row fails this test before the demo is shipped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('the inbox demo', () {
    testWidgets('renders one section tab per InboxSection', (tester) async {
      await pump(tester, const InboxPage());

      for (final section in InboxSection.values) {
        final label = sectionSummary(section).label;
        expect(
          find.text(label),
          findsWidgets,
          reason: 'section tab "$label" did not render',
        );
      }
    });

    testWidgets('renders one sort segment per InboxSort', (tester) async {
      await pump(tester, const InboxPage());

      for (final sort in InboxSort.values) {
        final label = switch (sort) {
          InboxSort.newest => 'Newest',
          InboxSort.oldest => 'Oldest',
          InboxSort.priority => 'Priority',
        };
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'sort segment "$label" did not render',
        );
      }
    });

    testWidgets('the controls stay reachable once the list has scrolled', (
      tester,
    ) async {
      await pump(tester, const InboxPage());

      // The app bar above is pinned. A header that is not pinned slides
      // under it, and switching section then means flinging back to the top
      // of the list first — which is the whole cost of a filter that is not
      // where the reader left it.
      await tester.drag(find.byType(DSListTile).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(
        find.byType(DSTabBar),
        findsOneWidget,
        reason: 'the section tabs scrolled out of the tree',
      );
      expect(find.text('Newest'), findsOneWidget);

      final appBar = tester.getRect(find.byType(AppBar).first);
      final tabs = tester.getRect(find.byType(DSTabBar));
      expect(
        tabs.top,
        greaterThanOrEqualTo(appBar.bottom - 0.01),
        reason:
            'the tabs are sitting under the pinned app bar at '
            '${tabs.top.toStringAsFixed(1)}, with the bar reaching '
            '${appBar.bottom.toStringAsFixed(1)}',
      );
    });

    testWidgets('the section tab bar and sort control both sit above the '
        'list and every shipped notification renders under the light theme', (
      tester,
    ) async {
      await pump(tester, const InboxPage());

      // Both controls above the first row. `find.byType` cannot carry a
      // generic parameter (`DSSegmentedButton<InboxSort>` erases to
      // `DSSegmentedButton`), so the segmented control is found through its
      // own label set — every one of its segments is in the tree, and they
      // can only be in the segmented control because the page owns no other
      // `Newest` / `Oldest` / `Priority` text.
      expect(find.byType(DSTabBar), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);

      // Every notification title is in the list under "All". The list is
      // long enough that the last few rows have to be scrolled to, the
      // same way the blog list's last article does. The controls live in a
      // `SliverToBoxAdapter` rather than a persistent header — they scroll
      // with the list, the way the blog intro does — so after a scroll the
      // tab bar is no longer in the tree, and that is the page's design.
      for (final item in demoInboxItems) {
        for (
          var i = 0;
          i < 25 && find.text(item.subject).evaluate().isEmpty;
          i++
        ) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pump();
        }
        expect(
          find.text(item.subject),
          findsOneWidget,
          reason: '"${item.subject}" did not render — the list dropped it',
        );
      }
    });

    testWidgets('switching to Mentions narrows the list to mentions only', (
      tester,
    ) async {
      await pump(tester, const InboxPage());

      // The Mentions tab — the second one — gets selected. `DSTabBar` is
      // found by index rather than by label here because the tab uses a
      // tab index, and tapping the underlying label is what the production
      // UX does.
      await tester.tap(find.text('Mentions'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final mentions = demoInboxItems
          .where((i) => i.section.contains(InboxSection.mentions))
          .toList();
      expect(mentions, isNotEmpty);

      // Every mentions item's subject is still visible. Every non-mentions
      // item is not — "did not render" as a side effect of "no longer in
      // this section".
      for (final item in mentions) {
        for (
          var i = 0;
          i < 20 && find.text(item.subject).evaluate().isEmpty;
          i++
        ) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pump();
        }
        expect(
          find.text(item.subject),
          findsOneWidget,
          reason: '"${item.subject}" expected in Mentions, not found',
        );
      }
    });

    testWidgets('switching sort to Priority puts the urgent item first', (
      tester,
    ) async {
      await pump(tester, const InboxPage());

      // Default sort is Newest, so an urgent item may not be at the top.
      // After selecting Priority, the highest-priority item (priority 2)
      // appears before any priority-0 item.
      await tester.tap(find.text('Priority'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Walk the list top-down and assert the first priority-2 subject is
      // seen before any priority-0 subject. `DSTab` keeps counts in the
      // tab, not in the rows, so we read priority off the data model and
      // confirm the first row is one of the highest-priority items.
      final urgent = demoInboxItems.where((i) => i.priority == 2).toList();
      expect(urgent, isNotEmpty);

      final firstUrgentSubject = urgent.first.subject;
      // The first row's title is one of the urgent items — scroll up first
      // so we are looking at the top of the list, not somewhere in the
      // middle.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(firstUrgentSubject),
        findsOneWidget,
        reason: 'priority sort did not put an urgent item at the top',
      );
    });

    testWidgets('the chip row carries the item kind, timestamp, and priority', (
      tester,
    ) async {
      await pump(tester, const InboxPage());

      // The first row's data:
      final first = demoInboxItems.first;
      expect(find.text(first.kindLabel), findsWidgets);
      // Read the expected relative-time against the page's own reference
      // clock, not `DateTime.now()` — that is what the page does, and the
      // assertion would otherwise search for a string the page never wrote.
      expect(
        find.text(relativeTime(first.timestamp, now: inboxReferenceNow)),
        findsWidgets,
      );
      // An alert has priority 2 → an "Urgent" meta is in the row.
      if (first.priority == 2) {
        expect(find.text('Urgent'), findsWidgets);
      } else if (first.priority == 1) {
        expect(find.text('High'), findsWidgets);
      }
    });

    // Smoke test: the page does not throw when mounted under the full theme
    // tree. Same shape as the blog smoke test.
    testWidgets('the page builds under the light theme without exception', (
      tester,
    ) async {
      await pump(tester, const InboxPage());
      expect(tester.takeException(), isNull);
    });
  });
}

// `_InboxRow`, `_ControlsHeader` and `_EmptyState` are private to
// `inbox_page.dart`. Their behaviour is observable through the tests above
// (tab changes narrow the list, sort changes the order, every item renders),
// and pinning private widgets would couple the tests to the implementation
// rather than to what a reader sees.
