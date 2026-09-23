import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// flutter-065 — the ink layer, as one component.
///
/// `Material(type: MaterialType.transparency)` around an `InkWell` was written
/// thirteen times in this kit and no two spellings agreed. The interesting
/// half of the defect is not the repetition: three of the thirteen skipped the
/// tap floor, four derived the ink's radius and the focus ring's silhouette
/// separately, and three rows dropped `DSPressable` entirely in order to avoid
/// the press dip — which took the focus ring with it, because the ring lives
/// there too.
void main() {
  late BuildContext ctx;

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  const mediaSource = DSMediaSource.widget(
    ColoredBox(color: Color(0xFF112233)),
    semanticLabel: 'Cover of the quarterly report',
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return Center(child: child);
              },
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

  Future<void> tabTo(WidgetTester tester, {int stops = 6}) async {
    for (var i = 0; i < stops; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (ringOf(tester)) return;
    }
  }

  group('the surface', () {
    testWidgets('takes the tap', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DSInkSurface(
          onTap: () => taps++,
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      await tester.tap(find.byType(DSInkSurface));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('holds the tap floor by default', (tester) async {
      // Every call site that skipped this skipped it by accident: a row that
      // paints 40 and answers to 40 is below SC 2.5.8 with nothing saying so.
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          child: const SizedBox(width: 200, height: 12),
        ),
      );
      expect(
        tester.getSize(find.byType(DSInkSurface)).height,
        ctx.design.component.minTapTarget,
      );
    });

    testWidgets('and lets a component that paints below it say so', (
      tester,
    ) async {
      // The escape is not "no floor" — it is `DSTapTarget` outside the ink, so
      // the ripple stays the size of the visual while the box around it grows.
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          minTapTarget: false,
          child: const SizedBox(width: 200, height: 12),
        ),
      );
      expect(tester.getSize(find.byType(DSInkSurface)).height, 12);
    });

    testWidgets('paints its tint into the material, under the splash', (
      tester,
    ) async {
      // A `DecoratedBox` above the ink covers the ripple, which is why the
      // tint is an argument here rather than something a caller wraps.
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          tint: const Color(0xFF112233),
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      final ink = tester.widget<Ink>(find.byType(Ink));
      expect(
        (ink.decoration! as ShapeDecoration).color,
        const Color(0xFF112233),
      );
    });

    testWidgets('and no tint means no box at all', (tester) async {
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      expect(find.byType(Ink), findsNothing);
    });

    testWidgets('clips the splash to the shape it is given', (tester) async {
      const shape = StadiumBorder();
      await pump(
        tester,
        const DSInkSurface(
          shape: shape,
          child: SizedBox(width: 200, height: 60),
        ),
      );
      expect(tester.widget<InkWell>(find.byType(InkWell)).customBorder, shape);
    });

    testWidgets('and asks Material for an unbounded splash when told to', (
      tester,
    ) async {
      // The round icon button: its ripple is wider than the glyph it circles,
      // which `InkWell` cannot draw at all.
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          unbounded: true,
          unboundedRadius: 24,
          child: const SizedBox.square(dimension: 40),
        ),
      );
      final ink = tester.widget<InkResponse>(find.byType(InkResponse));
      expect(ink.containedInkWell, isFalse);
      expect(ink.radius, 24);
    });

    testWidgets('does not dip on its own', (tester) async {
      // Press feedback is DSPressable's. Half the call sites own the dip at a
      // different level — the card scales its whole surface, the FAB scales
      // above its glass — and an ink layer with its own would scale them
      // twice.
      await pump(
        tester,
        DSInkSurface(
          onTap: () {},
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      expect(find.byType(DSPressable), findsNothing);
    });
  });

  group('the three rows that had no ring', () {
    testWidgets('a media row rings when the keyboard reaches it', (
      tester,
    ) async {
      // It opts out of the dip — a full-bleed row that shrinks detaches from
      // the column — and used to opt out of `DSPressable` to get that, so
      // tabbing through a list lit nothing at all.
      await pump(
        tester,
        DSMediaRow(source: mediaSource, title: 'Ocean floor', onTap: () {}),
      );
      await tabTo(tester);
      expect(ringOf(tester), isTrue);
    });

    testWidgets('and the dip is still off', (tester) async {
      await pump(
        tester,
        DSMediaRow(source: mediaSource, title: 'Ocean floor', onTap: () {}),
      );
      expect(
        tester
            .widgetList<DSPressable>(find.byType(DSPressable))
            .any((p) => p.enabled),
        isFalse,
        reason: 'a row that shrinks away from its neighbours detaches',
      );
    });

    testWidgets('every menu item reaches the floor', (tester) async {
      await pump(
        tester,
        DSMenu(
          semanticLabel: 'Actions',
          items: [
            DSMenuItem(label: 'Rename', onPressed: () {}),
            DSMenuItem(label: 'Duplicate', onPressed: () {}),
          ],
        ),
      );
      await tester.tap(find.byType(DSMenu));
      await tester.pumpAndSettle();

      for (final label in ['Rename', 'Duplicate']) {
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(DSPressable),
          ),
          findsOneWidget,
          reason: '$label is a control and rings like one',
        );
      }
    });

    testWidgets('and every select option does too', (tester) async {
      await pump(
        tester,
        DSSelect<String>(
          label: 'Folder',
          value: 'Documents',
          options: const [
            DSSelectOption<String>(value: 'Documents', label: 'Documents'),
            DSSelectOption<String>(value: 'Music', label: 'Music'),
          ],
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(DSSelect<String>));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Music'),
          matching: find.byType(DSPressable),
        ),
        findsOneWidget,
      );
    });
  });
}
