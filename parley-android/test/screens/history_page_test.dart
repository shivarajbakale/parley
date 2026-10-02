import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/screens/parley/history_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';

import '_parley_harness.dart';

/// History — the Collection archetype: grouped by day, searched by the words,
/// filtered by mode, swipe to delete with an undo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget screen() => Scaffold(body: HistoryPage(now: parleyTestNow));

  testWidgets('groups entries under Today and Yesterday', (tester) async {
    await pumpParley(tester, screen());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(
      find.text('Running ten minutes late, start without me.'),
      findsOneWidget,
    );
  });

  testWidgets('search runs over the words', (tester) async {
    await pumpParley(tester, screen());
    await tester.enterText(find.byType(EditableText), 'milk');
    await tester.pumpAndSettle();

    expect(
      find.text('Pick up milk, eggs and the dry cleaning on the way home.'),
      findsOneWidget,
    );
    expect(
      find.text('Running ten minutes late, start without me.'),
      findsNothing,
    );
  });

  testWidgets('nothing matched is its own screen, with a way out', (
    tester,
  ) async {
    await pumpParley(tester, screen());
    await tester.enterText(find.byType(EditableText), 'invoice');
    await tester.pumpAndSettle();

    expect(find.text('No match for “invoice”'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('the Edits filter shows the instruction', (tester) async {
    await pumpParley(tester, screen());
    await tester.tap(find.text('Edits'));
    await tester.pumpAndSettle();

    expect(find.text('Make it friendlier and shorter.'), findsOneWidget);
    expect(
      find.text('Running ten minutes late, start without me.'),
      findsNothing,
    );
  });

  testWidgets('no history at all offers a field to try it in', (tester) async {
    await pumpParley(
      tester,
      screen(),
      bridge: FakeParleyBridge.ready(history: const [], now: parleyTestNow),
    );
    expect(find.text('Nothing yet'), findsOneWidget);
    await tester.tap(find.text('Try it'));
    await tester.pumpAndSettle();
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('no history while Parley is off fixes the first blocker', (
    tester,
  ) async {
    final bridge = FakeParleyBridge(now: parleyTestNow, history: const []);
    await pumpParley(tester, screen(), bridge: bridge);
    expect(find.text('Parley is off'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(bridge.openedSettings, [SystemSettingsTarget.accessibility]);
  });

  testWidgets('swipe deletes, and Undo puts it back', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, screen(), bridge: bridge);
    const text = 'Running ten minutes late, start without me.';

    await tester.drag(find.text(text), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text(text), findsNothing);
    expect(await bridge.getHistoryEntry(12), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text(text), findsOneWidget);
  });
}
