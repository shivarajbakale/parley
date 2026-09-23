import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// flutter-028 — the focus ring.
///
/// The audit's A-2: 49 of 52 components rendered nothing when focused, which
/// fails WCAG 2.4.7 outright and makes the app unusable with a hardware
/// keyboard. `DSPressable` is where it is fixed, because every pressable in
/// the kit already goes through it.
///
/// Focus highlight mode is forced rather than assumed. In a test the manager
/// starts in [FocusHighlightMode.touch] on a mobile target, which is correct
/// behaviour and would make every assertion here pass for the wrong reason.
void main() {
  late BuildContext ctx;

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return Center(child: child);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool ringOf(WidgetTester tester) => tester
      .widgetList<DSFocusRing>(find.byType(DSFocusRing))
      .any((ring) => ring.visible);

  int visibleRings(WidgetTester tester) => tester
      .widgetList<DSFocusRing>(find.byType(DSFocusRing))
      .where((ring) => ring.visible)
      .length;

  /// The label inside whichever ring is lit, so a test can say the ring moved
  /// rather than only that one exists.
  String litLabel(WidgetTester tester) {
    final lit = find.byWidgetPredicate((w) => w is DSFocusRing && w.visible);
    return tester
        .widget<Text>(
          find.descendant(of: lit, matching: find.byType(Text)).first,
        )
        .data!;
  }

  /// Tab until a ring lights, the way a keyboard user reaches a control.
  ///
  /// Not one `nextFocus`: a component may put a focusable ahead of the one
  /// being tested — DSStepper's decrement button sits before its increment —
  /// and a test that assumes the first stop is the interesting one is testing
  /// traversal order rather than the ring.
  Future<void> tabTo(WidgetTester tester, {int stops = 6}) async {
    for (var i = 0; i < stops; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (ringOf(tester)) return;
    }
  }

  group('a pressable shows the ring when focus arrives from a keyboard', () {
    testWidgets('nothing is drawn before focus', (tester) async {
      await pump(tester, DSButton(label: 'Continue', onPressed: () {}));
      expect(find.byType(DSFocusRing), findsWidgets);
      expect(ringOf(tester), isFalse);
    });

    testWidgets('the ring appears once the button holds focus', (tester) async {
      await pump(tester, DSButton(label: 'Continue', onPressed: () {}));
      await tabTo(tester);
      expect(ringOf(tester), isTrue);
    });

    testWidgets('and exactly one control has it at a time', (tester) async {
      // Focus leaving is what a second ring would prove wrong, and it is the
      // realistic case: two rings on one screen is worse than none, because
      // the user cannot tell which control the keyboard is pointing at.
      await pump(
        tester,
        Column(
          children: [
            DSButton(label: 'Back', onPressed: () {}),
            DSButton(label: 'Continue', onPressed: () {}),
          ],
        ),
      );
      await tabTo(tester);
      expect(visibleRings(tester), 1);
      final first = litLabel(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(visibleRings(tester), 1);
      expect(litLabel(tester), isNot(first));
    });
  });

  testWidgets('a finger never sees it', (tester) async {
    // The whole reason the ring can be unconditional in the tree: on a phone
    // that has never seen a key press the highlight mode is `touch`, and a
    // control that was tapped may hold focus without the user knowing focus
    // exists.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await pump(tester, DSButton(label: 'Continue', onPressed: () {}));
    await tabTo(tester);
    expect(ringOf(tester), isFalse);
  });

  testWidgets('reduced motion removes the dip and keeps the ring', (
    tester,
  ) async {
    // The early return this replaced returned the bare child, so under reduced
    // motion the ring would have been missing from the whole kit — for the
    // users most likely to be driving it from a keyboard.
    await pump(
      tester,
      DSButton(label: 'Continue', onPressed: () {}),
      disableAnimations: true,
    );
    expect(
      find.descendant(
        of: find.byType(DSPressable),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    await tabTo(tester);
    expect(ringOf(tester), isTrue);
  });

  testWidgets('a pressable with its dip switched off still rings', (
    tester,
  ) async {
    // `enabled: false` is how DSStepper and DSDateStrip stop the container
    // scaling; both are fully tappable. A ring gated on `enabled` would be
    // missing from exactly those two.
    await pump(tester, DSStepper(value: 2, onChanged: (_) {}));
    await tabTo(tester);
    expect(ringOf(tester), isTrue);
  });

  group('the ring is drawn from tokens', () {
    testWidgets('accent, at the spec width and gap', (tester) async {
      await pump(tester, DSButton(label: 'Continue', onPressed: () {}));
      await tabTo(tester);
      final ring = tester
          .widgetList<DSFocusRing>(find.byType(DSFocusRing))
          .firstWhere((r) => r.visible);
      final component = ctx.design.component;
      expect(ring.color ?? ctx.palette.primary, ctx.palette.primary);
      expect(ring.width ?? component.focusRingWidth, component.focusRingWidth);
      expect(ring.gap ?? component.focusRingGap, component.focusRingGap);
      expect(component.focusRingWidth, greaterThanOrEqualTo(2));
    });

    testWidgets('and follows the control it rings, not a default', (
      tester,
    ) async {
      // A pill chip ringed as a rounded rectangle reads as a drawing error.
      await pump(tester, DSChip(label: 'Unread', onTap: () {}));
      final ring = tester.widget<DSFocusRing>(find.byType(DSFocusRing).first);
      expect(ring.shape, isNotNull);
    });
  });

  testWidgets('the ring costs no layout', (tester) async {
    // It paints outside the child's bounds on purpose: focusing a row in a
    // list must not move the rows under it.
    await pump(tester, DSButton(label: 'Continue', onPressed: () {}));
    final before = tester.getSize(find.byType(DSButton));
    await tabTo(tester);
    expect(tester.getSize(find.byType(DSButton)), before);
  });
}
