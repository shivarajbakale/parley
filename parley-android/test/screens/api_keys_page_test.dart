import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/models/parley.dart';
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

  group('transcription provider', () {
    testWidgets('opens on Whisper (Groq) with the Groq field', (tester) async {
      await pumpParley(tester, const ApiKeysPage());

      expect(find.text('Whisper (Groq)'), findsOneWidget);
      expect(find.text('Deepgram Nova-3'), findsOneWidget);
      expect(find.text('Groq API key'), findsOneWidget);
      expect(find.text('Deepgram API key'), findsNothing);
    });

    testWidgets('choosing Deepgram swaps the key field in place', (
      tester,
    ) async {
      await pumpParley(tester, const ApiKeysPage());

      await tester.tap(find.text('Deepgram Nova-3'));
      await tester.pumpAndSettle();

      expect(find.text('Deepgram API key'), findsOneWidget);
      expect(find.text('Groq API key'), findsNothing);
      expect(find.text('Required for transcription.'), findsOneWidget);
    });

    testWidgets('Deepgram with no key is refused and nothing switches', (
      tester,
    ) async {
      final bridge = FakeParleyBridge.ready(now: parleyTestNow);
      await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

      await tester.tap(find.text('Deepgram Nova-3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check and save'));
      await tester.pumpAndSettle();

      expect(find.text('Add a Deepgram key to use Deepgram.'), findsOneWidget);
      final config = await bridge.getConfig();
      expect(config.transcriptionProvider, TranscriptionProvider.groq);
      expect(config.deepgramKeyLast4, isNull);
    });

    testWidgets('a rejected Deepgram key keeps Groq in use', (tester) async {
      final bridge = FakeParleyBridge.ready(now: parleyTestNow);
      await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

      await tester.tap(find.text('Deepgram Nova-3'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'dg_bad_key_1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check and save'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid API Key'), findsOneWidget);
      final config = await bridge.getConfig();
      expect(config.transcriptionProvider, TranscriptionProvider.groq);
      expect(config.deepgramKeyLast4, isNull);
    });

    testWidgets('a good Deepgram key is saved and Deepgram takes over', (
      tester,
    ) async {
      final bridge = FakeParleyBridge.ready(now: parleyTestNow);
      await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

      await tester.tap(find.text('Deepgram Nova-3'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).first,
        'dg_live_key_Q9z1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check and save'));
      await tester.pumpAndSettle();

      final config = await bridge.getConfig();
      expect(config.transcriptionProvider, TranscriptionProvider.deepgram);
      expect(config.deepgramKeyLast4, 'Q9z1');
      expect(config.groqKeyLast4, 'x7Qa', reason: 'the Groq key is kept');
      final status = await bridge.getStatus();
      expect(status.transcriptionProvider, TranscriptionProvider.deepgram);
      expect(status.deepgramKeySet, isTrue);
      expect(status.ready, isTrue);
    });

    testWidgets(
      'switching back to Groq needs no retyping when a key is saved',
      (tester) async {
        final bridge = FakeParleyBridge.ready(now: parleyTestNow);
        await bridge.setKeys(deepgram: 'dg_live_key_Q9z1');
        await bridge.setTranscriptionProvider(TranscriptionProvider.deepgram);
        await pumpParley(tester, const ApiKeysPage(), bridge: bridge);

        expect(find.text('Deepgram API key'), findsOneWidget);
        expect(find.text('Saved ••Q9z1. Empty keeps it.'), findsOneWidget);

        await tester.tap(find.text('Whisper (Groq)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check and save'));
        await tester.pumpAndSettle();

        final config = await bridge.getConfig();
        expect(config.transcriptionProvider, TranscriptionProvider.groq);
        expect(config.deepgramKeyLast4, 'Q9z1');
      },
    );
  });

  group('ParleyStatus.ready', () {
    const base = ParleyStatus(serviceBound: true, micGranted: true);

    test('reads the chosen provider\'s key', () {
      expect(base.copyWith(groqKeySet: true).ready, isTrue);
      expect(
        base
            .copyWith(
              groqKeySet: true,
              transcriptionProvider: TranscriptionProvider.deepgram,
            )
            .ready,
        isFalse,
      );
      expect(
        base
            .copyWith(
              deepgramKeySet: true,
              transcriptionProvider: TranscriptionProvider.deepgram,
            )
            .ready,
        isTrue,
      );
    });

    test('crosses the bridge by name, defaulting to Groq', () {
      expect(
        ParleyStatus.fromMap(const {}).transcriptionProvider,
        TranscriptionProvider.groq,
      );
      final s = ParleyStatus.fromMap(const {
        'deepgramKeySet': true,
        'transcriptionProvider': 'deepgram',
      });
      expect(s.transcriptionProvider, TranscriptionProvider.deepgram);
      expect(s.transcriptionKeySet, isTrue);
      final c = ParleyConfig.fromMap(const {
        'transcriptionProvider': 'deepgram',
        'deepgramKeyLast4': 'Q9z1',
      });
      expect(c.transcriptionKeyLast4, 'Q9z1');
      expect(c.toMap()['transcriptionProvider'], 'deepgram');
    });
  });
}
