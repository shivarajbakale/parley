import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The whole reason this component exists is a number: Material's `Divider`
/// defaults `height` to 16, so a stock rule adds 16 points of space wherever
/// it lands. The first group is that number.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('the rule occupies its own thickness and nothing more', () {
    testWidgets('a horizontal rule is one hairline tall', (tester) async {
      await pump(tester, const DSDivider());

      final size = tester.getSize(find.byType(DSDivider));
      expect(size.height, ctx.design.component.hairlineWidth);
    });

    testWidgets('a vertical rule is one hairline wide', (tester) async {
      await pump(
        tester,
        const SizedBox(height: 40, child: DSDivider.vertical()),
      );

      final size = tester.getSize(find.byType(DSDivider));
      expect(size.width, ctx.design.component.hairlineWidth);
      expect(size.height, 40);
    });
  });

  group('the inset', () {
    testWidgets('indent is directional', (tester) async {
      // Under RTL the leading inset is on the right, which is where a row's
      // text inset is too — see docs/principles/direction.md.
      await pump(
        tester,
        const SizedBox(width: 200, child: DSDivider(indent: 40)),
        direction: TextDirection.rtl,
      );

      final line = tester.getRect(find.byType(DecoratedBox));
      final box = tester.getRect(find.byType(DSDivider));
      expect(line.left, box.left);
      expect(line.right, box.right - 40);
    });
  });

  group('accessibility', () {
    testWidgets('a rule is furniture, not content', (tester) async {
      await pump(tester, const DSDivider());
      // Twenty rows means twenty of these; a reader that stops on each one is
      // reading the furniture.
      expect(
        find.descendant(
          of: find.byType(DSDivider),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('the style chain', () {
    testWidgets('the colour is the soft outline, not the hard one', (
      tester,
    ) async {
      await pump(tester, const DSDivider());

      final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, ctx.palette.borderSoft);
    });

    testWidgets('an instance style overrides thickness and colour', (
      tester,
    ) async {
      await pump(
        tester,
        const DSDivider(
          style: DSDividerStyle(thickness: 4, color: Color(0xFF00FF00)),
        ),
      );

      expect(tester.getSize(find.byType(DSDivider)).height, 4);
      final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      expect(
        (decorated.decoration as BoxDecoration).color,
        const Color(0xFF00FF00),
      );
    });

    test('merge, copyWith and lerp walk every field', () {
      const base = DSDividerStyle(thickness: 1, indent: 8);
      const patch = DSDividerStyle(indent: 16, endIndent: 4);

      expect(base.merge(patch).thickness, 1);
      expect(base.merge(patch).indent, 16);
      expect(base.merge(patch).endIndent, 4);
      expect(base.merge(null), same(base));

      expect(base.copyWith(thickness: 2).indent, 8);

      const other = DSDividerStyle(thickness: 3, indent: 24);
      final half = base.lerp(other, 0.5);
      expect(half.thickness, 2);
      expect(half.indent, 16);
      expect(base.lerp(null, 0.5), same(base));
    });
  });
}
