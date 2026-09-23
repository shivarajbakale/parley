import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSBottomNavBar — plan 15.
///
/// A surgical redesign: the chrome reasoning was already right, so what these
/// hold open is what was wrong. `badgeCount` + `showBadge` were two fields for
/// one concept, with a state that compiled and meant nothing. Nothing stopped
/// a six-destination bar. The chrome tint was a different colour on each
/// platform because the two branches read two different scheme roles. And the
/// destination model was closed, so a destination with an avatar could not be
/// expressed at all.
void main() {
  final spec = AppTheme.spec;

  const home = DSBottomNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  );
  const library = DSBottomNavItem(
    label: 'Library',
    icon: Icons.book_outlined,
    selectedIcon: Icons.book,
  );
  const settings = DSBottomNavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );
  const three = [home, library, settings];

  /// What one side of a floating bar costs the destinations: the margin
  /// between the pill and the screen edge, plus the padding that holds the
  /// outer indicator inside the pill.
  final floatingInset = spec.space.lg + spec.space.md;

  Widget host(
    Widget bar, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) => Design(
    spec: spec,
    child: MaterialApp(
      theme:
          (brightness == Brightness.light
                  ? AppTheme.lightTheme
                  : AppTheme.darkTheme)
              .copyWith(platform: platform),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(bottomNavigationBar: bar),
      ),
    ),
  );

  Finder destination(int index) => find.byType(NavigationDestination).at(index);

  group('the framework underneath, not a hand-rolled row', () {
    testWidgets('it is a NavigationBar on an AppChromeSurface', (tester) async {
      await tester.pumpWidget(
        host(DSBottomNavBar(currentIndex: 1, onTap: (_) {}, items: three)),
      );

      // The equal columns, the indicator, the text scaling and the mutually
      // exclusive semantics are all Flutter's. A hand-rolled bar loses every
      // one of them silently.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppChromeSurface), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });

    testWidgets('the floating bar is inset from both edges', (tester) async {
      await tester.pumpWidget(
        host(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three)),
      );
      final viewport =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // Two insets, and they are different things: the margin is the gap
      // between the pill and the screen, and the inner padding is what keeps
      // the outer indicators inside the pill's round ends.
      expect(
        tester.getSize(find.byType(NavigationBar)).width,
        moreOrLessEquals(viewport - floatingInset * 2, epsilon: 1),
      );
    });

    testWidgets('switched off, it spans the viewport again', (tester) async {
      // The tablet answer, and the Material 2 one. A bar that is not floating
      // is welded to the edge, so it takes the whole width back.
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            style: const DSBottomNavBarStyle(floating: false),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(NavigationBar)).width,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
    });
  });

  group('the target is the whole column', () {
    testWidgets('every destination clears the tap-target floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three)),
      );

      // Asserted on what rendered, not on the constant that set it: a height
      // that is right in the style and wrong on screen is the failure this
      // catches.
      final viewport =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (var i = 0; i < three.length; i++) {
        final size = tester.getSize(destination(i));
        expect(
          size.height,
          greaterThanOrEqualTo(spec.component.minTapTarget),
          reason: 'destination $i is under the 48dp floor',
        );
        expect(
          size.width,
          moreOrLessEquals((viewport - floatingInset * 2) / 3, epsilon: 1),
        );
      }
    });

    testWidgets('a tap at the column edge still selects it', (tester) async {
      var tapped = -1;
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: three,
          ),
        ),
      );

      // A 24dp glyph in a 120dp column with a 24dp target is the failure that
      // makes a bar feel unresponsive at the edges.
      final column = tester.getRect(destination(1));
      await tester.tapAt(Offset(column.left + 2, column.center.dy));
      expect(tapped, 1);

      tapped = -1;
      await tester.tapAt(Offset(column.right - 2, column.center.dy));
      expect(tapped, 1);
    });

    testWidgets(
      'every column on iOS reports its own index, including the last',
      (tester) async {
        // Regression for "tab n+1, n gets clicked": each tap must report the
        // index of the column the finger landed in. The Cupertino branch's
        // destination is a private class, so the assertion runs against the
        // descendant GestureDetectors and DSPressables — one of each per
        // destination — and against `items.length` so the loop covers the
        // last column specifically (a regression that hit only the last
        // column would still pass with two destinations).
        const four = [
          DSBottomNavItem(
            label: 'Home',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          DSBottomNavItem(
            label: 'Library',
            icon: Icons.collections_bookmark_outlined,
            selectedIcon: Icons.collections_bookmark,
          ),
          DSBottomNavItem(
            label: 'Components',
            icon: Icons.widgets_outlined,
            selectedIcon: Icons.widgets,
          ),
          DSBottomNavItem(
            label: 'Settings',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
          ),
        ];

        for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
          var tapped = -1;
          await tester.pumpWidget(
            host(
              DSBottomNavBar(
                currentIndex: 0,
                onTap: (i) => tapped = i,
                items: four,
              ),
              platform: platform,
            ),
          );
          await tester.pumpAndSettle();
          // Material: NavigationDestination is the destination widget.
          // Cupertino: the destination is a private class; the GestureDetector
          // inside it is the public surface, and there is exactly one per
          // destination.
          if (platform == TargetPlatform.android) {
            for (var i = 0; i < four.length; i++) {
              tapped = -1;
              await tester.tapAt(
                tester.getCenter(find.byType(NavigationDestination).at(i)),
              );
              expect(
                tapped,
                i,
                reason: 'android column=$i tapped at its center',
              );
            }
          } else {
            final detectors = find.descendant(
              of: find.byType(DSBottomNavBar),
              matching: find.byType(GestureDetector),
            );
            final n = detectors.evaluate().length;
            expect(
              n,
              four.length,
              reason: 'all four destinations rendered on $platform',
            );
            for (var i = 0; i < n; i++) {
              tapped = -1;
              await tester.tapAt(tester.getCenter(detectors.at(i)));
              expect(tapped, i, reason: 'iOS column=$i tapped at its center');
            }
          }
        }
      },
    );

    testWidgets('the last column on iOS registers taps at the right edge too', (
      tester,
    ) async {
      // Regression for "the last item in the tab bar is still not registering":
      // the last column's right edge is the spot nearest the screen edge
      // and the most likely place a finger lands when the bar floats with a
      // margin, so it has to be a hit-target and not a gap. The Cupertino
      // branch's destination is private; the descendant GestureDetector is
      // the public surface.
      const four = [
        DSBottomNavItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        DSBottomNavItem(
          label: 'Library',
          icon: Icons.book_outlined,
          selectedIcon: Icons.book,
        ),
        DSBottomNavItem(
          label: 'Components',
          icon: Icons.widgets_outlined,
          selectedIcon: Icons.widgets,
        ),
        DSBottomNavItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
        ),
      ];
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        var tapped = -1;
        await tester.pumpWidget(
          host(
            DSBottomNavBar(
              currentIndex: 0,
              onTap: (i) => tapped = i,
              items: four,
            ),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        final detectors = find.descendant(
          of: find.byType(DSBottomNavBar),
          matching: find.byType(GestureDetector),
        );
        final n = detectors.evaluate().length;
        expect(n, four.length, reason: 'all four destinations rendered');
        // Tap at the right edge of the last column — the worst case.
        final lastRect = tester.getRect(detectors.at(n - 1));
        tapped = -1;
        await tester.tapAt(Offset(lastRect.right - 2, lastRect.center.dy));
        expect(
          tapped,
          n - 1,
          reason:
              'platform=$platform, last column right edge reports index ${n - 1}',
        );
      }
    });

    testWidgets('the Apple branch clears the tap-target floor too', (
      tester,
    ) async {
      // The Material branch's destination widget is findable; the Cupertino
      // branch's isn't, because its destination is a private class inside
      // the design-system library. The Column that fills the destination is
      // the same thing measured against the floor on Material, so the same
      // assertion runs here against the descendant Columns.
      await tester.pumpWidget(
        host(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      final appleDestinations = find.descendant(
        of: find.byType(DSBottomNavBar),
        matching: find.byType(Column),
      );
      expect(appleDestinations, findsNWidgets(3));
      for (var i = 0; i < three.length; i++) {
        final size = tester.getSize(appleDestinations.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(spec.component.minTapTarget),
          reason: 'destination $i is under the 48dp floor',
        );
      }
    });
  });

  group('a short bar does not overflow', () {
    // Cupertino's column is `MainAxisSize.max` so the column *is* the bar's
    // height. A bar shorter than glyph + gap + label used to overflow by
    // 2dp at the bottom because the children don't shrink. The build path
    // now clamps the height to the natural content plus the tap-target
    // minimum, and the matrix below proves no exception slips through at
    // any height down to the floor.
    for (final height in [40.0, 44.0, 48.0, 52.0, 56.0, 60.0, 64.0]) {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        testWidgets('height=$height on '
            '${platform == TargetPlatform.iOS ? 'iOS' : 'Android'} '
            'does not throw', (tester) async {
          final errors = <Object>[];
          final original = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.exception);
          addTearDown(() => FlutterError.onError = original);

          await tester.pumpWidget(
            host(
              DSBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: three,
                style: DSBottomNavBarStyle(height: height),
              ),
              platform: platform,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            errors.where((e) => e.toString().contains('overflowed')),
            isEmpty,
            reason: 'height=$height overflowed on $platform',
          );
        });
      }
    }

    testWidgets('a height below the natural content grows to fit on Apple', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            style: const DSBottomNavBarStyle(height: 44),
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      // Natural content at scale 1 is glyphSize 24 + glyphLabelGap 4 +
      // labelSmall 18 = 46. The Cupertino branch must clamp up to that,
      // not stay at 44 where the column would overflow by 2dp.
      final bar = find.byType(DSBottomNavBar);
      expect(tester.getSize(bar).height, greaterThanOrEqualTo(46));
      // The destination is the Column, and it must clear the tap-target
      // floor too — the clamp's second half.
      final dest = find
          .descendant(of: bar, matching: find.byType(Column))
          .first;
      expect(
        tester.getSize(dest).height,
        greaterThanOrEqualTo(spec.component.minTapTarget),
      );
    });

    testWidgets('the text scaler scales the floor, not just the bar', (
      tester,
    ) async {
      // At scale 1.5 the label is ~27dp tall, so the natural content is
      // ~55dp. A bar of 40 * 1.5 = 60 still fits without the clamp; a
      // bar of 30 * 1.5 = 45 would not, and the clamp has to take the
      // label-scaled floor, not the unscaled one.
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            style: const DSBottomNavBarStyle(height: 30),
          ),
          platform: TargetPlatform.iOS,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      // 30 * 1.5 = 45, but the label at 1.5× is ~27dp, so natural
      // content is ~55dp. The clamp must take 55, not 45.
      final dest = find
          .descendant(
            of: find.byType(DSBottomNavBar),
            matching: find.byType(Column),
          )
          .first;
      expect(tester.getSize(dest).height, greaterThanOrEqualTo(55));
    });
  });

  group('selection carries three channels', () {
    testWidgets('filled glyph, indicator pill and label weight', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three)),
      );
      await tester.pumpAndSettle();

      // 1 — the glyph swaps to its filled form. Only one of the two is built.
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.byIcon(Icons.book_outlined), findsOneWidget);

      // 2 — the indicator pill, in the brand gradient. Material's own
      // indicator only paints a flat colour, so it is turned transparent
      // and the pill itself is drawn behind the selected glyph instead
      // (see `_glyph`'s `paintIndicator` branch).
      final indicator = tester.widget<NavigationIndicator>(
        find.descendant(
          of: destination(0),
          matching: find.byType(NavigationIndicator),
        ),
      );
      expect(indicator.color, Colors.transparent);
      final pill = tester.widget<Container>(
        find.descendant(of: destination(0), matching: find.byType(Container)),
      );
      expect(
        (pill.decoration as ShapeDecoration).gradient,
        spec.palette.light.primaryGradient,
      );

      // 3 — the label goes heavier. Three channels, so the bar survives
      // greyscale (SC 1.4.1).
      TextStyle labelOf(int index) => tester
          .widget<Text>(
            find.descendant(
              of: destination(index),
              matching: find.byType(Text),
            ),
          )
          .style!;
      // Read from the spec rather than named as literals: the pair only has
      // to be *different* and in the right order, and pinning the two numbers
      // here meant an identity could not choose its own weights without this
      // test calling it a regression.
      expect(labelOf(0).fontWeight, spec.type.emphasisWeight);
      expect(labelOf(1).fontWeight, spec.type.labelWeight);
      expect(
        labelOf(0).fontWeight!.value,
        greaterThan(labelOf(1).fontWeight!.value),
      );
      expect(labelOf(0).color, spec.palette.light.primary);
      expect(labelOf(1).color, spec.palette.light.foreground);
    });
  });

  group('how many destinations a bar may have', () {
    test('two is a different control', () {
      expect(
        () => DSBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
          items: const [home, library],
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            allOf(contains('DSSegmentedButton'), contains('DSTabBar')),
          ),
        ),
      );
    });

    test('six is a sidebar', () {
      // component-selection.md already said this. This is where the rule is
      // enforced rather than documented — a six-tab bar used to compile.
      expect(
        () => DSBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
          items: const [home, library, settings, home, library, settings],
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('DSSidebar'),
          ),
        ),
      );
    });

    test('five is still a bar', () {
      expect(
        () => DSBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
          items: const [home, library, settings, home, library],
        ),
        returnsNormally,
      );
    });
  });

  group('one badge, one field', () {
    test('a count and a dot together is two answers to one question', () {
      expect(
        () => DSBottomNavItem(
          label: 'Inbox',
          icon: Icons.mail_outline,
          badgeCount: 3,
          badgeDot: true,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('the count is part of the destination, not a second node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              DSBottomNavItem(
                label: 'Library',
                icon: Icons.book_outlined,
                badgeCount: 3,
              ),
              settings,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(destination(1));
      expect(node.label, contains('Library'));
      expect(node.label, contains('3 new'));
      // Not separately actionable and not separately focusable: a badge is
      // never the thing a screen-reader user tabs to.
      expect(find.bySemanticsLabel('3'), findsNothing);
      handle.dispose();
    });

    testWidgets('a dot says "something", and says so out loud', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              DSBottomNavItem(
                label: 'Alerts',
                icon: Icons.notifications_none,
                badgeDot: true,
              ),
              settings,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(destination(1)).label,
        contains('new activity'),
      );
      handle.dispose();
    });

    testWidgets('badgeFormatter is honoured, on screen and in the name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            badgeFormatter: (count) => count > 9 ? '9+' : '$count',
            items: const [
              home,
              DSBottomNavItem(
                label: 'Library',
                icon: Icons.book_outlined,
                badgeCount: 150,
              ),
              settings,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A bar that hardcodes '99+' cannot be localised, and where the
      // threshold sits is a brand decision.
      expect(find.text('9+'), findsOneWidget);
      expect(find.text('150'), findsNothing);
      expect(tester.getSemantics(destination(1)).label, contains('9+ new'));
      handle.dispose();
    });

    testWidgets('a zero count draws nothing and says nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              DSBottomNavItem(
                label: 'Library',
                icon: Icons.book_outlined,
                badgeCount: 0,
              ),
              settings,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSemantics(destination(1)).label, isNot(contains('new')));
      handle.dispose();
    });
  });

  group('the destination model is open where it needs to be', () {
    testWidgets('iconSlot replaces the glyph and still takes its colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              library,
              DSBottomNavItem(
                label: 'You',
                icon: Icons.person_outline,
                iconSlot: Icon(Icons.face),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.face), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);
      // The slot sits inside the destination's IconTheme, so a plain Icon in
      // it still tints with selection rather than opting out of the bar.
      final theme = IconTheme.of(tester.element(find.byIcon(Icons.face)));
      expect(theme.color, spec.palette.light.foreground);
      expect(theme.size, spec.component.iconSize);
    });

    testWidgets('badgeSlot replaces the badge the count would have drawn', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              DSBottomNavItem(
                label: 'Library',
                icon: Icons.book_outlined,
                badgeCount: 3,
                badgeSlot: Icon(Icons.bolt, size: 12),
              ),
              settings,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('semanticLabel joins the name without replacing the label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              library,
              DSBottomNavItem(
                label: 'You',
                icon: Icons.person_outline,
                semanticLabel: 'Ada Lovelace',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // NavigationDestination's label is a String that is both drawn and
      // announced, and a wrapper cannot silence it — so the caller's name is
      // contributed alongside it rather than instead of it.
      final node = tester.getSemantics(destination(2));
      expect(node.label, contains('Ada Lovelace'));
      expect(node.label, contains('You'));
      handle.dispose();
    });

    testWidgets('a disabled destination is dimmed and does not answer', (
      tester,
    ) async {
      var tapped = -1;
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: const [
              home,
              library,
              DSBottomNavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                enabled: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(destination(2));
      await tester.pumpAndSettle();
      expect(tapped, -1);

      final label = tester
          .widget<Text>(
            find.descendant(of: destination(2), matching: find.byType(Text)),
          )
          .style!;
      expect(label.color!.a, closeTo(0.38, 0.01));
    });
  });

  group('the bar the platform draws', () {
    Finder appleDestination(int index) => find
        .descendant(
          of: find.byType(DSBottomNavBar),
          matching: find.byType(Column),
        )
        .at(index);

    testWidgets('on Apple there is no Material bar and no pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      // The indicator is Material's way of saying "you are here". iOS has
      // never drawn one, and a capsule sliding around inside the kit's own
      // floating capsule is the tell that gave this bar away.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationIndicator), findsNothing);
      // Still a bar: three destinations, on the kit's glass.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(AppChromeSurface), findsOneWidget);
    });

    testWidgets('selection is the tint and the weight, on both sides', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      // Two channels rather than Material's three, because the third *is*
      // the pill. The glyph still swaps to its filled form, which is the one
      // that survives greyscale.
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);

      TextStyle styleOf(String label) =>
          tester.widget<Text>(find.text(label)).style!;
      expect(styleOf('Home').color, spec.palette.light.primary);
      expect(styleOf('Home').fontWeight, spec.type.emphasisWeight);
      expect(styleOf('Library').color, spec.palette.light.foreground);
      expect(styleOf('Library').fontWeight, spec.type.labelWeight);
    });

    testWidgets('a disabled destination is dimmed and ignored on Apple too', (
      tester,
    ) async {
      // The first attempt used `CupertinoTabBar`, which draws the labels
      // itself in two colours — so a disabled destination read as merely
      // unselected. Both halves are asserted here because both were wrong.
      var tapped = -1;
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (i) => tapped = i,
            items: const [
              home,
              library,
              DSBottomNavItem(
                label: 'Settings',
                icon: Icons.settings_outlined,
                enabled: false,
              ),
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tapped, -1);
      expect(
        tester.widget<Text>(find.text('Settings')).style!.color!.a,
        closeTo(0.38, 0.01),
      );
      expect(appleDestination(0), findsOneWidget);
    });

    testWidgets('the badge and its name survive the branch', (tester) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              home,
              DSBottomNavItem(
                label: 'Library',
                icon: Icons.book_outlined,
                badgeCount: 3,
              ),
              settings,
            ],
          ),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      // One node, and the count is announced before the destination it
      // belongs to — the same contract the Material branch keeps.
      final node = tester.getSemantics(find.text('Library'));
      expect(node.label, contains('3 new'));
      expect(node.label, contains('Library'));
    });
  });

  group('the hand only speaks when something changed', () {
    final haptics = <MethodCall>[];

    setUp(() {
      haptics.clear();
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

    testWidgets(
      'a destination change fires selection, the current one does not',
      (tester) async {
        await tester.pumpWidget(
          host(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three)),
        );

        await tester.tap(destination(0));
        await tester.pumpAndSettle();
        // A bar that buzzes where the user already is teaches them the buzz
        // means nothing.
        expect(haptics, isEmpty);

        await tester.tap(destination(2));
        await tester.pumpAndSettle();
        expect(haptics, hasLength(1));
      },
    );
  });

  group('text scale', () {
    testWidgets('the bar grows with the labels, the glyph does not', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(NavigationBar)).height, 64 * 1.5);
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.home))).size,
        spec.component.iconSize,
      );
    });

    testWidgets('past 1.8x the labels are dropped and the bar stops growing', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      // Three lines of 22pt text under a 24dp glyph is a bar taller than the
      // content it navigates. The long-press tooltip carries the labels.
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        NavigationBarTheme.of(
          tester.element(find.byType(NavigationBar)),
        ).labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
      expect(tester.getSize(find.byType(NavigationBar)).height, 64);
      expect(bar.destinations, hasLength(3));
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('the badge keeps its size while everything else grows', (
      tester,
    ) async {
      Future<Size> badgeAt(double textScale) async {
        await tester.pumpWidget(
          host(
            DSBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                home,
                DSBottomNavItem(
                  label: 'Library',
                  icon: Icons.book_outlined,
                  badgeCount: 3,
                ),
                settings,
              ],
            ),
            textScale: textScale,
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.text('3'));
      }

      // The pill is a fixed 14dp so it stays a mark on a 24dp glyph. Scaled
      // up, the digit outgrows the pill and is clipped by it — which the
      // textScale 2.0 golden showed. The count still reaches a low-vision
      // user through the destination's name, which does scale.
      expect(await badgeAt(2), await badgeAt(1));
    });
  });

  group('the chrome tint is pinned across platforms', () {
    testWidgets('the same bar is the same colour on both', (tester) async {
      Future<AppMaterial> materialOn(TargetPlatform platform) async {
        late AppMaterial captured;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) {
                captured = AppMaterials.chrome(context);
                return DSBottomNavBar(
                  currentIndex: 0,
                  onTap: (_) {},
                  items: three,
                );
              },
            ),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        return captured;
      }

      final apple = await materialOn(TargetPlatform.iOS);
      final android = await materialOn(TargetPlatform.android);

      // C-6: the two branches used to read two different scheme roles, so the
      // same bar was a different colour on each platform and nobody had
      // chosen the second one. Translucency changes the *material* — Apple
      // blurs what is behind it — and never the hue.
      expect(apple.isGlass, isTrue);
      expect(android.isGlass, isFalse);
      expect(
        HSLColor.fromColor(apple.tint).hue,
        HSLColor.fromColor(android.tint).hue,
      );
      expect(apple.tint.withValues(alpha: 1), android.tint);
    });
  });

  group('the slots on the bar itself', () {
    testWidgets('leading and trailing sit beside the destinations', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            leading: const SizedBox(width: 40, child: Icon(Icons.rocket)),
            trailing: const SizedBox(width: 40, child: Icon(Icons.more_horiz)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.rocket), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      // The destinations still divide what is left, rather than the leading
      // widget becoming a fourth column.
      final viewport =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byType(NavigationBar)).width,
        moreOrLessEquals(viewport - floatingInset * 2 - 80, epsilon: 1),
      );
    });

    testWidgets('the surface slot replaces the chrome material', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            surface: const ColoredBox(color: Color(0xFF102030)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The hatch for a brand that needs a gradient there, without giving up
      // the destinations, the safe area or the semantics.
      expect(find.byType(AppChromeSurface), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
    });
  });

  group('the four layers', () {
    testWidgets('a theme extension reaches the bar', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSBottomNavBarStyle(height: 72)],
            ),
            home: Scaffold(
              bottomNavigationBar: DSBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: three,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(NavigationBar)).height, 72);
    });

    testWidgets('style: beats the extension', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSBottomNavBarStyle(height: 72)],
            ),
            home: Scaffold(
              bottomNavigationBar: DSBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: three,
                style: const DSBottomNavBarStyle(height: 56),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(NavigationBar)).height, 56);
    });

    testWidgets('showLabels: false hides them all, not some of them', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            style: const DSBottomNavBarStyle(showLabels: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        NavigationBarTheme.of(
          tester.element(find.byType(NavigationBar)),
        ).labelBehavior,
        NavigationDestinationLabelBehavior.alwaysHide,
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSBottomNavBarStyle(height: 64, glyphSize: 24);
      const over = DSBottomNavBarStyle(glyphSize: 28);
      final merged = base.merge(over);
      expect(merged.height, 64);
      expect(merged.glyphSize, 28);
    });

    test('lerp interpolates every number', () {
      const a = DSBottomNavBarStyle(
        height: 64,
        glyphSize: 24,
        badgeOffset: Offset(10, -4),
      );
      const b = DSBottomNavBarStyle(
        height: 80,
        glyphSize: 32,
        badgeOffset: Offset(20, 0),
      );
      final half = a.lerp(b, 0.5);
      expect(half.height, 72);
      expect(half.glyphSize, 28);
      expect(half.badgeOffset, const Offset(15, -2));
    });

    test('a bool snaps rather than half-showing the labels', () {
      const a = DSBottomNavBarStyle(showLabels: true);
      const b = DSBottomNavBarStyle(showLabels: false);
      expect(a.lerp(b, 0.4).showLabels, isTrue);
      expect(a.lerp(b, 0.6).showLabels, isFalse);
    });

    testWidgets('every default comes from the spec, not from a field', (
      tester,
    ) async {
      late DSBottomNavBarStyle resolved;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              resolved = DSBottomNavBarStyle.resolve(context);
              return DSBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: three,
              );
            },
          ),
        ),
      );

      // The style object itself carries nothing: a non-null default on it
      // would make a deliberate override indistinguishable from a default
      // that was never set.
      const bare = DSBottomNavBarStyle();
      expect(bare.height, isNull);
      expect(bare.glyphSize, isNull);
      expect(bare.showLabels, isNull);

      expect(resolved.glyphSize, spec.component.iconSize);
      expect(resolved.glyphLabelGap, spec.space.xs);
      expect(resolved.indicatorColor, spec.palette.light.secondary);
      expect(resolved.badgeOffset, const Offset(10, -4));
    });
  });

  group('plan 38 — labels fit', () {
    TextStyle labelStyleOf(WidgetTester tester, int index) => tester
        .widget<Text>(
          find.descendant(of: destination(index), matching: find.byType(Text)),
        )
        .style!;

    /// Wraps the bar in a SizedBox that pins the column to phone widths.
    /// The default Flutter test viewport is 800x600, where every label
    /// fits at 9.3pt — the shrink never kicks in and the assertions
    /// would always pass. Plan 38's bar is designed for 320–393dp
    /// phones; pin to 360dp to exercise the constraint.
    Widget phoneHost(
      Widget bar, {
      Brightness brightness = Brightness.light,
      double textScale = 1,
      TargetPlatform platform = TargetPlatform.android,
    }) => Design(
      spec: spec,
      child: MaterialApp(
        theme:
            (brightness == Brightness.light
                    ? AppTheme.lightTheme
                    : AppTheme.darkTheme)
                .copyWith(platform: platform),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            size: const Size(360, 640),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: Scaffold(bottomNavigationBar: bar),
            ),
          ),
        ),
      ),
    );

    testWidgets('a label longer than the column shrinks to fit', (
      tester,
    ) async {
      // Five destinations on a 360dp phone. The column width is small
      // enough that "Notifications" (13 chars at labelSmall) clips at
      // every step from 9.3pt down; the shrink lands at the 7pt
      // floor. This is the *cost* of a label that slipped past the
      // lint — 7pt is still legible, but the caller is told to fix
      // it via the suggestion in the lint diagnostic.
      const five = [
        DSBottomNavItem(label: 'Library', icon: Icons.book_outlined),
        DSBottomNavItem(label: 'Notifications', icon: Icons.notifications),
        DSBottomNavItem(label: 'Settings', icon: Icons.settings_outlined),
        DSBottomNavItem(label: 'Search', icon: Icons.search),
        DSBottomNavItem(label: 'Profile', icon: Icons.person_outline),
      ];
      await tester.pumpWidget(
        phoneHost(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: five)),
      );
      await tester.pumpAndSettle();

      // The Material branch is what `phoneHost` builds. The first
      // destination's `Text` (Library) renders at the bar-wide pick.
      // The pick is the largest step where ALL labels fit; on a 360dp
      // viewport with five destinations, "Notifications" forces the
      // bar to 7pt — the floor.
      expect(labelStyleOf(tester, 0).fontSize, 7.0);
    });

    testWidgets('a label that fits at 9.3pt never shrinks', (tester) async {
      await tester.pumpWidget(
        phoneHost(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three)),
      );
      await tester.pumpAndSettle();

      // Three short labels (Home, Library, Settings) on a 360dp phone
      // fit at 9.3pt — the shrink's largest step is its first one.
      expect(labelStyleOf(tester, 0).fontSize, 9.3);
      expect(labelStyleOf(tester, 1).fontSize, 9.3);
      expect(labelStyleOf(tester, 2).fontSize, 9.3);
    });

    testWidgets('the Cupertino branch shrinks the same way', (tester) async {
      const five = [
        DSBottomNavItem(label: 'Library', icon: Icons.book_outlined),
        DSBottomNavItem(label: 'Notifications', icon: Icons.notifications),
        DSBottomNavItem(label: 'Settings', icon: Icons.settings_outlined),
        DSBottomNavItem(label: 'Search', icon: Icons.search),
        DSBottomNavItem(label: 'Profile', icon: Icons.person_outline),
      ];
      await tester.pumpWidget(
        phoneHost(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: five),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.pumpAndSettle();

      // On Cupertino the destination is a Column inside the
      // `_AppleDestination` widget, and the label is the Text
      // widget inside that Column. The first destination's first
      // Text is the label.
      final firstColumn = find
          .descendant(
            of: find.byType(DSBottomNavBar),
            matching: find.byType(Column),
          )
          .first;
      final firstText = find.descendant(
        of: firstColumn,
        matching: find.byType(Text),
      );
      expect(
        tester.widget<Text>(firstText).style!.fontSize,
        7.0,
        reason: 'Cupertino column 0 (Library) lands at the bar-wide pick',
      );
    });

    testWidgets('a label of 22 chars forces the bar to the floor (7pt)', (
      tester,
    ) async {
      // 22 chars at any of the three steps exceeds the column width
      // even at the widest reasonable phone. The shrink lands at
      // 7pt, the floor.
      const oversize = [
        DSBottomNavItem(
          label: 'Subscription Manager',
          icon: Icons.payments_outlined,
        ),
        DSBottomNavItem(label: 'Home', icon: Icons.home),
        DSBottomNavItem(label: 'Settings', icon: Icons.settings),
      ];
      await tester.pumpWidget(
        phoneHost(
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: oversize),
        ),
      );
      await tester.pumpAndSettle();

      expect(labelStyleOf(tester, 0).fontSize, 7.0);
    });

    testWidgets('the bar-wide pick is the largest step where ALL labels fit', (
      tester,
    ) async {
      // Three destinations, one of them long. The pick is the
      // largest step where the long one fits — the two short ones
      // are over-sized for no reason, which is the price of a
      // single bar-wide pick over a per-destination shrink. The
      // test pins that exact behaviour so a future per-destination
      // shrink is a deliberate decision rather than a silent
      // change.
      const mixed = [
        DSBottomNavItem(label: 'Home', icon: Icons.home),
        DSBottomNavItem(label: 'Notifications', icon: Icons.notifications),
        DSBottomNavItem(label: 'Search', icon: Icons.search),
      ];
      await tester.pumpWidget(
        phoneHost(DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: mixed)),
      );
      await tester.pumpAndSettle();

      expect(
        labelStyleOf(tester, 0).fontSize,
        labelStyleOf(tester, 1).fontSize,
      );
      expect(
        labelStyleOf(tester, 2).fontSize,
        labelStyleOf(tester, 1).fontSize,
      );
      expect(labelStyleOf(tester, 0).fontSize, lessThan(9.3));
    });
  });

  group('back-off below the pill', () {
    /// Wraps the bar with a `viewPadding.bottom` value so the back-off
    /// formula reads a non-zero inset. The default test MediaQuery has
    /// `viewPadding.bottom = 0`, which the bar's clamp reduces to its
    /// `margin.bottom` floor (sm = 8dp) — not the iPhone-with-indicator
    /// case plan 38 is sized for.
    Widget hostWithInset(double inset, Widget bar) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: inset),
          padding: EdgeInsets.only(bottom: inset),
        ),
        child: Scaffold(bottomNavigationBar: bar),
      ),
    );

    testWidgets('a large inset is capped at lg below the pill', (tester) async {
      // On a viewport with `viewPadding.bottom = 34dp` (the iPhone
      // home indicator), the uncapped formula `inset − xs` would be
      // 30dp, which reads as the pill drifting up the screen. The cap
      // holds the back-off at `lg = 16dp`, so the bar widget is
      // 64 (pill) + 16 = 80dp tall.
      //
      // Asserted on what rendered, not on the constant that set it.
      await tester.pumpWidget(
        hostWithInset(
          34,
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byType(DSBottomNavBar);
      final rect = tester.getRect(bar);
      expect(rect.height, closeTo(80, 1));
    });

    testWidgets('an Android gesture inset (24dp) hits the same cap', (
      tester,
    ) async {
      // `viewPadding.bottom = 24dp` (typical Android phone with nav
      // gestures) would be `24 − 4 = 20dp` uncapped; the cap makes it
      // 16dp, so the bar is 64 + 16 = 80dp — the same resting gap the
      // iPhone gets. The gap is a design constant now, not a device one.
      await tester.pumpWidget(
        hostWithInset(
          24,
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byType(DSBottomNavBar);
      final rect = tester.getRect(bar);
      expect(rect.height, closeTo(80, 1));
    });

    testWidgets('below the cap the inset still drives the back-off', (
      tester,
    ) async {
      // `viewPadding.bottom = 16dp` is under the cap, so the old
      // `inset − xs = 12dp` still applies and the pill is never pushed
      // *down* onto a short inset. The bar is 64 + 12 = 76dp tall.
      await tester.pumpWidget(
        hostWithInset(
          16,
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byType(DSBottomNavBar);
      final rect = tester.getRect(bar);
      expect(rect.height, closeTo(76, 1));
    });

    testWidgets('a zero inset falls back to the margin floor (sm, not xs)', (
      tester,
    ) async {
      // A device with no system inset (a desktop web view, an iPad
      // without a home indicator) reads `viewPadding.bottom = 0`,
      // and the bar's `margin.bottom = sm = 8dp` is the floor. The
      // bar widget is 64 + 8 = 72dp tall — the floor, not xs.
      await tester.pumpWidget(
        hostWithInset(
          0,
          DSBottomNavBar(currentIndex: 0, onTap: (_) {}, items: three),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byType(DSBottomNavBar);
      final rect = tester.getRect(bar);
      expect(rect.height, closeTo(72, 1));
    });

    testWidgets('back-off does not affect non-floating bars', (tester) async {
      // The non-floating bar's height is owned by the chrome
      // surface, not by the back-off formula. It grew by exactly
      // the inset (34dp) because the surface absorbs the safe area
      // into its own height when it welds to the edge. The back-off
      // formula never runs for the non-floating branch, so the cap
      // is invisible here.
      await tester.pumpWidget(
        hostWithInset(
          34,
          DSBottomNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: three,
            style: const DSBottomNavBarStyle(floating: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = find.byType(DSBottomNavBar);
      final rect = tester.getRect(bar);
      // 64 (pill) + 34 (inset absorbed into the surface) = 98.
      expect(rect.height, closeTo(98, 1));
    });
  });
}
