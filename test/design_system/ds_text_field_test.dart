import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/10-ds-text-field.plan.md`.
///
/// Two of these are the audit's own regressions: C-5, where the `filled` skin
/// sat 1.09:1 against the page and so had no boundary at all, and S-5, where
/// the helper and the error occupied different slots so every field below a
/// failing one jumped.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    ThemeData? theme,
    double textScale = 1,
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
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: Center(child: SizedBox(width: 320, child: child)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  ShapeDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(DSTextField),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as ShapeDecoration;

  // The border lives on a DecoratedBox stacked behind the Row (flutter-035).
  // The AnimatedContainer's decoration carries only the fill; the side
  // reaches the inner DecoratedBox that paints it without affecting layout.
  // The AnimatedContainer's own DecoratedBox also has a
  // RoundedRectangleBorder (with `BorderSide.none`), so pick the one whose
  // side is actually drawn.
  BorderSide sideOf(WidgetTester tester) {
    final decorated = find.descendant(
      of: find.byType(AnimatedContainer),
      matching: find.byType(DecoratedBox),
    );
    for (final box in tester.widgetList<DecoratedBox>(decorated)) {
      final d = box.decoration;
      if (d is ShapeDecoration &&
          d.shape is RoundedRectangleBorder &&
          (d.shape as RoundedRectangleBorder).side != BorderSide.none) {
        return (d.shape as RoundedRectangleBorder).side;
      }
    }
    fail(
      'no drawn RoundedRectangleBorder found under the field\'s AnimatedContainer',
    );
  }

  group('the boundary is visible — audit C-5', () {
    for (final brightness in Brightness.values) {
      testWidgets('the rest outline stays visible in ${brightness.name}', (
        tester,
      ) async {
        await pump(
          tester,
          const DSTextField(label: 'Email'),
          brightness: brightness,
        );
        final resolved = DSTextFieldStyle.resolve(ctx, null);

        // Borders are deliberately quiet (gate K3 holds them at 1.15-1.6:1),
        // which trades the WCAG SC 1.4.11 3:1 floor for a lighter look. The
        // outline must still exist: a `filled` skin once measured 1.09:1 and
        // had no boundary at all.
        for (final (name, ground, floor) in <(String, Color, double)>[
          ('its own fill', resolved.fillColor!, 1.15),
          ('the page it sits on', ctx.palette.background, 1.1),
        ]) {
          final ratio = contrastRatio(resolved.outlineColor!, ground);
          expect(
            ratio,
            greaterThanOrEqualTo(floor),
            reason:
                'the boundary is what identifies this control. Against $name '
                'it measures ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      testWidgets('and so does the disabled state in ${brightness.name}', (
        tester,
      ) async {
        await pump(
          tester,
          const DSTextField(label: 'Email', enabled: false),
          brightness: brightness,
        );
        final resolved = DSTextFieldStyle.resolve(ctx, null);
        final ratio = contrastRatio(
          resolved.disabledTextColor!,
          resolved.disabledFill!,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              'WCAG exempts disabled controls from the ratio and the '
              'exemption is widely read as licence to make them invisible. '
              'This one measures ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }

    testWidgets('the outline is drawn, not merely resolved', (tester) async {
      await pump(tester, const DSTextField(label: 'Email'));
      final resolved = DSTextFieldStyle.resolve(ctx, null);
      expect(sideOf(tester).color, resolved.outlineColor);
      expect(sideOf(tester).width, resolved.outlineWidth);
    });

    testWidgets('an error swaps the colour and the width, not the layout', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', errorText: 'Missing an @.'),
      );
      await tester.pumpAndSettle();
      final resolved = DSTextFieldStyle.resolve(ctx, null);
      expect(sideOf(tester).color, resolved.errorOutline);
      expect(sideOf(tester).width, resolved.focusedWidth);
    });
  });

  group('the helper slot is reserved — audit S-5', () {
    testWidgets('an error does not change the height', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', helperText: 'We only use this.'),
      );
      final settled = tester.getSize(find.byType(DSTextField)).height;

      await pump(
        tester,
        const DSTextField(
          label: 'Email',
          helperText: 'We only use this.',
          errorText: 'That address is missing an @.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DSTextField)).height,
        settled,
        reason:
            'on a login form a field that grows when a validator fires moves '
            'the button out from under the user’s thumb mid-tap',
      );
    });

    testWidgets('and neither does having no helper text at all', (
      tester,
    ) async {
      await pump(tester, const DSTextField(label: 'Email'));
      final bare = tester.getSize(find.byType(DSTextField)).height;

      await pump(
        tester,
        const DSTextField(label: 'Email', helperText: 'We only use this.'),
      );
      expect(tester.getSize(find.byType(DSTextField)).height, bare);
    });

    testWidgets('a field that can say nothing may give the line back', (
      tester,
    ) async {
      await pump(tester, const DSTextField(label: 'Where'));
      final reserved = tester.getSize(find.byType(DSTextField)).height;

      await pump(
        tester,
        const DSTextField(label: 'Where', reserveHelper: false),
      );
      final collapsed = tester.getSize(find.byType(DSTextField)).height;

      final resolved = DSTextFieldStyle.resolve(ctx, null);
      expect(
        reserved - collapsed,
        resolved.helperSlotHeight! + resolved.helperGap!,
        reason:
            'the slot and the gap above it come back together — half of a '
            'gap is still a gap',
      );
      expect(find.byType(DSFieldHelper), findsNothing);
    });

    testWidgets('a counter keeps the line whatever the flag says', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTextField(
          label: 'Bio',
          reserveHelper: false,
          input: DSFieldInput(maxLength: 40),
          affordances: DSFieldAffordances(showCharCount: true),
        ),
      );
      expect(
        find.byType(DSFieldHelper),
        findsOneWidget,
        reason:
            'the counter lives in that slot, and a count that appears with '
            'the first keystroke is the jump in its purest form',
      );
    });

    testWidgets('the error replaces the helper in place', (tester) async {
      await pump(
        tester,
        const DSTextField(
          label: 'Email',
          helperText: 'We only use this.',
          errorText: 'That address is missing an @.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('That address is missing an @.'), findsOneWidget);
      expect(find.text('We only use this.'), findsNothing);
    });

    testWidgets('and it is announced', (tester) async {
      final handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics();
      await pump(
        tester,
        const DSTextField(label: 'Email', errorText: 'Missing an @.'),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.text('Missing an @.'));
      expect(
        node.flagsCollection.isLiveRegion,
        isTrue,
        reason:
            'the user did not navigate here, the content changed under them, '
            'and it blocks their task — the one place a live region is right',
      );
      handle.dispose();
    });

    testWidgets('the slot grows with the text scale', (tester) async {
      await pump(tester, const DSTextField(label: 'Email'));
      final resolved = DSTextFieldStyle.resolve(ctx, null);
      final single = tester.getSize(find.byType(DSTextField)).height;

      await pump(tester, const DSTextField(label: 'Email'), textScale: 2);
      expect(
        tester.getSize(find.byType(DSTextField)).height - single,
        greaterThanOrEqualTo(resolved.helperSlotHeight!),
        reason: 'reserved space that does not scale clips the error it holds',
      );
    });
  });

  group('the affordances are their own controls', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('the clear button arrives with the first character', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTextField(
          label: 'Search',
          affordances: DSFieldAffordances(showClearButton: true),
        ),
      );
      expect(find.byTooltip('Clear'), findsNothing);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Clear'),
        findsOneWidget,
        reason:
            'the button is drawn from the text, and the TextField below '
            'rebuilds without rebuilding this widget',
      );
    });

    testWidgets('the toggle and the clear button are labelled, 48dp nodes', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'hunter2');
      addTearDown(controller.dispose);
      await pump(
        tester,
        DSTextField(
          label: 'Password',
          controller: controller,
          input: const DSFieldInput.password(),
          affordances: const DSFieldAffordances(showClearButton: true),
        ),
      );
      await tester.pumpAndSettle();

      final target = ctx.design.component.minTapTarget;
      for (final finder in [
        find.byTooltip('Show password'),
        find.byTooltip('Clear'),
      ]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(target));
        expect(size.height, greaterThanOrEqualTo(target));
        final node = tester.getSemantics(finder);
        expect(
          '${node.label}${node.tooltip}',
          isNotEmpty,
          reason: 'never an unlabelled icon inside the field’s own node',
        );
      }
    });

    testWidgets('the toggle reveals and re-hides', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Password', input: DSFieldInput.password()),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('the counter is drawn once, and only by this widget', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pump(
        tester,
        DSTextField(
          label: 'Display name',
          controller: controller,
          input: const DSFieldInput(maxLength: 4),
          affordances: const DSFieldAffordances(showCharCount: true),
        ),
      );
      expect(find.text('0/4'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abcdefgh');
      await tester.pumpAndSettle();
      expect(
        controller.text,
        'abcd',
        reason: 'suppressing the framework counter must not drop the limit',
      );
      expect(find.text('4/4'), findsOneWidget);
    });
  });

  group('the label is a label', () {
    testWidgets('and is rendered whether or not the field has focus', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', hintText: 'you@example.com'),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(
        find.text('you@example.com'),
        findsOneWidget,
        reason:
            'the hint is an example beside the label, never a replacement '
            'for it (WCAG SC 3.3.2)',
      );
    });

    testWidgets('required draws a mark', (tester) async {
      await pump(
        tester,
        const DSTextField(
          label: 'Email',
          validation: DSFieldValidation(required: true),
        ),
      );
      final label = tester.widget<Text>(find.byType(Text).first);
      expect(
        label.textSpan!.toPlainText(includeSemanticsLabels: false),
        'Email *',
      );
      expect(
        label.textSpan!.toPlainText(),
        contains('required'),
        reason: 'a mark that is only drawn is a mark half the users miss',
      );
    });
  });

  group('validation still belongs to the form', () {
    testWidgets('Form.validate reaches the field and the error lands in the '
        'reserved slot', (tester) async {
      final key = GlobalKey<FormState>();
      await pump(
        tester,
        Form(
          key: key,
          child: DSTextField(
            label: 'Email',
            helperText: 'We only use this.',
            validation: DSFieldValidation(
              validator: (v) => (v ?? '').isEmpty ? 'Enter your email' : null,
            ),
          ),
        ),
      );
      final settled = tester.getSize(find.byType(DSTextField)).height;

      expect(key.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DSTextField)).height,
        settled,
        reason: 'the same slot, whichever string is in it',
      );

      await tester.enterText(find.byType(TextField), 'ada@example.com');
      expect(key.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('We only use this.'), findsOneWidget);
    });

    testWidgets('a caller’s own errorText wins over the validator', (
      tester,
    ) async {
      final key = GlobalKey<FormState>();
      await pump(
        tester,
        Form(
          key: key,
          child: DSTextField(
            label: 'Email',
            errorText: 'That address is already in use.',
            validation: DSFieldValidation(
              validator: (v) => (v ?? '').isEmpty ? 'Enter your email' : null,
            ),
          ),
        ),
      );
      key.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('That address is already in use.'), findsOneWidget);
      expect(
        find.text('Enter your email'),
        findsNothing,
        reason: 'one error string on the widget, not two that can disagree',
      );
    });
  });

  group('focus does not shift content — flutter-035', () {
    // Flutter's `ShapeDecoration.padding` returns `EdgeInsets.all(side.width)`
    // for a `RoundedRectangleBorder`, and `Container` adds that to its own
    // padding for layout. Going from a 1dp hairline to a 2dp focus border
    // therefore added 1dp of effective inset on every side, so the Row's
    // children were squeezed by 1dp on focus. The DSFieldBox comment
    // 'The side is painted, not laid out' was the source of the mistake.
    // The fix draws the border on a layout-neutral DecoratedBox stacked
    // behind the content, so changing the side width never reaches layout.

    testWidgets('the leading and trailing icons stay put on focus', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTextField(
          label: 'Email',
          leadingIcon: Icons.mail_outline,
          trailingIcon: Icons.check_circle_outline,
          hintText: 'you@example.com',
        ),
      );
      final lead0 = tester.getCenter(find.byIcon(Icons.mail_outline)).dx;
      final trail0 = tester
          .getCenter(find.byIcon(Icons.check_circle_outline))
          .dx;
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byIcon(Icons.mail_outline)).dx,
        lead0,
        reason:
            'the focus border must not steal 1dp of horizontal inset from the '
            'leading icon',
      );
      expect(
        tester.getCenter(find.byIcon(Icons.check_circle_outline)).dx,
        trail0,
        reason: 'and not from the trailing icon either',
      );
    });

    testWidgets('the field box height is unchanged on focus', (tester) async {
      await pump(
        tester,
        DSSearchBar(value: '', onChanged: (_) {}, hintText: 'Search'),
      );
      final box0 = tester.getSize(
        find.descendant(
          of: find.byType(DSSearchBar),
          matching: find.byType(AnimatedContainer),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final box1 = tester.getSize(
        find.descendant(
          of: find.byType(DSSearchBar),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        box1.height,
        box0.height,
        reason:
            'a search bar with a 48dp trailing affordance grew 2dp on focus '
            'because the thicker border added inset that absorbed into the '
            'vertical padding',
      );
    });

    testWidgets('the select trigger keeps its leading on focus', (
      tester,
    ) async {
      await pump(
        tester,
        DSSelect<String>(
          options: const [
            DSSelectOption<String>(value: 'a', label: 'A'),
            DSSelectOption<String>(value: 'b', label: 'B'),
          ],
          value: null,
          onChanged: (_) {},
          hintText: 'Pick one',
          leading: const Icon(Icons.star, size: 18),
        ),
      );
      final lead0 = tester.getCenter(find.byIcon(Icons.star)).dx;
      await tester.tap(find.text('Pick one'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byIcon(Icons.star)).dx,
        lead0,
        reason:
            'DSSelect uses DSFieldBox for its trigger; the same 1dp horizontal '
            'shift must not reach it either',
      );
    });
  });

  group('the whole box is the target', () {
    // The input inside a field is a collapsed, borderless TextField: its own
    // gesture detector is one line of text tall and ends where the box's
    // inset begins. Everything else in the 48dp box — the air above and
    // below the line, the horizontal inset, the leading icon — was painted
    // as the field and did nothing when touched.
    bool focused(WidgetTester tester) => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    Rect boxOf(WidgetTester tester, Type field) => tester.getRect(
      find.descendant(
        of: find.byType(field),
        matching: find.byType(AnimatedContainer),
      ),
    );

    testWidgets('a tap in the inset corner focuses the field', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', hintText: 'you@example.com'),
      );
      await tester.tapAt(
        boxOf(tester, DSTextField).topLeft + const Offset(4, 4),
      );
      await tester.pump();
      expect(focused(tester), isTrue);
    });

    testWidgets('and so does a tap on the air under the text', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', hintText: 'you@example.com'),
      );
      final box = boxOf(tester, DSTextField);
      await tester.tapAt(Offset(box.center.dx, box.bottom - 3));
      await tester.pump();
      expect(focused(tester), isTrue);
    });

    testWidgets('and on the leading icon', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Email', leadingIcon: Icons.mail_outline),
      );
      await tester.tap(find.byIcon(Icons.mail_outline));
      await tester.pump();
      expect(focused(tester), isTrue);
    });

    testWidgets('a disabled field stays unfocused', (tester) async {
      await pump(tester, const DSTextField(label: 'Email', enabled: false));
      await tester.tapAt(
        boxOf(tester, DSTextField).topLeft + const Offset(4, 4),
      );
      await tester.pump();
      expect(focused(tester), isFalse);
    });

    testWidgets('the search bar’s box is a target too', (tester) async {
      await pump(
        tester,
        DSSearchBar(value: '', onChanged: (_) {}, hintText: 'Search'),
      );
      final box = boxOf(tester, DSSearchBar);
      await tester.tapAt(Offset(box.center.dx, box.top + 3));
      await tester.pump();
      expect(focused(tester), isTrue);
    });
  });

  group('the four layers stack', () {
    testWidgets('the spec supplies the ground', (tester) async {
      await pump(tester, const DSTextField(label: 'Email'));
      final resolved = DSTextFieldStyle.resolve(ctx, null);
      // `fieldFill`, not `surface`. The role is measured — it resolves to
      // whichever of the card and the page is the lighter — so on an identity
      // whose page is the lightest, naming `surface` here asserted the card's
      // grey and an input would have been a slab darker than the page it sat
      // on.
      expect(resolved.fillColor, ctx.palette.fieldFill);
      expect(resolved.focusedOutline, ctx.palette.primary);
      expect(resolved.errorOutline, ctx.palette.destructive);
    });

    testWidgets('a theme extension moves every field below it', (tester) async {
      await pump(
        tester,
        const DSTextField(label: 'Email'),
        theme: AppTheme.lightTheme.copyWith(
          extensions: const [DSTextFieldStyle(height: 72)],
        ),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(DSTextField),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .height,
        72,
      );
    });

    testWidgets('the three deleted skins are reachable through style:', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSTextField(
            label: 'Email',
            style: DSTextFieldStyle(
              fillColor: context.palette.muted,
              outlineColor: const Color(0x00000000),
            ),
          ),
        ),
      );
      expect(decorationOf(tester).color, ctx.palette.muted);
      expect(sideOf(tester).color, const Color(0x00000000));
    });

    testWidgets('a DSScope installs the size, and an explicit size wins', (
      tester,
    ) async {
      await pump(
        tester,
        const DSScope(
          size: DSSize.sm,
          child: Column(
            children: [
              DSTextField(label: 'Scoped'),
              DSTextField(label: 'Own', size: DSTextFieldSize.lg),
            ],
          ),
        ),
      );
      final boxes = find.descendant(
        of: find.byType(DSTextField),
        matching: find.byType(AnimatedContainer),
      );
      // `height` is a `minHeight`, so the assertion is the floor and the
      // order, not two exact numbers: at a 16pt body the small field's text
      // needs 41 and the container correctly grows to hold it. Pinning 40
      // here would have made a legible body size look like a regression.
      final small = tester.getSize(boxes.first).height;
      final large = tester.getSize(boxes.last).height;
      expect(small, greaterThanOrEqualTo(40.0));
      expect(large, greaterThanOrEqualTo(56.0));
      expect(small, lessThan(large), reason: 'the scope did not lose to size:');
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSTextFieldStyle(height: 48, iconSize: 20);
      final merged = base.merge(const DSTextFieldStyle(height: 56));
      expect(merged.height, 56);
      expect(merged.iconSize, 20, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSTextFieldStyle(height: 0, focusedWidth: 0);
      const b = DSTextFieldStyle(height: 48, focusedWidth: 2);
      final mid = a.lerp(b, 0.5);
      expect(mid.height, 24);
      expect(mid.focusedWidth, 1);
    });

    testWidgets('a field that expands fills the height it is given', (
      tester,
    ) async {
      // The Editor archetype's document. It threw during layout until the
      // field became the flexible child of this component's own column: a
      // Column hands its children an unbounded main axis whatever its own
      // constraints are, so `expands: true` asked for infinite height.
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SizedBox(
                height: 400,
                width: 320,
                child: DSTextField(
                  hintText: 'Write',
                  input: DSFieldInput(maxLines: null, expands: true),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The box takes what is left after the reserved helper slot rather
      // than settling at one line.
      expect(tester.getSize(find.byType(TextField)).height, greaterThan(300));
    });

    test('the reserved slot cannot be shrunk by a style', () {
      expect(
        // ignore: prefer_const_constructors
        () => DSTextFieldStyle(helperSlotHeight: 0),
        throwsAssertionError,
        reason:
            'a style field that could zero the slot would reintroduce the S-5 '
            'jump one call site at a time — a field that can say nothing '
            'drops the whole line with reserveHelper instead, which the '
            'constructor checks',
      );
    });

    test('and a field that can speak cannot drop the line', () {
      expect(
        // ignore: prefer_const_constructors
        () => DSTextField(label: 'Email', errorText: 'x', reserveHelper: false),
        throwsAssertionError,
      );
      expect(
        // ignore: prefer_const_constructors
        () => DSSelect<int>.fromValues(
          values: const <int>[1],
          optionBuilder: (int v) => DSSelectOption<int>(value: v, label: '1'),
          value: 1,
          onChanged: (int? _) {},
          helperText: 'Pick one',
          reserveHelper: false,
        ),
        throwsAssertionError,
      );
    });
  });
}
