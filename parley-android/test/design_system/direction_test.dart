import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/principles/direction.md`, at the level a lint cannot reach.
///
/// `ui_lint`'s `physical-direction` rule reads source: it catches a `left:`
/// that should have been a `start:`. What it cannot see is a widget that asks
/// `Directionality.of(context)` itself and gets the branch backwards, or a
/// glyph that carries a direction and never flips. That is what is here.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required TextDirection direction,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  IconData glyphOf(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon)).icon!;

  group('the chevron points the way the row opens', () {
    testWidgets('right under LTR', (tester) async {
      await pump(tester, const DSChevron(), direction: TextDirection.ltr);
      expect(glyphOf(tester), Icons.chevron_right);
    });

    testWidgets('left under RTL', (tester) async {
      // Not cosmetic: a chevron_right at the end of an Arabic row points back
      // the way the reader came, which reads as "go back", not "open this".
      await pump(tester, const DSChevron(), direction: TextDirection.rtl);
      expect(glyphOf(tester), Icons.chevron_left);
    });

    testWidgets('a row flips its own chevron too', (tester) async {
      await pump(
        tester,
        DSListTile(title: 'Settings', onTap: () {}),
        direction: TextDirection.rtl,
      );
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('an explicit glyph is the caller\'s, not ours', (tester) async {
      // A caller passing an icon has said what they want; a component that
      // second-guesses it cannot be used for a non-directional glyph.
      await pump(
        tester,
        const DSChevron(icon: Icons.expand_more),
        direction: TextDirection.rtl,
      );
      expect(glyphOf(tester), Icons.expand_more);
    });
  });

  group('the kit renders under both directions', () {
    testWidgets('a message keeps its leading rule on the leading edge', (
      tester,
    ) async {
      // The border is a BorderDirectional, so this is really asserting the
      // paint path does not throw: a non-uniform directional border needs a
      // TextDirection at paint time and asserts without one.
      for (final direction in TextDirection.values) {
        await pump(
          tester,
          const DSMessage(
            tone: DSTone.warning,
            message: 'Your trial ends tomorrow.',
          ),
          direction: direction,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
