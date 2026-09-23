import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/01-ds-progress-ring.plan.md`.
///
/// The painter is public precisely so these can assert the number that drove
/// the arc rather than the pixels it produced: a golden tells you the ring
/// changed, and this tells you which value changed it.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
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

  DSProgressRingPainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is DSProgressRingPainter,
                ),
              )
              .painter!
          as DSProgressRingPainter;

  group('the sweep', () {
    for (final (value, expected) in <(double, double)>[
      (0, 0),
      (0.34, 0.34),
      (1, 1),
      // Capped: two laps at a glance is indistinguishable from ten percent.
      (1.4, 1),
    ]) {
      testWidgets('a value of $value sweeps $expected', (tester) async {
        await pump(tester, DSProgressRing(label: 'Goal', value: value));
        await tester.pumpAndSettle();
        expect(painterOf(tester).sweep, closeTo(expected, 0.001));
      });
    }

    testWidgets('over target the arc takes the warning tone, not the '
        'category tone', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Budget', value: 1.14));
      await tester.pumpAndSettle();
      expect(painterOf(tester).arcColor, ctx.palette.warning);
      // closeTo, not 1: a spring settles asymptotically, and the frame the
      // controller stops on is a thousandth short of its target.
      expect(painterOf(tester).sweep, closeTo(1, 0.001));
    });

    testWidgets('under target it takes the first category arc', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Budget', value: 0.5));
      await tester.pumpAndSettle();
      expect(painterOf(tester).arcColor, ctx.palette.chart[0]);
    });
  });

  group('the painter is not hardcoded to one orientation', () {
    testWidgets('clockwise: false and a custom startAngle reach the paint', (
      tester,
    ) async {
      await pump(
        tester,
        const DSProgressRing(
          label: 'Countdown',
          value: 0.25,
          style: DSProgressRingStyle(clockwise: false, startAngle: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(painterOf(tester).clockwise, isFalse);
      expect(painterOf(tester).startAngle, 0);
    });

    testWidgets('the default starts at twelve o clock', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Goal', value: 0.5));
      expect(painterOf(tester).startAngle, closeTo(-math.pi / 2, 0.0001));
      expect(painterOf(tester).clockwise, isTrue);
    });
  });

  group('accessibility', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('the value is a sentence, not a bare number', (tester) async {
      await pump(
        tester,
        const DSProgressRing(
          label: 'Storage',
          value: 68.4,
          max: 128,
          valueText: '68.4 gigabytes',
          caption: 'of 128 gigabytes',
        ),
      );
      final node = tester.getSemantics(find.byType(DSProgressRing));
      expect(node.label, 'Storage');
      expect(node.value, '68.4 gigabytes of 128 gigabytes, 53 percent');
    });

    testWidgets('at zero it still says zero percent', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Goal', value: 0));
      final node = tester.getSemantics(find.byType(DSProgressRing));
      expect(node.value, '0%, 0 percent');
    });

    testWidgets('over target the sentence is not clamped even though the arc '
        'is', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Budget', value: 1.14));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(DSProgressRing));
      expect(
        node.value,
        contains('114 percent'),
        reason: 'a user over target sees 114%; only the arc stops at full',
      );
      expect(painterOf(tester).sweep, closeTo(1, 0.001));
    });

    testWidgets('the ring itself has nothing to say', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Goal', value: 0.4));
      final node = tester.getSemantics(find.byType(DSProgressRing));
      expect(node.childrenCount, 0);
    });
  });

  group('motion', () {
    testWidgets('reduced motion creates no controller and paints the final '
        'sweep on the first frame', (tester) async {
      await pump(
        tester,
        const DSProgressRing(label: 'Goal', value: 0.75),
        reducedMotion: true,
      );
      expect(painterOf(tester).sweep, 0.75);
      expect(
        find.descendant(
          of: find.byType(DSProgressRing),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
        reason:
            'the value is information and the sweep is decoration; a '
            'controller that only ever holds still is a ticker nobody asked '
            'for',
      );
    });

    testWidgets('with animation on, the first frame is not the final sweep', (
      tester,
    ) async {
      await pump(tester, const DSProgressRing(label: 'Goal', value: 0.75));
      expect(painterOf(tester).sweep, lessThan(0.75));
      await tester.pumpAndSettle();
      expect(painterOf(tester).sweep, closeTo(0.75, 0.001));
    });

    testWidgets('a rebuild with an unchanged value does not re-animate', (
      tester,
    ) async {
      const ring = DSProgressRing(label: 'Goal', value: 0.75);
      await pump(tester, ring);
      await tester.pumpAndSettle();
      await pump(tester, ring);
      await tester.pump();
      expect(painterOf(tester).sweep, closeTo(0.75, 0.001));
    });
  });

  group('the four layers stack', () {
    testWidgets('the spec supplies the defaults', (tester) async {
      await pump(tester, const DSProgressRing(label: 'Goal', value: 0.5));
      final painter = painterOf(tester);
      expect(painter.strokeWidth, 6);
      expect(painter.trackColor, ctx.palette.borderSoft);
      expect(painter.cap, StrokeCap.round);
    });

    testWidgets('a theme extension overrides only what it sets', (
      tester,
    ) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSProgressRingStyle(strokeWidth: 14)],
            ),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(
                  body: DSProgressRing(label: 'Goal', value: 0.5),
                );
              },
            ),
          ),
        ),
      );
      final painter = painterOf(tester);
      expect(painter.strokeWidth, 14);
      expect(
        painter.trackColor,
        ctx.palette.borderSoft,
        reason: 'and nothing else moved',
      );
    });

    testWidgets('the arcColor shorthand beats the style it is shorthand for', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSProgressRing(
            label: 'Goal',
            value: 0.5,
            arcColor: context.palette.chart[3],
            style: DSProgressRingStyle(arcColor: context.palette.chart[1]),
          ),
        ),
      );
      expect(painterOf(tester).arcColor, ctx.palette.chart[3]);
    });

    testWidgets('a compact scope shrinks a ring that did not ask', (
      tester,
    ) async {
      await pump(
        tester,
        const DSScope(
          density: DSDensity.compact,
          child: DSProgressRing(label: 'Goal', value: 0.5),
        ),
      );
      expect(painterOf(tester).strokeWidth, 5);
      expect(
        tester.getSize(find.byType(CustomPaint).first).width,
        greaterThan(0),
      );
    });

    testWidgets('an explicit size beats the scope', (tester) async {
      await pump(
        tester,
        const DSScope(
          density: DSDensity.compact,
          child: DSProgressRing(
            label: 'Goal',
            value: 0.5,
            size: DSProgressRingSize.hero,
          ),
        ),
      );
      expect(painterOf(tester).strokeWidth, 8);
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSProgressRingStyle(strokeWidth: 6, diameter: 56);
      final merged = base.merge(const DSProgressRingStyle(strokeWidth: 10));
      expect(merged.strokeWidth, 10);
      expect(merged.diameter, 56, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSProgressRingStyle(strokeWidth: 0, diameter: 0);
      const b = DSProgressRingStyle(strokeWidth: 10, diameter: 100);
      final mid = a.lerp(b, 0.5);
      expect(mid.strokeWidth, 5);
      expect(mid.diameter, 50);
    });
  });

  group('the formatter', () {
    testWidgets('defaults to a rounded percent', (tester) async {
      await pump(
        tester,
        const DSProgressRing(label: 'Goal', value: 68.4, max: 128),
      );
      expect(find.text('53%'), findsOneWidget);
    });

    testWidgets('an injected one replaces it without a locale branch inside '
        'the widget', (tester) async {
      await pump(
        tester,
        DSProgressRing(
          label: 'Goal',
          value: 3,
          max: 5,
          valueFormatter: (value, max) => '${value.toInt()} of ${max.toInt()}',
        ),
      );
      expect(find.text('3 of 5'), findsOneWidget);
    });
  });
}
