import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/08-ds-button.plan.md`.
///
/// The two tests that matter most here are regressions: the disabled contrast
/// the audit measured at 1.18:1, and the type ramp that ran w500 → w700 → w500
/// and made a medium button look like a different component from a large one.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme:
              theme ??
              (brightness == Brightness.light
                  ? AppTheme.lightTheme
                  : AppTheme.darkTheme),
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
  }

  group('the disabled state is reachable, not invisible', () {
    for (final brightness in Brightness.values) {
      for (final variant in DSButtonVariant.values) {
        testWidgets('$variant clears 3:1 in ${brightness.name}', (
          tester,
        ) async {
          await pump(
            tester,
            DSButton(label: 'Continue', variant: variant),
            brightness: brightness,
          );
          final resolved = DSButtonStyle.resolve(ctx, variant, null);
          // The ground a disabled label sits on: its own disabled fill for a
          // filled variant, the page for a bare one.
          final ground = resolved.fillColor == null
              ? ctx.palette.background
              : resolved.disabledFill!;
          final ratio = contrastRatio(resolved.disabledLabel!, ground);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                'WCAG exempts disabled controls from the ratio and the '
                'exemption is widely read as licence to make them invisible. '
                'This one measured ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    }
  });

  group('the type ramp is monotonic', () {
    testWidgets('in size, weight and tracking', (tester) async {
      await pump(tester, const DSButton(label: 'x'));
      final styles = [
        for (final size in DSButtonSize.values)
          DSButtonStyle.resolve(ctx, DSButtonVariant.primary, size).labelStyle!,
      ];

      expect(styles[0].fontSize!, lessThan(styles[1].fontSize!));
      expect(styles[1].fontSize!, lessThan(styles[2].fontSize!));

      expect(styles.map((s) => s.fontWeight).toSet(), {
        ctx.design.type.emphasisWeight,
      }, reason: 'one weight; the ramp this replaces went w500, w700, w500');

      expect(styles[0].letterSpacing!, greaterThan(styles[1].letterSpacing!));
      expect(
        styles[1].letterSpacing!,
        greaterThan(styles[2].letterSpacing!),
        reason: 'tracking tightens as the size grows, in one direction',
      );
    });
  });

  group('loading', () {
    testWidgets('keeps the label, and with an icon keeps the exact width', (
      tester,
    ) async {
      await pump(
        tester,
        DSButton(
          label: 'Save changes',
          icon: Icons.save_outlined,
          onPressed: () {},
        ),
      );
      final settled = tester.getSize(find.byType(DSButton));

      await pump(
        tester,
        DSButton(
          label: 'Save changes',
          icon: Icons.save_outlined,
          onPressed: () {},
          loading: true,
        ),
      );
      expect(
        find.text('Save changes'),
        findsOneWidget,
        reason: 'a button that becomes a spinner loses the user’s place',
      );
      expect(
        tester.getSize(find.byType(DSButton)).width,
        settled.width,
        reason: 'the spinner takes the icon’s place rather than joining it',
      );
      expect(find.byIcon(Icons.save_outlined), findsNothing);
    });

    testWidgets('blocks the gesture and says so', (tester) async {
      final handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics();
      var pressed = 0;
      await pump(
        tester,
        DSButton(label: 'Save', loading: true, onPressed: () => pressed++),
      );
      await tester.tap(find.byType(DSButton));
      await tester.pump();
      expect(pressed, 0);
      final node = tester.getSemantics(find.byType(DSButton));
      expect(node.label, 'Save, loading');
      handle.dispose();
    });

    testWidgets('a caller can bring their own indicator', (tester) async {
      await pump(
        tester,
        const DSButton(
          label: 'Save',
          loading: true,
          loadingIndicator: Text('...'),
        ),
      );
      expect(find.text('...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('the geometry', () {
    testWidgets('sm paints 36 and is a target at the floor on both axes', (
      tester,
    ) async {
      await pump(
        tester,
        DSButton(label: 'x', size: DSButtonSize.sm, onPressed: () {}),
      );
      // Two boxes, and the distinction is the whole point: the pill is drawn
      // at 36 because that is the density a secondary button reads at, and the
      // box it occupies is the floor because that is what a thumb needs. The
      // widget used to be 36 on both counts, and the probe measured a control
      // twelve points under the floor the spec declares.
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(DSButton),
                matching: find.byType(InkWell),
              ),
            )
            .height,
        36,
      );
      final size = tester.getSize(find.byType(DSButton));
      expect(
        size.height,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
      expect(
        size.width,
        greaterThanOrEqualTo(ctx.design.component.minTapTarget),
      );
    });

    testWidgets('a long label wraps and grows the button rather than '
        'clipping', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 160,
          child: DSButton(
            label: 'Continue to the next step of setup',
            onPressed: () {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester.getSize(find.byType(DSButton)).height,
        greaterThan(ctx.design.component.buttonHeight),
        reason: 'a truncated action label is an unknown action',
      );
    });

    testWidgets('fullWidth fills its parent', (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 300,
          child: DSButton(label: 'x', fullWidth: true, onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(DSButton)).width, 300);
    });
  });

  group('the four layers stack', () {
    testWidgets('the variant supplies the ground', (tester) async {
      await pump(tester, const DSButton(label: 'x'));
      expect(
        DSButtonStyle.resolve(ctx, DSButtonVariant.primary, null).fillColor,
        ctx.palette.primary,
      );
      expect(
        DSButtonStyle.resolve(ctx, DSButtonVariant.outlined, null).fillColor,
        isNull,
      );
      expect(
        DSButtonStyle.resolve(ctx, DSButtonVariant.destructive, null).fillColor,
        ctx.palette.destructive,
      );
    });

    testWidgets('the nine deleted variants are now two style fields', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          // Not the primary variant: primary now carries the brand
          // gradient by default, which a `fillColor` override alone cannot
          // null back out (the merge chain only ever replaces a null with
          // a value, never the reverse). A non-primary variant has no
          // spec-default gradient to fight, so the custom flat fill shows.
          builder: (context) => DSButton(
            label: 'Approve',
            variant: DSButtonVariant.secondary,
            onPressed: () {},
            style: DSButtonStyle(
              fillColor: context.palette.success,
              labelColor: context.palette.onSuccess,
            ),
          ),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DSButton),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as ShapeDecoration).color, ctx.palette.success);
    });

    testWidgets('a theme extension moves every button below it', (
      tester,
    ) async {
      await pump(
        tester,
        DSButton(label: 'x', onPressed: () {}),
        theme: AppTheme.lightTheme.copyWith(
          extensions: const [DSButtonStyle(height: 72)],
        ),
      );
      expect(tester.getSize(find.byType(DSButton)).height, 72);
    });

    testWidgets('a DSButtonGroup installs the size as a scope, and an '
        'explicit size still wins', (tester) async {
      await pump(
        tester,
        DSButtonGroup(
          size: DSSize.sm,
          children: [
            DSButton(label: 'Scoped', onPressed: () {}),
            DSButton(label: 'Own', size: DSButtonSize.lg, onPressed: () {}),
          ],
        ),
      );
      final buttons = tester.widgetList<DSButton>(find.byType(DSButton));
      // Measured on the painted pill rather than on the widget's box: both
      // buttons occupy at least the tap floor, so the box cannot tell a
      // scoped `sm` from an explicit `lg`.
      double pill(DSButton button) => tester
          .getSize(
            find.descendant(
              of: find.byWidget(button),
              matching: find.byType(InkWell),
            ),
          )
          .height;
      expect(pill(buttons.first), 36, reason: 'the scope supplies a default');
      expect(
        pill(buttons.last),
        greaterThan(36),
        reason: 'and an explicit argument beats it',
      );
    });

    testWidgets('the group takes widgets, not DSButtons', (tester) async {
      await pump(tester, const DSButtonGroup(children: [Text('NOT A BUTTON')]));
      expect(find.text('NOT A BUTTON'), findsOneWidget);
    });
  });

  group('what was removed', () {
    test('there are exactly five variants', () {
      expect(DSButtonVariant.values, hasLength(5));
      expect(DSButtonVariant.values.map((v) => v.name), [
        'primary',
        'secondary',
        'outlined',
        'ghost',
        'destructive',
      ]);
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSButtonStyle(height: 48, iconGap: 8);
      final merged = base.merge(const DSButtonStyle(height: 56));
      expect(merged.height, 56);
      expect(merged.iconGap, 8, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSButtonStyle(height: 0, iconGap: 0);
      const b = DSButtonStyle(height: 48, iconGap: 16);
      final mid = a.lerp(b, 0.5);
      expect(mid.height, 24);
      expect(mid.iconGap, 8);
    });
  });
}
