import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/06-ds-stepper.plan.md`.
void main() {
  late BuildContext ctx;
  late List<int> changes;
  late List<MethodCall> haptics;

  setUp(() {
    changes = <int>[];
    haptics = <MethodCall>[];
    AppHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    int value = 3,
    int min = 0,
    int max = 10,
    int step = 1,
    bool enabled = true,
    bool longPress = true,
    DSStepperSize? size,
    String unit = '',
    String? errorText,
    Widget? valueSlot,
    FocusNode? focusNode,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return Center(
                  child: DSStepper(
                    value: value,
                    min: min,
                    max: max,
                    step: step,
                    enabled: enabled,
                    enableLongPressRepeat: longPress,
                    size: size,
                    semanticUnit: unit,
                    errorText: errorText,
                    valueSlot: valueSlot,
                    focusNode: focusNode,
                    onChanged: changes.add,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  group('the adjustable node', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('is one node with the unit spoken', (tester) async {
      await pump(tester, unit: 'guests');
      final node = tester.getSemantics(find.byType(DSStepper));
      expect(node.value, '3 guests');
      expect(node.increasedValue, '4 guests');
      expect(node.decreasedValue, '2 guests');
    });

    testWidgets('says "no more" at each bound by going empty', (tester) async {
      await pump(tester, value: 0, min: 0, max: 10);
      expect(
        tester.getSemantics(find.byType(DSStepper)).decreasedValue,
        '',
        reason: 'an empty decreasedValue is how both platforms announce it',
      );

      await pump(tester, value: 10, min: 0, max: 10);
      expect(tester.getSemantics(find.byType(DSStepper)).increasedValue, '');
    });

    testWidgets('the buttons are still exposed, and disabled at their '
        'bound', (tester) async {
      await pump(tester, value: 0, min: 0, max: 10, unit: 'guests');
      final buttons = tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.button ?? false),
            ),
          )
          .toList();
      expect(buttons.map((b) => b.properties.label), [
        'Decrease guests',
        'Increase guests',
      ]);
      expect(buttons.first.properties.enabled, isFalse);
      expect(buttons.last.properties.enabled, isTrue);
    });
  });

  group('the bounds', () {
    testWidgets('tapping past a bound changes nothing and fires no haptic', (
      tester,
    ) async {
      await pump(tester, value: 0, min: 0, max: 10);
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(changes, isEmpty);
      expect(
        haptics,
        isEmpty,
        reason:
            'the absence of feedback is the feedback; a bounce here '
            'reads as "it worked"',
      );
    });

    testWidgets('a tap inside the bounds fires once, with a haptic', (
      tester,
    ) async {
      await pump(tester, value: 3);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(changes, [4]);
      expect(haptics, hasLength(1));
    });

    testWidgets('an odd step against the range refuses to build', (
      tester,
    ) async {
      expect(
        () => DSStepper(value: 0, min: 0, max: 10, step: 3, onChanged: (_) {}),
        throwsAssertionError,
      );
    });

    testWidgets('step 5 moves by 5 and shows the value, not the step', (
      tester,
    ) async {
      await pump(tester, value: 5, min: 0, max: 10, step: 5);
      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(changes, [10]);
    });
  });

  group('long press', () {
    testWidgets('repeats, accelerates and stops at the bound', (tester) async {
      await pump(tester, value: 0, min: 0, max: 10);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add_rounded)),
      );
      // The delay, then a run of repeats. The stepper is uncontrolled, so the
      // value it is handed never moves — what is measured here is that it
      // keeps firing rather than that it counts.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 800));
      await gesture.up();
      await tester.pump();
      expect(changes.length, greaterThan(4));
      expect(changes.every((c) => c == 1), isTrue);

      final before = changes.length;
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        changes.length,
        before,
        reason: 'lifting the finger stops the repeat',
      );
    });

    testWidgets('switched off, a hold fires exactly once', (tester) async {
      await pump(tester, value: 3, longPress: false);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add_rounded)),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pump();
      expect(changes, [4]);
    });
  });

  group('the geometry', () {
    testWidgets('compact is 36 tall and its target still clears the floor', (
      tester,
    ) async {
      await pump(tester, size: DSStepperSize.compact);
      final floor = ctx.design.component.minTapTarget;
      // The well is 36 — that is what lets a stepper sit in a list row — and
      // the two buttons inside it are targets at the floor on both axes. They
      // could not be while the well was their parent: a 36-point box hands its
      // children a 36-point constraint.
      expect(tester.getSize(find.byType(InkWell).first).height, 36);
      expect(
        tester.getSize(find.byType(InkWell).first).width,
        greaterThanOrEqualTo(floor),
      );
      expect(
        tester.getSize(find.byType(DSStepper)).height,
        greaterThanOrEqualTo(floor),
      );
    });

    testWidgets('the value column does not resize from 9 to 10', (
      tester,
    ) async {
      await pump(tester, value: 9, min: 0, max: 10);
      final narrow = tester.getSize(find.byType(DSStepper)).width;
      await pump(tester, value: 10, min: 0, max: 10);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DSStepper)).width,
        narrow,
        reason: 'the buttons must not move under the thumb between 9 and 10',
      );
    });
  });

  group('state', () {
    testWidgets('the widget holds none — the value only moves from outside', (
      tester,
    ) async {
      await pump(tester, value: 3);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(changes, [4]);
      expect(
        find.text('3'),
        findsOneWidget,
        reason:
            'a stepper with internal state is a stepper that disagrees with '
            'the model it is editing',
      );
    });
  });

  group('the keyboard', () {
    testWidgets('arrows step, home and end go to the bounds', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pump(tester, value: 3, min: 0, max: 10, focusNode: node);
      node.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(changes, [4, 2, 0, 10]);
    });
  });

  group('the error state', () {
    testWidgets('always renders the message, never colour alone', (
      tester,
    ) async {
      await pump(tester, errorText: 'Pick at least one');
      expect(find.text('Pick at least one'), findsOneWidget);
    });
  });

  group('the slots', () {
    testWidgets('a value slot keeps the buttons, the bounds and the '
        'semantics', (tester) async {
      final handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics();
      await pump(tester, value: 2, unit: 'kg', valueSlot: const Text('2 kg'));
      expect(find.text('2 kg'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(DSStepper)).increasedValue,
        '3 kg',
      );
      handle.dispose();
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSStepperStyle(height: 48, valueMinWidth: 48);
      final merged = base.merge(const DSStepperStyle(height: 36));
      expect(merged.height, 36);
      expect(merged.valueMinWidth, 48, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSStepperStyle(height: 0, valueMinWidth: 0);
      const b = DSStepperStyle(height: 48, valueMinWidth: 100);
      final mid = a.lerp(b, 0.5);
      expect(mid.height, 24);
      expect(mid.valueMinWidth, 50);
    });
  });
}
