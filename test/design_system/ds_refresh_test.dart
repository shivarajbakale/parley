import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two claims `DSRefresh` exists to make good on:
///
///   * the pull fires on a list short enough to fit, which a bare
///     `RefreshIndicator` does not;
///   * the gesture is felt, not only seen.
///
/// Everything else here is the style chain, which is the contract every
/// component in the kit signs.
void main() {
  late BuildContext ctx;
  late List<MethodCall> haptics;

  setUp(() {
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

  /// A list of two rows inside a box that fits them — the case where the raw
  /// indicator is dead, so it is the only case worth pumping.
  Future<void> pumpShortList(
    WidgetTester tester, {
    required Future<void> Function() onRefresh,
    bool enabled = true,
    bool reducedMotion = false,
    DSRefreshStyle? style,
    Widget? child,
    Key? refreshKey,
    TargetPlatform? platform,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: platform == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(platform: platform),
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: inner!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return SizedBox(
                  height: 300,
                  child: DSRefresh(
                    key: refreshKey,
                    onRefresh: onRefresh,
                    enabled: enabled,
                    style: style,
                    child:
                        child ??
                        ListView(
                          children: const [
                            SizedBox(height: 40, child: Text('one')),
                            SizedBox(height: 40, child: Text('two')),
                          ],
                        ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Where the pull has put the disc, relative to the top of the component.
  ///
  /// Read off the disc's own box rather than the indicator inside it: the
  /// indicator is scaled up as the pull grows, and a scale about the centre
  /// moves the painted top even when the layout has not.
  double discTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(DSRefresh.discKey)).dy -
      tester.getTopLeft(find.byType(DSRefresh)).dy;

  /// A drag the test controls the speed of. [fast] is the flick; the slow one
  /// covers the same distance over seven times as long, so the two differ in
  /// exit velocity and in nothing else.
  Future<TestGesture> pull(
    WidgetTester tester,
    double distance, {
    bool fast = false,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('one')),
    );
    final gap = Duration(milliseconds: fast ? 8 : 60);
    var at = Duration.zero;
    for (var i = 0; i < 10; i++) {
      at += gap;
      await gesture.moveBy(Offset(0, distance / 10), timeStamp: at);
      await tester.pump(gap);
    }
    return gesture;
  }

  Future<void> pullDown(WidgetTester tester) async {
    await tester.fling(find.text('one'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('the gesture on a list that fits', () {
    testWidgets('a pull refreshes even though nothing overscrolls', (
      tester,
    ) async {
      var refreshes = 0;
      await pumpShortList(
        tester,
        onRefresh: () async {
          refreshes++;
        },
      );

      await pullDown(tester);
      await tester.pumpAndSettle();

      expect(refreshes, 1);
    });

    testWidgets('the physics reach the child through ScrollConfiguration', (
      tester,
    ) async {
      await pumpShortList(tester, onRefresh: () async {});

      // The child passes no `physics`, so what reaches its Scrollable is
      // whatever the inherited behaviour resolved to — which is the whole
      // point: the call site does not have to know.
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('a drag past the top comes back', (tester) async {
      // The defect this catches shipped: the physics were replaced with a bare
      // `AlwaysScrollableScrollPhysics()`, which has no parent — and
      // `ScrollPhysics` on its own clamps nothing and simulates nothing. A
      // list dragged past its own end stayed exactly where the finger left it,
      // with the content pushed down the screen and no way back. On a page
      // inside a `PageView` that reads as an app that has frozen.
      await pumpShortList(tester, onRefresh: () async {});

      final ScrollableState state = tester.state(find.byType(Scrollable));
      expect(state.position.pixels, 0);

      await tester.dragFrom(const Offset(100, 100), const Offset(0, 250));
      await tester.pumpAndSettle();

      expect(
        state.position.pixels,
        0,
        reason: 'the list stayed where the drag left it',
      );
    });

    testWidgets('the always-scrollable physics keep a parent', (tester) async {
      // The structural half of the test above: a wrapper with a null parent is
      // the shape of the bug, and it is invisible to an `isA` check.
      await pumpShortList(tester, onRefresh: () async {});

      final ScrollableState st = tester.state(find.byType(Scrollable));
      ScrollPhysics? link = st.position.physics;
      var reachesThePlatform = false;
      while (link != null) {
        if (link is! AlwaysScrollableScrollPhysics) reachesThePlatform = true;
        link = link.parent;
      }
      expect(
        reachesThePlatform,
        isTrue,
        reason:
            'the chain is always-scrollable all the way down, so nothing '
            'in it clamps an overscroll or simulates a fling',
      );
    });

    testWidgets('a child with its own physics still wins', (tester) async {
      await pumpShortList(
        tester,
        onRefresh: () async {},
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [SizedBox(height: 40, child: Text('one'))],
        ),
      );

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('the pull ticks once, when it commits', (tester) async {
      await pumpShortList(tester, onRefresh: () async {});

      expect(haptics, isEmpty);
      await pullDown(tester);
      await tester.pumpAndSettle();

      expect(haptics, hasLength(1));
    });
  });

  group('disabled', () {
    testWidgets('enabled: false leaves no indicator and no physics', (
      tester,
    ) async {
      var refreshes = 0;
      await pumpShortList(
        tester,
        enabled: false,
        onRefresh: () async {
          refreshes++;
        },
      );

      expect(find.byKey(DSRefresh.discKey), findsNothing);

      final inherited = ScrollConfiguration.of(
        tester.element(find.byType(ListView)),
      ).getScrollPhysics(tester.element(find.byType(ListView)));
      expect(inherited, isNot(isA<AlwaysScrollableScrollPhysics>()));

      await pullDown(tester);
      await tester.pumpAndSettle();
      expect(refreshes, 0);
      expect(haptics, isEmpty);
    });
  });

  group('the style chain', () {
    testWidgets('the arc and the disc come from the palette', (tester) async {
      await pumpShortList(tester, onRefresh: () async {});

      final disc = tester.widget<RefreshProgressIndicator>(
        find.byType(RefreshProgressIndicator),
      );
      expect(disc.color, ctx.palette.primary);
      expect(disc.backgroundColor, ctx.palette.card);
    });

    testWidgets('an instance style overrides the spec default', (tester) async {
      await pumpShortList(
        tester,
        onRefresh: () async {},
        style: const DSRefreshStyle(color: Color(0xFF00FF00), edgeOffset: 56),
      );

      final disc = tester.widget<RefreshProgressIndicator>(
        find.byType(RefreshProgressIndicator),
      );
      expect(disc.color, const Color(0xFF00FF00));
      // `edgeOffset` is geometry, not a field to hand on, so the assertion is
      // where the disc actually parks: a screen with a pinned bar 56 high
      // wants the pull to start below it.
      expect(discTop(tester), 56 - DSRefresh.parkedAbove);
      // Untouched fields still come from the spec.
      expect(disc.backgroundColor, ctx.palette.card);
    });

    test('merge takes the other side field by field', () {
      const base = DSRefreshStyle(color: Color(0xFF111111), displacement: 10);
      const patch = DSRefreshStyle(displacement: 20, strokeWidth: 4);

      final merged = base.merge(patch);
      expect(merged.color, const Color(0xFF111111));
      expect(merged.displacement, 20);
      expect(merged.strokeWidth, 4);
      expect(base.merge(null), same(base));
    });

    test('lerp walks every field', () {
      const a = DSRefreshStyle(
        color: Color(0xFF000000),
        displacement: 10,
        strokeWidth: 2,
      );
      const b = DSRefreshStyle(
        color: Color(0xFFFFFFFF),
        displacement: 30,
        strokeWidth: 6,
      );

      final half = a.lerp(b, 0.5);
      expect(half.displacement, 20);
      expect(half.strokeWidth, 4);
      expect(half.color, Color.lerp(a.color, b.color, 0.5));
      expect(a.lerp(null, 0.5), same(a));
    });

    test('copyWith replaces only what it is given', () {
      const base = DSRefreshStyle(color: Color(0xFF111111), edgeOffset: 8);
      final copy = base.copyWith(edgeOffset: 16);
      expect(copy.color, const Color(0xFF111111));
      expect(copy.edgeOffset, 16);
    });
  });

  /// The claim flutter-083 exists to make good on: the pull is this
  /// component's own, so releasing it hands the spring the speed of the
  /// finger instead of starting a fixed timer.
  group('the pull the component owns', () {
    testWidgets('the disc is parked out of sight until a finger pulls', (
      tester,
    ) async {
      await pumpShortList(tester, onRefresh: () async {});

      expect(discTop(tester), -DSRefresh.parkedAbove);
      expect(tester.widget<Opacity>(find.byKey(DSRefresh.discKey)).opacity, 0);
    });

    testWidgets('the disc follows the finger down', (tester) async {
      await pumpShortList(tester, onRefresh: () async {});

      final gesture = await pull(tester, 60);
      final part = discTop(tester);
      expect(
        part,
        greaterThan(-DSRefresh.parkedAbove),
        reason: 'the disc left its parking spot',
      );
      expect(
        part,
        lessThan(ctx.design.space.xxl),
        reason: 'a pull short of the trigger has not reached the commit point',
      );

      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(discTop(tester), greaterThan(part));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a release short of the trigger springs back and refreshes '
        'nothing', (tester) async {
      var refreshes = 0;
      await pumpShortList(
        tester,
        onRefresh: () async {
          refreshes++;
        },
      );

      final gesture = await pull(tester, 60);
      expect(discTop(tester), greaterThan(-DSRefresh.parkedAbove));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshes, 0);
      expect(haptics, isEmpty);
      expect(discTop(tester), closeTo(-DSRefresh.parkedAbove, 0.5));
    });

    testWidgets('the velocity the finger left at reaches the spring', (
      tester,
    ) async {
      // Two identical pulls — same distance, same start, same end value —
      // that differ only in how long the finger took. Under a fixed-duration
      // settle these two are the same animation, which is the flatness being
      // removed here.
      Future<double> deepest({required bool fast}) async {
        final holding = Completer<void>();
        await pumpShortList(
          tester,
          // Keyed, or the second pumpWidget matches the first component's
          // element and keeps the State the first pull left behind.
          refreshKey: ValueKey<bool>(fast),
          onRefresh: () => holding.future,
        );

        final gesture = await pull(tester, 160, fast: fast);
        await gesture.up();
        var lowest = discTop(tester);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          lowest = math.max(lowest, discTop(tester));
        }
        holding.complete();
        await tester.pump();
        return lowest;
      }

      final crawl = await deepest(fast: false);
      final flick = await deepest(fast: true);

      final commit = ctx.design.space.xxl;
      expect(
        crawl,
        greaterThanOrEqualTo(commit),
        reason: 'the pull was past the commit point when the finger lifted',
      );
      expect(
        flick,
        greaterThan(crawl + 4),
        reason:
            'the flick carried speed into the spring and rode further past '
            'the commit point before it came back',
      );
    });

    testWidgets('a bouncing list does not park the disc while it bounces', (
      tester,
    ) async {
      // The regression this component was rewritten around a second time. On
      // bouncing physics the release hands straight to a ballistic activity,
      // so `ScrollEndNotification` — which the first cut waited for — does not
      // arrive until the list has finished springing back, several hundred
      // milliseconds later and with the drag details gone. The disc sat at
      // full pull for that whole time and then settled from a standstill.
      await pumpShortList(
        tester,
        platform: TargetPlatform.iOS,
        onRefresh: () async {},
      );

      final gesture = await pull(tester, 60);
      final held = discTop(tester);
      expect(held, greaterThan(-DSRefresh.parkedAbove));

      // Four frames, which is about 64ms. The first ballistic tick is where
      // the finger is seen to be gone, and the spring it starts advances from
      // the frame after that. The list's own bounce is still running well past
      // here, so a settle that waited for the end notification has not moved
      // the disc at all yet.
      await gesture.up();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        discTop(tester),
        lessThan(held - 1),
        reason:
            'the disc started back within a frame of the finger leaving, '
            'rather than waiting for the list to finish bouncing',
      );
      await tester.pumpAndSettle();
      expect(discTop(tester), closeTo(-DSRefresh.parkedAbove, 0.5));
    });

    testWidgets('a bouncing release still hands its speed to the spring', (
      tester,
    ) async {
      // The velocity now comes off the pull's own pointer timestamps, so it
      // has to survive the physics family where the end notification carries
      // none at all.
      Future<double> deepest({required bool fast}) async {
        final holding = Completer<void>();
        await pumpShortList(
          tester,
          refreshKey: ValueKey<bool>(fast),
          platform: TargetPlatform.iOS,
          onRefresh: () => holding.future,
        );

        final gesture = await pull(tester, 400, fast: fast);
        await gesture.up();
        var lowest = discTop(tester);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          lowest = math.max(lowest, discTop(tester));
        }
        holding.complete();
        await tester.pump();
        return lowest;
      }

      final crawl = await deepest(fast: false);
      final flick = await deepest(fast: true);

      expect(
        flick,
        greaterThan(crawl + 4),
        reason: 'the flick rode further past the commit point',
      );
    });

    testWidgets('reduced motion lands on the commit point without '
        'travelling', (tester) async {
      final holding = Completer<void>();
      await pumpShortList(
        tester,
        reducedMotion: true,
        onRefresh: () => holding.future,
      );

      final gesture = await pull(tester, 160);
      await gesture.up();
      await tester.pump();

      expect(discTop(tester), ctx.design.space.xxl);
      expect(haptics, hasLength(1), reason: 'a tick is not motion');
      holding.complete();
      await tester.pump();
    });

    testWidgets('triggerDistance decides how far is far enough', (
      tester,
    ) async {
      var refreshes = 0;
      Future<void> counted() async => refreshes++;

      await pumpShortList(
        tester,
        refreshKey: const ValueKey<String>('strict'),
        style: const DSRefreshStyle(triggerDistance: 400),
        onRefresh: counted,
      );
      var gesture = await pull(tester, 160);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshes, 0);

      await pumpShortList(
        tester,
        refreshKey: const ValueKey<String>('default'),
        onRefresh: counted,
      );
      gesture = await pull(tester, 160);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        refreshes,
        1,
        reason: 'the same pull commits against the spec default',
      );
    });
  });
}
