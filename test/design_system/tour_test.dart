import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<DSTourStop> stops = <DSTourStop>[
    DSTourStop(
      art: (bool active) => const DSTourCanvas(child: SizedBox.shrink()),
      headline: 'One',
      body: 'The first claim.',
    ),
    DSTourStop(
      art: (bool active) => const DSTourCanvas(child: SizedBox.shrink()),
      headline: 'Two',
      body: 'The second claim.',
    ),
    DSTourStop(
      art: (bool active) => const DSTourCanvas(child: SizedBox.shrink()),
      headline: 'Three',
      body: 'The handover.',
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onSkip,
    required VoidCallback onFinish,
    int initialStop = 0,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DSTour(
          // A fresh element per stop: `initialStop` is read once, when the
          // state is created, so re-pumping the same tree with a different
          // value would keep the old page — as `PageView.initialPage` does.
          key: ValueKey<int>(initialStop),
          stops: stops,
          initialStop: initialStop,
          onFinish: onFinish,
          onSkip: onSkip,
          finishLabel: 'Get started',
          finishCaption: 'About two minutes, once.',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('advances by tap, and the label changes exactly once', (
    tester,
  ) async {
    bool finished = false;
    await pump(tester, onFinish: () => finished = true);

    for (int i = 0; i < 2; i++) {
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Next'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('swiping reaches the same last stop as tapping', (tester) async {
    await pump(tester, onFinish: () {});
    for (int i = 0; i < 2; i++) {
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('a back-swipe on the first stop does not fall out', (
    tester,
  ) async {
    await pump(tester, onFinish: () {});
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.byType(DSTour), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('no onSkip means no way out but the end', (tester) async {
    await pump(tester, onFinish: () {});
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('an onSkip is offered, and taken', (tester) async {
    bool skipped = false;
    await pump(tester, onFinish: () {}, onSkip: () => skipped = true);
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(skipped, isTrue);
  });

  testWidgets('the caption appears only on the last stop', (tester) async {
    // The Text is always built — a fixed slot, so the button does not move
    // when the line under it appears — so the opacity is what is asserted,
    // reached through the caption rather than by position in the tree.
    double captionOpacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text('About two minutes, once.'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    await pump(tester, onFinish: () {});
    expect(captionOpacity(), 0);

    await pump(tester, onFinish: () {}, initialStop: 2);
    expect(captionOpacity(), 1);
  });

  testWidgets('the art is hidden from screen readers', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, onFinish: () {});
    expect(
      find.descendant(
        of: find.byType(DSTourSlide),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('initialStop opens where it is asked to', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, onFinish: () {}, initialStop: 1);
    expect(find.text('Two'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
    handle.dispose();
  });
}
