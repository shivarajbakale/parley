import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/07-ds-date-strip.plan.md`.
void main() {
  late BuildContext ctx;
  late List<DateTime> selections;

  // Fixed, never `DateTime.now()`: a widget that reads the clock internally
  // cannot be golden-tested, which is why `today:` is a parameter.
  final today = DateTime(2026, 3, 11);

  setUp(() => selections = <DateTime>[]);

  Future<void> pump(
    WidgetTester tester, {
    DateTime? first,
    DateTime? last,
    DateTime? selected,
    bool compact = false,
    bool Function(DateTime)? isDayEnabled,
    Widget Function(BuildContext, DSDateState, DateTime)? dayBuilder,
    TextDirection direction = TextDirection.ltr,
    TextScaler textScaler = TextScaler.noScaling,
    ScrollController? controller,
    Widget? empty,
    // A test watching something move has to stop before it has stopped.
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Builder(
                    builder: (context) {
                      ctx = context;
                      final strip = compact
                          ? DSDateStrip.compact(
                              firstDate:
                                  first ??
                                  today.subtract(const Duration(days: 2)),
                              lastDate:
                                  last ?? today.add(const Duration(days: 4)),
                              today: today,
                              selectedDate: selected,
                              controller: controller,
                              isDayEnabled: isDayEnabled,
                              dayBuilder: dayBuilder,
                              empty: empty,
                              onDateSelected: selections.add,
                            )
                          : DSDateStrip(
                              firstDate:
                                  first ??
                                  today.subtract(const Duration(days: 2)),
                              lastDate:
                                  last ?? today.add(const Duration(days: 4)),
                              today: today,
                              selectedDate: selected,
                              controller: controller,
                              isDayEnabled: isDayEnabled,
                              dayBuilder: dayBuilder,
                              empty: empty,
                              onDateSelected: selections.add,
                            );
                      return strip;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  group('the range', () {
    testWidgets('renders one cell per day and nothing outside it', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(DSDateStripDay), findsNWidgets(7));
      expect(
        find.text('8'),
        findsNothing,
        reason: 'an infinite run of dead cells is a worse answer than an edge',
      );
      expect(find.text('9'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('an empty range shows the empty slot, not zero cells', (
      tester,
    ) async {
      await pump(
        tester,
        first: today,
        last: today.subtract(const Duration(days: 1)),
        empty: const Text('Nothing available'),
      );
      expect(find.byType(DSDateStripDay), findsNothing);
      expect(find.text('Nothing available'), findsOneWidget);
    });
  });

  group('semantics', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('each cell announces the full date, not the day number', (
      tester,
    ) async {
      await pump(tester, selected: today);
      final cells = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.inMutuallyExclusiveGroup ?? false),
            ),
          )
          .toList();
      expect(cells, hasLength(7));
      expect(
        cells.map((c) => c.properties.label).every((l) => l!.length > 2),
        isTrue,
      );
      expect(
        cells
            .firstWhere((c) => c.properties.selected ?? false)
            .properties
            .label,
        contains('today'),
      );
    });

    testWidgets('a disabled day is not selectable', (tester) async {
      await pump(tester, isDayEnabled: (date) => date.day != 12);
      await tester.tap(find.text('12'));
      await tester.pump();
      expect(selections, isEmpty);

      await tester.tap(find.text('13'));
      await tester.pump();
      expect(selections.single.day, 13);
    });
  });

  group('today and selected', () {
    testWidgets('today alone draws an outline and a dot', (tester) async {
      await pump(tester);
      final cell = tester.widget<DSDateStripDay>(
        find.byWidgetPredicate((w) => w is DSDateStripDay && w.state.today),
      );
      expect(cell.state.today, isTrue);
      expect(cell.state.selected, isFalse);
    });

    testWidgets('today and selected keeps the dot on the fill', (tester) async {
      await pump(tester, selected: today);
      final cell = tester.widget<DSDateStripDay>(
        find.byWidgetPredicate(
          (w) => w is DSDateStripDay && w.state.today && w.state.selected,
        ),
      );
      expect(cell.state.selected, isTrue);
      // The dot survives the fill: it is drawn in the on-colour rather than
      // dropped, so "today" is still legible on the selected day.
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byWidget(cell),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        ctx.palette.primaryForeground,
      );
    });

    testWidgets('no selection is a valid state', (tester) async {
      await pump(tester);
      expect(
        find.byWidgetPredicate((w) => w is DSDateStripDay && w.state.selected),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => w is DSDateStripDay && w.state.today),
        findsOneWidget,
      );
    });
  });

  group('the targets', () {
    testWidgets('compact cells are 40 wide and their targets are not', (
      tester,
    ) async {
      await pump(tester, compact: true);
      final floor = ctx.design.component.minTapTarget;
      expect(
        tester.getSize(find.byType(InkWell).first).width,
        greaterThanOrEqualTo(floor),
      );
      expect(ctx.design.component.wellSize, 40);
    });
  });

  group('the keyboard', () {
    testWidgets('is one tab stop, and arrows move by day and by week', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        first: today.subtract(const Duration(days: 10)),
        last: today.add(const Duration(days: 20)),
        selected: today,
        controller: controller,
      );

      final focus = Focus.of(tester.element(find.byType(DSDateStripDay).first));
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is DSDateStripDay && w.state.focused && w.date.day == 12,
        ),
        findsOneWidget,
      );

      final before = controller.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        greaterThan(before),
        reason: 'the focused cell is always scrolled into view',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
    });
  });

  group('direction', () {
    testWidgets('an RTL strip lays its first day out at the right edge', (
      tester,
    ) async {
      await pump(tester, direction: TextDirection.rtl);
      final first = tester.getRect(find.text('9'));
      final last = tester.getRect(find.text('15'));
      expect(
        first.left,
        greaterThan(last.left),
        reason: 'nothing is mirrored by hand — the layout is directional',
      );
    });
  });

  group('dayBuilder', () {
    testWidgets('replaces the paint and keeps the semantics', (tester) async {
      final handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics();
      await pump(
        tester,
        selected: today,
        dayBuilder: (context, state, date) =>
            Text('${date.day}${state.selected ? '*' : ''}'),
      );
      expect(find.byType(DSDateStripDay), findsNothing);
      expect(find.text('11*'), findsOneWidget);
      expect(
        tester
            .widgetList<Semantics>(
              find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    (w.properties.inMutuallyExclusiveGroup ?? false),
              ),
            )
            .length,
        7,
      );
      handle.dispose();
    });
  });

  group('text scale', () {
    testWidgets('past 1.6 the weekday row goes, whatever the caller asked', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(DSDateStripDay).evaluate().isNotEmpty, isTrue);
      final roomy = tester.widget<DSDateStripDay>(
        find.byType(DSDateStripDay).first,
      );
      expect(roomy.weekday, isNotNull);

      await pump(tester, textScaler: const TextScaler.linear(2));
      final tight = tester.widget<DSDateStripDay>(
        find.byType(DSDateStripDay).first,
      );
      expect(
        tight.weekday,
        isNull,
        reason: 'the weekday row cannot survive at that scale at any width',
      );
    });
  });

  group('the month', () {
    // Constructed rather than pumped: the range is arithmetic, and a lazy
    // ListView never builds the twenty cells that would have to be counted.
    DSDateStrip monthStrip(DateTime? month) =>
        DSDateStrip.month(month: month, onDateSelected: (_) {});

    test('a 31-day month runs to the 31st', () {
      final strip = monthStrip(DateTime(2026, 3, 17));
      expect(strip.firstDate, DateTime(2026, 3, 1));
      expect(strip.lastDate, DateTime(2026, 3, 31));
    });

    test('a common-year February stops at the 28th', () {
      expect(monthStrip(DateTime(2026, 2, 17)).lastDate, DateTime(2026, 2, 28));
    });

    test('a leap-year February reaches the 29th', () {
      expect(monthStrip(DateTime(2028, 2, 17)).lastDate, DateTime(2028, 2, 29));
    });

    test('December rolls the year rather than overflowing the month', () {
      expect(
        monthStrip(DateTime(2026, 12, 3)).lastDate,
        DateTime(2026, 12, 31),
      );
    });

    test('no month given is the month the clock is in', () {
      final now = DateTime.now();
      final strip = monthStrip(null);
      expect(strip.firstDate, DateTime(now.year, now.month, 1));
      expect(strip.lastDate, DateTime(now.year, now.month + 1, 0));
    });
  });

  group('the opening scroll', () {
    testWidgets('a late selection is on screen at the first frame', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        first: DateTime(2026, 3, 1),
        last: DateTime(2026, 3, 31),
        selected: DateTime(2026, 3, 28),
        controller: controller,
      );
      // The cell is built at all only because the viewport reaches it: a
      // strip parked on the 1st never constructs the 28th.
      expect(find.text('28'), findsOneWidget);
    });

    testWidgets('a selection already in view does not scroll', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        first: DateTime(2026, 3, 1),
        last: DateTime(2026, 3, 31),
        // Not the first day: the fourth is well inside the opening viewport,
        // and centring it would scroll a strip that had nothing to reveal —
        // clipping a half cell at the *leading* edge, where the page gutter
        // is, to move a day that was already on screen.
        selected: DateTime(2026, 3, 10),
        controller: controller,
      );
      expect(controller.offset, 0);
    });
  });

  group('the selection scroll', () {
    Future<void> pumpRange(
      WidgetTester tester,
      DateTime selected,
      ScrollController controller,
    ) => pump(
      tester,
      first: DateTime(2026, 3, 1),
      last: DateTime(2026, 3, 31),
      selected: selected,
      controller: controller,
    );

    testWidgets('a day arriving from off screen lands in the middle', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRange(tester, DateTime(2026, 3, 1), controller);
      await pumpRange(tester, DateTime(2026, 3, 16), controller);

      final viewport = tester.getRect(find.byType(ListView));
      expect(
        tester.getCenter(find.text('16')).dx,
        closeTo(viewport.center.dx, 40),
        reason: 'a day pinned to the leading edge shows nothing before it',
      );
    });

    testWidgets('a day already on screen does not move the strip', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRange(tester, DateTime(2026, 3, 1), controller);
      await pumpRange(tester, DateTime(2026, 3, 5), controller);
      expect(controller.offset, 0);
    });

    testWidgets('an arrow key scrolls only far enough to reveal the day', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpRange(tester, DateTime(2026, 3, 1), controller);

      final focus = Focus.of(tester.element(find.byType(DSDateStripDay).first));
      focus.requestFocus();
      await tester.pump();
      // Far enough to walk the focus off the trailing edge, one day at a time.
      for (var i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget);
      expect(
        controller.offset,
        lessThan(100),
        reason:
            'one keypress must not throw the strip half a viewport '
            'sideways: stepping is not jumping',
      );
    });
  });

  group('the travelling fill', () {
    Finder pill() => find.byKey(DSDateStrip.indicatorKey);

    Rect cellOf(WidgetTester tester, int day) => tester.getRect(
      find.byWidgetPredicate((w) => w is DSDateStripDay && w.date.day == day),
    );

    testWidgets('the selection is one pill, not a fill in every cell', (
      tester,
    ) async {
      await pump(tester, selected: today);
      expect(pill(), findsOneWidget);
      for (final cell in tester.widgetList<DSDateStripDay>(
        find.byType(DSDateStripDay),
      )) {
        expect(
          cell.fill,
          isFalse,
          reason:
              'a cell that paints its own fill cannot hand it to a '
              'neighbour: two boxes cross-fading is what travel replaces',
        );
      }
    });

    testWidgets('the pill comes to rest on the chosen day', (tester) async {
      await pump(tester, selected: today);
      await pump(tester, selected: today.add(const Duration(days: 2)));
      await tester.pumpAndSettle();
      expect(tester.getRect(pill()), cellOf(tester, today.day + 2));
    });

    testWidgets('it travels rather than jumping', (tester) async {
      await pump(tester, selected: today);
      final start = tester.getRect(pill()).left;
      await pump(
        tester,
        selected: today.add(const Duration(days: 2)),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 40));
      final middle = tester.getRect(pill()).left;
      await tester.pumpAndSettle();
      final end = tester.getRect(pill()).left;
      expect(middle, greaterThan(start));
      expect(
        middle,
        lessThan(end),
        reason: 'a pill already at its destination one frame in is a jump',
      );
    });

    testWidgets('it lands scaled to the cell it settles on', (tester) async {
      await pump(tester, selected: today);
      await pump(
        tester,
        selected: today.add(const Duration(days: 2)),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 16));
      final travelling = tester.getRect(pill()).width;
      await tester.pumpAndSettle();
      final landed = tester.getRect(pill()).width;
      expect(
        travelling,
        lessThan(landed),
        reason: 'the pill gathers on the way and settles at full size',
      );
    });

    testWidgets('the numerals change colour as the pill crosses them', (
      tester,
    ) async {
      double coverageOf(WidgetTester tester, int day) =>
          tester
              .widget<DSDateStripDay>(
                find.byWidgetPredicate(
                  (w) => w is DSDateStripDay && w.date.day == day,
                ),
              )
              .coverage ??
          0;

      await pump(tester, selected: today);
      final arriving = today.day + 2;
      expect(coverageOf(tester, arriving), 0);

      await pump(
        tester,
        selected: today.add(const Duration(days: 2)),
        settle: false,
      );
      // Sampled frame by frame rather than at a guessed instant: the pill
      // only reaches this cell late in the travel, and how late depends on
      // whether the platform is running a spring or the curve fallback.
      double covered = 0;
      for (var frame = 0; frame < 24 && covered == 0; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        covered = coverageOf(tester, arriving);
      }
      expect(
        covered,
        greaterThan(0),
        reason:
            'a cell that only rebuilds when the travel is over keeps a '
            'dark numeral under an arriving fill',
      );
    });

    testWidgets('no selection draws no pill', (tester) async {
      await pump(tester);
      expect(pill(), findsNothing);
    });

    testWidgets('a dayBuilder keeps the paint it was given', (tester) async {
      await pump(
        tester,
        selected: today,
        dayBuilder: (context, state, date) => Text('${date.day}'),
      );
      expect(
        pill(),
        findsNothing,
        reason: 'a caller who owns the pixels does not get a pill behind them',
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSDateStripStyle(cellWidth: 48, cellGap: 8);
      final merged = base.merge(const DSDateStripStyle(cellWidth: 40));
      expect(merged.cellWidth, 40);
      expect(merged.cellGap, 8, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSDateStripStyle(cellWidth: 0, cellHeight: 0);
      const b = DSDateStripStyle(cellWidth: 40, cellHeight: 80);
      final mid = a.lerp(b, 0.5);
      expect(mid.cellWidth, 20);
      expect(mid.cellHeight, 40);
    });
  });
}
