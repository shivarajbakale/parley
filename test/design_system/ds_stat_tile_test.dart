import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/02-ds-stat-tile.plan.md`, and the half of
/// `docs/plans/16-remove-stat-and-metric-card.plan.md` that is a claim rather
/// than a deletion.
///
/// The two widgets this replaces differed by one field's *type* — `String
/// value` against `int count` — so the tests that matter here are the ones
/// about the boundary that redrawing fixed: the tile owns no layout, the grid
/// owns no children, and the conveniences are conveniences rather than
/// variants.
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
              // copyWith, never a fresh MediaQueryData: a bare one has a zero
              // size, and every layout under it collapses for a reason that
              // has nothing to do with the test.
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

  /// The value's own `Text`, found by the tabular feature only this widget
  /// sets — the label and the note are `Text`s too.
  Text valueTextOf(WidgetTester tester) => tester.widget<Text>(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.style?.fontFeatures?.contains(
                const FontFeature.tabularFigures(),
              ) ??
              false),
    ),
  );

  group('the figure', () {
    testWidgets('count formats 1284 with grouping and stays tabular', (
      tester,
    ) async {
      await pump(tester, DSStatTile.count(label: 'Users', count: 1284));
      expect(find.text('1,284'), findsOneWidget);
      expect(
        valueTextOf(tester).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason:
            'figures that share a column must share a width or the column '
            'jitters as the values change',
      );
    });

    testWidgets('count honours an injected formatter', (tester) async {
      await pump(
        tester,
        DSStatTile.count(
          label: 'Users',
          count: 1284,
          valueFormatter: (n) => '${n.toStringAsFixed(0)} people',
        ),
      );
      expect(find.text('1284 people'), findsOneWidget);
      expect(
        find.text('1,284'),
        findsNothing,
        reason:
            'the default comma is exactly what the injection point exists to '
            'replace',
      );
    });

    testWidgets('an empty value is an em-dash in textTertiary, not a zero', (
      tester,
    ) async {
      await pump(tester, const DSStatTile(label: 'Refunds', value: ''));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(valueTextOf(tester).style?.color, ctx.palette.mutedForeground);
    });
  });

  group('the trend', () {
    testWidgets('down renders a down arrow in the error tone', (tester) async {
      await pump(
        tester,
        const DSStatTile(
          label: 'Sessions',
          value: '8,402',
          deltaLabel: '3.2%',
          trend: DSTrend.down,
        ),
      );
      final arrow = tester.widget<Icon>(
        find.byIcon(Icons.arrow_downward_rounded),
      );
      expect(arrow.color, ctx.palette.destructive);
      expect(
        find.byIcon(Icons.arrow_upward_rounded),
        findsNothing,
        reason:
            'direction is the arrow and colour is the reinforcement, never '
            'colour alone',
      );
    });

    testWidgets('the value never takes the trend colour', (tester) async {
      await pump(
        tester,
        const DSStatTile(
          label: 'Sessions',
          value: '8,402',
          deltaLabel: '3.2%',
          trend: DSTrend.down,
        ),
      );
      expect(valueTextOf(tester).style?.color, ctx.palette.foreground);
      expect(
        valueTextOf(tester).style?.color,
        isNot(ctx.palette.destructive),
        reason:
            'colouring the value by its trend makes the value unreadable and '
            'the trend invisible',
      );
    });

    testWidgets('no trend renders no chip at all', (tester) async {
      await pump(
        tester,
        const DSStatTile(label: 'Sessions', value: '8,402', deltaLabel: '0%'),
      );
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
      expect(
        find.text('0%'),
        findsNothing,
        reason: 'a 0% delta in grey is a row of pixels that says nothing',
      );
    });
  });

  group('the tap target', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('without onTap there is nothing to focus and no ink', (
      tester,
    ) async {
      await pump(tester, const DSStatTile(label: 'Uptime', value: '99.98%'));
      expect(find.byType(InkWell), findsNothing);
      final node = tester.getSemantics(find.byType(DSStatTile));
      expect(node.flagsCollection.isButton, isFalse);
    });

    testWidgets('with onTap it is one button node of at least 48dp', (
      tester,
    ) async {
      await pump(
        tester,
        DSStatTile(label: 'Uptime', value: '99.98%', onTap: () {}),
      );
      final node = tester.getSemantics(find.byType(DSStatTile));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, 'Uptime');
      expect(node.value, '99.98%');
      expect(
        tester.getSize(find.byType(DSStatTile)).height,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
    });

    testWidgets('the whole tile is one node, not three', (tester) async {
      await pump(
        tester,
        const DSStatTile(
          label: 'Active users',
          value: '1,284',
          deltaLabel: '12.4%',
          trend: DSTrend.up,
          note: 'vs last week',
        ),
      );
      final node = tester.getSemantics(find.byType(DSStatTile));
      expect(node.value, '1,284, up 12.4% vs last week');
      expect(node.childrenCount, 0);
    });

    testWidgets('loading announces the label plus loading, not an empty '
        'value', (tester) async {
      await pump(
        tester,
        const DSStatTile(label: 'Revenue', value: '12,400', loading: true),
      );
      final node = tester.getSemantics(find.byType(DSStatTile));
      expect(node.label, 'Revenue');
      expect(node.value, 'loading');
    });
  });

  group('slots beat conveniences', () {
    testWidgets('leading replaces the mark and the icon well', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSStatTile.icon(
            icon: Icons.folder_outlined,
            label: 'Storage',
            value: '68.4 GB',
            markColor: context.palette.primary,
            leading: const Text('LEAD'),
          ),
        ),
      );
      expect(find.text('LEAD'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });

    testWidgets('deltaSlot replaces deltaLabel and trend', (tester) async {
      await pump(
        tester,
        const DSStatTile(
          label: 'Sessions',
          value: '8,402',
          deltaLabel: '4.1%',
          trend: DSTrend.up,
          deltaSlot: Text('SPARK'),
        ),
      );
      expect(find.text('SPARK'), findsOneWidget);
      expect(find.text('4.1%'), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });
  });

  group('the tile owns no layout', () {
    testWidgets('it pads nothing by default, and can still be padded', (
      tester,
    ) async {
      await pump(tester, const DSStatTile(label: 'Uptime', value: '99.98%'));
      final bare = tester.getSize(find.byType(DSStatTile));

      await pump(
        tester,
        const DSStatTile(
          label: 'Uptime',
          value: '99.98%',
          style: DSStatTileStyle(padding: EdgeInsets.all(20)),
        ),
      );
      expect(
        tester.getSize(find.byType(DSStatTile)).height,
        bare.height + 40,
        reason:
            '"this component refuses to pad itself" is a rule; "this '
            'component cannot be padded" is a defect',
      );
    });
  });

  group('DSStatTileGrid', () {
    testWidgets('renders a child that is not a DSStatTile', (tester) async {
      await pump(
        tester,
        const DSStatTileGrid(
          children: [
            DSStatTile(label: 'Sessions', value: '8,402'),
            Text('NOT A TILE'),
          ],
        ),
      );
      expect(find.text('NOT A TILE'), findsOneWidget);
      expect(find.text('8,402'), findsOneWidget);
    });

    testWidgets('two columns become one past the collapse scale', (
      tester,
    ) async {
      const grid = DSStatTileGrid(
        children: [
          DSStatTile(label: 'A', value: '1'),
          DSStatTile(label: 'B', value: '2'),
        ],
      );

      // One DSDivider widget, two axes: the rule between columns is vertical
      // and the rule between rows is horizontal, so the finder reads the axis
      // rather than the type.
      List<Axis> axesOf(WidgetTester tester) => tester
          .widgetList<DSDivider>(find.byType(DSDivider))
          .map((d) => d.axis)
          .toList();

      await pump(tester, grid);
      expect(axesOf(tester), [Axis.vertical]);

      await pump(tester, grid, textScaler: const TextScaler.linear(2));
      await tester.pumpAndSettle();
      expect(axesOf(tester), [
        Axis.horizontal,
      ], reason: 'one column has nothing to divide side to side');
    });

    testWidgets('a short last row keeps its empty cell', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 400,
          child: DSStatTileGrid(
            children: [
              DSStatTile(label: 'A', value: '1'),
              DSStatTile(label: 'B', value: '2'),
              DSStatTile(label: 'C', value: '3'),
            ],
          ),
        ),
      );
      final a = tester.getSize(find.byType(DSStatTile).first);
      final c = tester.getSize(find.byType(DSStatTile).last);
      expect(
        c.width,
        a.width,
        reason:
            'a three-tile grid must not stretch its last tile across two '
            'columns',
      );
    });
  });

  group('the style object', () {
    testWidgets('a theme extension restyles every tile below it', (
      tester,
    ) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSStatTileStyle(markSize: 24)],
            ),
            home: Builder(
              builder: (context) {
                ctx = context;
                return Scaffold(
                  body: DSStatTile(
                    label: 'Sessions',
                    value: '8,402',
                    markColor: context.palette.chart[0],
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DSStatTileMark)), const Size(24, 24));
    });

    testWidgets('an instance style beats the extension', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSStatTileStyle(markSize: 24)],
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: DSStatTile(
                  label: 'Sessions',
                  value: '8,402',
                  markColor: context.palette.chart[0],
                  style: const DSStatTileStyle(markSize: 4),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DSStatTileMark)), const Size(4, 4));
    });

    testWidgets('a compact DSScope tightens tiles that did not ask', (
      tester,
    ) async {
      late DSStatTileStyle roomy;
      late DSStatTileStyle tight;
      await pump(
        tester,
        Builder(
          builder: (context) {
            roomy = DSStatTileStyle.resolve(context, null);
            return DSScope(
              density: DSDensity.compact,
              child: Builder(
                builder: (context) {
                  tight = DSStatTileStyle.resolve(context, null);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      );
      expect(tight.labelGap, lessThan(roomy.labelGap!));
      expect(tight.wellSize, lessThan(roomy.wellSize!));
    });

    testWidgets('an explicit size beats the scope', (tester) async {
      late DSStatTileStyle explicit;
      await pump(
        tester,
        DSScope(
          density: DSDensity.compact,
          child: Builder(
            builder: (context) {
              explicit = DSStatTileStyle.resolve(context, DSStatTileSize.md);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(explicit.wellSize, ctx.design.component.wellSize);
    });

    test('merge takes the non-null fields of the layer above', () {
      const base = DSStatTileStyle(markSize: 8, labelGap: 4);
      final merged = base.merge(const DSStatTileStyle(markSize: 12));
      expect(merged.markSize, 12);
      expect(merged.labelGap, 4, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSStatTileStyle(markSize: 0, labelGap: 0);
      const b = DSStatTileStyle(markSize: 10, labelGap: 20);
      final mid = a.lerp(b, 0.5);
      expect(mid.markSize, 5);
      expect(mid.labelGap, 10);
    });

    test('the grid style lerps too', () {
      const a = DSStatTileGridStyle(dividerThickness: 0);
      const b = DSStatTileGridStyle(dividerThickness: 4);
      expect(a.lerp(b, 0.5).dividerThickness, 2);
    });
  });
}
