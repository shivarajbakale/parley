import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSFieldGroup's style object.
///
/// The group was one of the last two painting components outside the
/// component contract: its gutter, its eyebrow inset, the gap between fields
/// and the footer's type were all computed inside `build`, so the only way to
/// change a form's rhythm was to edit the file. These are the four layers
/// proving they reach it.
void main() {
  final spec = AppTheme.spec;

  Widget host(
    Widget child, {
    List<ThemeExtension<dynamic>> extensions = const [],
  }) => Design(
    spec: spec,
    child: MaterialApp(
      theme: AppTheme.lightTheme.copyWith(extensions: extensions),
      home: Scaffold(body: child),
    ),
  );

  double gapBetweenFields(WidgetTester tester) {
    final boxes = tester
        .widgetList<SizedBox>(
          find.descendant(
            of: find.byType(DSFieldGroup),
            matching: find.byType(SizedBox),
          ),
        )
        .where((b) => b.height != null && b.width == null);
    return boxes.first.height!;
  }

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSFieldGroupStyle(itemSpacing: 24, padding: EdgeInsets.zero);
      const over = DSFieldGroupStyle(itemSpacing: 8);
      final merged = base.merge(over);
      expect(merged.itemSpacing, 8);
      expect(
        merged.padding,
        EdgeInsets.zero,
        reason: 'null does not overwrite',
      );
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSFieldGroupStyle(itemSpacing: 10);
      const b = DSFieldGroupStyle(itemSpacing: 20);
      expect(a.lerp(b, 0.5).itemSpacing, 15);
    });

    testWidgets('layer 1 — defaults come from the spec', (tester) async {
      await tester.pumpWidget(
        host(
          const DSFieldGroup(children: [SizedBox.shrink(), SizedBox.shrink()]),
        ),
      );
      expect(gapBetweenFields(tester), spec.space.lg);
    });

    testWidgets('layer 2 — a theme extension reaches every group', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSFieldGroup(children: [SizedBox.shrink(), SizedBox.shrink()]),
          extensions: const [DSFieldGroupStyle(itemSpacing: 3)],
        ),
      );
      expect(gapBetweenFields(tester), 3);
    });

    testWidgets('layer 3 — a compact container closes the gap', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => DSScope.merge(
              context,
              density: DSDensity.compact,
              child: const DSFieldGroup(
                children: [SizedBox.shrink(), SizedBox.shrink()],
              ),
            ),
          ),
        ),
      );
      expect(gapBetweenFields(tester), spec.space.md);
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
              child: const DSFieldGroup(
                style: DSFieldGroupStyle(itemSpacing: 7),
                children: [SizedBox.shrink(), SizedBox.shrink()],
              ),
            ),
          ),
          extensions: const [DSFieldGroupStyle(itemSpacing: 3)],
        ),
      );
      expect(gapBetweenFields(tester), 7);
    });
  });
}
