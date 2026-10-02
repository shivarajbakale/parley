import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The claims `DSHero` makes that a screenshot cannot check:
///
///   * the plate never collapses below its floor, and grows past it rather
///     than clipping when the reader has asked for bigger type;
///   * the light comes from the trailing side, which moves in Arabic;
///   * a screen reader hears the title once, as the route's name, and does
///     not hear the mark at all;
///   * every colour on the plate is the palette's, so the four identities get
///     four plates and nobody maintains a second copy for dark.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester, {
    String title = 'Sign in',
    String? eyebrow,
    String? subtitle,
    Widget? mark,
    Widget? leading,
    DSHeroStyle? style,
    DesignSpec? spec,
    TextDirection direction = TextDirection.ltr,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: spec ?? AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: direction,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    ctx = context;
                    return Column(
                      children: [
                        DSHero(
                          title: title,
                          eyebrow: eyebrow,
                          subtitle: subtitle,
                          mark: mark,
                          leading: leading,
                          style: style,
                        ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('the plate as a box', () {
    testWidgets('a two-word title still fills the floor', (tester) async {
      await pump(tester, eyebrow: 'Welcome back');

      final height = tester.getSize(find.byType(DSHero)).height;
      expect(height, ctx.design.component.heroMinHeight);
    });

    testWidgets('bigger type grows the plate instead of clipping it', (
      tester,
    ) async {
      await pump(tester, eyebrow: 'Welcome back', textScale: 1);
      final atOne = tester.getSize(find.byType(DSHero)).height;

      await pump(
        tester,
        eyebrow: 'Welcome back',
        subtitle: 'Pick up where you left off.',
        textScale: 2,
      );
      final atTwo = tester.getSize(find.byType(DSHero)).height;

      // The defect this guards is the one the DSChart axis had: a fixed box
      // and a scaling label, so the reader who most needs the words is the
      // one who loses them.
      expect(atTwo, greaterThan(atOne));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the title sits clear of the sheet lip', (tester) async {
      await pump(tester, eyebrow: 'Welcome back');

      final style = DSHeroStyle.resolve(ctx);
      final plateBottom = tester.getRect(find.byType(DSHero)).bottom;
      final titleBottom = tester.getRect(find.text('Sign in')).bottom;

      // Content that ran under the turn would be clipped by a corner nobody
      // can see coming.
      expect(plateBottom - titleBottom, greaterThan(style.sheetRadius!));
    });

    testWidgets('leading takes a full tap target at the top', (tester) async {
      await pump(
        tester,
        leading: DSIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'Back',
          onPressed: () {},
        ),
      );

      final back = tester.getRect(find.bySemanticsLabel('Back'));
      final title = tester.getRect(find.text('Sign in'));
      expect(back.bottom, lessThan(title.top));
      expect(
        back.height,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
    });
  });

  group('the light and the direction it comes from', () {
    /// The painter is the component: read it back off the tree rather than
    /// asserting on pixels, which would only restate the golden.
    CustomPainter painterOf(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(DSHero),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.painter)
        .whereType<CustomPainter>()
        .first;

    testWidgets('the plate is repainted when the direction flips', (
      tester,
    ) async {
      await pump(tester);
      final ltr = painterOf(tester);

      await pump(tester, direction: TextDirection.rtl);
      final rtl = painterOf(tester);

      // A plate lit from the wrong side reads as a different design rather
      // than as the same one translated.
      expect(rtl.shouldRepaint(ltr), isTrue);
    });

    testWidgets('the same plate twice repaints nothing', (tester) async {
      await pump(tester);
      final a = painterOf(tester);
      await pump(tester);
      expect(painterOf(tester).shouldRepaint(a), isFalse);
    });
  });

  group('what a screen reader hears', () {
    testWidgets('the title names the route, once', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, eyebrow: 'Welcome back');

      expect(
        tester.getSemantics(find.text('Sign in')),
        matchesSemantics(
          isHeader: true,
          namesRoute: true,
          label: 'WELCOME BACK\nSign in',
        ),
      );
      handle.dispose();
    });

    testWidgets('the mark is not read', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, mark: const Icon(Icons.star, semanticLabel: 'A star'));

      // The mark says what the title says. Hearing the app's name twice
      // before the first field is not an accessibility feature.
      expect(find.bySemanticsLabel('A star'), findsNothing);
      handle.dispose();
    });
  });

  group('the style chain', () {
    testWidgets('every colour on the plate comes from the palette', (
      tester,
    ) async {
      await pump(tester);
      final style = DSHeroStyle.resolve(ctx);
      final palette = ctx.palette;

      expect(style.plateTopColor, palette.secondary);
      expect(style.plateBottomColor, palette.card);
      expect(style.bloomColor, palette.primary);
      expect(style.arcColor, palette.primary);
      // The page's own ground, not a third step of its own.
      expect(style.sheetColor, palette.background);
      expect(style.hairlineColor, palette.borderSoft);
      expect(style.markGroundColor, palette.primary);
      expect(style.markColor, palette.primaryForeground);
    });

    testWidgets('a second identity gets a second plate for free', (
      tester,
    ) async {
      await pump(tester);
      final first = DSHeroStyle.resolve(ctx);

      await pump(tester, spec: DesignSpec.ledger());
      final second = DSHeroStyle.resolve(ctx);

      expect(second.plateTopColor, isNot(first.plateTopColor));
      expect(second.sheetRadius, ctx.radiusOf(AppShape.sheet));
    });

    testWidgets('an instance style overrides the spec default', (tester) async {
      await pump(
        tester,
        style: const DSHeroStyle(
          minHeight: 420,
          plateTopColor: Color(0xFF00FF00),
        ),
      );

      final style = DSHeroStyle.resolve(
        ctx,
        const DSHeroStyle(minHeight: 420, plateTopColor: Color(0xFF00FF00)),
      );
      expect(style.plateTopColor, const Color(0xFF00FF00));
      expect(tester.getSize(find.byType(DSHero)).height, 420);
      // Untouched fields still come from the spec.
      expect(style.bloomColor, ctx.palette.primary);
    });

    test('merge takes the other side field by field', () {
      const base = DSHeroStyle(minHeight: 300, arcStroke: 1.5);
      const patch = DSHeroStyle(arcStroke: 3, markSize: 72);

      final merged = base.merge(patch);
      expect(merged.minHeight, 300);
      expect(merged.arcStroke, 3);
      expect(merged.markSize, 72);
      expect(base.merge(null), same(base));
    });

    test('lerp walks every field', () {
      const a = DSHeroStyle(
        minHeight: 200,
        markSize: 40,
        arcStroke: 1,
        sheetRadius: 8,
        plateTopColor: Color(0xFF000000),
      );
      const b = DSHeroStyle(
        minHeight: 400,
        markSize: 80,
        arcStroke: 3,
        sheetRadius: 24,
        plateTopColor: Color(0xFFFFFFFF),
      );

      final half = a.lerp(b, 0.5);
      expect(half.minHeight, 300);
      expect(half.markSize, 60);
      expect(half.arcStroke, 2);
      expect(half.sheetRadius, 16);
      expect(
        half.plateTopColor,
        Color.lerp(a.plateTopColor, b.plateTopColor, 0.5),
      );
      expect(a.lerp(null, 0.5), same(a));
    });

    test('copyWith replaces only what it is given', () {
      const base = DSHeroStyle(minHeight: 300, markSize: 56);
      final copy = base.copyWith(markSize: 64);
      expect(copy.minHeight, 300);
      expect(copy.markSize, 64);
    });
  });
}
