import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSGround: the soft colour wash a page sits on.
void main() {
  Widget host(
    DesignSpec spec,
    Widget child, [
    Brightness b = Brightness.light,
  ]) => Design(
    spec: spec,
    child: MaterialApp(theme: spec.themeFor(b), home: child),
  );

  // The shipped identity has no wash any more, so the washed case is built
  // here: the component still has to work for an identity that sets one.
  final washed = AppTheme.spec.copyWith(
    chrome: AppTheme.spec.chrome.copyWith(
      groundWash: const <Color>[
        Color(0xFFEAF7FA),
        Color(0xFFEDF8F1),
        Color(0xFFFCF8E8),
      ],
      groundWashDark: const <Color>[
        Color(0xFF0F2830),
        Color(0xFF0F2622),
        Color(0xFF1A1F17),
      ],
    ),
  );
  final flat = AppTheme.spec.copyWith(
    chrome: AppTheme.spec.chrome.copyWith(
      groundWash: const <Color>[],
      groundWashDark: const <Color>[],
    ),
  );

  Iterable<LinearGradient> washes(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((b) => (b.decoration as BoxDecoration?)?.gradient)
      .whereType<LinearGradient>();

  testWidgets('an identity with no wash gets its child back', (tester) async {
    await tester.pumpWidget(
      host(flat, const DSGround(child: Scaffold(body: Text('page')))),
    );
    expect(washes(tester), isEmpty);
  });

  testWidgets('a washed identity paints one wash under a clear scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        washed,
        const DSGround(
          child: DSGround(child: Scaffold(body: Text('page'))),
        ),
      ),
    );
    expect(
      washes(tester),
      hasLength(1),
      reason: 'a ground in a ground is a no-op',
    );
    final context = tester.element(find.text('page'));
    expect(Theme.of(context).scaffoldBackgroundColor.a, 0);
  });

  for (final b in Brightness.values) {
    testWidgets('every stop is opaque and link text reads on it (${b.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(washed, const DSGround(child: Scaffold(body: Text('page'))), b),
      );
      final palette = washed.palette.resolve(b);
      final gradient = washes(tester).single;
      expect(
        gradient.colors.length,
        greaterThan(2),
        reason: 'a wash, not a fill',
      );
      for (final stop in gradient.colors) {
        expect(stop.a, 1);
        expect(contrastRatio(palette.primary, stop), greaterThanOrEqualTo(4.5));
        expect(
          contrastRatio(palette.mutedForeground, stop),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  }

  testWidgets('a pinned header paints a slice of the wash, not a flat band', (
    tester,
  ) async {
    Widget page(DesignSpec spec) => host(
      spec,
      const DSGround(
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: 120)),
              DSPinnedHeader(child: SizedBox(height: 48)),
              SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );
    Iterable<RenderObject> painted() => tester
        .renderObjectList(find.byType(DSGroundSlice))
        .where((r) => r is! RenderDecoratedBox);

    await tester.pumpWidget(page(washed));
    expect(find.byType(DSGroundSlice), findsOneWidget);
    expect(painted(), isNotEmpty, reason: 'on a wash it paints a slice');

    await tester.pumpWidget(page(flat));
    expect(
      painted(),
      isEmpty,
      reason: 'with no wash the band is a plain decorated fill again',
    );
  });
}
