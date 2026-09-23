import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One route, one scrim, one dismissal contract.
///
/// The kit used to present transient surfaces four ways, and the fourth was
/// not a route at all: `DSSelect` inserted an `OverlayEntry`, so the Android
/// back button exited the screen underneath while the menu stayed painted.
/// Everything asserted here is a property the navigator supplies for free and
/// that not one of those four mechanisms had all of.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final GlobalKey anchor = GlobalKey();

  Future<void> pumpHost(
    WidgetTester tester, {
    required Widget Function(BuildContext) trigger,
    Size size = const Size(390, 844),
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
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) =>
                    KeyedSubtree(key: anchor, child: trigger(context)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget body(BuildContext context) => const DSOverlaySurface(
    showDragHandle: false,
    child: SizedBox(height: 120, child: Center(child: Text('surface'))),
  );

  group('the header aligns its glyph, not its hit area', () {
    testWidgets('the × is as far from its edge as the title is from its', (
      tester,
    ) async {
      // The screenshot this exists for: a picker whose × sat 30 points from
      // the sheet edge above rows whose check marks sat 12. A tap target is a
      // hit area, not a visual edge, and laying the 48-point box flush
      // against the padding left the 20-point glyph 14 points further in.
      //
      // Measured as the header's own symmetry rather than against a token:
      // the inset is a tree-level decision — this kit pads on `space.lg` and
      // the template it syncs to pads on `pageGutter` — and the title is
      // drawn ink sitting on that line already. Whatever the number is, the
      // two sides of one header owe each other the same one.
      final design = AppTheme.spec;
      await pumpHost(
        tester,
        trigger: (context) => const DSBottomSheet(
          header: DSSheetHeader(title: 'Folder'),
          child: SizedBox(height: 80),
        ),
      );
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(DSBottomSheet));
      final title = tester.getRect(find.text('Folder'));
      final glyph = tester.getRect(find.byIcon(Icons.close));
      final target = tester.getRect(find.byType(IconButton).first);

      expect(
        sheet.right - glyph.right,
        title.left - sheet.left,
        reason:
            'a reader sees the ink, not the hit area, and one header cannot '
            'inset its two sides differently',
      );
      expect(
        target.width,
        greaterThanOrEqualTo(design.component.minTapTarget),
        reason:
            'aligning the glyph must not be paid for by shrinking the hit '
            'area — the target overhangs into the gutter instead',
      );
      expect(
        target.right,
        greaterThan(glyph.right),
        reason: 'the overhang is the whole mechanism; without it nothing moved',
      );
    });
  });

  group('the responsive rule', () {
    // A popover is a regular-width idiom: below 600 the same content is a
    // sheet. One call site, both form factors — the rule the HIG states and
    // the one a caller should never be writing an `if` for.
    testWidgets('a popover is a sheet on a phone and anchored on a pad', (
      tester,
    ) async {
      for (final (Size size, DSOverlayPresentation expected)
          in <(Size, DSOverlayPresentation)>[
            (const Size(400, 800), DSOverlayPresentation.sheet),
            (const Size(800, 900), DSOverlayPresentation.popover),
          ]) {
        late DSOverlayPresentation resolved;
        await pumpHost(
          tester,
          size: size,
          trigger: (context) => TextButton(
            onPressed: () {
              resolved = resolveDSPresentation(
                context,
                DSOverlayPresentation.popover,
              );
            },
            child: const Text('open'),
          ),
        );
        await tester.tap(find.text('open'));
        expect(resolved, expected, reason: 'at ${size.width} wide');
      }
    });

    testWidgets('responsive: false keeps the popover a popover', (
      tester,
    ) async {
      late DSOverlayPresentation resolved;
      await pumpHost(
        tester,
        size: const Size(400, 800),
        trigger: (context) => TextButton(
          onPressed: () => resolved = resolveDSPresentation(
            context,
            DSOverlayPresentation.popover,
            responsive: false,
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      expect(resolved, DSOverlayPresentation.popover);
    });
  });

  group('the barrier', () {
    testWidgets('a tap on the scrim dismisses, by default', (tester) async {
      await pumpHost(
        tester,
        trigger: (context) => TextButton(
          onPressed: () => showDSOverlay<void>(context: context, builder: body),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('surface'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('surface'), findsNothing);
    });

    testWidgets('barrierDismissible: false takes the semantics node too', (
      tester,
    ) async {
      // Not only the handler. A screen reader offered a "dismiss" action that
      // does nothing is worse than being offered nothing: the user tries it,
      // and the surface stays.
      final handle = tester.ensureSemantics();

      await pumpHost(
        tester,
        trigger: (context) => TextButton(
          onPressed: () => showDSOverlay<void>(
            context: context,
            barrierDismissible: false,
            builder: body,
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final route =
          ModalRoute.of(tester.element(find.text('surface')))!
              as DSOverlayRoute;
      expect(route.barrierDismissible, isFalse);
      expect(route.semanticsDismissible, isFalse);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('surface'), findsOneWidget);

      handle.dispose();
    });
  });

  testWidgets('a dialog opened from a sheet stacks, and back pops one', (
    tester,
  ) async {
    // Free from Navigator, and precisely what the OverlayEntry path could
    // not do: the sheet stays, the second scrim composites over it.
    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showDSBottomSheet<void>(
          context: context,
          builder: (sheetContext) => TextButton(
            onPressed: () => showDSDialog<void>(
              context: sheetContext,
              title: 'Send this link?',
              message: 'Anyone with it can open the document.',
            ),
            child: const Text('ask'),
          ),
        ),
        child: const Text('open'),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    expect(find.text('Send this link?'), findsOneWidget);
    expect(find.text('ask'), findsOneWidget);

    await simulateAndroidBackButton();
    await tester.pumpAndSettle();

    expect(find.text('Send this link?'), findsNothing);
    expect(find.text('ask'), findsOneWidget, reason: 'the sheet is still up');

    await simulateAndroidBackButton();
    await tester.pumpAndSettle();
    expect(find.text('ask'), findsNothing);
  });

  testWidgets('reduced motion is a cross-fade, for every presentation', (
    tester,
  ) async {
    // The claim is checked once, here, rather than in five surfaces: the
    // route owns the transition, so `disableAnimations` collapsing every
    // enter to a fade with zero translation is one assertion.
    for (final presentation in DSOverlayPresentation.values) {
      await pumpHost(
        tester,
        reducedMotion: true,
        size: const Size(900, 900),
        trigger: (context) => TextButton(
          onPressed: () => showDSOverlay<void>(
            context: context,
            presentation: presentation,
            anchor: anchor,
            builder: body,
          ),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      // Mid-flight, where a slide or a scale would be visible.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Above the surface, not anywhere in the tree: the app's own page
      // route builds transitions of its own, and they are not this claim.
      expect(
        find.ancestor(
          of: find.text('surface'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
        reason: '$presentation still translates under reduced motion',
      );
      expect(
        find.ancestor(
          of: find.text('surface'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
        reason: '$presentation still scales under reduced motion',
      );
      expect(
        find.ancestor(
          of: find.text('surface'),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      await simulateAndroidBackButton();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an anchored surface flips above a trigger near the bottom', (
    tester,
  ) async {
    // A menu that runs off the bottom of the screen is the commonest anchored
    // defect, and it is invisible in a story rendered at the top of a page.
    Future<(Rect menu, Rect trigger)> openFrom(Alignment where) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Align(
                alignment: where,
                child: Builder(
                  builder: (context) => TextButton(
                    key: key,
                    onPressed: () => showDSOverlay<void>(
                      context: context,
                      presentation: DSOverlayPresentation.menu,
                      anchor: key,
                      builder: body,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final trigger = tester.getRect(find.byKey(key));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final menu = tester.getRect(find.text('surface'));
      await simulateAndroidBackButton();
      await tester.pumpAndSettle();
      return (menu, trigger);
    }

    final (topMenu, topTrigger) = await openFrom(Alignment.topCenter);
    expect(
      topMenu.top,
      greaterThanOrEqualTo(topTrigger.bottom),
      reason: 'with room below, a menu opens downward',
    );

    final (bottomMenu, bottomTrigger) = await openFrom(Alignment.bottomCenter);
    expect(
      bottomMenu.bottom,
      lessThanOrEqualTo(bottomTrigger.top),
      reason: 'anchored at the bottom edge, it has to open upward',
    );
  });

  testWidgets('the drag handle is a control, not a decorative box', (
    tester,
  ) async {
    // It was a `Container` in three sheets. The handle is the affordance a
    // screen reader is told about, and an unlabelled box tells them nothing.
    final handle = tester.ensureSemantics();
    await pumpHost(
      tester,
      trigger: (context) => TextButton(
        onPressed: () => showDSBottomSheet<void>(
          context: context,
          builder: (context) => const SizedBox(height: 200),
        ),
        child: const Text('open'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final data = tester
        .getSemantics(find.byType(DSDragHandle))
        .getSemanticsData();
    expect(data.label, contains('Dismiss'));
    expect(data.hasAction(SemanticsAction.dismiss), isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('the style resolves its scrim from the palette, per theme', (
    tester,
  ) async {
    // The scrim is an accessibility surface rather than a taste one, and the
    // same alpha over a near-black page is not a barrier.
    late DSOverlayStyle light;
    late DSOverlayStyle dark;
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              light = DSOverlayStyle.resolve(context);
              return Theme(
                data: AppTheme.darkTheme,
                child: Builder(
                  builder: (context) {
                    dark = DSOverlayStyle.resolve(context);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(light.scrimOpacity, lessThan(dark.scrimOpacity!));
    expect(
      light.scrimColor,
      AppTheme.spec.palette.resolve(Brightness.light).overlay,
    );
  });

  test('the style object merges, lerps and never defaults a field', () {
    const empty = DSOverlayStyle();
    expect(empty.scrimOpacity, isNull, reason: 'defaults live in resolve');

    const a = DSOverlayStyle(scrimOpacity: 0.2, dialogMaxWidth: 400);
    const b = DSOverlayStyle(scrimOpacity: 0.6);
    expect(a.merge(b).scrimOpacity, 0.6);
    expect(a.merge(b).dialogMaxWidth, 400);

    final mid = a.lerp(const DSOverlayStyle(scrimOpacity: 0.6), 0.5);
    expect(mid.scrimOpacity, closeTo(0.4, 0.001));
  });
}

/// The platform's own back gesture, which is what the `OverlayEntry` this
/// replaces never saw.
Future<void> simulateAndroidBackButton() async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
}
