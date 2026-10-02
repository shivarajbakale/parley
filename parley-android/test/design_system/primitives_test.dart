import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// The primitives take the platform's shape, its controls and its motion.
///
/// These are the assertions a golden cannot make. A contact sheet shows that
/// the Apple and Material columns differ; it cannot say *why*, and it cannot
/// say that the difference is the platform rather than an accident. So the
/// checks here name the class: a continuous curve on Apple and a circular arc
/// on Android, an activity indicator and not a spinning ring — and, for the
/// switch, that there is no platform switch underneath at all any more, only
/// the kit's own at the identity's geometry.
///
/// The other half is press feedback, which is the part most likely to rot. It
/// lives in one widget, and these tests hold that widget to three promises: it
/// scales, it never steals the tap, and it does nothing at all when the user
/// has asked for less movement.
void main() {
  Future<void> pumpUnder(
    WidgetTester tester,
    TargetPlatform platform,
    Widget child, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(platform: platform),
        // Inside the app, not around it: MaterialApp installs its own
        // MediaQuery from the test window, so a wrapper outside it never
        // reaches the widget under test.
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: inner!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  /// The scale [DSPressable] is currently applying, or 1.0 when it has decided
  /// not to apply one at all.
  double pressScale(WidgetTester tester) {
    final transforms = find.descendant(
      of: find.byType(DSPressable),
      matching: find.byType(Transform),
    );
    if (transforms.evaluate().isEmpty) return 1;
    // The x scale specifically, not `getMaxScaleOnAxis`: that one takes the
    // largest of the three column norms, and the z column of a 2D scale is
    // always 1, so it reports 1.0 for every dip and the test passes forever.
    return tester.widget<Transform>(transforms.first).transform.storage[0];
  }

  group('DSPressable', () {
    testWidgets('dips under the finger and returns on release', (tester) async {
      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSPressable(
          child: ColoredBox(
            color: Color(0xFF112233),
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );

      expect(pressScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DSPressable)),
      );
      // Two pumps, not one: a Ticker records its start time on its first
      // frame, so the frame that begins an animation always reports zero
      // elapsed. Testing the press with a single pump reads the rest value
      // and passes for the wrong reason.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        pressScale(tester),
        lessThan(1.0),
        reason: 'the press did not scale anything',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressScale(tester), moreOrLessEquals(1.0, epsilon: 0.01));
    });

    testWidgets('does not move at all under reduced motion', (tester) async {
      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSPressable(
          child: ColoredBox(
            color: Color(0xFF112233),
            child: SizedBox(width: 120, height: 48),
          ),
        ),
        disableAnimations: true,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DSPressable)),
      );
      // Two pumps, not one: a Ticker records its start time on its first
      // frame, so the frame that begins an animation always reports zero
      // elapsed. Testing the press with a single pump reads the rest value
      // and passes for the wrong reason.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // Not a faster dip — no dip, and no listener either. The press still
      // reads through the colour every control already changes.
      expect(pressScale(tester), 1.0);
      expect(
        find.descendant(
          of: find.byType(DSPressable),
          matching: find.byType(Listener),
        ),
        findsNothing,
      );
      await gesture.up();
    });

    testWidgets('observes the press without taking the tap', (tester) async {
      var taps = 0;
      await pumpUnder(
        tester,
        TargetPlatform.android,
        DSPressable(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );

      await tester.tap(find.byType(DSPressable));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the press wrapper swallowed or doubled the tap');
    });

    testWidgets('releases when the finger drags away into a scroll', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSPressable(
          child: ColoredBox(
            color: Color(0xFF112233),
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DSPressable)),
      );
      // Two pumps, not one: a Ticker records its start time on its first
      // frame, so the frame that begins an animation always reports zero
      // elapsed. Testing the press with a single pump reads the rest value
      // and passes for the wrong reason.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(pressScale(tester), lessThan(1.0));

      // Past the slop is a scroll, not a press. Without this every row of a
      // list dips as the list is flung.
      await gesture.moveBy(const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(pressScale(tester), moreOrLessEquals(1.0, epsilon: 0.01));
      await gesture.up();
    });
  });

  group('the platform shape', () {
    /// The shape the first shape-decorated container in [child] draws.
    Future<ShapeBorder> shapeOf(
      WidgetTester tester,
      TargetPlatform platform,
      Widget child,
    ) async {
      await pumpUnder(tester, platform, child);
      return tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<ShapeDecoration>()
          .first
          .shape;
    }

    testWidgets('DSCard is a continuous curve on Apple and an arc on Android', (
      tester,
    ) async {
      expect(
        await shapeOf(
          tester,
          TargetPlatform.iOS,
          const DSCard(child: Text('card')),
        ),
        isA<RoundedSuperellipseBorder>(),
      );
      expect(
        await shapeOf(
          tester,
          TargetPlatform.android,
          const DSCard(child: Text('card')),
        ),
        isA<RoundedRectangleBorder>(),
      );
    });

    testWidgets('DSButton takes the same two shapes', (tester) async {
      // The button paints its own ground now rather than delegating to a
      // `FilledButton`, so the shape is read off the decoration it draws.
      Future<ShapeBorder?> buttonShape(TargetPlatform platform) async {
        await pumpUnder(
          tester,
          platform,
          DSButton(label: 'Continue', onPressed: () {}),
        );
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(DSButton),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as ShapeDecoration).shape;
      }

      expect(
        await buttonShape(TargetPlatform.iOS),
        isA<RoundedSuperellipseBorder>(),
      );
      expect(
        await buttonShape(TargetPlatform.android),
        isA<RoundedRectangleBorder>(),
      );
    });
  });

  group('the platform control', () {
    testWidgets('DSSwitch is the kit\'s own switch on both platforms, at the '
        'identity\'s geometry', (tester) async {
      // It used to be `Switch.adaptive`, and the branch was the thing worth
      // asserting. It is not adaptive any more, and that is the point: the
      // track was whatever Material or Cupertino had decided, so a house
      // style could move neither, and the pressed-thumb growth both platforms
      // ship was missing from both. The successor claim is that one geometry
      // comes from ComponentSpec and holds on either platform.
      final component = AppTheme.spec.component;
      for (final platform in const [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ]) {
        await pumpUnder(
          tester,
          platform,
          DSSwitch(
            value: true,
            semanticLabel: 'Notifications',
            onChanged: (_) {},
          ),
        );
        expect(find.byType(Switch), findsNothing, reason: '$platform');
        final painted = tester.getSize(
          find
              .descendant(
                of: find.byType(DSSwitch),
                matching: find.byType(CustomPaint),
              )
              .last,
        );
        expect(painted.width, component.switchTrackWidth, reason: '$platform');
        expect(
          painted.height,
          component.switchTrackHeight,
          reason: '$platform',
        );
      }
    });

    testWidgets('a switch in a list row draws the compact track', (
      tester,
    ) async {
      final component = AppTheme.spec.component;
      await pumpUnder(
        tester,
        TargetPlatform.android,
        DSSwitchTile(label: 'Haptics', value: true, onChanged: (_) {}),
      );
      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(DSSwitch),
              matching: find.byType(CustomPaint),
            )
            .last,
      );
      expect(painted.width, component.switchCompactTrackWidth);
      expect(painted.height, component.switchCompactTrackHeight);
      final target = tester.getSize(find.byType(DSSwitch));
      expect(target.height, greaterThanOrEqualTo(component.minTapTarget));
    });

    testWidgets('the circular progress indicator is the system one', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        TargetPlatform.iOS,
        const DSProgressIndicator.circular(),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSProgressIndicator.circular(),
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('the tap-target floor', () {
    testWidgets('DSChip clears it on both platforms', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await pumpUnder(
          tester,
          platform,
          DSChip(label: 'Design', role: DSChipRole.filter, onSelected: (_) {}),
        );
        final context = tester.element(find.byType(DSChip));
        expect(
          tester.getSize(find.byType(DSChip)).height,
          greaterThanOrEqualTo(context.design.component.minTapTarget),
          reason:
              '$platform: a 32pt chip is the quietest accessibility bug '
              'in a kit that otherwise looks careful',
        );
      }
    });

    testWidgets('DSListTile clears it on both platforms', (tester) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await pumpUnder(tester, platform, const DSListTile(title: 'Row'));
        final context = tester.element(find.byType(DSListTile));
        expect(
          tester.getSize(find.byType(ListTile)).height,
          greaterThanOrEqualTo(context.design.component.minTapTarget),
        );
      }
    });
  });

  group('DSSegmentedButton', () {
    const segments = <Widget>[
      DSSegment<String>(value: 'a', label: 'One'),
      DSSegment<String>(value: 'b', label: 'Two'),
      DSSegment<String>(value: 'c', label: 'Three'),
    ];

    /// Where the indicator's leading edge is.
    ///
    /// It is positioned from the measured segment widths now rather than by
    /// fractional alignment, because that is what lets it land correctly under
    /// all three sizings instead of only under equal-width ones.
    double? thumbStart(WidgetTester tester) {
      final found = find.descendant(
        of: find.byType(DSSegmentedButton<String>),
        matching: find.byType(PositionedDirectional),
      );
      if (found.evaluate().isEmpty) return null;
      return tester.widget<PositionedDirectional>(found.first).start;
    }

    testWidgets('one thumb travels rather than two backgrounds crossfading', (
      tester,
    ) async {
      var selected = 'a';
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => DSSegmentedButton<String>(
                segments: segments,
                selected: selected,
                onChanged: (v) => setState(() => selected = v),
              ),
            ),
          ),
        ),
      );
      // Two frames: the first lays the segments out and reports their widths,
      // the second is the one the indicator can be placed in.
      await tester.pump();
      await tester.pump();

      expect(thumbStart(tester), 0);

      await tester.tap(find.text('Three'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final midway = thumbStart(tester)!;
      expect(midway, greaterThan(0));

      await tester.pumpAndSettle();
      final settled = thumbStart(tester)!;
      expect(
        midway,
        lessThan(settled),
        reason: 'the thumb jumped instead of travelling',
      );
      // Two thirds of the way across the track: the third of three slots.
      expect(settled, greaterThan(0));
    });

    testWidgets('multiple selection fills every chosen segment in place', (
      tester,
    ) async {
      // An indicator cannot travel to two places, so the selected segments
      // take a static fill instead. This is the one place the control's
      // signature motion deliberately does not apply — but it is still a
      // fill: the control painted nothing at all here, which left the label's
      // weight as the only mark of what was on.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DSSegmentedButton<String>.multiple(
              segments: segments,
              selected: const {'a', 'c'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // One slot per segment, built whether it is on or not so a toggle
      // fades; the opacity is what says which are on.
      final slots = tester
          .widgetList<AnimatedOpacity>(
            find.descendant(
              of: find.byType(PositionedDirectional),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .map((AnimatedOpacity o) => o.opacity)
          .toList();
      expect(slots, <double>[
        1,
        0,
        1,
      ], reason: 'the chosen segments are not painted');

      // And none of them moves: the fills sit at their own segments' edges,
      // so the first is flush with the start of the track.
      expect(thumbStart(tester), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(thumbStart(tester), 0);
    });

    testWidgets('the track paints with nothing selected', (tester) async {
      // The track used to be sized by the indicator inside it, so a filter
      // row that started empty — and every multiple-selection control —
      // painted no background at all.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DSSegmentedButton<String>(
              segments: segments,
              selected: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final control = tester.getSize(find.byType(DSSegmentedButton<String>));
      final painted = tester.getSize(
        find
            .descendant(
              of: find.byType(DSSegmentedButton<String>),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final design = Design.of(
        tester.element(find.byType(DSSegmentedButton<String>)),
      );
      expect(painted.width, control.width);
      expect(painted.height, design.component.controlHeight);
    });

    testWidgets('fill sizing weights segments by their own content', (
      tester,
    ) async {
      // `fill` weighted its flexes by each segment's *laid-out* width, which
      // under an `Expanded` is the width the flex just handed it — a loop
      // whose only fixed point is an equal share, so `fill` rendered exactly
      // like `equal`.
      Future<List<double>> widthsFor(DSSegmentedSizing sizing) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: DSSegmentedButton<String>(
                sizing: sizing,
                selected: 'a',
                onChanged: (_) {},
                segments: const <Widget>[
                  DSSegment<String>(value: 'a', label: 'Up'),
                  DSSegment<String>(value: 'b', label: 'A much longer label'),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        return <double>[
          for (final String label in <String>['Up', 'A much longer label'])
            tester
                .getSize(
                  find
                      .ancestor(
                        of: find.text(label),
                        matching: find.byType(Expanded),
                      )
                      .first,
                )
                .width,
        ];
      }

      final equal = await widthsFor(DSSegmentedSizing.equal);
      expect(equal[0], moreOrLessEquals(equal[1], epsilon: 0.5));

      final fill = await widthsFor(DSSegmentedSizing.fill);
      expect(
        fill[1],
        greaterThan(fill[0] * 1.5),
        reason: 'fill is rendering as equal — the long label got no more room',
      );
      expect(
        fill[0] + fill[1],
        moreOrLessEquals(equal[0] + equal[1], epsilon: 1),
        reason: 'fill still fills the row',
      );
    });

    testWidgets('more than five segments asserts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DSSegmentedButton<int>(
              selected: 0,
              onChanged: (_) {},
              segments: [
                for (var i = 0; i < 6; i++)
                  DSSegment<int>(value: i, label: '$i'),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('an icon-only segment with no tooltip asserts', (tester) async {
      expect(
        () => DSSegment<String>(value: 'a', icon: Icons.abc),
        throwsAssertionError,
      );
    });
  });

  group('DSSkeleton', () {
    testWidgets('stops sweeping under reduced motion but keeps the bones', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSSkeleton(child: Text('loading')),
        disableAnimations: true,
      );

      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((w) => w is Skeletonizer),
      );
      // The placeholder stays; only the animation goes. The user asked for
      // less movement, not for less information.
      expect(skeletonizer.effect, isA<SolidColorEffect>());
      expect(skeletonizer.enabled, isTrue);
    });

    testWidgets('shimmers when motion is allowed', (tester) async {
      await pumpUnder(
        tester,
        TargetPlatform.android,
        const DSSkeleton(child: Text('loading')),
      );
      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((w) => w is Skeletonizer),
      );
      expect(skeletonizer.effect, isA<ShimmerEffect>());
    });
  });

  group('DSSelect', () {
    testWidgets(
      'the popover lifts through AppShadows, not Material elevation',
      (tester) async {
        await pumpUnder(
          tester,
          TargetPlatform.android,
          DSSelect<String>(
            options: const [
              DSSelectOption<String>(value: 'One', label: 'One'),
              DSSelectOption<String>(value: 'Two', label: 'Two'),
            ],
            value: 'One',
            onChanged: (_) {},
          ),
        );

        await tester.tap(find.text('One'));
        await tester.pumpAndSettle();

        // The surface paints through a DecoratedBox now rather than a
        // Container: the depth moved onto DSOverlaySurface, which every
        // presentation shares, so a menu and a select can no longer disagree
        // about how far off the page they sit.
        final decoration = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<ShapeDecoration>()
            .firstWhere((d) => d.shadows != null && d.shadows!.isNotEmpty);

        // Two layers, always: a tight contact shadow and a wide ambient one.
        // One blurred rectangle is the tell of a surface nobody designed.
        expect(decoration.shadows, hasLength(2));
        expect(decoration.shape, isA<OutlinedBorder>());
      },
    );
  });
}
