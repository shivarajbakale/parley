import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// What `DSChart` claims, and the one claim that is a defence rather than a
/// feature:
///
///   * a series takes its colour from the identity by name, so nobody picks a
///     hex and two charts of the same thing match;
///   * the scrub reads the data under the finger and says so out loud;
///   * **the scrub reaches the chart from inside a scrolling page, and a plain
///     drag still belongs to the page.** The library's own touch is a pan, and
///     a pan loses the arena to any scrollable's drag — so a drag-to-scrub
///     works on a screen with nothing to scroll and quietly does not on the
///     screen it ships in. The long press wins outright, which is the whole
///     reason it is a long press.
void main() {
  late BuildContext ctx;
  late List<MethodCall> haptics;

  setUp(() {
    haptics = <MethodCall>[];
    AppHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return SizedBox(width: 320, child: child);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const revenue = DSSeries(name: 'Revenue', values: [10, 20, 15, 30]);
  const costs = DSSeries(name: 'Costs', values: [5, 8, 9, 7]);
  const labels = ['Q1', 'Q2', 'Q3', 'Q4'];

  group('the series colour comes from the identity', () {
    testWidgets('a line takes its hue from the category ramp, by name', (
      tester,
    ) async {
      await pump(tester, const DSChart.line(series: [revenue], labels: labels));

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.lineBarsData.first.color,
        DSChart.seriesColor(ctx.palette, 'Revenue'),
      );
    });

    testWidgets(
      'colorKey decides the hue, so a localised name cannot move it',
      (tester) async {
        await pump(
          tester,
          const DSChart.line(
            series: [
              DSSeries(
                name: 'Chiffre d\'affaires',
                values: [10, 20, 15, 30],
                colorKey: 'Revenue',
              ),
            ],
            labels: labels,
          ),
        );

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(
          chart.data.lineBarsData.first.color,
          DSChart.seriesColor(ctx.palette, 'Revenue'),
          reason: 'the display name moved but the identity did not',
        );
      },
    );

    testWidgets(
      'the wash under the line is on for one series and off for two',
      (tester) async {
        await pump(
          tester,
          const DSChart.line(series: [revenue], labels: labels),
        );
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .lineBarsData
              .first
              .belowBarData
              .show,
          isTrue,
        );

        await pump(
          tester,
          const DSChart.line(series: [revenue, costs], labels: labels),
        );
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .lineBarsData
              .every((b) => !b.belowBarData.show),
          isTrue,
          reason: 'two translucent fills over each other make a third colour',
        );
      },
    );
  });

  group('the axis', () {
    testWidgets('a bar chart starts at zero however high the bars are', (
      tester,
    ) async {
      await pump(
        tester,
        const DSChart.bar(
          series: [
            DSSeries(name: 'Revenue', values: [90, 92, 94, 96]),
          ],
          labels: labels,
        ),
      );

      expect(
        tester.widget<BarChart>(find.byType(BarChart)).data.minY,
        0,
        reason: 'a bar is read by its area, so a cropped baseline lies',
      );
    });

    testWidgets('a sparkline draws no axes and no grid', (tester) async {
      await pump(tester, const DSChart.sparkline(values: [1, 4, 2, 6]));

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.titlesData.show, isFalse);
      expect(data.gridData.show, isFalse);
    });
  });

  group('the scrub', () {
    testWidgets('a long press reads out the point under the finger', (
      tester,
    ) async {
      await pump(tester, const DSChart.line(series: [revenue], labels: labels));

      Finder inReadout(String text) => find.descendant(
        of: find.byKey(readoutKey),
        matching: find.text(text),
      );

      expect(find.byKey(readoutKey), findsNothing);

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(
        Offset(box.right - 4, box.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump();

      expect(inReadout('30'), findsOneWidget, reason: 'the last value');
      expect(inReadout('Q4'), findsOneWidget, reason: 'and its label');
      expect(haptics, isNotEmpty, reason: 'the point was felt, not only seen');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        find.byKey(readoutKey),
        findsNothing,
        reason: 'the readout let go',
      );
    });

    testWidgets('a bar scrub marks the bar it is reading', (tester) async {
      // The readout is only half of a scrub. On a line the finger is followed
      // by a rule and a dot; a bar plot cannot take a vertical line at all —
      // `fl_chart` refuses to paint one — so the bar under the finger stands
      // in a ground instead. Without it the readout named a value and nothing
      // on the plot said which bar it had come from.
      await pump(tester, const DSChart.bar(series: [revenue], labels: labels));

      List<bool> bandsShown() => tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups
          .map((g) => g.barRods.first.backDrawRodData.show)
          .toList();

      expect(
        bandsShown(),
        everyElement(isFalse),
        reason: 'at rest nothing is being read, so nothing is marked',
      );

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(
        Offset(box.right - 20, box.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump();

      expect(
        find.descendant(of: find.byKey(readoutKey), matching: find.text('Q4')),
        findsOneWidget,
      );
      // Exactly one, and it is the one the readout named. Two grounds is two
      // answers to "which bar".
      expect(bandsShown(), [false, false, false, true]);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        bandsShown(),
        everyElement(isFalse),
        reason: 'the mark let go with the readout',
      );
    });

    testWidgets('a stacked bar takes the same ground', (tester) async {
      // One rod carrying every series, so the mark cannot be per-series
      // either — a stack that highlighted only its first band would say the
      // reader was reading a part of a total they had asked the whole of.
      await pump(
        tester,
        const DSChart.bar(
          series: [revenue, costs],
          labels: labels,
          grouping: DSBarGrouping.stacked,
        ),
      );

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(
        Offset(box.left + box.width * 0.2, box.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump();

      final groups = tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups;
      expect(
        groups.where((g) => g.barRods.first.backDrawRodData.show),
        hasLength(1),
      );

      await gesture.up();
    });

    testWidgets('a sparkline is scrubbed too, and reads out its number', (
      tester,
    ) async {
      // A sparkline has no axes and no labels, so the readout is the only
      // way the shape beside a figure can be asked what it is worth at a
      // point. It is still a chart, and every chart answers a finger.
      await pump(
        tester,
        const DSChart.sparkline(values: [12, 24, 18, 30], name: 'Revenue'),
      );

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(
        Offset(box.right - 4, box.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump();

      expect(
        find.descendant(of: find.byKey(readoutKey), matching: find.text('30')),
        findsOneWidget,
      );
      // No category label: a sparkline was given numbers, not names, and a
      // readout that invented one would be reading out an index.
      expect(
        find.descendant(of: find.byKey(readoutKey), matching: find.text('Q4')),
        findsNothing,
      );

      await gesture.up();
    });

    testWidgets('enabled: false leaves a picture', (tester) async {
      await pump(
        tester,
        const DSChart.line(series: [revenue], labels: labels, enabled: false),
      );

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(box.center);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump();

      expect(find.byKey(readoutKey), findsNothing);
      await gesture.up();
    });

    testWidgets('a plain horizontal drag still turns the page', (tester) async {
      // A guard rather than a repair: measured against fl_chart 1.2.0 the
      // library's pan already loses this arena to the page's drag. What this
      // pins is that the chart never grows a recogniser that would win it —
      // the tab swipe is not something a component gets to take.
      final controller = PageController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        SizedBox(
          height: 400,
          child: PageView(
            controller: controller,
            children: const [
              Center(
                child: DSChart.line(series: [revenue], labels: labels),
              ),
              Center(child: Text('page two')),
            ],
          ),
        ),
      );

      await tester.fling(find.byType(DSChart), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(
        controller.page,
        1,
        reason: 'the chart swallowed the swipe to the next page',
      );
    });
  });

  group('the scrub inside a scrolling page', () {
    testWidgets('the scrub reaches the chart from inside a scrolling list', (
      tester,
    ) async {
      // The claim the long press exists for. A drag here would be taken by the
      // list — the library's own pan needs kPanSlop and the list's drag needs
      // half of it — so a drag-scrub would read nothing on exactly the screens
      // a chart ships on.
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await pump(
        tester,
        SizedBox(
          height: 400,
          child: ListView(
            controller: controller,
            children: [
              const DSChart.line(series: [revenue], labels: labels),
              for (var i = 0; i < 12; i++)
                SizedBox(height: 80, child: Text('row $i')),
            ],
          ),
        ),
      );

      final box = tester.getRect(find.byType(DSChart));
      final gesture = await tester.startGesture(
        Offset(box.left + 8, box.center.dy),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await gesture.moveBy(Offset(box.width - 16, 0));
      await tester.pump();

      expect(find.byKey(readoutKey), findsOneWidget);
      expect(
        controller.offset,
        0,
        reason: 'the list moved instead of the scrub reading',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('what a screen reader hears', () {
    testWidgets('a chart describes itself rather than staying silent', (
      tester,
    ) async {
      await pump(tester, const DSChart.line(series: [revenue], labels: labels));

      expect(
        tester.getSemantics(find.byType(DSChart)).label,
        contains('Revenue, 4 points, 10 to 30, trending up'),
      );
    });

    testWidgets('an explicit label wins', (tester) async {
      await pump(
        tester,
        const DSChart.line(
          series: [revenue],
          labels: labels,
          semanticsLabel: 'Revenue up 200% over the quarter',
        ),
      );

      expect(
        tester.getSemantics(find.byType(DSChart)).label,
        'Revenue up 200% over the quarter',
      );
    });
  });

  group('the style chain', () {
    testWidgets('the grid and the line come from the spec', (tester) async {
      await pump(tester, const DSChart.line(series: [revenue], labels: labels));

      final resolved = DSChartStyle.resolve(ctx, DSChartKind.line);
      expect(resolved.gridColor, ctx.palette.borderSoft);
      expect(resolved.lineWidth, ctx.design.component.chartLineWidth);
      expect(resolved.height, ctx.design.component.chartHeight);
    });

    testWidgets('a sparkline resolves to the sparkline height', (tester) async {
      await pump(tester, const DSChart.sparkline(values: [1, 2, 3]));

      expect(
        DSChartStyle.resolve(ctx, DSChartKind.sparkline).height,
        ctx.design.component.sparklineHeight,
      );
    });

    testWidgets('an instance style overrides the spec default', (tester) async {
      await pump(
        tester,
        const DSChart.line(
          series: [revenue],
          labels: labels,
          style: DSChartStyle(lineWidth: 9),
        ),
      );

      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData
            .first
            .barWidth,
        9,
      );
    });

    test('merge takes the other side field by field', () {
      const base = DSChartStyle(lineWidth: 2, dotRadius: 3);
      const patch = DSChartStyle(dotRadius: 6, barWidth: 10);

      final merged = base.merge(patch);
      expect(merged.lineWidth, 2);
      expect(merged.dotRadius, 6);
      expect(merged.barWidth, 10);
      expect(base.merge(null), same(base));
    });

    test('lerp walks every field', () {
      const a = DSChartStyle(
        gridColor: Color(0xFF000000),
        lineWidth: 2,
        barWidth: 10,
        scrubBandColor: Color(0xFF000000),
      );
      const b = DSChartStyle(
        gridColor: Color(0xFFFFFFFF),
        lineWidth: 6,
        barWidth: 20,
        scrubBandColor: Color(0xFFFFFFFF),
      );

      final half = a.lerp(b, 0.5);
      expect(half.lineWidth, 4);
      expect(half.barWidth, 15);
      expect(half.gridColor, Color.lerp(a.gridColor, b.gridColor, 0.5));
      expect(
        half.scrubBandColor,
        Color.lerp(a.scrubBandColor, b.scrubBandColor, 0.5),
      );
      expect(a.lerp(null, 0.5), same(a));
    });

    test('copyWith replaces only what it is given', () {
      const base = DSChartStyle(lineWidth: 2, dotRadius: 3);
      final copy = base.copyWith(dotRadius: 8);
      expect(copy.lineWidth, 2);
      expect(copy.dotRadius, 8);
    });
  });
}
