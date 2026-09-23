import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/03-ds-metric-bar.plan.md`.
void main() {
  late BuildContext ctx;
  const barWidth = 300.0;

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
                body: Center(
                  child: SizedBox(
                    width: barWidth,
                    child: Builder(
                      builder: (context) {
                        ctx = context;
                        return child;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The fill, found by its colour and taken last: the track is a
  /// `DecoratedBox` too, and when the bar is disabled both of them are
  /// `outlineSoft` — which is the disabled state, not an ambiguity.
  Size fillSize(WidgetTester tester, Color color) => tester.getSize(
    find
        .byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).color == color,
        )
        .last,
  );

  group('the fill', () {
    testWidgets('a near-zero value is still visible, and the text still tells '
        'the truth', (tester) async {
      await pump(
        tester,
        const DSMetricBar(label: 'Cache', value: 0.4, max: 100),
      );
      await tester.pumpAndSettle();
      final height = ctx.design.space.sm;
      expect(
        fillSize(tester, ctx.palette.chart[0]).width,
        greaterThanOrEqualTo(height),
        reason: 'a rounded cap swallows anything narrower than the bar height',
      );
      expect(find.text('0.4%'), findsOneWidget);
    });

    testWidgets('zero paints nothing at all', (tester) async {
      await pump(tester, const DSMetricBar(label: 'Cache', value: 0, max: 100));
      await tester.pumpAndSettle();
      expect(fillSize(tester, ctx.palette.chart[0]).width, 0);
      expect(find.text('0.0%'), findsOneWidget);
    });

    testWidgets('over the ceiling the fill caps at full and takes the warning '
        'tone', (tester) async {
      await pump(
        tester,
        const DSMetricBar(label: 'Backups', value: 146, max: 128),
      );
      await tester.pumpAndSettle();
      final fill = fillSize(tester, ctx.palette.warning);
      expect(fill.width, closeTo(barWidth, 0.5));
      expect(
        find.text('114.1%'),
        findsOneWidget,
        reason: 'the value text tells the truth at 114%',
      );
    });

    testWidgets('disabled keeps the height and drops the fill to the outline', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMetricBar(label: 'Archived', value: 0.6, enabled: false),
      );
      await tester.pumpAndSettle();
      expect(
        fillSize(tester, ctx.palette.borderSoft).height,
        ctx.design.space.sm,
        reason: 'a meter that vanishes when disabled makes the row above jump',
      );
    });
  });

  group('the header', () {
    testWidgets('no label means no header row at all', (tester) async {
      await pump(tester, const DSMetricBar(value: 0.4));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('thin drops the inline value', (tester) async {
      await pump(
        tester,
        const DSMetricBar(
          label: 'Secondary',
          value: 0.34,
          size: DSMetricBarSize.thin,
        ),
      );
      expect(find.text('Secondary'), findsOneWidget);
      expect(
        find.text('34.0%'),
        findsNothing,
        reason:
            'at h4 the figure is the larger of the two and the bar stops '
            'reading as primary',
      );
    });
  });

  group('stacked', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    Widget stacked(BuildContext context) => DSMetricBar.stacked(
      label: 'Storage',
      valueText: '128 GB',
      segments: [
        DSMetricSegment(
          label: 'Docs',
          value: 42,
          color: context.palette.chart[0],
        ),
        DSMetricSegment(
          label: 'Media',
          value: 31,
          color: context.palette.chart[1],
        ),
        DSMetricSegment(
          label: 'Other',
          value: 27,
          color: context.palette.chart[2],
        ),
      ],
    );

    testWidgets('emits one node carrying every segment, not one node per '
        'segment', (tester) async {
      await pump(tester, Builder(builder: stacked));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(DSMetricBar));
      expect(node.label, 'Storage');
      expect(node.value, contains('Docs 42 percent'));
      expect(node.value, contains('Media 31 percent'));
      expect(node.value, contains('Other 27 percent'));
      expect(
        node.childrenCount,
        0,
        reason:
            'three nodes make a screen reader walk a bar chart one rectangle '
            'at a time',
      );
    });

    testWidgets('the generated legend names every segment', (tester) async {
      await pump(tester, Builder(builder: stacked));
      await tester.pumpAndSettle();
      expect(find.byType(DSMetricBarLegend), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('a legend slot replaces the generated one wholesale', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSMetricBar.stacked(
            label: 'Storage',
            legend: const Text('ELSEWHERE'),
            segments: [
              DSMetricSegment(
                label: 'Docs',
                value: 42,
                color: context.palette.chart[0],
              ),
            ],
          ),
        ),
      );
      expect(find.text('ELSEWHERE'), findsOneWidget);
      expect(find.byType(DSMetricBarLegend), findsNothing);
    });
  });

  group('motion', () {
    testWidgets('reduced motion paints the final width on the first frame', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMetricBar(label: 'Goal', value: 0.5),
        reducedMotion: true,
      );
      expect(
        fillSize(tester, ctx.palette.chart[0]).width,
        closeTo(barWidth / 2, 0.5),
      );
    });

    testWidgets('a rebuild with an unchanged value starts no animation', (
      tester,
    ) async {
      const bar = DSMetricBar(label: 'Goal', value: 0.5);
      await pump(tester, bar);
      await tester.pumpAndSettle();
      final settled = fillSize(tester, ctx.palette.chart[0]).width;

      await pump(tester, bar);
      await tester.pump();
      expect(
        fillSize(tester, ctx.palette.chart[0]).width,
        closeTo(settled, 0.5),
        reason: 'a re-animated meter flashes back to zero on every rebuild',
      );
    });
  });

  group('the style object', () {
    testWidgets('a theme extension changes every bar below it', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSMetricBarStyle(height: 20)],
            ),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(
                  body: DSMetricBar(label: 'Goal', value: 0.5),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fillSize(tester, ctx.palette.chart[0]).height, 20);
    });

    testWidgets('an instance style beats it', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSMetricBarStyle(height: 20)],
            ),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(
                  body: DSMetricBar(
                    label: 'Goal',
                    value: 0.5,
                    style: DSMetricBarStyle(height: 6),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fillSize(tester, ctx.palette.chart[0]).height, 6);
    });

    test('merge takes the non-null fields of the layer above', () {
      const base = DSMetricBarStyle(height: 8, segmentGap: 2);
      final merged = base.merge(const DSMetricBarStyle(height: 12));
      expect(merged.height, 12);
      expect(merged.segmentGap, 2, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSMetricBarStyle(height: 0, segmentGap: 0);
      const b = DSMetricBarStyle(height: 10, segmentGap: 4);
      final mid = a.lerp(b, 0.5);
      expect(mid.height, 5);
      expect(mid.segmentGap, 2);
    });
  });
}
