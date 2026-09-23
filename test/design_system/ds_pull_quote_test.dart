import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The defect this component was extracted for: an article page drew a
/// 48-point bar beside a three-line quote, and every quote longer than two
/// lines shipped with the rule stopping a third of the way down.
void main() {
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester, Widget child, {double width = 300}) {
    return tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return Center(
                  child: SizedBox(width: width, child: child),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The rule is the only sized box drawn as a decoration inside the quote.
  Rect ruleOf(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(DSPullQuote),
      matching: find.byType(DecoratedBox),
    ),
  );

  group('the rule is as tall as the words', () {
    testWidgets('a one-line quote and a five-line quote differ', (
      tester,
    ) async {
      await pump(tester, const DSPullQuote(quote: 'Short.'));
      final short = ruleOf(tester).height;

      await pump(
        tester,
        const DSPullQuote(
          quote:
              'A sentence long enough to wrap several times inside a narrow '
              'reading column, which is the case the fixed-height bar got '
              'wrong every single time it was asked to.',
        ),
      );
      final long = ruleOf(tester).height;

      expect(long, greaterThan(short));
      expect(long, ruleOf(tester).height);
    });

    testWidgets('the rule spans the quote and its attribution', (tester) async {
      await pump(tester, const DSPullQuote(quote: 'Short.'));
      final withoutAttribution = ruleOf(tester).height;

      await pump(
        tester,
        const DSPullQuote(quote: 'Short.', attribution: 'Ada Lovelace'),
      );

      expect(ruleOf(tester).height, greaterThan(withoutAttribution));
    });
  });

  group('what it says', () {
    testWidgets('the quote and its attribution are one node', (tester) async {
      // Two nodes would make a screen reader stop twice on one sentence and
      // read a bare name as if it were the next paragraph.
      await pump(
        tester,
        const DSPullQuote(quote: 'Make it work.', attribution: 'Kent Beck'),
      );

      final node = tester.getSemantics(find.byType(DSPullQuote));
      expect(node.label, 'Make it work., Kent Beck');
    });

    testWidgets('the attribution renders with an em dash', (tester) async {
      await pump(
        tester,
        const DSPullQuote(quote: 'Make it work.', attribution: 'Kent Beck'),
      );

      expect(find.text('— Kent Beck'), findsOneWidget);
    });

    testWidgets('no attribution means no second line', (tester) async {
      await pump(tester, const DSPullQuote(quote: 'Make it work.'));

      expect(find.textContaining('—'), findsNothing);
    });
  });

  group('the style chain', () {
    testWidgets('the rule is the accent by default', (tester) async {
      await pump(tester, const DSPullQuote(quote: 'Short.'));

      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DSPullQuote),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (decorated.decoration as BoxDecoration).color,
        ctx.palette.primary,
      );
    });

    testWidgets('accentColor overrides it for a category surface', (
      tester,
    ) async {
      await pump(
        tester,
        const DSPullQuote(quote: 'Short.', accentColor: Color(0xFF00FF00)),
      );

      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DSPullQuote),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (decorated.decoration as BoxDecoration).color,
        const Color(0xFF00FF00),
      );
    });

    testWidgets('an instance style widens the rule', (tester) async {
      await pump(
        tester,
        const DSPullQuote(
          quote: 'Short.',
          style: DSPullQuoteStyle(ruleWidth: 12),
        ),
      );

      expect(ruleOf(tester).width, 12);
    });

    test('merge, copyWith and lerp walk every field', () {
      const base = DSPullQuoteStyle(ruleWidth: 4, gap: 8);
      const patch = DSPullQuoteStyle(gap: 16, attributionGap: 2);

      expect(base.merge(patch).ruleWidth, 4);
      expect(base.merge(patch).gap, 16);
      expect(base.merge(patch).attributionGap, 2);
      expect(base.merge(null), same(base));
      expect(base.copyWith(gap: 24).ruleWidth, 4);

      const other = DSPullQuoteStyle(ruleWidth: 8, gap: 24);
      final half = base.lerp(other, 0.5);
      expect(half.ruleWidth, 6);
      expect(half.gap, 16);
      expect(base.lerp(null, 0.5), same(base));
    });
  });
}
