import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Design(
    spec: AppTheme.spec,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  ),
);

Gradient? _gradientUnder(WidgetTester tester, Finder of) {
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: of, matching: find.byType(DecoratedBox)),
  )) {
    final d = box.decoration;
    if (d is ShapeDecoration && d.gradient != null) return d.gradient;
    if (d is BoxDecoration && d.gradient != null) return d.gradient;
  }
  return null;
}

void main() {
  testWidgets('a primary button paints the brand gradient', (tester) async {
    await _pump(tester, DSButton(label: 'Go', onPressed: () {}));
    final g = _gradientUnder(tester, find.byType(DSButton));
    expect(g, isA<LinearGradient>());
    expect(g!.colors, AppTheme.spec.palette.light.primaryGradient.colors);
  });

  testWidgets('a secondary button stays flat', (tester) async {
    await _pump(
      tester,
      DSButton(
        label: 'Go',
        variant: DSButtonVariant.secondary,
        onPressed: () {},
      ),
    );
    expect(_gradientUnder(tester, find.byType(DSButton)), isNull);
  });

  testWidgets('a disabled primary button drops the gradient', (tester) async {
    await _pump(tester, const DSButton(label: 'Go', onPressed: null));
    expect(_gradientUnder(tester, find.byType(DSButton)), isNull);
  });
}
