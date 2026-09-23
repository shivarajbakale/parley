import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

import '../../tool/ui_lint.dart';

/// DSIconButton — plan 13.
///
/// Four variants became two because `filled` and `filledTonal` measured
/// 1.19:1 apart in dark; `tooltip` became a required `semanticLabel` because
/// three unlabelled icon buttons shipped in the demo screens; and the private
/// `_useErrorColor` became the same five-value tone every other component
/// uses. Each group below holds one of those open.
void main() {
  final spec = AppTheme.spec;

  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) => Design(
    spec: spec,
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  group('the target never shrinks with the glyph', () {
    testWidgets('every size renders a target at the floor', (tester) async {
      for (final size in DSIconButtonSize.values) {
        await tester.pumpWidget(
          host(
            DSIconButton(
              icon: Icons.edit_outlined,
              semanticLabel: 'Edit',
              size: size,
              onPressed: () {},
            ),
          ),
        );

        final target = tester.getSize(find.byType(InkResponse));
        expect(
          target.height,
          greaterThanOrEqualTo(spec.component.minTapTarget),
          reason: '$size: the visual shrinks, the target does not',
        );
        expect(target.width, greaterThanOrEqualTo(spec.component.minTapTarget));
      }
    });

    testWidgets('the visual extent still differs by size', (tester) async {
      final extents = <double>[];
      for (final size in DSIconButtonSize.values) {
        await tester.pumpWidget(
          host(
            DSIconButton(
              icon: Icons.edit_outlined,
              semanticLabel: 'Edit',
              size: size,
              variant: DSIconButtonVariant.filled,
              onPressed: () {},
            ),
          ),
        );
        extents.add(tester.getSize(find.byType(DecoratedBox).last).height);
      }
      // 32 / 40 / 48 — a ladder, not three names for one control.
      expect(extents, [
        spec.component.minTapTarget - spec.space.lg,
        spec.component.minTapTarget - spec.space.sm,
        spec.component.minTapTarget,
      ]);
    });

    testWidgets('a group keeps two sm targets from overlapping', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButtonGroup(
            children: [
              for (var i = 0; i < 3; i++)
                DSIconButton(
                  icon: Icons.edit_outlined,
                  semanticLabel: 'Edit $i',
                  size: DSIconButtonSize.sm,
                  onPressed: () {},
                ),
            ],
          ),
        ),
      );

      final targets = tester
          .widgetList<InkResponse>(find.byType(InkResponse))
          .toList();
      expect(targets, hasLength(3));
      final rects = [
        for (var i = 0; i < 3; i++)
          tester.getRect(find.byType(InkResponse).at(i)),
      ];
      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left,
          greaterThanOrEqualTo(rects[i - 1].right),
          reason:
              'at sm the visual is 32 and the target is 48, so without the '
              'gap the button a user hits is not the one they aimed at',
        );
      }
    });

    testWidgets('the glyph does not grow at text scale 2, and the target '
        'does not shrink', (tester) async {
      Size measure(WidgetTester tester) => tester.getSize(
        find.descendant(
          of: find.byType(DSIconButton),
          matching: find.byType(Icon),
        ),
      );

      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.edit_outlined,
            semanticLabel: 'Edit',
            onPressed: () {},
          ),
        ),
      );
      final glyph = measure(tester);
      final target = tester.getSize(find.byType(InkResponse));

      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.edit_outlined,
            semanticLabel: 'Edit',
            onPressed: () {},
          ),
          textScale: 2,
        ),
      );
      // An icon is a graphic, not text. Nothing changes, which is the correct
      // behaviour and is the reason it is asserted.
      expect(measure(tester), glyph);
      expect(tester.getSize(find.byType(InkResponse)), target);
    });
  });

  group('M-2 — the name is required, and it is what a reader hears', () {
    testWidgets('the label reaches semantics and the tooltip defaults to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.search,
            semanticLabel: 'Search',
            onPressed: () {},
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(DSIconButton));
      expect(node.label, 'Search');
      expect(node.flagsCollection.isButton, isTrue);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Search');
    });

    testWidgets('a longer tooltip does not become a second name', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.search,
            semanticLabel: 'Search',
            tooltip: 'Search this library',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSemantics(find.byType(DSIconButton)).label, 'Search');
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Search this library',
      );
    });

    testWidgets('the badge count joins the name and is not a second node', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.notifications_none,
            semanticLabel: 'Notifications',
            badgeCount: 3,
            onPressed: () {},
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(DSIconButton));
      expect(node.label, 'Notifications, 3 unread');
      // A badge is not separately actionable, so it is not separately
      // reachable either.
      expect(find.text('3'), findsOneWidget);
      expect(node.childrenCount, 0);
    });

    testWidgets('a count past 99 stops growing the badge', (tester) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.notifications_none,
            semanticLabel: 'Notifications',
            badgeCount: 250,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(DSIconButton)).label,
        'Notifications, 250 unread',
      );
    });
  });

  group('S-12 — two variants that are actually two', () {
    testWidgets('filled fills and standard does not', (tester) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.add,
            semanticLabel: 'Compose',
            variant: DSIconButtonVariant.filled,
            onPressed: () {},
          ),
        ),
      );
      final filled =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
              as ShapeDecoration;
      expect(filled.color, spec.palette.light.primary);

      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.add,
            semanticLabel: 'Compose',
            onPressed: () {},
          ),
        ),
      );
      final standard =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
              as ShapeDecoration;
      // Distinguishable without colour: fill versus no fill.
      expect(standard.color, isNull);
    });

    testWidgets('the removed variants are still reachable through the style', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.share_outlined,
            semanticLabel: 'Share',
            style: DSIconButtonStyle(
              fillColor: spec.palette.light.secondary,
              glyphColor: spec.palette.light.primary,
              outlineColor: spec.palette.light.border,
            ),
            onPressed: () {},
          ),
        ),
      );
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
              as ShapeDecoration;
      expect(decoration.color, spec.palette.light.secondary);
      expect(
        (decoration.shape as RoundedRectangleBorder).side.color,
        spec.palette.light.border,
      );
    });

    testWidgets('the shape follows the identity rather than being a circle', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.add,
            semanticLabel: 'Compose',
            variant: DSIconButtonVariant.filled,
            onPressed: () {},
          ),
        ),
      );
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
              as ShapeDecoration;
      expect(decoration.shape, isA<RoundedRectangleBorder>());
    });
  });

  group('M-3 — tone replaces the private bool', () {
    testWidgets('each tone moves the glyph on standard', (tester) async {
      for (final tone in DSTone.values) {
        await tester.pumpWidget(
          host(
            DSIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Delete',
              tone: tone,
              onPressed: () {},
            ),
          ),
        );
        final context = tester.element(find.byType(DSIconButton));
        final resolved = DSIconButtonStyle.resolve(
          context,
          DSIconButtonVariant.standard,
          null,
          tone,
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: find.byType(DSIconButton),
                  matching: find.byType(Icon),
                ),
              )
              .color,
          resolved.glyphColor,
        );
      }
    });

    testWidgets('a filled tone keeps its glyph legible on its own fill', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final tone in DSTone.values) {
          await tester.pumpWidget(
            host(
              DSIconButton(
                icon: Icons.delete_outline,
                semanticLabel: 'Delete',
                variant: DSIconButtonVariant.filled,
                tone: tone,
                onPressed: () {},
              ),
              brightness: brightness,
            ),
          );
          final context = tester.element(find.byType(DSIconButton));
          final resolved = DSIconButtonStyle.resolve(
            context,
            DSIconButtonVariant.filled,
            null,
            tone,
          );
          expect(
            contrastRatio(resolved.glyphColor!, resolved.fillColor!),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness $tone: gate K1, and the glyph is all there is',
          );
        }
      }
    });

    testWidgets('a disabled glyph clears 3:1 in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(
            const DSIconButton(
              icon: Icons.delete_outline,
              semanticLabel: 'Delete',
            ),
            brightness: brightness,
          ),
        );
        final context = tester.element(find.byType(DSIconButton));
        final palette = context.palette;
        final resolved = DSIconButtonStyle.resolve(
          context,
          DSIconButtonVariant.standard,
          null,
          DSTone.neutral,
        );
        expect(
          contrastRatio(resolved.disabledGlyph!, palette.card),
          greaterThanOrEqualTo(3.0),
          reason:
              '$brightness: reachable but clearly unavailable — a disabled '
              'control a user cannot find is a defect, not an affordance',
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: find.byType(DSIconButton),
                  matching: find.byType(Icon),
                ),
              )
              .color,
          resolved.disabledGlyph,
        );
      }
    });

    testWidgets(
      'a disabled filled button drops its fill as well as its glyph',
      (tester) async {
        await tester.pumpWidget(
          host(
            const DSIconButton(
              icon: Icons.add,
              semanticLabel: 'Compose',
              variant: DSIconButtonVariant.filled,
            ),
          ),
        );
        final decoration =
            tester
                    .widget<DecoratedBox>(find.byType(DecoratedBox).last)
                    .decoration
                as ShapeDecoration;
        // A disabled button that keeps its accent fill reads as available, and
        // the glyph would then be the only thing saying otherwise.
        expect(decoration.color, spec.palette.light.muted);
        expect(decoration.color, isNot(spec.palette.light.primary));
      },
    );

    testWidgets('a null onPressed takes no gesture', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          const DSIconButton(icon: Icons.delete_outline, semanticLabel: 'D'),
        ),
      );
      await tester.tap(find.byType(DSIconButton));
      expect(taps, 0);
      expect(
        tester.widget<InkResponse>(find.byType(InkResponse)).onTap,
        isNull,
      );
    });
  });

  group('a toggle says so twice', () {
    testWidgets('the glyph swaps and the semantics say toggled', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.bookmark_border,
            selectedIcon: Icons.bookmark,
            selected: true,
            semanticLabel: 'Remove from saved',
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      final node = tester.getSemantics(find.byType(DSIconButton));
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      // The fill is the second channel, never the only one.
      final decoration =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
              as ShapeDecoration;
      expect(decoration.color, spec.palette.light.secondary);
    });

    testWidgets('a toggle with no selectedIcon is what the lint catches', (
      tester,
    ) async {
      // The widget still renders — the fill alone is a design defect, not a
      // crash — so the guard is `tool/ui_lint.dart`, at the call site.
      final findings = lintSource('lib/screens/thing_page.dart', '''
  DSIconButton(
    icon: Icons.bookmark_border,
    semanticLabel: 'Save',
    selected: true,
    onPressed: _toggle,
  ),
''');
      expect(findings.single, contains('toggle-glyph'));
    });
  });

  group('loading holds the shape', () {
    testWidgets('the spinner replaces the glyph without moving the button', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.save_outlined,
            semanticLabel: 'Save',
            onPressed: () {},
          ),
        ),
      );
      final before = tester.getSize(find.byType(InkResponse));

      await tester.pumpWidget(
        host(
          DSIconButton(
            icon: Icons.save_outlined,
            semanticLabel: 'Save',
            loading: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A toolbar must not reflow because one of its buttons is busy.
      expect(tester.getSize(find.byType(InkResponse)), before);
      expect(
        tester.widget<InkResponse>(find.byType(InkResponse)).onTap,
        isNull,
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSIconButtonStyle(extent: 40, pressScale: 0.94);
      const over = DSIconButtonStyle(pressScale: 0.9);
      final merged = base.merge(over);
      expect(merged.extent, 40);
      expect(merged.pressScale, 0.9);
    });

    test('lerp interpolates every number', () {
      const a = DSIconButtonStyle(extent: 32, barGap: 8);
      const b = DSIconButtonStyle(extent: 48, barGap: 16);
      expect(a.lerp(b, 0.5).extent, 40);
      expect(a.lerp(b, 0.5).barGap, 12);
    });

    testWidgets('a theme extension reaches every button', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSIconButtonStyle(extent: 36)],
            ),
            home: Scaffold(
              body: Center(
                child: DSIconButton(
                  icon: Icons.add,
                  semanticLabel: 'Compose',
                  variant: DSIconButtonVariant.filled,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DecoratedBox).last).height, 36);
    });
  });
}
