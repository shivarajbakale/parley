import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, double position) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(child: DSTourDots(count: 4, position: position)),
      ),
    ),
  );

  testWidgets('says which page you are on', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, 0);
    expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('names the page being arrived at, not the one left behind', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    // More than half way from page 2 to page 3.
    await pump(tester, 1.6);
    expect(find.bySemanticsLabel('Page 3 of 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('overscroll past either end still reads in range', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, -0.4);
    expect(find.bySemanticsLabel('Page 1 of 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the current page is a bar and the rest are dots', (
    tester,
  ) async {
    await pump(tester, 0);

    // Measured off the render tree rather than read off the widget: the
    // width is interpolated, so it is only true after layout.
    final Finder marks = find.descendant(
      of: find.byType(DSTourDots),
      matching: find.byType(Container),
    );
    expect(marks, findsNWidgets(4));
    final List<double> widths = <double>[
      for (int i = 0; i < 4; i++) tester.getSize(marks.at(i)).width,
    ];

    expect(widths.first, greaterThan(widths[1]));
    expect(widths[1], widths[2], reason: 'two pages away is two pages away');
    expect(widths[1], widths[3]);
  });

  testWidgets('the track is not a tap target', (tester) async {
    await pump(tester, 0);
    expect(
      find.descendant(
        of: find.byType(DSTourDots),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
      reason:
          'the button and the swipe are the two ways forward; a third one on '
          'a 6pt dot is a mis-tap waiting to happen',
    );
  });
}
