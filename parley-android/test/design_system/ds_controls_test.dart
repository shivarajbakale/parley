import 'dart:ui' show CheckedState, Tristate, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Four hand-built copies of one row became one, and one control that did not
/// exist arrived.
///
/// The claims here are the ones the consolidation is *for*: that a switch row
/// and a list row are the same height because they read the same fields, that
/// the third checkbox state the old signature promised is now reachable, and
/// that a bare control still refuses to ship without a name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
    bool reducedMotion = false,
    bool scroll = true,
    DesignSpec? spec,
    TargetPlatform? platform,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Design(
        spec: spec ?? AppTheme.spec,
        child: MaterialApp(
          theme: platform == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(platform: platform),
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: inner!,
          ),
          home: Scaffold(
            body: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the row that used to be written four times', () {
    testWidgets('a switch row and a list row are the same height for the '
        'same content', (tester) async {
      // The drift this plan exists for: DSSwitch padded `md` vertically and
      // DSSlider padded `sm`, so a settings screen with both had two heights.
      //
      // The label is short on purpose. What is being compared is the vertical
      // padding, and a title takes two lines now rather than being cut at one
      // — so a label long enough to wrap makes the row with a trailing switch
      // taller than the row without one, which is a fact about the width left
      // for the text and not about the padding this asserts.
      await pump(
        tester,
        Column(
          children: [
            DSSwitchTile(
              label: 'Sync',
              subtitle: 'Uses your data plan',
              value: true,
              onChanged: (_) {},
            ),
            DSListTile(
              title: 'Sync',
              subtitle: 'Uses your data plan',
              onTap: () {},
            ),
          ],
        ),
      );

      expect(
        tester.getSize(find.byType(DSSwitchTile)).height,
        tester.getSize(find.byType(DSListTile).last).height,
      );
    });

    testWidgets('a control tile is one semantics node carrying the label, '
        'the subtitle and the state', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DSSwitchTile(
          label: 'Sync over cellular',
          subtitle: 'Uses your data plan',
          value: true,
          onChanged: (_) {},
        ),
      );

      final node = _find(
        tester,
        (data) => data.label.contains('Sync over cellular'),
      );
      expect(node, isNotNull);
      expect(
        node!.getSemanticsData().label.contains('Uses your data plan'),
        isTrue,
        reason: 'the subtitle belongs to the same node, not a second one',
      );
      expect(
        node.getSemanticsData().flagsCollection.isToggled,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('a control tile stays one tap target for the whole row', (
      tester,
    ) async {
      var taps = 0;
      await pump(
        tester,
        DSSwitchTile(
          label: 'Sync over cellular',
          value: false,
          onChanged: (_) => taps++,
        ),
      );
      // The far end of the row, nowhere near the switch.
      await tester.tapAt(
        tester.getRect(find.byType(DSSwitchTile)).centerLeft +
            const Offset(24, 0),
      );
      expect(taps, 1);
    });

    testWidgets('control targets in a list do not overlap, at 1.0 and at 2.0', (
      tester,
    ) async {
      for (final scale in const [1.0, 2.0]) {
        await pump(
          tester,
          Column(
            children: [
              for (final row in const ['One', 'Two', 'Three'])
                DSSwitchTile(label: row, value: true, onChanged: (_) {}),
            ],
          ),
          textScale: scale,
        );
        final rects = tester
            .widgetList<DSSwitch>(find.byType(DSSwitch))
            .toList()
            .asMap()
            .keys
            .map((i) => tester.getRect(find.byType(DSSwitch).at(i)))
            .toList();
        for (var i = 1; i < rects.length; i++) {
          expect(
            rects[i - 1].bottom,
            lessThanOrEqualTo(rects[i].top + 0.5),
            reason: 'two switch targets overlap at text scale $scale',
          );
        }
      }
    });
  });

  group('the checkbox that can finally hold three values', () {
    testWidgets('tapping cycles false, true, mixed and back', (tester) async {
      bool? value = false;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSCheckbox(
            value: value,
            tristate: true,
            semanticLabel: 'Select all',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );

      await tester.tap(find.byType(DSCheckbox));
      await tester.pump();
      expect(value, isTrue);

      await tester.tap(find.byType(DSCheckbox));
      await tester.pump();
      expect(value, isNull, reason: 'the third state has to be reachable');

      await tester.tap(find.byType(DSCheckbox));
      await tester.pump();
      expect(value, isFalse);
    });

    testWidgets('the indeterminate state is announced as mixed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const DSCheckbox(
          value: null,
          tristate: true,
          semanticLabel: 'Select all',
          onChanged: _noop,
        ),
      );
      final node = _find(tester, (data) => data.label == 'Select all');
      expect(node, isNotNull);
      expect(
        node!.getSemanticsData().flagsCollection.isChecked,
        CheckedState.mixed,
      );
      handle.dispose();
    });

    testWidgets('a two-state checkbox given null asserts', (tester) async {
      expect(
        () => DSCheckbox(
          value: null,
          semanticLabel: 'Nothing',
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('a bare control with no name asserts', (tester) async {
      expect(
        () => DSCheckbox(value: false, onChanged: (_) {}),
        throwsAssertionError,
      );
      expect(
        () => DSSwitch(value: false, onChanged: (_) {}),
        throwsAssertionError,
      );
      expect(
        () => DSSlider(value: 0.5, onChanged: (_) {}),
        throwsAssertionError,
      );
    });
  });

  group('the radio the kit did not have', () {
    testWidgets('inside a group it reports mutual exclusivity', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DSRadioGroup<String>(
          value: 'Express',
          onChanged: (_) {},
          children: const [
            DSRadio<String>(value: 'Standard', semanticLabel: 'Standard'),
            DSRadio<String>(value: 'Express', semanticLabel: 'Express'),
          ],
        ),
      );
      final node = _find(tester, (data) => data.label == 'Express');
      expect(node, isNotNull);
      expect(
        node!.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      expect(
        node.getSemanticsData().flagsCollection.isChecked,
        CheckedState.isTrue,
      );
      handle.dispose();
    });

    testWidgets('outside a group it asserts', (tester) async {
      await pump(
        tester,
        const DSRadio<String>(value: 'Alone', semanticLabel: 'Alone'),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('choosing one option deselects the other', (tester) async {
      String chosen = 'Standard';
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSRadioGroup<String>(
            value: chosen,
            onChanged: (value) => setState(() => chosen = value!),
            children: const [
              DSRadioTile<String>(label: 'Standard', value: 'Standard'),
              DSRadioTile<String>(label: 'Express', value: 'Express'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Express'));
      await tester.pump();
      expect(chosen, 'Express');
    });
  });

  group('the switch', () {
    testWidgets('the thumb grows while a finger is on it and shrinks back', (
      tester,
    ) async {
      // Not in a scroll view: a Scrollable's drag recogniser holds the arena
      // open, and the tap's down callback — which is what starts the growth —
      // does not fire until it resolves.
      await pump(
        tester,
        DSSwitch(value: true, semanticLabel: 'Sync', onChanged: (_) {}),
        scroll: false,
      );
      double thumb() {
        final painters = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(DSSwitch),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((paint) => paint.painter)
            .whereType<CustomPainter>();
        final painter = painters.firstWhere(
          (p) => p.runtimeType.toString().contains('Switch'),
        );
        return (painter as dynamic).thumbSize as double;
      }

      final rest = thumb();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DSSwitch)),
      );
      // Two frames on purpose. The first carries the clock past the tap
      // deadline, which is when the recogniser reports the press and the
      // growth starts; the second is the frame that growth is drawn in.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(thumb(), greaterThan(rest));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(thumb(), closeTo(rest, 0.01));
    });

    testWidgets('a disabled switch does not change', (tester) async {
      await pump(
        tester,
        const DSSwitch(value: false, semanticLabel: 'Sync', onChanged: null),
      );
      await tester.tap(find.byType(DSSwitch));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the slider', () {
    testWidgets('the semantics increase and decrease actions move it by one '
        'division', (tester) async {
      final handle = tester.ensureSemantics();
      double value = 0.5;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSSlider(
            value: value,
            divisions: 4,
            semanticLabel: 'Volume',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      final node = _find(
        tester,
        (data) => data.value.isNotEmpty && data.value.contains('of'),
      );
      expect(node, isNotNull);
      node!.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(value, closeTo(0.75, 0.001));
      handle.dispose();
    });

    testWidgets('a discrete slider announces its position in the set', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DSSlider(
          value: 0.5,
          divisions: 6,
          formatter: (v) => '${(v * 100).round()}%',
          semanticLabel: 'Volume',
          onChanged: (_) {},
        ),
      );
      final node = _find(tester, (data) => data.value.contains('of'));
      expect(node, isNotNull);
      expect(node!.getSemanticsData().value, '50%, 4 of 7');
      handle.dispose();
    });

    testWidgets('without a formatter the readout stops at the precision the '
        'range deserves', (tester) async {
      await pump(
        tester,
        DSSlider(
          value: 0.63 * 0.999999,
          showValue: true,
          semanticLabel: 'Volume',
          onChanged: (_) {},
        ),
      );
      expect(find.text('0.6'), findsOneWidget);

      await pump(
        tester,
        DSSlider(
          value: 62.4999,
          min: 0,
          max: 100,
          showValue: true,
          semanticLabel: 'Volume',
          onChanged: (_) {},
        ),
      );
      expect(find.text('62'), findsOneWidget);
    });

    testWidgets('Page Up, Page Down, Home and End reach the far keys Material '
        'does not handle', (tester) async {
      double value = 0.5;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSSlider(
            value: value,
            divisions: 10,
            semanticLabel: 'Volume',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      // Tab moves focus into the slider; the four keys below then bubble past
      // its own node to the kit's handler.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(value, closeTo(1.0, 0.001), reason: 'ten divisions from a half');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(value, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(value, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(value, 0);
    });

    testWidgets('a disabled slider keeps its tap target', (tester) async {
      await pump(
        tester,
        const DSSlider(value: 0.5, semanticLabel: 'Volume', onChanged: null),
      );
      expect(
        tester.getSize(find.byType(DSSlider)).height,
        greaterThanOrEqualTo(AppTheme.spec.component.minTapTarget),
      );
    });

    testWidgets('range thumbs cannot cross and honour the minimum gap', (
      tester,
    ) async {
      DSRange range = const DSRange(20, 30);
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSRangeSlider(
            value: range,
            min: 0,
            max: 100,
            minimumGap: 10,
            onChanged: (next) => setState(() => range = next),
          ),
        ),
      );
      final box = tester.getRect(find.byType(RangeSlider));
      // Drag the leading thumb well past the trailing one.
      await tester.dragFrom(
        Offset(box.left + box.width * 0.2, box.center.dy),
        Offset(box.width * 0.6, 0),
      );
      await tester.pumpAndSettle();
      expect(range.start, lessThanOrEqualTo(range.end));
      expect(range.end - range.start, greaterThanOrEqualTo(10 - 0.001));
    });
  });

  group('the thumb the finger grabs', () {
    // The thumb was the one press in the kit that Material drew: its growth
    // came from `activationAnimation`, a fixed 100ms curve on a controller
    // `Slider` keeps private, so the app's `speed` and `springiness` reached
    // every button and card and stopped at the slider.
    const size = 20.0;
    const pressed = 28.0;
    const style = DSSliderStyle(
      thumbSize: size,
      pressedThumbSize: pressed,
      // No shadow, so the first circle the thumb paints is the thumb.
      thumbShadows: [],
    );

    DSSliderThumb thumbOf(WidgetTester tester) =>
        tester
                .widget<SliderTheme>(
                  find.descendant(
                    of: find.byType(DSSlider),
                    matching: find.byType(SliderTheme),
                  ),
                )
                .data
                .thumbShape!
            as DSSliderThumb;

    /// A finger down, held until the grab has actually started.
    ///
    /// `Slider` hands the press to a drag recogniser, which does not declare
    /// until its own deadline, so the frames right after the pointer lands say
    /// nothing about the spring.
    Future<TestGesture> hold(WidgetTester tester, Finder of) async {
      final gesture = await tester.startGesture(tester.getCenter(of));
      for (var i = 0; i < 200 && thumbOf(tester).grab == 0; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      return gesture;
    }

    Future<void> pumpSlider(
      WidgetTester tester, {
      DesignSpec? spec,
      TargetPlatform? platform,
      Key? key,
    }) async {
      double value = 0.5;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSSlider(
            // Keyed, or a second pump in the same tester keeps the first
            // slider's State and starts the press from where it left off.
            key: key,
            value: value,
            style: style,
            semanticLabel: 'Volume',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
        spec: spec,
        platform: platform,
      );
    }

    testWidgets('the thumb grows under the finger and shrinks when it goes', (
      tester,
    ) async {
      await pumpSlider(tester);
      expect(thumbOf(tester).grab, 0);

      final gesture = await hold(tester, find.byType(Slider));
      await tester.pumpAndSettle();
      expect(thumbOf(tester).grab, closeTo(1, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(thumbOf(tester).grab, closeTo(0, 0.01));
    });

    testWidgets('the grab is what the thumb is drawn at', (tester) async {
      // The wiring, not the number: a grab that never reaches the canvas is a
      // field that animates nothing.
      await pumpSlider(tester);
      expect(find.byType(Slider), paints..circle(radius: size / 2));

      final gesture = await hold(tester, find.byType(Slider));
      await tester.pump(const Duration(milliseconds: 24));
      final grab = thumbOf(tester).grab;
      expect(grab, greaterThan(0));
      expect(grab, lessThan(1), reason: 'caught mid-growth');
      expect(
        find.byType(Slider),
        paints..circle(radius: lerpDouble(size, pressed, grab)! / 2),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('springiness reaches the thumb', (tester) async {
      // The knob is the point. Two identical presses under two springs: the
      // stiffer one is further along on the same frame.
      Future<double> after(double springiness) async {
        await pumpSlider(
          tester,
          key: ValueKey<double>(springiness),
          spec: AppTheme.spec.copyWith(
            motion: AppTheme.spec.motion.copyWith(springiness: springiness),
          ),
        );
        final gesture = await hold(tester, find.byType(Slider));
        await tester.pump(const Duration(milliseconds: 16));
        final grab = thumbOf(tester).grab;
        await gesture.up();
        await tester.pumpAndSettle();
        return grab;
      }

      final loose = await after(1);
      final tight = await after(4);
      expect(tight, greaterThan(loose + 0.05));
    });

    testWidgets('on Apple the growth is a duration, because the kit does not '
        'spring there', (tester) async {
      await pumpSlider(tester, platform: TargetPlatform.iOS);
      final gesture = await hold(tester, find.byType(Slider));
      await tester.pump(AppTheme.spec.motion.press);
      await tester.pump();
      expect(
        thumbOf(tester).grab,
        1,
        reason: 'a curve is exactly done at its duration',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a release mid-growth shrinks from where it got to', (
      tester,
    ) async {
      // What the spring is for. An interrupted press that restarts from 1
      // jumps, and the jump is the whole reason a fixed curve reads as cheap.
      await pumpSlider(tester);
      final gesture = await hold(tester, find.byType(Slider));
      await tester.pump(const Duration(milliseconds: 16));
      final caught = thumbOf(tester).grab;
      expect(caught, lessThan(1));

      await gesture.up();
      await tester.pump();
      expect(
        thumbOf(tester).grab,
        lessThanOrEqualTo(caught),
        reason: 'the shrink continued from the growth, it did not restart',
      );
      expect(thumbOf(tester).grab, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('the range slider grows on the same spring', (tester) async {
      var value = const DSRange(0.3, 0.7);
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => DSRangeSlider(
            value: value,
            style: style,
            startSemanticLabel: 'From',
            endSemanticLabel: 'To',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );

      final box = tester.getRect(find.byType(RangeSlider));
      final gesture = await tester.startGesture(
        Offset(box.left + box.width * 0.3, box.center.dy),
      );
      await tester.pumpAndSettle();

      final shape =
          tester
                  .widget<SliderTheme>(
                    find.descendant(
                      of: find.byType(DSRangeSlider),
                      matching: find.byType(SliderTheme),
                    ),
                  )
                  .data
                  .rangeThumbShape!
              as DSRangeSliderThumb;
      // The shape, not the canvas: `RangeSlider` draws its two thumbs through
      // a paint path this matcher cannot reach past, and the single slider
      // above already proves the grab arrives at `drawCircle` through the one
      // expression both shapes share.
      expect(shape.grab, closeTo(1, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('the style objects', () {
    test('every one of the four interpolates rather than snapping', () {
      const a = DSCheckboxStyle(size: 10, strokeWidth: 1);
      const b = DSCheckboxStyle(size: 20, strokeWidth: 3);
      expect(a.lerp(b, 0.5).size, 15);
      expect(a.lerp(b, 0.5).strokeWidth, 2);

      const c = DSSwitchStyle(trackWidth: 40, thumbSize: 20);
      const d = DSSwitchStyle(trackWidth: 60, thumbSize: 30);
      expect(c.lerp(d, 0.5).trackWidth, 50);
      expect(c.lerp(d, 0.5).thumbSize, 25);

      const e = DSRadioStyle(size: 16, dotFraction: 0.4);
      const f = DSRadioStyle(size: 24, dotFraction: 0.6);
      expect(e.lerp(f, 0.5).size, 20);
      expect(e.lerp(f, 0.5).dotFraction, closeTo(0.5, 0.0001));

      const g = DSSliderStyle(trackHeight: 2, thumbSize: 16);
      const h = DSSliderStyle(trackHeight: 6, thumbSize: 24);
      expect(g.lerp(h, 0.5).trackHeight, 4);
      expect(g.lerp(h, 0.5).thumbSize, 20);

      const i = DSControlTileStyle(gap: 8, verticalPadding: 4);
      const j = DSControlTileStyle(gap: 16, verticalPadding: 12);
      expect(i.lerp(j, 0.5).gap, 12);
      expect(i.lerp(j, 0.5).verticalPadding, 8);
    });

    test('merge lets a later layer override only what it sets', () {
      const base = DSCheckboxStyle(size: 18, strokeWidth: 2);
      final merged = base.merge(const DSCheckboxStyle(size: 24));
      expect(merged.size, 24);
      expect(merged.strokeWidth, 2);
    });
  });
}

void _noop(bool? _) {}

/// The first semantics node matching [test], anywhere in the tree.
///
/// The node rather than its data, because an action has to be performed
/// against an id and only the node carries one.
SemanticsNode? _find(WidgetTester tester, bool Function(SemanticsData) test) {
  SemanticsNode? found;
  void walk(SemanticsNode node) {
    if (found != null) return;
    if (test(node.getSemanticsData())) {
      found = node;
      return;
    }
    node.visitChildren((child) {
      walk(child);
      return found == null;
    });
  }

  walk(_rootSemantics(tester));
  return found;
}

/// The root of the rendered semantics tree.
///
/// `tester.binding.pipelineOwner` is deprecated; the tree is rooted at
/// `rootPipelineOwner` and the node lives on one of its children.
SemanticsNode _rootSemantics(WidgetTester tester) {
  SemanticsNode? found;
  void visit(PipelineOwner owner) {
    found ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  return found!;
}
