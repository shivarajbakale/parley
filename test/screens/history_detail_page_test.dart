import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/parley/history_detail_page.dart';

import '_parley_harness.dart';

/// Transcript — the Detail archetype: the words, the facts, Copy pinned.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a dictation shows its words and details', (tester) async {
    await pumpParley(tester, HistoryDetailPage(id: 12, now: parleyTestNow));

    expect(
      find.textContaining(RegExp('you said', caseSensitive: false)),
      findsOneWidget,
    );
    expect(
      find.text('“Running ten minutes late, start without me.”'),
      findsOneWidget,
    );
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Inserted'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('an edit shows the instruction, before and after', (
    tester,
  ) async {
    await pumpParley(tester, HistoryDetailPage(id: 11, now: parleyTestNow));

    expect(
      find.textContaining(RegExp('you asked', caseSensitive: false)),
      findsOneWidget,
    );
    expect(find.text('“Make it friendlier and shorter.”'), findsOneWidget);
    expect(
      find.textContaining(RegExp('^before\$', caseSensitive: false)),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp('^after\$', caseSensitive: false)),
      findsOneWidget,
    );
    expect(find.text('Copy rewritten text'), findsOneWidget);
  });

  testWidgets('Copy puts the text on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpParley(tester, HistoryDetailPage(id: 12, now: parleyTestNow));

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, ['Running ten minutes late, start without me.']);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('a missing entry says so in a snack bar', (tester) async {
    await pumpParley(tester, HistoryDetailPage(id: 404, now: parleyTestNow));
    await tester.pumpAndSettle();
    expect(find.text('That transcript no longer exists'), findsOneWidget);
  });
}
