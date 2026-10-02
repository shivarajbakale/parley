import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:parley_android/design_system/ds_card.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';

void main() {
  group('AppHaptics gate', () {
    tearDown(() => AppHaptics.enabled = true);

    test('helpers are no-ops when disabled (no throw, honours setting)', () {
      AppHaptics.enabled = false;
      // Should not touch the platform channel / should be silently ignored.
      expect(AppHaptics.selection, returnsNormally);
      expect(AppHaptics.light, returnsNormally);
      expect(AppHaptics.medium, returnsNormally);
      expect(AppHaptics.heavy, returnsNormally);
      expect(AppHaptics.success, returnsNormally);
      expect(AppHaptics.warning, returnsNormally);
      expect(AppHaptics.error, returnsNormally);
    });

    test(
      'defaults to enabled so the app feels tactile before settings load',
      () {
        expect(AppHaptics.enabled, isTrue);
      },
    );
  });

  group('DSSkeleton', () {
    testWidgets('delegates to the skeletonizer package rather than '
        'hand-drawn placeholder boxes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DSSkeleton(child: Text('content'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(_skeletonizer, findsOneWidget);
      expect(tester.widget<Skeletonizer>(_skeletonizer).enabled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('enabled: false renders the real content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DSSkeleton(enabled: false, child: Text('content')),
          ),
        ),
      );
      await tester.pump();

      expect(tester.widget<Skeletonizer>(_skeletonizer).enabled, isFalse);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('DSSkeletonList builds its rows from the real list row, so '
        'the skeleton cannot drift out of shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DSSkeletonList(itemCount: 4))),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The loading state is the row's own skeleton, which takes its extents
      // from the same spec values the loaded row does — so the list does not
      // jump when the data lands.
      expect(find.byType(DSListTileSkeleton), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('DSCard depth', () {
    testWidgets('elevated variant paints the shared AppShadows box shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DSCard(child: Text('card'))),
        ),
      );

      // A [ShapeDecoration] rather than a [BoxDecoration]: the card takes an
      // [OutlinedBorder] so it can draw Apple's continuous curve, which a
      // BorderRadius cannot express.
      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<ShapeDecoration>()
          .firstWhere((d) => d.shadows != null && d.shadows!.isNotEmpty);
      expect(decoration.shadows, isNotEmpty);
      expect(decoration.shape, isA<OutlinedBorder>());
    });

    testWidgets('hero gradient renders and overrides the flat colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => DSCard(
                style: DSCardStyle(
                  fillGradient: LinearGradient(
                    colors: [context.palette.secondary, context.palette.card],
                  ),
                ),
                child: const Text('hero'),
              ),
            ),
          ),
        ),
      );

      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<ShapeDecoration>()
          .firstWhere((d) => d.gradient != null);
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.color, isNull); // gradient replaces the flat fill
    });
  });
}

/// `Skeletonizer` is an abstract widget with const factories, so `byType`
/// (which matches the exact runtime type) never finds it.
final _skeletonizer = find.byWidgetPredicate((w) => w is Skeletonizer);
