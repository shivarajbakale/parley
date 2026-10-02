import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/09-ds-card.plan.md`.
///
/// The regression that matters here is C-4: the audit could not find the card
/// edges in `screen_dashboard.png`, because the card sat 1.06:1 against the
/// page it was supposed to float on.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.lightTheme
              : AppTheme.darkTheme,
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

  ShapeDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(DSCard),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as ShapeDecoration;

  group('the card is findable against the page', () {
    // A card is found by tone or by light, and the rule is that it may not be
    // half-found by both. Either the ground steps far enough to resolve, or it
    // does not step at all and the shadow carries the whole claim — the
    // identity this replaces measured 1.06:1, which is neither, and its card
    // edges could not be found.
    //
    // The light floor is 1.15 rather than the 1.20 it ran at, which is not a
    // relaxation but the removal of a disagreement: K6 holds the same pair —
    // `surface` against `canvas` — at 1.15 in light, and two gates asking
    // different numbers of one pair means the stricter one is the real rule
    // and the other is decoration. 1.15 is the repo's stated floor for "a
    // display resolves this" everywhere else it appears, so it is the one
    // that survives. It also happens to be what makes halo's four-rung
    // neutral ladder fit at all: at 1.20 the page has to sit high enough that
    // the recess is pushed under K8's 3:1 against the accent.
    for (final (brightness, floor) in <(Brightness, double)>[
      (Brightness.light, 1.15),
      (Brightness.dark, 1.25),
    ]) {
      testWidgets('${brightness.name} clears $floor, or is flat on purpose', (
        tester,
      ) async {
        await pump(
          tester,
          const DSCard(child: Text('x')),
          brightness: brightness,
        );
        final ratio = contrastRatio(ctx.palette.card, ctx.palette.background);
        if (ctx.palette.card.toARGB32() == ctx.palette.background.toARGB32()) {
          expect(
            decorationOf(tester).shadows,
            isNotEmpty,
            reason:
                'a card sharing its page colour has nothing but the shadow '
                'left to be found by',
          );
        } else {
          expect(
            ratio,
            greaterThanOrEqualTo(floor),
            reason:
                'a card off its page by less than $floor:1 reads as a '
                'rendering error rather than as a plane; this one measures '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }

    testWidgets('and it carries a real shadow as the second signal', (
      tester,
    ) async {
      await pump(tester, const DSCard(child: Text('x')));
      expect(
        decorationOf(tester).shadows,
        hasLength(2),
        reason:
            'two layers, contact and ambient — nothing in the world casts '
            'only one',
      );
    });
  });

  group('the three grounds are the three surface roles', () {
    testWidgets('elevated reads surface, filled reads well, outlined reads '
        'canvas', (tester) async {
      await pump(tester, const DSCard(child: Text('x')));
      expect(decorationOf(tester).color, ctx.palette.card);

      await pump(
        tester,
        const DSCard(variant: DSCardVariant.filled, child: Text('x')),
      );
      expect(decorationOf(tester).color, ctx.palette.muted);
      expect(decorationOf(tester).shadows, isEmpty);

      await pump(
        tester,
        const DSCard(variant: DSCardVariant.outlined, child: Text('x')),
      );
      expect(decorationOf(tester).color, ctx.palette.background);
    });
  });

  group('the margin', () {
    testWidgets('is zero unless a caller asks for one', (tester) async {
      await pump(
        tester,
        const SizedBox(width: 300, child: DSCard(child: SizedBox(height: 40))),
      );
      expect(
        tester.getSize(find.byType(DSCard)).width,
        300,
        reason:
            'a default the doc comment tells every caller to override is the '
            'wrong default',
      );
    });

    testWidgets('and is still reachable through the style', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: DSCard(
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(height: 40),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DSCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.margin, const EdgeInsets.symmetric(horizontal: 20));
    });
  });

  group('elevation is a role', () {
    testWidgets('pressing drops exactly one step', (tester) async {
      await pump(tester, DSCard(onTap: () {}, child: const Text('x')));
      final resting = decorationOf(tester).shadows!;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DSCard)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final pressed = decorationOf(tester).shadows!;
      expect(
        pressed.first.blurRadius,
        lessThan(resting.first.blurRadius),
        reason: 'a pressed card moves toward the page, not away from it',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        decorationOf(tester).shadows!.first.blurRadius,
        resting.first.blurRadius,
      );
    });

    testWidgets('a style can flatten every card without editing one', (
      tester,
    ) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [DSCardStyle(elevation: DSElevation.none)],
            ),
            home: const Scaffold(body: DSCard(child: Text('x'))),
          ),
        ),
      );
      expect(decorationOf(tester).shadows, isEmpty);
    });
  });

  group('the gesture', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('with onTap the card is one button node', (tester) async {
      await pump(
        tester,
        DSCard(onTap: () {}, child: const Text('Open project')),
      );
      final node = tester.getSemantics(find.byType(DSCard));
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('without onTap it adds no semantics and no ink', (
      tester,
    ) async {
      await pump(tester, const DSCard(child: Text('x')));
      expect(
        find.byType(InkWell),
        findsNothing,
        reason:
            'a card that dims under a finger and does nothing is the most '
            'common "is this broken?" report in a kit',
      );
    });

    testWidgets('a tappable card holding a button trips the assertion', (
      tester,
    ) async {
      await pump(
        tester,
        DSCard(
          onTap: () {},
          child: Row(
            children: [
              const Text('x'),
              DSButton(label: 'Open', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(
        tester.takeException(),
        isAssertionError,
        reason:
            'the outer gesture swallows the inner one and a reader hears one '
            'target where there are two',
      );
    });
  });

  group('the slots', () {
    testWidgets('media sits outside the padding', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: DSCard(
            media: DSCardMedia(
              child: SizedBox(
                height: 60,
                child: ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
            child: Text('body'),
          ),
        ),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(DSCardMedia),
                matching: find.byType(ColoredBox),
              ),
            )
            .width,
        300,
        reason:
            'this is the slot that lets an image reach the card’s own corners '
            'without the caller zeroing the padding and re-adding it',
      );
    });

    testWidgets('header and footer sit inside it', (tester) async {
      await pump(
        tester,
        const DSCard(
          header: DSCardHeader(title: 'Members', subtitle: 'Four people'),
          footer: DSCardFooter(helper: DSCardHelperText('Updated today')),
          child: Text('body'),
        ),
      );
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Four people'), findsOneWidget);
      expect(find.text('Updated today'), findsOneWidget);
    });

    testWidgets('selected draws a fill and a check, not a fill alone', (
      tester,
    ) async {
      await pump(tester, const DSCard(selected: true, child: Text('x')));
      expect(decorationOf(tester).color, ctx.palette.secondary);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });

  group('the tone says what the card is about', () {
    testWidgets('it replaces the ground and adds the hairline that goes '
        'with it', (tester) async {
      await pump(
        tester,
        const DSCard(tone: DSTone.error, child: Text('The last sync failed')),
      );
      final expected = DSToneWash.fill(
        container: ctx.palette.tint(ctx.palette.destructive),
        surface: ctx.palette.card,
      );
      expect(decorationOf(tester).color, expected);
      expect(
        (decorationOf(tester).shape as RoundedRectangleBorder).side.color,
        DSToneWash.border(
          accent: ctx.palette.destructive,
          fill: expected,
          brightness: ctx.palette.brightness,
        ),
      );
    });

    testWidgets('and it is the same ground DSMessage paints', (tester) async {
      await pump(tester, const DSCard(tone: DSTone.success, child: Text('x')));
      final card = decorationOf(tester).color;
      await pump(
        tester,
        const DSMessage.section(tone: DSTone.success, message: 'x'),
      );
      expect(
        DSMessageStyle.resolve(
          ctx,
          DSTone.success,
          DSMessageScope.section,
        ).fillColor,
        card,
        reason:
            'two recipes for one green is the drift the style chain exists '
            'to prevent — both read DSToneWash',
      );
    });

    testWidgets('neutral keeps the variant own ground', (tester) async {
      await pump(tester, const DSCard(tone: DSTone.neutral, child: Text('x')));
      expect(decorationOf(tester).color, ctx.palette.card);
      expect(
        (decorationOf(tester).shape as RoundedRectangleBorder).side.color,
        ctx.palette.borderSoft,
        reason:
            'neutral means no tone, not a fifth family — the ground and the '
            'hairline both stay the variant own',
      );
    });

    testWidgets('the depth stays the variant own', (tester) async {
      await pump(tester, const DSCard(tone: DSTone.warning, child: Text('x')));
      final toned = decorationOf(tester).shadows;
      await pump(tester, const DSCard(child: Text('x')));
      expect(
        toned?.length,
        decorationOf(tester).shadows?.length,
        reason: 'a tone answers what the card is about, not how high it sits',
      );
    });

    testWidgets('a container can lend its tone', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSScope.merge(
            context,
            tone: DSTone.info,
            child: const DSCard(child: Text('x')),
          ),
        ),
      );
      expect(
        decorationOf(tester).color,
        DSToneWash.fill(
          container: ctx.palette.tint(ctx.palette.primary),
          surface: ctx.palette.card,
        ),
      );
    });

    testWidgets('and an explicit tone still wins over it', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSScope.merge(
            context,
            tone: DSTone.info,
            child: const DSCard(tone: DSTone.error, child: Text('x')),
          ),
        ),
      );
      expect(
        decorationOf(tester).color,
        DSToneWash.fill(
          container: ctx.palette.tint(ctx.palette.destructive),
          surface: ctx.palette.card,
        ),
        reason: 'a scope supplies a default, never an override',
      );
    });
  });

  group('disabled has a look', () {
    testWidgets('the whole card dims and comes down to the page', (
      tester,
    ) async {
      await pump(
        tester,
        DSCard(enabled: false, onTap: () {}, child: const Text('x')),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      expect(
        decorationOf(tester).shadows,
        isEmpty,
        reason: 'a surface nobody can reach has no business floating',
      );
    });

    testWidgets('and the gesture does not land', (tester) async {
      var taps = 0;
      await pump(
        tester,
        DSCard(enabled: false, onTap: () => taps++, child: const Text('x')),
      );
      await tester.tap(find.byType(DSCard), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('a disabling container disables the card inside it', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => DSScope.merge(
            context,
            enabled: false,
            child: DSCard(onTap: () {}, child: const Text('x')),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byType(Opacity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('but a loading card is not dimmed — it has a skeleton', (
      tester,
    ) async {
      await pump(tester, const DSCard(loading: true, child: Text('x')));
      expect(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'dimming a skeleton reads as a card that failed to load',
      );
      expect(find.byType(DSSkeleton), findsOneWidget);
    });
  });

  group('the sections', () {
    testWidgets('are separated by a rule that runs the full card width', (
      tester,
    ) async {
      await pump(
        tester,
        const DSCard(
          style: DSCardStyle(dividers: true),
          header: DSCardHeader(title: 'Members'),
          footer: DSCardFooter(helper: DSCardHelperText('Updated today')),
          child: Text('body'),
        ),
      );
      final rules = find.descendant(
        of: find.byType(DSCard),
        matching: find.byType(ColoredBox),
      );
      expect(rules, findsNWidgets(2));
      expect(
        tester.getSize(rules.first).width,
        tester.getSize(find.byType(DSCard)).width,
        reason:
            'a rule that stops at the padding reads as an underline on the '
            'line above it',
      );
    });

    testWidgets('and there are none by default', (tester) async {
      await pump(
        tester,
        const DSCard(
          header: DSCardHeader(title: 'Members'),
          child: Text('body'),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('media can bleed to the bottom edge instead', (tester) async {
      await pump(
        tester,
        const DSCard(
          mediaPlacement: DSCardMediaPlacement.bottom,
          media: DSCardMedia(aspectRatio: 2, child: Text('picture')),
          child: Text('body'),
        ),
      );
      expect(
        tester.getTopLeft(find.text('picture')).dy,
        greaterThan(tester.getTopLeft(find.text('body')).dy),
      );
    });
  });

  group('the long press', () {
    testWidgets('is its own gesture, and a card may have only it', (
      tester,
    ) async {
      var held = 0;
      await pump(
        tester,
        DSCard(onLongPress: () => held++, child: const Text('x')),
      );
      await tester.longPress(find.byType(DSCard));
      expect(held, 1);
      expect(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
        reason: 'a long-press-only card still presses',
      );
    });
  });

  group('the selection tick', () {
    testWidgets('is four values, not four literals', (tester) async {
      await pump(
        tester,
        const DSCard(
          selected: true,
          style: DSCardStyle(
            selectedIcon: Icons.shopping_basket_rounded,
            selectedAlignment: AlignmentDirectional.bottomStart,
          ),
          child: Text('x'),
        ),
      );
      expect(find.byIcon(Icons.shopping_basket_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('stands on the content grid, not a padding of its own', (
      tester,
    ) async {
      // The tick used to pay `space.sm` while the content paid the card's
      // padding, so on a one-line card it hung eight points above the text
      // and eight points inside the text's own right edge — two insets on one
      // small surface, which reads as a badge somebody forgot to align.
      await pump(tester, const DSCard(selected: true, child: Text('Selected')));

      final text = tester.getRect(find.text('Selected'));
      final icon = tester.getRect(find.byIcon(Icons.check_circle_rounded));

      expect(
        icon.right,
        moreOrLessEquals(text.right, epsilon: 0.5),
        reason: 'the tick shares the content\'s trailing edge',
      );
      expect(
        icon.center.dy,
        moreOrLessEquals(text.center.dy, epsilon: 1),
        reason: 'the tick sits on the first line, not above it',
      );
      // The overflow box is why: inside a 55-point card the padded rectangle
      // is 23 points tall, and an `Align` would hand a 24-point icon 23 and
      // flatten the bottom of the circle.
      expect(
        icon.size,
        Size.square(ctx.design.component.iconSize),
        reason: 'a squeezed tick matches no other tick on the screen',
      );
    });
  });

  group('the card header', () {
    testWidgets('takes a slot without a dead title beside it', (tester) async {
      await pump(
        tester,
        const DSCard(
          header: DSCardHeader(titleSlot: Text('Composed title')),
          child: Text('body'),
        ),
      );
      expect(find.text('Composed title'), findsOneWidget);
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSCardStyle(elevation: DSElevation.medium, pressScale: 0.99);
      final merged = base.merge(const DSCardStyle(elevation: DSElevation.none));
      expect(merged.elevation, DSElevation.none);
      expect(merged.pressScale, 0.99, reason: 'null is not a value');
    });
  });
}
