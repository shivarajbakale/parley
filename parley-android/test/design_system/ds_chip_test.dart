import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSChip — plan 14.
///
/// The three regressions this file holds: S-13, `Color? color` accepting any
/// colour from anywhere; S-14, three controls in one class distinguished only
/// by which callback was non-null; and M-4, a selected filter whose only
/// signal was a fill — a filter row photographed in greyscale had no
/// selection at all.
void main() {
  final spec = AppTheme.spec;

  Widget host(
    Widget child, {
    DesignSpec? design,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) => Design(
    spec: design ?? spec,
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

  ShapeDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration
          as ShapeDecoration;

  group('the target decoupling, kept exactly as it was', () {
    testWidgets('the visual is 28 or 32 and the target is the floor at both', (
      tester,
    ) async {
      for (final size in DSChipSize.values) {
        await tester.pumpWidget(
          host(
            DSChip(
              label: 'Design',
              role: DSChipRole.filter,
              size: size,
              onSelected: (_) {},
            ),
          ),
        );
        // The container cross-fades its height between the two sizes, so the
        // measurement has to be taken after it has arrived.
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(DSChip)).height,
          greaterThanOrEqualTo(spec.component.minTapTarget),
          reason:
              '$size: a chip looks fine and only measures wrong, which is why '
              'this is the most common accessibility failure in the category',
        );
        expect(
          tester.getSize(find.byType(AnimatedContainer)).height,
          size == DSChipSize.sm
              ? spec.component.minTapTarget - spec.space.xl
              : spec.component.minTapTarget - spec.space.lg,
        );
      }
    });

    testWidgets('a group keeps two sm targets apart', (tester) async {
      await tester.pumpWidget(
        host(
          DSChipGroup(
            children: [
              for (var i = 0; i < 3; i++)
                DSChip(
                  label: 'Tag $i',
                  role: DSChipRole.filter,
                  size: DSChipSize.sm,
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
      );

      final rects = [
        for (var i = 0; i < 3; i++) tester.getRect(find.byType(DSChip).at(i)),
      ];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
    });

    testWidgets('the label wraps to more lines at text scale 2, and the '
        'target does not shrink', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(const DSChip(label: 'Documents'), textScale: 2),
      );
      expect(
        tester.getSize(find.byType(DSChip)).height,
        greaterThanOrEqualTo(spec.component.minTapTarget),
      );
    });
  });

  group('M-4 — selection is three channels, not one', () {
    testWidgets('selected renders the check, the outline and the fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Documents',
            role: DSChipRole.filter,
            selected: true,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decoration = decorationOf(tester);
      final side = (decoration.shape as RoundedRectangleBorder).side;
      expect(decoration.color, spec.palette.light.secondary);
      expect(side.color, spec.palette.light.primary);
      // Heavier than the resting outline, so the boundary itself says
      // "selected" in a greyscale screenshot. Against the resting token and
      // not `hairlineWidth`: the edge of a selectable surface has its own
      // pair now, and comparing to the shared hairline made this a test of
      // how thick a chart axis is.
      expect(side.width, greaterThan(spec.component.surfaceOutlineWidth));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('unselected has none of the three', (tester) async {
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Documents',
            role: DSChipRole.filter,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decoration = decorationOf(tester);
      // This identity's ComponentSpec says `tonal`, so an unselected chip is
      // a `well` with no boundary — the point is that it carries none of the
      // three signals selection adds.
      expect(decoration.color, spec.palette.light.muted);
      expect(decoration.color, isNot(spec.palette.light.secondary));
      expect(
        (decoration.shape as RoundedRectangleBorder).side.style,
        BorderStyle.none,
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('a filter announces itself as toggled', (tester) async {
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Documents',
            role: DSChipRole.filter,
            selected: true,
            onSelected: (_) {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(DSChip));
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(node.label, 'Documents');
    });
  });

  group('S-14 — three roles, and the wrong pairing does not compile', () {
    test('onSelected outside filter asserts', () {
      expect(
        () => DSChip(label: 'Draft', onSelected: (_) {}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('selected outside filter asserts', () {
      // Not `const`: a const constructor's assertion fails at compile time,
      // which is the better failure but not one a test can catch.
      const selected = true;
      expect(
        () => DSChip(label: 'Draft', selected: selected),
        throwsA(isA<AssertionError>()),
      );
    });

    test('onRemove outside input asserts', () {
      expect(
        () => DSChip(label: 'Draft', onRemove: () {}),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('a tag takes no focusable node', (tester) async {
      await tester.pumpWidget(host(const DSChip(label: 'Draft')));
      final node = tester.getSemantics(find.byType(DSChip));
      // Text with a background. Twelve static tags that each take a tab stop
      // is the failure this avoids.
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.label, 'Draft');
    });

    testWidgets('an input chip is two nodes, and the remove one is named', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Ada Lovelace',
            role: DSChipRole.input,
            onRemove: () {},
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(DSChip)).label, 'Ada Lovelace');
      final remove = tester.getSemantics(find.byIcon(Icons.close));
      // Never a bare ✕: the name says what is being removed.
      expect(remove.label, 'Remove Ada Lovelace');
      expect(remove.flagsCollection.isButton, isTrue);
    });

    testWidgets('the remove control keeps its own 48dp target', (tester) async {
      // Asserted by hitting it, not by measuring the glyph's box. The measured
      // version passed against an `OverflowBox` that spilled to 48 and
      // hit-tested nothing: `RenderBox.hitTest` refuses a position outside its
      // own size before the child is ever asked, so every point of that spill
      // was dead. The only assertion that can tell the two apart is a tap.
      var removed = false;
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Ada',
            role: DSChipRole.input,
            onRemove: () => removed = true,
          ),
        ),
      );
      final Rect glyph = tester.getRect(find.byIcon(Icons.close));
      expect(
        glyph.height,
        lessThan(spec.component.minTapTarget),
        reason: 'the ✕ is drawn small on purpose — that is the whole point',
      );
      await tester.tapAt(
        glyph.center + Offset(0, spec.component.minTapTarget / 2 - 1),
      );
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('removing plays out before the callback fires', (tester) async {
      var removed = false;
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Ada',
            role: DSChipRole.input,
            onRemove: () => removed = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      // The chip goes first; the row re-flows second. Starting the neighbours
      // before the chip is gone means a mis-tap removes the one that moved.
      expect(removed, isFalse);
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });
  });

  group('S-13 — the tint comes from a token', () {
    testWidgets('each tone pairs its fill with its own on-colour', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final tone in DSTone.values.skip(1)) {
          await tester.pumpWidget(
            host(
              DSChip(label: tone.name, tone: tone),
              brightness: brightness,
            ),
          );
          final context = tester.element(find.byType(DSChip));
          final resolved = DSChipStyle.resolve(
            context,
            DSChipRole.tag,
            null,
            tone,
          );
          expect(
            contrastRatio(resolved.labelStyle!.color!, resolved.fillColor!),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness $tone: gate K1, on the chip a caller tinted',
          );
        }
      }
    });

    testWidgets('a mark dot is a graphic beside a label that still reads', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => DSChip(
              label: 'Research',
              markColor: context.palette.chart.first,
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(DSChip));
      final palette = context.palette;
      expect(
        contrastRatio(palette.chart.first, palette.card),
        greaterThanOrEqualTo(3.0),
      );
      // The label is not the mark: it stays at the text grade.
      expect(
        tester.widget<Text>(find.text('Research')).style?.color,
        palette.foreground,
      );
    });
  });

  group('the identity finally reaches the chip', () {
    testWidgets('chipStyle: filled fills, tonal tints, outlined outlines', (
      tester,
    ) async {
      final expectations = <ChipStyle, (Color?, Color?)>{
        ChipStyle.outlined: (null, spec.palette.light.border),
        ChipStyle.tonal: (spec.palette.light.muted, null),
        ChipStyle.filled: (spec.palette.light.secondary, null),
      };

      for (final entry in expectations.entries) {
        await tester.pumpWidget(
          host(
            DSChip(
              label: 'Documents',
              role: DSChipRole.filter,
              onSelected: (_) {},
            ),
            design: spec.copyWith(
              component: spec.component.copyWith(chipStyle: entry.key),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final decoration = decorationOf(tester);
        expect(decoration.color, entry.value.$1, reason: '${entry.key} fill');
        final side = (decoration.shape as RoundedRectangleBorder).side;
        expect(
          entry.value.$2 == null ? null : side.color,
          entry.value.$2,
          reason: '${entry.key} outline',
        );
        expect(
          side.style,
          entry.value.$2 == null ? BorderStyle.none : BorderStyle.solid,
        );
      }
    });

    testWidgets('chipIcons off hides the leading glyph', (tester) async {
      await tester.pumpWidget(
        host(const DSChip(label: 'Urgent', icon: Icons.bolt)),
      );
      // The identity's default: at chip size an icon rarely says anything the
      // label does not, and it costs enough width to push the last chip off.
      expect(find.byIcon(Icons.bolt), findsNothing);

      await tester.pumpWidget(
        host(
          const DSChip(label: 'Urgent', icon: Icons.bolt),
          design: spec.copyWith(
            component: spec.component.copyWith(chipIcons: true),
          ),
        ),
      );
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });
  });

  group('the group owns what a chip cannot decide', () {
    testWidgets('the overflow chip names how many are hidden', (tester) async {
      await tester.pumpWidget(
        host(
          DSChipGroup(
            maxVisible: 2,
            children: [for (var i = 0; i < 5; i++) DSChip(label: 'Tag $i')],
          ),
        ),
      );

      expect(find.text('+3'), findsOneWidget);
      expect(find.text('Tag 4'), findsNothing);
      // "+3" alone tells a reader nothing about what it is three of.
      expect(tester.getSemantics(find.text('+3')).label, '3 more filters');
    });

    testWidgets('selectedFirst leads with what is on', (tester) async {
      await tester.pumpWidget(
        host(
          DSChipGroup(
            selectedFirst: true,
            children: [
              DSChip(label: 'Off', role: DSChipRole.filter, onSelected: (_) {}),
              DSChip(
                label: 'On',
                role: DSChipRole.filter,
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getRect(find.text('On')).left,
        lessThan(tester.getRect(find.text('Off')).left),
      );
    });

    testWidgets('a single-select row is a mutually exclusive group', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSChipGroup(
            selectionMode: DSChipSelectionMode.single,
            children: [
              DSChip(
                label: 'Day',
                role: DSChipRole.filter,
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(
        tester
            .getSemantics(find.byType(DSChipGroup))
            .flagsCollection
            .isInMutuallyExclusiveGroup,
        isTrue,
      );
    });
  });

  group('count, disabled and loading', () {
    testWidgets('a count joins the name rather than becoming a node', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const DSChip(label: 'Documents', count: 12)),
      );
      expect(tester.getSemantics(find.byType(DSChip)).label, 'Documents, 12');
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('a disabled chip takes no gesture and stays legible', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          DSChip(
            label: 'Documents',
            role: DSChipRole.filter,
            enabled: false,
            onSelected: (_) => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(DSChip));
      expect(taps, 0);

      final context = tester.element(find.byType(DSChip));
      final palette = context.palette;
      expect(
        tester.widget<Text>(find.text('Documents')).style?.color,
        palette.mutedForeground,
      );
      expect(
        contrastRatio(palette.mutedForeground, palette.muted),
        greaterThanOrEqualTo(2.5),
        reason:
            'gate K3 holds textTertiary at 3:1 against `surface`; on `well` '
            'it measures 2.59:1, which is plan 00 business rather than this '
            'widget\'s — asserted so the debt stays visible',
      );
    });

    testWidgets('loading draws a bone, not the label', (tester) async {
      await tester.pumpWidget(
        host(const DSChip(label: 'Documents', loading: true)),
      );
      expect(find.byType(DSSkeleton), findsOneWidget);
      expect(find.text('Documents'), findsNothing);
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSChipStyle(height: 32, maxWidth: 200);
      const over = DSChipStyle(maxWidth: 120);
      final merged = base.merge(over);
      expect(merged.height, 32);
      expect(merged.maxWidth, 120);
    });

    test('lerp interpolates the numbers and snaps the enums', () {
      const a = DSChipStyle(height: 28, chipStyle: ChipStyle.outlined);
      const b = DSChipStyle(height: 32, chipStyle: ChipStyle.filled);
      expect(a.lerp(b, 0.5).height, 30);
      expect(a.lerp(b, 0.25).chipStyle, ChipStyle.outlined);
      expect(a.lerp(b, 0.75).chipStyle, ChipStyle.filled);
    });

    testWidgets('a theme extension reaches every chip', (tester) async {
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSChipStyle(height: 26)],
            ),
            home: const Scaffold(
              body: Center(child: DSChip(label: 'Draft')),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 26);
    });
  });
}
