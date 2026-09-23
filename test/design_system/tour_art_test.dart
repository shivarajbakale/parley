import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduced,
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );

  group('DSTourCanvas', () {
    testWidgets('composes at one width whatever the text scale', (
      tester,
    ) async {
      await pump(tester, const DSTourCanvas(child: Text('1,345.20')));
      final double plain = tester.getSize(find.byType(DSTourCanvas)).width;

      await pump(
        tester,
        const DSTourCanvas(child: Text('1,345.20')),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(DSTourCanvas)).width,
        plain,
        reason:
            'the board is a drawing, not a paragraph — the caller scales it, '
            'so a doubled text scale must not reflow the picture',
      );
    });

    testWidgets('the style can move the width', (tester) async {
      await pump(
        tester,
        const DSTourCanvas(
          style: DSTourArtStyle(canvasWidth: 240),
          child: SizedBox.shrink(),
        ),
      );
      expect(tester.getSize(find.byType(DSTourCanvas)).width, 240);
    });
  });

  group('DSTourFillSlot', () {
    testWidgets('shows the filled content once active', (tester) async {
      await pump(
        tester,
        const DSTourFillSlot(
          active: true,
          delay: Duration.zero,
          placeholderWidth: 80,
          child: Text('Acme Ltd'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Acme Ltd'), findsOneWidget);
    });

    testWidgets('under reduced motion the slot is already filled', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTourFillSlot(
          active: false,
          delay: Duration.zero,
          placeholderWidth: 80,
          child: Text('Acme Ltd'),
        ),
        reduced: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Acme Ltd'), findsOneWidget);
      // Scoped to the slot itself: `MaterialApp(home: …)` mounts through a
      // MaterialPageRoute, and AppTheme's FadeForwardsPageTransitionsBuilder
      // (the Android/desktop branch of pageTransitionsTheme) wraps that
      // route's child in its own FadeTransition regardless of this widget —
      // an unscoped finder would fail on that ambient transition even when
      // DSTourFillSlot itself renders none.
      expect(
        find.descendant(
          of: find.byType(DSTourFillSlot),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });
}
