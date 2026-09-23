import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/parley/parley_settings_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';

import '_parley_harness.dart';

/// Settings — every change reaches the service through `setConfig`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget screen() => const Scaffold(body: ParleySettingsPage());

  testWidgets('shows every group', (tester) async {
    await pumpParley(tester, screen());
    for (final eyebrow in ['TRIGGERS', 'DICTATION', 'KEYS']) {
      expect(
        find.textContaining(RegExp('^$eyebrow\$', caseSensitive: false)),
        findsOneWidget,
        reason: eyebrow,
      );
    }
    await tester.scrollUntilVisible(find.text('Run setup again'), 200);
    expect(
      find.textContaining(RegExp('^history\$', caseSensitive: false)),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp('^system\$', caseSensitive: false)),
      findsOneWidget,
    );
  });

  testWidgets('turning off the volume gesture reaches the service', (
    tester,
  ) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, screen(), bridge: bridge);

    await tester.tap(find.text('Volume-down tap-tap-hold'));
    await tester.pumpAndSettle();

    expect((await bridge.getConfig()).volumeGestureEnabled, isFalse);
    expect((await bridge.getStatus()).volumeGestureEnabled, isFalse);
  });

  testWidgets('the language picker sets the language', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, screen(), bridge: bridge);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kannada'));
    await tester.pumpAndSettle();

    expect((await bridge.getConfig()).language, 'kn');
    expect(find.text('Kannada'), findsOneWidget);
  });

  testWidgets('keys show only their last four characters', (tester) async {
    await pumpParley(tester, screen());
    expect(find.textContaining('••x7Qa'), findsOneWidget);
  });

  testWidgets('clearing history asks first, then clears', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, screen(), bridge: bridge);

    await tester.scrollUntilVisible(find.text('Clear history'), 200);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all history?'), findsOneWidget);

    await tester.tap(find.text('Clear history').last);
    await tester.pumpAndSettle();
    expect(await bridge.listHistory(), isEmpty);
  });
}
