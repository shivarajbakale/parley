import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSSettingsSection's style object.
///
/// The section painted `palette.card` at a fixed corner with a fixed
/// hairline, all read inside `build`. A screen that wanted its groups flat had
/// no way to say so and neither did an identity. These are the four layers
/// proving they reach it.
void main() {
  final spec = AppTheme.spec;

  Widget host(
    Widget child, {
    List<ThemeExtension<dynamic>> extensions = const [],
    DesignSpec? design,
  }) => Design(
    spec: design ?? spec,
    child: MaterialApp(
      theme: AppTheme.lightTheme.copyWith(extensions: extensions),
      home: Scaffold(body: child),
    ),
  );

  ShapeDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(DSSettingsSection),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as ShapeDecoration;

  BorderRadius radiusOf(ShapeDecoration decoration) =>
      (decoration.shape as RoundedRectangleBorder).borderRadius as BorderRadius;

  const rows = [SizedBox.shrink(), SizedBox.shrink()];

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSSettingsSectionStyle(
        dividerThickness: 1,
        dividerIndent: 16,
      );
      const over = DSSettingsSectionStyle(dividerThickness: 2);
      final merged = base.merge(over);
      expect(merged.dividerThickness, 2);
      expect(merged.dividerIndent, 16, reason: 'null does not overwrite');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSSettingsSectionStyle(dividerIndent: 10);
      const b = DSSettingsSectionStyle(dividerIndent: 30);
      expect(a.lerp(b, 0.5).dividerIndent, 20);
    });

    testWidgets('layer 1 — the fill comes from the palette', (tester) async {
      await tester.pumpWidget(host(const DSSettingsSection(children: rows)));
      expect(decorationOf(tester).color, spec.palette.light.card);
    });

    testWidgets('layer 2 — a theme extension reaches every section', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSSettingsSection(children: rows),
          extensions: [
            DSSettingsSectionStyle(fillColor: spec.palette.light.muted),
          ],
        ),
      );
      expect(decorationOf(tester).color, spec.palette.light.muted);
    });

    testWidgets('layer 3 — a compact container tightens the corner', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => DSScope.merge(
              context,
              density: DSDensity.compact,
              child: const DSSettingsSection(children: rows),
            ),
          ),
        ),
      );
      final radius = radiusOf(decorationOf(tester));
      expect(
        radius.topLeft.x,
        lessThan(spec.shape.radiusOf(AppShape.tile, isApple: true)),
      );
    });

    testWidgets('layer 4 — an instance style wins over all of them', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => DSScope.merge(
              context,
              density: DSDensity.compact,
              child: DSSettingsSection(
                style: DSSettingsSectionStyle(
                  fillColor: spec.palette.light.background,
                ),
                children: rows,
              ),
            ),
          ),
          extensions: [
            DSSettingsSectionStyle(fillColor: spec.palette.light.muted),
          ],
        ),
      );
      expect(decorationOf(tester).color, spec.palette.light.background);
    });
  });

  group('the rule between two rows', () {
    Rect lineOf(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(DSDivider).first,
        matching: find.byType(DecoratedBox),
      ),
    );

    // The card itself: the Container's rect less its horizontal margin.
    Rect cardOf(WidgetTester tester) {
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(DSSettingsSection),
              matching: find.byType(Container),
            )
            .first,
      );
      final gutter = spec.space.pageGutter;
      return Rect.fromLTRB(
        box.left + gutter,
        box.top,
        box.right - gutter,
        box.bottom,
      );
    }

    // The rule runs from where the row's content starts to where it ends,
    // never into the card's own padding.
    void expectEdgeToEdge(WidgetTester tester) {
      final line = lineOf(tester);
      final card = cardOf(tester);
      final outline = spec.component.surfaceOutlineWidth;
      final gutter = spec.space.pageGutter;
      expect(line.left, closeTo(card.left + gutter, outline));
      expect(line.right, closeTo(card.right - gutter, outline));
    }

    testWidgets('runs content edge to content edge under a plain row', (tester) async {
      await tester.pumpWidget(
        host(
          DSSettingsSection(
            children: [
              const DSSettingsRow(label: 'Version', value: '0.1.0'),
              DSSettingsRow(label: 'About', onTap: () {}),
            ],
          ),
        ),
      );
      expectEdgeToEdge(tester);
    });

    testWidgets('and under a row with a glyph', (tester) async {
      await tester.pumpWidget(
        host(
          DSSettingsSection(
            children: [
              DSSettingsRow(
                label: 'Sign out',
                icon: Icons.logout,
                onTap: () {},
              ),
              DSSettingsRow(label: 'About', onTap: () {}),
            ],
          ),
        ),
      );
      expectEdgeToEdge(tester);
    });

    testWidgets('and under a switch row', (tester) async {
      await tester.pumpWidget(
        host(
          DSSettingsSection(
            children: [
              DSSwitchTile(label: 'Haptics', value: true, onChanged: (_) {}),
              DSSettingsRow(label: 'About', onTap: () {}),
            ],
          ),
        ),
      );
      expectEdgeToEdge(tester);
    });

    testWidgets('an inset identity starts the rule at the row\'s text', (
      tester,
    ) async {
      final inset = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.inset),
      );
      await tester.pumpWidget(
        host(
          DSSettingsSection(
            children: [
              DSSettingsRow(
                label: 'Sign out',
                icon: Icons.logout,
                onTap: () {},
              ),
              DSSettingsRow(label: 'About', onTap: () {}),
            ],
          ),
          design: inset,
        ),
      );
      expect(lineOf(tester).left, tester.getTopLeft(find.text('Sign out')).dx);
    });

    testWidgets('a policy of none draws no rule', (tester) async {
      final bare = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.none),
      );
      await tester.pumpWidget(
        host(
          DSSettingsSection(
            children: [
              const DSSettingsRow(label: 'Version', value: '0.1.0'),
              DSSettingsRow(label: 'About', onTap: () {}),
            ],
          ),
          design: bare,
        ),
      );
      expect(find.byType(DSDivider), findsNothing);
    });
  });
}
