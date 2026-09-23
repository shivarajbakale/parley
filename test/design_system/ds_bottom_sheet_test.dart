import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Three sheets became one, and the physics that was already right stayed.
///
/// The claims here are the ones the consolidation could have lost: the
/// scroll-aware drag, the pinned header and footer, the keyboard, and the
/// behaviour at a raised text scale. `useSnapPoints` is gone — passing the
/// points *is* the opt-in — so the two code paths one boolean used to choose
/// between are now one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(
    WidgetTester tester,
    Widget sheet, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: sheet),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// A snapping sheet whose body is a plain vertical list.
  ///
  /// It passes no `ScrollController`, which makes it `primary` and attaches it
  /// to the one `DraggableScrollableSheet` publishes through
  /// `PrimaryScrollController`. `onController` hands that controller back,
  /// because it is now the only thing that knows where the list is — and the
  /// fixture this replaces, which owned its own controller, is precisely how
  /// the defect below stayed invisible.
  Widget snapping({
    required ValueChanged<ScrollController> onController,
    ScrollPhysics? physics,
  }) => DSBottomSheet(
    snapPoints: const [0.3, 0.6, 0.9],
    initialSnap: 0.6,
    child: Builder(
      builder: (context) {
        onController(PrimaryScrollController.of(context));
        return ListView.builder(
          physics: physics,
          itemCount: 30,
          itemBuilder: (context, index) =>
              SizedBox(height: 56, child: Text('Row $index')),
        );
      },
    ),
  );

  /// What the user sees. `DSBottomSheet` is now the full-height box that
  /// `DraggableScrollableSheet` positions the surface inside, so the height of
  /// the sheet is the height of the surface.
  double surfaceHeight(WidgetTester tester) =>
      tester.getSize(find.byType(DSOverlaySurface)).height;

  group('the gesture a sheet has to resolve', () {
    // Dragging down at the top of a scrolled-to-top list moves the sheet;
    // anywhere else it scrolls the list. This is the hardest part of a sheet
    // to get right and the hand-written version had it wrong: it asked
    // `Scrollable.maybeOf(context)` for the body's position from a context
    // above the body, always got null, and always concluded "at the top".
    testWidgets('at the top of the list, the drag moves the sheet', (
      tester,
    ) async {
      late ScrollController list;
      await pumpSheet(tester, snapping(onController: (c) => list = c));

      final before = surfaceHeight(tester);
      await tester.drag(find.text('Row 1'), const Offset(0, 220));
      await tester.pump();

      expect(
        list.offset,
        0,
        reason: 'the list was already at the top; it should not have scrolled',
      );
      expect(
        surfaceHeight(tester),
        lessThan(before),
        reason: 'the sheet should have followed the finger down',
      );
    });

    testWidgets('further down the list, a downward drag scrolls the list and '
        'leaves the sheet where it is', (tester) async {
      // The defect, stated. The old suite tested this direction with an
      // *upward* drag, which the previous handler ignored outright
      // (`event.delta.dy <= 0`), so it passed without ever exercising the
      // broken path. Downward, from offset 400, the sheet used to follow the
      // finger 1:1 — 506.4 points to 286.4 in one gesture, and a second one
      // crossed the dismiss threshold and popped the route.
      late ScrollController list;
      await pumpSheet(tester, snapping(onController: (c) => list = c));

      list.jumpTo(400);
      await tester.pump();
      final before = surfaceHeight(tester);

      await tester.drag(find.text('Row 8'), const Offset(0, 220));
      await tester.pump();

      expect(
        surfaceHeight(tester),
        before,
        reason: 'the gesture belongs to the list, which was not at its top',
      );
      expect(
        list.offset,
        lessThan(400),
        reason: 'the list should have scrolled back toward its top',
      );
    });

    testWidgets('further up the list, an upward drag scrolls the list', (
      tester,
    ) async {
      late ScrollController list;
      await pumpSheet(tester, snapping(onController: (c) => list = c));

      list.jumpTo(100);
      await tester.pump();
      final before = surfaceHeight(tester);

      await tester.drag(find.text('Row 3'), const Offset(0, -60));
      await tester.pump();

      expect(list.offset, greaterThan(100));
      expect(surfaceHeight(tester), before);
    });

    testWidgets(
      'an upward drag at the top of the body expands the sheet to the next '
      'detent',
      (tester) async {
        // This claim changed with the mechanism, and the change is the point.
        // The old handler acted on downward drags only, so an upward drag at
        // the top of a half-open sheet did nothing at all — a dead gesture the
        // old test froze in place as if it were the design. A snapping sheet
        // that will not open by being pulled open is a sheet with one working
        // direction.
        late ScrollController list;
        await pumpSheet(tester, snapping(onController: (c) => list = c));

        final before = surfaceHeight(tester);
        await tester.drag(find.text('Row 1'), const Offset(0, -180));
        await tester.pumpAndSettle();

        expect(
          surfaceHeight(tester),
          greaterThan(before),
          reason: 'pulling up at the top of the body opens the sheet further',
        );
        expect(
          list.offset,
          0,
          reason: 'the sheet took the gesture, so the list never scrolled',
        );
      },
    );

    testWidgets(
      'the drag works under ClampingScrollPhysics as well as bouncing',
      (tester) async {
        // flutter-036: the drag had to be platform-agnostic. An older handler
        // depended on `OverscrollNotification`, which `BouncingScrollPhysics`
        // dispatches and `ClampingScrollPhysics` (Android default, every
        // `ListView` the kit ships) does not. `DraggableScrollableSheet` reads
        // the scroll position rather than an overscroll signal, so neither
        // physics can hide the gesture from it.
        late ScrollController list;
        await pumpSheet(
          tester,
          snapping(
            onController: (c) => list = c,
            physics: const ClampingScrollPhysics(),
          ),
        );

        final before = surfaceHeight(tester);
        await tester.drag(find.text('Row 1'), const Offset(0, 220));
        await tester.pump();

        expect(
          list.offset,
          0,
          reason: 'ClampingScrollPhysics clamped the list at the top',
        );
        expect(
          surfaceHeight(tester),
          lessThan(before),
          reason:
              'the sheet should have followed the finger down regardless of '
              'the platform scroll physics',
        );
      },
    );
  });

  testWidgets('the catalog\'s snapping story, climbed detent by detent', (
    tester,
  ) async {
    // The unit tests above reach a scrolled list with `jumpTo`, which skips
    // the part a user cannot skip: a sheet opens at a detent, and the list
    // under it does not scroll at all until the sheet has been pulled to its
    // maximum. Presented through `showDSBottomSheet` — a route, not an inline
    // widget — and configured exactly as `overlay_stories.dart` ships it, so
    // the thing under test is the thing that shipped.
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => DSButton(
                label: 'Open a snapping sheet',
                onPressed: () => showDSBottomSheet<void>(
                  context: context,
                  snapPoints: const [0.3, 0.6, 0.9],
                  snapLabels: const ['Peek', 'Half', 'Near full'],
                  initialSnap: 0.6,
                  builder: (context) => ListView.builder(
                    itemCount: 20,
                    itemBuilder: (context, index) =>
                        DSListTile(title: 'Result ${index + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open a snapping sheet'));
    await tester.pumpAndSettle();

    double sheet() => tester.getSize(find.byType(DSOverlaySurface)).height;
    double list() => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(DSBottomSheet),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;

    Future<void> dragBy(double dy) async {
      await tester.drag(find.text('Result 1').hitTestable(), Offset(0, dy));
      await tester.pumpAndSettle();
    }

    expect(sheet(), closeTo(844 * 0.6, 2), reason: 'opened at initialSnap');

    // Each drag at the top of the body takes one detent, and the list — which
    // has 20 rows and plenty to scroll — stays exactly where it is.
    await dragBy(150);
    expect(sheet(), closeTo(844 * 0.3, 2));
    expect(list(), 0);
    await dragBy(-300);
    expect(sheet(), closeTo(844 * 0.6, 2));
    expect(list(), 0);
    await dragBy(-300);
    expect(sheet(), closeTo(844 * 0.9, 2), reason: 'the sheet is now at max');
    expect(list(), 0);

    // Only now does the gesture belong to the list.
    final atMax = sheet();
    await dragBy(-300);
    expect(sheet(), atMax, reason: 'at max the sheet stops taking the drag');
    expect(list(), greaterThan(0), reason: 'the list scrolled instead');

    // And the direction that used to dismiss the sheet from any offset now
    // scrolls the list back, leaving the sheet where the user parked it.
    final scrolled = list();
    await tester.drag(find.text('Result 8'), const Offset(0, 200));
    await tester.pump();
    expect(sheet(), atMax, reason: 'mid-list, a downward drag is the list\'s');
    expect(list(), lessThan(scrolled));
    expect(find.byType(DSBottomSheet), findsOneWidget);
  });

  testWidgets('the header divider appears only once the body scrolls', (
    tester,
  ) async {
    // Never animated with the scroll offset itself: a divider driven by the
    // offset flickers on every small movement.
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpSheet(
      tester,
      SizedBox(
        height: 300,
        child: DSBottomSheet(
          header: const DSSheetHeader(title: 'Choose a folder'),
          // The body is its own scroll view.
          scrollable: false,
          child: ListView.builder(
            controller: controller,
            itemCount: 30,
            itemBuilder: (context, index) =>
                SizedBox(height: 56, child: Text('Row $index')),
          ),
        ),
      ),
    );

    bool dividerDrawn() => tester
        .widget<DSOverlayHeader>(find.byType(DSOverlayHeader))
        .showDivider;

    expect(dividerDrawn(), isFalse);

    controller.jumpTo(80);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(dividerDrawn(), isTrue);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(dividerDrawn(), isFalse);
  });

  testWidgets('at text scale 2.0 a content sheet stops at 90% and scrolls', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      DSBottomSheet(
        header: const DSSheetHeader(title: 'Choose a folder'),
        footer: DSSheetFooter(
          actions: DSButton(label: 'Choose', onPressed: () {}),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final row in const ['Documents', 'Downloads', 'Pictures'])
              SizedBox(height: 56, child: Text(row)),
          ],
        ),
      ),
      textScale: 2,
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'a sheet at a doubled text scale must grow, not clip',
    );
    expect(
      tester.getSize(find.byType(DSBottomSheet)).height,
      lessThanOrEqualTo(844 * 0.9 + 0.5),
    );
  });

  testWidgets('the last row is reachable above a home indicator', (
    tester,
  ) async {
    // The footer is pinned above the safe area, so content cannot hide under
    // it. 34 points is the iPhone home indicator.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34 * 3);
    tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DSBottomSheet(
                footer: DSSheetFooter(
                  actions: DSButton(label: 'Choose', onPressed: () {}),
                ),
                child: const SizedBox(
                  height: 120,
                  child: Column(children: [Spacer(), Text('the last row')]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final last = tester.getRect(find.text('the last row'));
    final footer = tester.getRect(find.byType(DSSheetFooter));
    expect(last.bottom, lessThanOrEqualTo(footer.top + 0.5));
    expect(footer.bottom, lessThanOrEqualTo(844 - 34 + 0.5));
  });

  group('the states a sheet can be in', () {
    testWidgets('loading draws a header bar and a footer bar when it has '
        'those slots, and neither when it does not', (tester) async {
      await pumpSheet(
        tester,
        DSBottomSheet(
          loading: true,
          header: const DSSheetHeader(title: 'Choose a folder'),
          footer: DSSheetFooter(
            actions: DSButton(label: 'Choose', onPressed: () {}),
          ),
          child: const SizedBox.shrink(),
        ),
      );
      expect(find.byType(DSSheetSkeleton), findsOneWidget);
      var skeleton = tester.widget<DSSheetSkeleton>(
        find.byType(DSSheetSkeleton),
      );
      expect(skeleton.showHeader, isTrue);
      expect(skeleton.showFooter, isTrue);

      await pumpSheet(
        tester,
        const DSBottomSheet(loading: true, child: SizedBox.shrink()),
      );
      skeleton = tester.widget<DSSheetSkeleton>(find.byType(DSSheetSkeleton));
      expect(skeleton.showHeader, isFalse);
      expect(skeleton.showFooter, isFalse);
    });

    testWidgets('an empty body is never a bare header over blank surface', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        const DSBottomSheet(
          empty: true,
          header: DSSheetHeader(title: 'Choose a folder'),
          child: SizedBox.shrink(),
        ),
      );
      expect(find.byType(DSEmptyState), findsOneWidget);
    });
  });

  testWidgets('settling on a snap point announces its label', (tester) async {
    // The use `SnapPoint.label` was clearly written for and never wired to.
    final announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') {
          announcements.add(
            (map['data'] as Map<dynamic, dynamic>)['message'] as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );

    // The body is a list rather than a `SizedBox.expand`: a snapping sheet
    // moves through its scroll position, so a body with nothing to scroll is
    // a sheet with nothing to drag. The drag is on the handle, which has no
    // scroll view under it and is therefore the sheet's own chrome gesture.
    await pumpSheet(
      tester,
      DSBottomSheet(
        snapPoints: const <double>[0.3, 0.6, 0.9],
        snapLabels: const <String>['Peek', 'Half', 'Near full'],
        initialSnap: 0.6,
        child: ListView.builder(
          itemCount: 30,
          itemBuilder: (context, index) =>
              SizedBox(height: 56, child: Text('Row $index')),
        ),
      ),
    );

    await tester.drag(find.byType(DSDragHandle), const Offset(0, -200));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(announcements, isNotEmpty);
    expect(announcements.last, anyOf('Half', 'Near full'));
  });

  testWidgets('a fit that is not `content` is the height it says it is', (
    tester,
  ) async {
    for (final (DSSheetFit fit, double fraction) in <(DSSheetFit, double)>[
      (DSSheetFit.half, 0.5),
      (DSSheetFit.full, 0.9),
      (DSSheetFit.expanded, 1.0),
    ]) {
      await pumpSheet(
        tester,
        DSBottomSheet(fit: fit, child: const SizedBox.expand()),
      );
      expect(
        tester.getSize(find.byType(DSBottomSheet)).height,
        closeTo(844 * fraction, 1),
        reason: '$fit',
      );
    }
  });

  testWidgets('initialSnap has to be one of the snapPoints', (tester) async {
    // A sheet that opens between two detents settles the first time it is
    // touched, which reads as the sheet correcting the developer in front of
    // the user. The assert is on the presentation rather than the widget,
    // because a `const` constructor cannot narrow a nullable list.
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDSBottomSheet<void>(
                  context: context,
                  snapPoints: const [0.3, 0.6],
                  initialSnap: 0.45,
                  builder: (context) => const SizedBox(height: 100),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(tester.takeException(), isAssertionError);
  });

  // flutter-036: a loading state no longer fills the body with an empty
  // `SingleChildScrollView`. The skeleton is its own intrinsic height; the
  // sheet's column lays it out without a phantom scroll region below it.
  testWidgets(
    'loading: the body is the skeleton\'s height, not the body slot',
    (tester) async {
      await pumpSheet(
        tester,
        const DSBottomSheet(loading: true, child: SizedBox.shrink()),
      );

      // The sheet's height is content-sized: drag handle + the skeleton's
      // own intrinsic height, NOT the body's slot allocation. Without the
      // flutter-036 fix, a `SingleChildScrollView` would fill the slot and
      // force the column to allocate the full cap.
      final sheetHeight = tester.getSize(find.byType(DSBottomSheet)).height;
      final skeletonHeight = tester
          .getSize(find.byType(DSSheetSkeleton))
          .height;
      // The skeleton lives inside the sheet; the sheet is taller by the
      // drag handle.
      expect(sheetHeight, lessThan(skeletonHeight + 100));
      expect(sheetHeight, greaterThan(skeletonHeight));
    },
  );

  testWidgets('empty: a small emptySlot does not push the sheet to the cap', (
    tester,
  ) async {
    // The default DSEmptyState carries an illustration + action + helper
    // and is large by design. To test the "no phantom scroll region" claim
    // we feed the slot a known-small widget and assert the sheet sizes to
    // it rather than filling the body's slot.
    const small = SizedBox(height: 80, child: Text('Nothing here yet.'));
    await pumpSheet(
      tester,
      const DSBottomSheet(
        empty: true,
        emptySlot: small,
        child: SizedBox.shrink(),
      ),
    );

    final sheetHeight = tester.getSize(find.byType(DSBottomSheet)).height;
    // Without the flutter-036 fix, the body is a `SingleChildScrollView`
    // that fills the slot, dragging the sheet height toward 90% of screen.
    // With the fix, the slot wraps no scroll view and the sheet is small.
    expect(
      sheetHeight,
      lessThan(844 * 0.4),
      reason: 'a sheet with an 80-px body must not balloon to the cap',
    );
  });

  /// The settle after a chrome drag is a spring, and the gesture's velocity is
  /// its initial condition.
  ///
  /// The `animateTo(duration: fast, curve: enter)` this replaced read the
  /// velocity only to choose *which* detent and then started from rest, so a
  /// hard fling and a slow nudge to the same place looked identical the moment
  /// the finger lifted.
  group('the settle carries the velocity the finger left at', () {
    /// [key] is not decoration: the two runs below pump into the same tester,
    /// and without it the second `pumpWidget` matches the first sheet's
    /// element, keeps its `State` — and with it the extent the first fling
    /// left the sheet at — and quietly ignores `initialSnap`.
    Widget twoDetents(Object key) => DSBottomSheet(
      key: ValueKey<Object>(key),
      snapPoints: const <double>[0.3, 0.9],
      initialSnap: 0.3,
      child: const _Rows(),
    );

    /// Flings the handle 200px up at [velocity] and reports where the sheet is
    /// 60ms later — while the settle is still running.
    ///
    /// The distance is the same in both cases, so the spring starts from the
    /// same extent and aims at the same detent. Velocity is the only variable.
    Future<double> midSettle(WidgetTester tester, double velocity) async {
      await pumpSheet(tester, twoDetents(velocity));
      await tester.fling(
        find.byType(DSDragHandle),
        const Offset(0, -200),
        velocity,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final at = surfaceHeight(tester);
      await tester.pumpAndSettle();
      expect(
        surfaceHeight(tester),
        closeTo(844 * 0.9, 2),
        reason: 'both speeds come to rest on the same detent',
      );
      return at;
    }

    testWidgets('a fling is further along than a nudge after the same time', (
      tester,
    ) async {
      final flung = await midSettle(tester, 2500);
      final nudged = await midSettle(tester, 600);
      expect(
        flung,
        greaterThan(nudged + 10),
        reason:
            'the faster gesture hands more speed to the spring, so 60ms in '
            'the sheet is further up the screen. Equal heights here is the '
            'old behaviour: velocity read for the target and then discarded',
      );
    });

    testWidgets('under reduced motion the sheet arrives without a settle', (
      tester,
    ) async {
      await pumpSheet(tester, twoDetents('reduced'), reducedMotion: true);
      await tester.fling(
        find.byType(DSDragHandle),
        const Offset(0, -200),
        2500,
      );
      await tester.pump();
      expect(
        surfaceHeight(tester),
        closeTo(844 * 0.9, 2),
        reason:
            'the user asked for less movement, not for a slower spring: the '
            'sheet is at the detent on the first frame after the lift',
      );
    });
  });
}

/// A body with something to scroll, so the sheet has a scroll position to move
/// through. The drags above are on the handle, which is chrome and never the
/// list's.
class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: 30,
    itemBuilder: (context, index) =>
        SizedBox(height: 56, child: Text('Row $index')),
  );
}
