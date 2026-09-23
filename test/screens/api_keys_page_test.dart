import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/parley/api_keys_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';

import '_parley_harness.dart';

/// API keys — nothing is saved until every typed key has been checked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Check and save is off until something is typed', (tester) async {
    await pumpParley(tester, const ApiKeysPage());
    final button = find.text('Check and save');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // Still here, nothing sent.
    expect(find.text('Check and save'), findsOneWidget);
  });

  testWidgets('a rejected key shows the provider\'s message and is not saved', (
    tester,
  ) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

    await tester.enterText(find.byType(EditableText).first, 'gsk_bad_key_999');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check and save'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid API Key'), findsOneWidget);
    expect((await bridge.getConfig()).groqKeyLast4, 'x7Qa');
  });

  testWidgets('a good key is saved as its last four', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

    await tester.enterText(find.byType(EditableText).first, 'gsk_new_key_WXYZ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check and save'));
    await tester.pumpAndSettle();

    expect((await bridge.getConfig()).groqKeyLast4, 'WXYZ');
  });

  testWidgets('the MiniMax key can be removed', (tester) async {
    final bridge = FakeParleyBridge.ready(now: parleyTestNow);
    await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

    await tester.tap(find.text('Remove MiniMax key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check and save'));
    await tester.pumpAndSettle();

    expect((await bridge.getConfig()).minimaxKeyLast4, isNull);
    expect((await bridge.getStatus()).minimaxKeySet, isFalse);
  });
}
