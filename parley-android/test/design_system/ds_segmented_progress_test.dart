import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/04-ds-segmented-progress.plan.md`.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    ctx = context;
                    return Center(child: child);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('semantics', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('without onStepTap there is exactly one node', (tester) async {
      await pump(
        tester,
        const DSSegmentedProgress(
          label: 'Payment',
          currentStep: 3,
          totalSteps: 5,
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(DSSegmentedProgress));
      expect(node.value, 'Step 3 of 5, Payment');
      expect(
        node.childrenCount,
        0,
        reason:
            'nobody wants to arrow through five rectangles to learn they are '
            'on step three',
      );
    });

    testWidgets('with onStepTap only reached steps become buttons', (
      tester,
    ) async {
      await pump(
        tester,
        DSSegmentedProgress(
          label: 'Checkout',
          currentStep: 3,
          totalSteps: 5,
          onStepTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final buttons = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.button ?? false),
      );
      expect(
        tester.widgetList(buttons).length,
        3,
        reason: 'steps 1, 2 and 3 are reached; 4 and 5 are not',
      );
    });

    testWidgets('an error step says so in words, not only in colour', (
      tester,
    ) async {
      await pump(
        tester,
        DSSegmentedProgress(
          currentStep: 3,
          totalSteps: 5,
          errorSteps: const {2},
          onStepTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.button ?? false),
            ),
          )
          .map((w) => w.properties.label)
          .toList();
      expect(labels, contains('Step 2, has an error'));
    });
  });

  group('the tap target is not the painted segment', () {
    testWidgets('the segment stays six points while the target clears the '
        'floor', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress(
            currentStep: 2,
            totalSteps: 4,
            onStepTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(DSSegmentedProgress),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(painted.height, ctx.design.space.sm - ctx.design.space.hairline);
      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
    });

    testWidgets('without onStepTap it draws no ink at all', (tester) async {
      await pump(
        tester,
        const DSSegmentedProgress(currentStep: 2, totalSteps: 4),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('the target sizes every cell, not only the reachable ones', (
      tester,
    ) async {
      // Reachability varies step by step; cell height must not. When it did,
      // the three reachable steps' labels sat 24 points below the two
      // upcoming ones' and the connectors ran above the nodes they joined.
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const <String>['Cart', 'Ship', 'Pay', 'Review', 'Done'],
            onStepTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tops = <String, double>{
        for (final name in ['Cart', 'Ship', 'Pay', 'Review', 'Done'])
          name: tester.getRect(find.text(name)).top,
      };
      expect(
        tops.values.toSet(),
        hasLength(1),
        reason: 'every label starts on one line: $tops',
      );
    });

    testWidgets('a read-only labelled row is not padded to a finger', (
      tester,
    ) async {
      // The other half of the same rule: nothing is tappable, so no cell is
      // grown, and a display-only row keeps the node's own height.
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const <String>['Cart', 'Ship', 'Pay', 'Review', 'Done'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tops = <double>[
        for (final name in ['Cart', 'Ship', 'Pay', 'Review', 'Done'])
          tester.getRect(find.text(name)).top,
      ];
      expect(tops.toSet(), hasLength(1));
      expect(
        tester.getSize(find.byType(DSSegmentedProgress)).height,
        lessThan(ctx.design.component.minTapTarget + ctx.design.space.xl),
      );
    });
  });

  group('the states', () {
    testWidgets('the last step is current, not current and complete', (
      tester,
    ) async {
      await pump(
        tester,
        const DSSegmentedProgress(currentStep: 5, totalSteps: 5),
      );
      final progress = tester.widget<DSSegmentedProgress>(
        find.byType(DSSegmentedProgress),
      );
      expect(progress.stateOf(5), DSStepState.current);
      expect(progress.stateOf(4), DSStepState.complete);
    });

    testWidgets('a skipped step keeps its place in the count', (tester) async {
      await pump(
        tester,
        const DSSegmentedProgress(
          currentStep: 4,
          totalSteps: 5,
          skippedSteps: {3},
        ),
      );
      final progress = tester.widget<DSSegmentedProgress>(
        find.byType(DSSegmentedProgress),
      );
      expect(progress.stateOf(3), DSStepState.skipped);
      expect(progress.totalSteps, 5);
    });

    testWidgets('the current segment is wider than its neighbours', (
      tester,
    ) async {
      await pump(
        tester,
        const SizedBox(
          width: 320,
          child: DSSegmentedProgress(currentStep: 2, totalSteps: 4),
        ),
      );
      await tester.pumpAndSettle();
      final segments = tester
          .widgetList<Expanded>(
            find.descendant(
              of: find.byType(DSSegmentedProgress),
              matching: find.byType(Expanded),
            ),
          )
          .toList();
      expect(segments[1].flex, greaterThan(segments[0].flex));
      expect(
        segments[0].flex,
        segments[2].flex,
        reason: 'only the current step carries the extra width',
      );
    });
  });

  group('stepBuilder', () {
    testWidgets('replaces the paint and keeps the semantics', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress(
            label: 'Custom',
            currentStep: 2,
            totalSteps: 3,
            stepBuilder: (context, state, index) =>
                Text('$index:${state.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1:complete'), findsOneWidget);
      expect(find.text('2:current'), findsOneWidget);
      expect(find.text('3:upcoming'), findsOneWidget);
    });
  });

  group('labelled', () {
    testWidgets('five steps build', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 340,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsOneWidget);
    });

    test('six steps refuse to build rather than truncating a name', () {
      expect(
        () => DSSegmentedProgress.labelled(
          currentStep: 1,
          stepLabels: const ['a', 'b', 'c', 'd', 'e', 'f'],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('at text scale 2 it collapses to the bar rather than '
        'shrinking the labels', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 340,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
          ),
        ),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pay'), findsNothing);
      expect(
        find.byType(Expanded),
        findsWidgets,
        reason: 'the bar is what is left when the labels cannot fit',
      );
    });

    testWidgets('the nodes sit on one pitch whatever the names are', (
      tester,
    ) async {
      // The defect this replaces: every cell was as wide as its own label, so
      // the gap between a node and the rule beside it was (label - node) / 2
      // and no two of them matched. "Review" held its rules eight points
      // further off than "Pay" did, and the five nodes were not evenly spaced
      // at any step.
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final centres = <double>[
        for (final name in ['Cart', 'Ship', 'Pay', 'Review', 'Done'])
          tester.getRect(find.text(name)).center.dx,
      ];
      final pitches = <double>[
        for (var i = 1; i < centres.length; i++) centres[i] - centres[i - 1],
      ];
      for (final pitch in pitches) {
        expect(pitch, closeTo(pitches.first, 0.01), reason: '$pitches');
      }
    });

    testWidgets('advancing the step does not move the row sideways', (
      tester,
    ) async {
      // The current label is bold, and bold is wider. While the cells were
      // sized by their labels that width difference moved every node the
      // moment the step advanced.
      const names = ['Cart', 'Ship', 'Pay', 'Review', 'Done'];
      Future<List<double>> centresAt(int step) async {
        await pump(
          tester,
          SizedBox(
            width: 320,
            child: DSSegmentedProgress.labelled(
              currentStep: step,
              stepLabels: names,
            ),
          ),
        );
        await tester.pumpAndSettle();
        return <double>[
          for (final name in names) tester.getRect(find.text(name)).center.dx,
        ];
      }

      final before = await centresAt(2);
      final after = await centresAt(3);
      for (var i = 0; i < names.length; i++) {
        expect(after[i], closeTo(before[i], 0.01), reason: names[i]);
      }
    });

    testWidgets('the current node is bigger than the ones around it', (
      tester,
    ) async {
      // Size is the redundant channel here. completeColor and currentColor
      // default to one hue two lightness steps apart, so without this the
      // tick and the digit were the only thing separating done from doing.
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Size nodeOf(String digit) => tester.getSize(
        find
            .ancestor(of: find.text(digit), matching: find.byType(SizedBox))
            .first,
      );
      expect(nodeOf('3').width, greaterThan(nodeOf('4').width));
      expect(nodeOf('4').width, nodeOf('5').width);
    });

    testWidgets('the name is part of the target rather than padding under it', (
      tester,
    ) async {
      // Growing the *cell* to a finger centred a node in a 48-point box and
      // left twelve points of nothing above the name, which read as two rows.
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 3,
            stepLabels: const ['Cart', 'Ship', 'Pay', 'Review', 'Done'],
            onStepTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getRect(
        find
            .ancestor(of: find.text('3'), matching: find.byType(SizedBox))
            .first,
      );
      expect(
        tester.getRect(find.text('Pay')).top - node.bottom,
        lessThanOrEqualTo(ctx.design.space.sm),
      );
      // And the pair still clears the floor.
      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
    });

    testWidgets('the rule fills over time rather than snapping', (
      tester,
    ) async {
      // The labelled shape read none of `animatedStep` while sitting inside
      // the tween that computes it, so it was the one shape that jumped.
      const names = ['Cart', 'Ship', 'Pay', 'Review', 'Done'];
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 2,
            stepLabels: names,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pump(
        tester,
        SizedBox(
          width: 320,
          child: DSSegmentedProgress.labelled(
            currentStep: 4,
            stepLabels: names,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(ctx.design.motion.normal ~/ 2);
      final factors = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((box) => box.widthFactor ?? 0)
          .toList();
      expect(
        factors.any((factor) => factor > 0 && factor < 1),
        isTrue,
        reason: 'mid-transition one rule is part filled: $factors',
      );
      await tester.pumpAndSettle();
    });
  });

  group('the counter', () {
    testWidgets('defaults to "3 of 5"', (tester) async {
      await pump(
        tester,
        const DSSegmentedProgress(
          label: 'Payment',
          currentStep: 3,
          totalSteps: 5,
        ),
      );
      expect(find.text('3 of 5'), findsOneWidget);
    });

    testWidgets('an injected formatter replaces it', (tester) async {
      await pump(
        tester,
        DSSegmentedProgress(
          label: 'Payment',
          currentStep: 3,
          totalSteps: 5,
          counterFormatter: (current, total) => '$current/$total',
        ),
      );
      expect(find.text('3/5'), findsOneWidget);
    });

    testWidgets('a counter slot replaces it wholesale', (tester) async {
      await pump(
        tester,
        const DSSegmentedProgress(
          label: 'Payment',
          currentStep: 3,
          totalSteps: 5,
          counterSlot: Text('almost there'),
        ),
      );
      expect(find.text('almost there'), findsOneWidget);
      expect(find.text('3 of 5'), findsNothing);
    });
  });

  group('the style object', () {
    testWidgets('the width channel cannot be styled away', (tester) async {
      await pump(tester, const SizedBox.shrink());
      expect(
        () => DSSegmentedProgressStyle.resolve(
          ctx,
          const DSSegmentedProgressStyle(currentFlex: 1),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('the diameter channel cannot be styled away either', (
      tester,
    ) async {
      await pump(tester, const SizedBox.shrink());
      expect(
        () => DSSegmentedProgressStyle.resolve(
          ctx,
          DSSegmentedProgressStyle(
            nodeSize: ctx.design.space.xl,
            currentNodeSize: ctx.design.space.xl,
          ),
        ),
        throwsAssertionError,
      );
    });

    test('merge takes the non-null fields of the layer above', () {
      const base = DSSegmentedProgressStyle(segmentHeight: 6, segmentGap: 4);
      final merged = base.merge(const DSSegmentedProgressStyle(segmentGap: 8));
      expect(merged.segmentGap, 8);
      expect(merged.segmentHeight, 6, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSSegmentedProgressStyle(segmentHeight: 0, currentFlex: 1);
      const b = DSSegmentedProgressStyle(segmentHeight: 10, currentFlex: 2);
      final mid = a.lerp(b, 0.5);
      expect(mid.segmentHeight, 5);
      expect(mid.currentFlex, 1.5);
    });
  });

  group('the range', () {
    test('a current step outside the sequence refuses to build', () {
      expect(
        () => DSSegmentedProgress(currentStep: 0, totalSteps: 5),
        throwsAssertionError,
      );
      expect(
        () => DSSegmentedProgress(currentStep: 6, totalSteps: 5),
        throwsAssertionError,
      );
    });
  });
}
