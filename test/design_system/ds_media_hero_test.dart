import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
    DSDensity? density,
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
                    final Widget body = Builder(builder: (_) => child);
                    return density == null
                        ? body
                        : DSScope.merge(context, density: density, child: body);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  const source = DSMediaSource.widget(
    ColoredBox(color: Color(0xFF112233)),
    semanticLabel: 'Cover of the quarterly report',
  );

  group('DSMediaHero', () {
    testWidgets('below is the default, and the text is under the picture', (
      tester,
    ) async {
      await pump(tester, const DSMediaHero(source: source, title: 'Featured'));
      final Rect media = tester.getRect(find.byType(DSMediaSurface));
      final Rect title = tester.getRect(find.text('Featured'));
      expect(title.top, greaterThanOrEqualTo(media.bottom - 1));
    });

    testWidgets('overlay draws the text on the picture', (tester) async {
      await pump(
        tester,
        const DSMediaHero(
          source: source,
          title: 'Featured',
          placement: DSMediaHeroPlacement.overlay,
        ),
      );
      final Rect media = tester.getRect(find.byType(DSMediaSurface));
      expect(
        media.contains(tester.getRect(find.text('Featured')).center),
        isTrue,
      );
    });

    testWidgets('overlay degrades to below past 1.6x text scale', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMediaHero(
          source: source,
          title: 'Featured',
          placement: DSMediaHeroPlacement.overlay,
        ),
        textScaler: const TextScaler.linear(2),
      );
      final Rect media = tester.getRect(find.byType(DSMediaSurface));
      final Rect title = tester.getRect(find.text('Featured'));
      expect(
        title.top,
        greaterThanOrEqualTo(media.bottom - 1),
        reason: 'text over a picture cannot be trusted once it is this big',
      );
    });

    testWidgets('overlay needs a picture to sit on', (tester) async {
      // Deviation from the brief: its version is a plain `test()` expecting
      // the constructor itself to throw. `source.isEmpty` cannot be a
      // constructor assert here (see the comment in ds_media_hero.dart's
      // `build` — confirmed by direct compiler probe, not just declined on
      // suspicion), so the check runs on first build instead, and only a
      // pumped widget can observe it.
      await pump(
        tester,
        const DSMediaHero(
          source: DSMediaSource.none(),
          title: 'Nothing to sit on',
          placement: DSMediaHeroPlacement.overlay,
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('fullBleed drops the gutter and the radius', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        const DSMediaHero(
          source: source,
          title: 'Edge to edge',
          fullBleed: true,
        ),
      );
      expect(tester.getRect(find.byType(DSMediaSurface)).left, 0);

      // And the radius, which the test was named for and did not assert:
      // a full-bleed picture with rounded corners shows the page's ground
      // in four notches at the screen's edge.
      final bled = tester.widget<DSMediaSurface>(find.byType(DSMediaSurface));
      expect(bled.style?.radius, BorderRadius.zero);

      // The brief's own snippet reads `ctx.design.space.pageGutter` here with
      // no `ctx` ever declared — there is no BuildContext in scope at that
      // point. A `Builder` captures one from inside the pumped tree instead,
      // exercised in the same pump as the widget being asserted on.
      late double gutter;
      await pump(
        tester,
        Builder(
          builder: (context) {
            gutter = context.design.space.pageGutter;
            return const DSMediaHero(source: source, title: 'Inset');
          },
        ),
      );
      expect(tester.getRect(find.byType(DSMediaSurface)).left, gutter);
    });
  });
}
