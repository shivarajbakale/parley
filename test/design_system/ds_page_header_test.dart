import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/ds_large_app_bar.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_page_header_style.dart';
import 'package:parley_android/theme/app_theme.dart';

void main() {
  _titleSizeIsOneNumber();
  Future<DSPageHeaderStyle> resolveOn(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    late DSPageHeaderStyle style;
    // Reset the widget tree to force full rebuild. Without this, pumpWidget
    // on the second call reuses the existing element, and the Builder never
    // re-runs, so we would read the first platform's cached value both times.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              style = DSPageHeaderStyle.resolve(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return style;
  }

  group('DSPageHeaderStyle', () {
    testWidgets('the compact height is the platform navigation-bar height', (
      tester,
    ) async {
      final apple = await resolveOn(tester, TargetPlatform.iOS);
      final material = await resolveOn(tester, TargetPlatform.android);

      // 44 is the iOS navigation bar; 56 is Material's toolbar. A compact bar
      // that split the difference would be wrong on both platforms.
      expect(apple.compactHeight, 44);
      expect(material.compactHeight, kToolbarHeight);
    });

    testWidgets('the subtitle style is one step below the body text', (
      tester,
    ) async {
      final style = await resolveOn(tester, TargetPlatform.iOS);
      final theme = AppTheme.lightTheme.textTheme;

      // bodySmall, not bodyMedium: FlexibleSpaceBar paints the whole title
      // block at expandedTitleScale (1.25), so a subtitle specified at
      // bodyMedium lands a step above the body copy it is introducing.
      expect(style.subtitleStyle?.fontSize, theme.bodySmall?.fontSize);
    });

    testWidgets('copyWith and merge carry the new fields', (tester) async {
      const base = DSPageHeaderStyle(compactHeight: 44);
      expect(base.copyWith(compactHeight: 56).compactHeight, 56);
      expect(
        base.merge(const DSPageHeaderStyle(compactHeight: 56)).compactHeight,
        56,
      );
      expect(
        base
            .lerp(const DSPageHeaderStyle(compactHeight: 56), 0.5)
            .compactHeight,
        50,
      );

      // The toolbar title's own step, through all four. A field added to the
      // constructor and forgotten in `merge` is a style override that works
      // on the instance and not through the theme or a scope.
      const withCompact = DSPageHeaderStyle(
        compactTitleStyle: TextStyle(fontSize: 20),
      );
      expect(
        withCompact
            .copyWith(compactTitleStyle: const TextStyle(fontSize: 24))
            .compactTitleStyle
            ?.fontSize,
        24,
      );
      expect(
        withCompact
            .merge(
              const DSPageHeaderStyle(
                compactTitleStyle: TextStyle(fontSize: 24),
              ),
            )
            .compactTitleStyle
            ?.fontSize,
        24,
      );
      expect(
        withCompact
            .lerp(
              const DSPageHeaderStyle(
                compactTitleStyle: TextStyle(fontSize: 24),
              ),
              0.5,
            )
            .compactTitleStyle
            ?.fontSize,
        22,
      );
    });
  });

  group('DSLargeAppBar subtitle', () {
    Future<void> pumpBar(
      WidgetTester tester,
      TargetPlatform platform, {
      String? subtitle,
      TextScaler textScaler = TextScaler.noScaling,
    }) async {
      // Reset the widget tree to force full rebuild. Without this, pumpWidget
      // on the second call reuses the existing element, and the Builder never
      // re-runs, so we would read the first platform's cached value both
      // times.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          // Inside the app, not around it: MaterialApp installs its own
          // MediaQuery from the test window, so a wrapper outside it never
          // reaches the widget under test.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DSLargeAppBar(title: 'Blog', subtitle: subtitle),
                SliverList.list(
                  children: List.generate(
                    30,
                    (i) => SizedBox(height: 80, child: Text('row $i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders under the title', (tester) async {
      await pumpBar(
        tester,
        TargetPlatform.iOS,
        subtitle: '5 short essays on the kit behind this app.',
      );

      expect(find.text('Blog'), findsOneWidget);
      expect(
        find.text('5 short essays on the kit behind this app.'),
        findsOneWidget,
      );

      final title = tester.getTopLeft(find.text('Blog'));
      final sub = tester.getTopLeft(
        find.text('5 short essays on the kit behind this app.'),
      );
      expect(sub.dy, greaterThan(title.dy));
      // Same left edge: the subtitle is the second line of one block, not a
      // separate indented caption.
      expect(sub.dx, closeTo(title.dx, 0.5));
    });

    testWidgets('grows the bar rather than being drawn through the leading', (
      tester,
    ) async {
      await pumpBar(tester, TargetPlatform.iOS);
      final withoutSubtitle = tester.getRect(find.byType(AppBar)).height;

      await pumpBar(
        tester,
        TargetPlatform.iOS,
        subtitle: '5 short essays on the kit behind this app.',
      );
      final withSubtitle = tester.getRect(find.byType(AppBar)).height;

      expect(withSubtitle, greaterThan(withoutSubtitle));
    });

    testWidgets(
      'the room the subtitle earns grows with text scale, because it is '
      'measured rather than a flat allowance',
      (tester) async {
        // The title's own block already scales with textScaler, so at a
        // single scale a subtitle-adds-a-flat-constant implementation would
        // still show a taller bar as the scale grows — that growth would just
        // be the title's, not the subtitle's, and the assertion would pass
        // for the wrong reason. Isolate the subtitle's own contribution by
        // subtracting the subtitle-less bar's height at each scale before
        // comparing: a flat allowance produces the same delta at both
        // scales, while a TextPainter measurement — which is what has to
        // grow at 1.3x text scale so the block isn't drawn through the
        // leading button, the defect that shipped here before — produces a
        // bigger delta at the larger scale.
        Future<double> subtitleContribution(TextScaler scaler) async {
          await pumpBar(tester, TargetPlatform.iOS, textScaler: scaler);
          final withoutSubtitle = tester.getRect(find.byType(AppBar)).height;

          await pumpBar(
            tester,
            TargetPlatform.iOS,
            subtitle: '5 short essays on the kit behind this app.',
            textScaler: scaler,
          );
          final withSubtitle = tester.getRect(find.byType(AppBar)).height;

          return withSubtitle - withoutSubtitle;
        }

        final atDefaultScale = await subtitleContribution(TextScaler.noScaling);
        final atLargerScale = await subtitleContribution(
          const TextScaler.linear(1.3),
        );

        expect(atLargerScale, greaterThan(atDefaultScale));
      },
    );

    testWidgets('forces the measured path on Android', (tester) async {
      // Material's SliverAppBar.large renders its own title and has nowhere to
      // put a second line, so a subtitle has to take the flexibleSpace branch
      // on both platforms — the same reason an eyebrow does.
      await pumpBar(
        tester,
        TargetPlatform.android,
        subtitle: '5 short essays on the kit behind this app.',
      );
      expect(find.byType(FlexibleSpaceBar), findsOneWidget);
    });

    testWidgets('without a subtitle, Android keeps its fast path and skips '
        'FlexibleSpaceBar entirely', (tester) async {
      // Android, not iOS: Apple always takes the glass-bar/FlexibleSpaceBar
      // branch regardless of subtitle (see DSLargeAppBar's class doc), so
      // this claim is only checkable on the platform with a fast path to
      // fall out of — the same platform 'forces the measured path on
      // Android' checks falling *into* it.
      await pumpBar(tester, TargetPlatform.android);
      expect(find.byType(FlexibleSpaceBar), findsNothing);
    });
  });
}

/// The title's size, wherever the header decides to draw it.
///
/// `DSPageHeader` is one component with three build branches — a compact bar,
/// a large sliver bar and a fixed header — and only the third of them applied
/// `resolved.titleStyle`. The two bars left their titles as bare `Text`, so
/// they took `AppBarTheme.titleTextStyle` instead: Material's `titleLarge` at
/// 20.4pt with no emphasis weight, against the fixed header's `headlineMedium`
/// at 24.4pt with it. Same component, same string, two sizes — and the
/// documented `DSPageHeaderStyle(titleStyle:)` override reached one branch of
/// the three.
void _titleSizeIsOneNumber() {
  Future<TextStyle> titleStyleOf(WidgetTester tester, Widget header) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              header,
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The large bar paints its title in more than one slot as it collapses.
    // Every copy is the same title, so they have to agree — a disagreement
    // here is the defect this group exists for, wearing a different hat.
    final styles = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byWidget(header),
            matching: find.text('Reading list'),
          ),
        )
        .map((t) => t.style!)
        .toList();
    expect(styles, isNotEmpty);
    for (final s in styles) {
      expect(
        s.fontSize,
        styles.first.fontSize,
        reason: 'the header drew its own title at two sizes at once',
      );
    }
    return styles.first;
  }

  group('the page title is one size in all three branches', () {
    testWidgets('the large bar draws the page title, not Material\'s', (
      tester,
    ) async {
      final style = await titleStyleOf(
        tester,
        const DSPageHeader.sliver(title: 'Reading list'),
      );
      final expected = AppTheme.lightTheme.textTheme.headlineMedium!;
      expect(
        style.fontSize,
        expected.fontSize,
        reason:
            'the large bar drew ${style.fontSize} where the page title is '
            '${expected.fontSize} — Material\'s titleLarge, not the kit\'s',
      );
      // The weight the fixed branch has always had, which the bar never did.
      expect(style.fontWeight, isNotNull);
    });

    testWidgets('and a titleStyle override reaches it', (tester) async {
      // The point of the field. Before this it moved the fixed header alone,
      // so the same override produced two different headers.
      final style = await titleStyleOf(
        tester,
        const DSPageHeader.sliver(
          title: 'Reading list',
          style: DSPageHeaderStyle(titleStyle: TextStyle(fontSize: 31)),
        ),
      );
      expect(style.fontSize, 31);
    });

    testWidgets('the compact bar is a toolbar title, deliberately smaller', (
      tester,
    ) async {
      // Not the same number as the other two, and that is the decision: a bar
      // collapsed to one toolbar row is not the place for a 24pt headline.
      // The step is unchanged — what changed is that it is now a field on the
      // style rather than `AppBarTheme.titleTextStyle`, so it can be moved
      // without restyling Material's bar for the whole app.
      //
      // Raising it was tried and reverted: at `screenTitle`'s own step the
      // catalog's "DSSegmentedProgress" — one unbreakable nineteen-character
      // word — truncated at a 1.3x text scale, and `make ui-probe` failed it.
      final style = await titleStyleOf(
        tester,
        const DSPageHeader.compactSliver(title: 'Reading list'),
      );
      expect(
        style.fontSize,
        AppTheme.lightTheme.textTheme.titleLarge!.fontSize,
      );
    });

    testWidgets('and the toolbar title has a field of its own to move', (
      tester,
    ) async {
      final style = await titleStyleOf(
        tester,
        const DSPageHeader.compactSliver(
          title: 'Reading list',
          style: DSPageHeaderStyle(compactTitleStyle: TextStyle(fontSize: 17)),
        ),
      );
      expect(style.fontSize, 17);
    });
  });
}
