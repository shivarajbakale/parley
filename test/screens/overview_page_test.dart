import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/screens/parley/overview_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';

import '_parley_harness.dart';

/// Overview — the hero says whether talking works right now, and fixes it
/// when it does not; the figures are the week's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget screen() => const Scaffold(body: OverviewPage());

  testWidgets('ready: says so, shows the switch, and no fix button', (
    tester,
  ) async {
    await pumpParley(tester, screen());
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Parley is on'), findsOneWidget);
    expect(find.text('Open Accessibility settings'), findsNothing);
  });

  testWidgets('the week\'s figures match the seeded history', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    final summary = await bridge.getUsageSummary();
    await pumpParley(tester, screen(), bridge: bridge);

    expect(find.text('Words this week'), findsOneWidget);
    expect(find.text('${summary.weekWords}'), findsOneWidget);
    expect(find.text('Saved typing'), findsOneWidget);
  });

  testWidgets('the last dictation is quoted', (tester) async {
    await pumpParley(tester, screen());
    expect(
      find.text('“Running ten minutes late, start without me.”'),
      findsOneWidget,
    );
  });

  testWidgets('the switch pauses Parley', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, screen(), bridge: bridge);

    await tester.ensureVisible(find.text('Parley is on'));
    await tester.tap(find.text('Parley is on'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect((await bridge.getStatus()).paused, isTrue);
  });

  testWidgets('missing microphone: the fix asks for it', (tester) async {
    final bridge = FakeParleyBridge(
      now: parleyTestNow,
      status: const ParleyStatus(serviceBound: true, groqKeySet: true),
    );
    await pumpParley(tester, screen(), bridge: bridge);

    expect(find.text('Needs the microphone'), findsOneWidget);
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('empty history: a setup ring replaces the zero figures', (
    tester,
  ) async {
    await pumpParley(
      tester,
      screen(),
      bridge: FakeParleyBridge.ready(history: const [], now: parleyTestNow),
    );
    expect(find.text('Next: say something'), findsOneWidget);
    expect(find.text('Words this week'), findsNothing);

    await tester.ensureVisible(find.text('Try it'));
    await tester.tap(find.text('Try it'));
    await tester.pumpAndSettle();
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('empty history before setup counts the steps and defers to '
      'the hero for the fix', (tester) async {
    await pumpParley(
      tester,
      screen(),
      bridge: FakeParleyBridge(
        now: parleyTestNow,
        history: const [],
        status: const ParleyStatus(serviceBound: true, groqKeySet: true),
      ),
    );
    expect(find.text('Next: allow the mic'), findsOneWidget);
    expect(find.text('Try it'), findsNothing);
  });
}
