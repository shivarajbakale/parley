import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/parley/empty_scene.dart';

import '_parley_harness.dart';

/// The empty-state scenes are decorative: they draw, they hold still when
/// motion is off, and they add nothing to the semantics tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final scenes = <String, Widget>{
    'dictate': const EmptyScene.dictate(),
    'asleep': const EmptyScene.asleep(),
    'noMatch': const EmptyScene.noMatch(),
    'progress': const EmptyScene.progress(done: 2, total: 4),
    'progress complete': const EmptyScene.progress(done: 4, total: 4),
  };

  for (final MapEntry(:key, :value) in scenes.entries) {
    testWidgets('$key draws, settles and stays out of semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpParley(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: value)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byWidget(value), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getSemantics(find.byWidget(value)).label, isEmpty);
      handle.dispose();
    });
  }

  test('progress rejects more steps done than exist', () {
    expect(() => EmptyScene.progress(done: 5, total: 4), throwsAssertionError);
  });
}
