import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/models/parley.dart';
import 'package:parley_android/screens/parley/setup_page.dart';
import 'package:parley_android/services/parley/fake_parley_bridge.dart';

import '_parley_harness.dart';

/// Setup — one job per step, honest progress, and a grant that arrives while
/// a step is showing moves it on. The full walk is in `onboarding_test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress says which of six steps this is', (tester) async {
    await pumpParley(
      tester,
      const SetupPage(initialStep: 3),
      bridge: FakeParleyBridge(now: parleyTestNow),
    );
    expect(find.text('Turn on Parley in Accessibility'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.text('Password fields are never read.'), findsOneWidget);
  });

  testWidgets('the key step can switch to Deepgram and saves its key', (
    tester,
  ) async {
    final bridge = FakeParleyBridge(now: parleyTestNow);
    await pumpParley(tester, const SetupPage(initialStep: 1), bridge: bridge);
    expect(find.text('Your Groq key'), findsOneWidget);

    await tester.tap(find.text('Use Deepgram Nova-3 instead'));
    await tester.pumpAndSettle();
    expect(find.text('Your Deepgram key'), findsOneWidget);
    expect(find.text('Deepgram API key'), findsOneWidget);
    expect(find.text('Use Whisper (Groq) instead'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'dg_live_key_Q9z1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check key'));
    await tester.pumpAndSettle();

    final status = await bridge.getStatus();
    expect(status.transcriptionProvider, TranscriptionProvider.deepgram);
    expect(status.deepgramKeySet, isTrue);
    expect(status.groqKeySet, isFalse);
    expect(find.text('Microphone'), findsOneWidget);
  });

  testWidgets('the battery step can be skipped', (tester) async {
    await pumpParley(
      tester,
      const SetupPage(initialStep: 4),
      bridge: FakeParleyBridge(now: parleyTestNow),
    );
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Try it'), findsOneWidget);
  });

  testWidgets('the battery grant arriving moves the step on', (tester) async {
    final bridge = FakeParleyBridge(now: parleyTestNow);
    await pumpParley(tester, const SetupPage(initialStep: 4), bridge: bridge);

    await tester.tap(find.text('Let Parley run in the background'));
    await tester.pumpAndSettle();
    expect(bridge.openedSettings, [SystemSettingsTarget.battery]);

    bridge.simulate(
      (await bridge.getStatus()).copyWith(batteryUnrestricted: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try it'), findsOneWidget);
  });

  testWidgets('practice: Done appears once something was dictated', (
    tester,
  ) async {
    await pumpParley(
      tester,
      const SetupPage(initialStep: 5),
      bridge: FakeParleyBridge(now: parleyTestNow),
    );
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'testing one two three');
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
  });
}
