import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The six components that are compositions of other components.
///
/// Each was small and each reimplemented something a plan above it now owns: a
/// settings row was the fourth hand-built copy of the labelled row, a sidebar
/// carried a second destination model, a theme picker shipped three cells with
/// no accessible name at all, and a progress bar drew its track in a surface
/// colour, so it was invisible on the card it was usually on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: inner!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  group('the fourth copy of the labelled row', () {
    testWidgets('a settings row, a switch tile and a list row are the same '
        'height for the same content', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            const DSSettingsRow(label: 'Profile', description: 'Name, photo'),
            DSSwitchTile(
              label: 'Profile',
              subtitle: 'Name, photo',
              value: true,
              onChanged: (_) {},
            ),
            const DSListTile(title: 'Profile', subtitle: 'Name, photo'),
          ],
        ),
      );

      final settings = tester.getSize(find.byType(DSSettingsRow)).height;
      final toggle = tester.getSize(find.byType(DSSwitchTile)).height;
      final row = tester.getSize(find.byType(DSListTile).last).height;

      expect(settings, closeTo(row, 0.5));
      expect(toggle, closeTo(row, 0.5));
    });

    testWidgets('only a row that goes somewhere shows a chevron', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          children: [
            DSSettingsRow(label: 'Display', onTap: () {}),
            const DSSettingsRow(label: 'Version', value: '0.1.0'),
          ],
        ),
      );

      expect(find.byType(DSChevron), findsOneWidget);
    });
  });

  group('the theme picker', () {
    testWidgets('the icon-only form names all three of its cells', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DSThemeModePicker(
          value: ThemeMode.system,
          showLabels: false,
          onChanged: (_) {},
        ),
      );

      // `label: ''` used to ship three cells a screen reader announced as
      // "button, button, button" — in a control whose whole job is to say
      // which of three things is chosen.
      for (final name in ['Light', 'System', 'Dark']) {
        expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
      }
      handle.dispose();
    });
  });

  group('the swipe', () {
    testWidgets('its action is invokable from the semantics tree, with no '
        'gesture at all', (tester) async {
      final handle = tester.ensureSemantics();
      var removed = 0;

      await pump(
        tester,
        DSDismissibleTile(
          key: const ValueKey<String>('row'),
          trailingAction: DSSwipeAction(
            icon: Icons.delete_outline,
            label: 'Delete',
            tone: DSTone.error,
            onInvoke: () => removed++,
          ),
          child: const DSListTile(title: 'Quarterly report'),
        ),
      );

      final node = tester.getSemantics(find.text('Quarterly report'));
      final action = node.getSemanticsData().customSemanticsActionIds!;
      expect(action, isNotEmpty);
      expect(CustomSemanticsAction.getAction(action.first)!.label, 'Delete');
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        action.first,
      );
      await tester.pump();

      expect(
        removed,
        1,
        reason: 'a swipe with no semantics action is a hidden feature',
      );
      handle.dispose();
    });

    /// The swipe's one decision is "far enough or not", and until the tile was
    /// stateful the user found out by letting go. `Dismissible.onUpdate`
    /// reports the crossing; the glyph and the tick are what it now drives.
    group('says it is armed', () {
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

      /// The scale the glyph is drawn at. `Transform.scale` does not change
      /// layout, so `getSize` reports the same box armed or not — the matrix
      /// is the only place the pop is visible.
      double glyphScale(WidgetTester tester, IconData icon) => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byIcon(icon),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();

      Widget deleteRow({DSSwipeAction? leading}) => DSDismissibleTile(
        key: const ValueKey<String>('row'),
        leadingAction: leading,
        trailingAction: DSSwipeAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          tone: DSTone.error,
          onInvoke: () {},
        ),
        child: const DSListTile(title: 'Quarterly report'),
      );

      // The row is 390 wide and the threshold is 0.4 of it, so 156px is the
      // line: 100 is short of it and 200 is past.
      testWidgets('the glyph pops at the threshold and settles back if the '
          'finger retreats', (tester) async {
        await pump(tester, deleteRow());
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Quarterly report')),
        );

        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();
        expect(
          glyphScale(tester, Icons.delete_outline),
          closeTo(1, 0.001),
          reason: 'short of the threshold the swipe is not armed',
        );
        expect(haptics, isEmpty);

        await gesture.moveBy(const Offset(-100, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          glyphScale(tester, Icons.delete_outline),
          greaterThan(1.05),
          reason: 'past it the glyph is growing under the thumb',
        );
        expect(
          haptics,
          hasLength(1),
          reason: 'the tick is the half of the answer the thumb is covering',
        );

        await gesture.moveBy(const Offset(140, 0));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          glyphScale(tester, Icons.delete_outline),
          closeTo(1, 0.01),
          reason: 'backing off disarms it',
        );
        expect(
          haptics,
          hasLength(1),
          reason: 'no second tick for a decision the user has un-made',
        );

        await gesture.up();
        await tester.pumpAndSettle();
      });

      /// `Dismissible` builds one panel at a time — the background for the
      /// direction the finger is currently going — so a two-action row swaps
      /// the whole panel as the finger crosses the centre. The armed value
      /// must not cross with it.
      testWidgets('the pop does not carry across to the other panel', (
        tester,
      ) async {
        await pump(
          tester,
          deleteRow(
            leading: DSSwipeAction(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onInvoke: () {},
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Quarterly report')),
        );

        await gesture.moveBy(const Offset(-200, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(glyphScale(tester, Icons.delete_outline), greaterThan(1.05));
        expect(
          find.byIcon(Icons.archive_outlined),
          findsNothing,
          reason: 'only the panel being swiped toward is in the tree',
        );

        // Across the centre and back under the threshold on the other side,
        // read on the very next frame — before any spring could have settled.
        // Without the reset this reads the delete glyph's 1.18 on a glyph the
        // user is seeing for the first time.
        await gesture.moveBy(const Offset(250, 0));
        await tester.pump();
        expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
        expect(
          glyphScale(tester, Icons.archive_outlined),
          closeTo(1, 0.001),
          reason: 'the archive swipe has not reached its own threshold yet',
        );

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('under reduced motion the glyph is simply already there', (
        tester,
      ) async {
        await pump(tester, deleteRow(), reducedMotion: true);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Quarterly report')),
        );
        await gesture.moveBy(const Offset(-200, 0));
        await tester.pump();

        expect(
          glyphScale(tester, Icons.delete_outline),
          closeTo(DSDismissibleTile.armedScale, 0.001),
          reason:
              'no spring and no overshoot — but the size still carries the '
              'meaning, so it is not removed',
        );
        expect(haptics, hasLength(1), reason: 'a tick is not motion');

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('the slide and the collapse are on the app\'s scale', (
        tester,
      ) async {
        await pump(tester, deleteRow());
        final motion = AppTheme.spec.motion;
        final dismissible = tester.widget<Dismissible>(
          find.byType(Dismissible),
        );

        // Unset, these are the framework's own 200ms and 300ms — which happen
        // to match `fast` and `normal` today and would not move at all if a
        // build turned the `speed` knob.
        expect(dismissible.movementDuration, motion.scaled(motion.fast));
        expect(dismissible.resizeDuration, motion.scaled(motion.normal));
      });
    });
  });

  group('progress', () {
    testWidgets('the linear bar is visible on a card', (tester) async {
      await pump(
        tester,
        const DSCard(child: DSProgressIndicator.linear(value: 0.4)),
      );

      final context = tester.element(find.byType(DSProgressIndicator));
      final resolved = DSProgressStyle.resolve(context);
      final palette = context.palette;

      expect(
        resolved.trackColor,
        isNot(palette.card),
        reason: 'a surface-coloured track on a card is an invisible track',
      );
      expect(resolved.trackColor, palette.muted);
    });
  });

  group('the sidebar', () {
    testWidgets('it takes the same destinations the bottom bar does, and '
        'selects the same index', (tester) async {
      const destinations = [
        DSBottomNavItem(label: 'Home', icon: Icons.home_outlined),
        DSBottomNavItem(
          label: 'Library',
          icon: Icons.book_outlined,
          badgeCount: 3,
        ),
        DSBottomNavItem(
          label: 'Archive',
          icon: Icons.archive_outlined,
          enabled: false,
        ),
      ];

      var fromBar = -1;
      var fromDrawer = -1;
      final key = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              key: key,
              drawer: DSSidebar(
                destinations: destinations,
                selectedIndex: 0,
                onDestinationSelected: (i) => fromDrawer = i,
              ),
              body: const SizedBox.expand(),
              bottomNavigationBar: DSBottomNavBar(
                currentIndex: 0,
                onTap: (i) => fromBar = i,
                items: destinations,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(DSBottomNavBar),
          matching: find.text('Library'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fromBar, 1);

      key.currentState!.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DSSidebar),
          matching: find.text('Library'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fromDrawer, 1, reason: 'one destination list, one index');
    });

    testWidgets('a disabled destination cannot be entered', (tester) async {
      var selected = -1;
      final key = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              key: key,
              drawer: DSSidebar(
                destinations: const [
                  DSBottomNavItem(label: 'Home', icon: Icons.home_outlined),
                  DSBottomNavItem(
                    label: 'Archive',
                    icon: Icons.archive_outlined,
                    enabled: false,
                  ),
                ],
                selectedIndex: 0,
                onDestinationSelected: (i) => selected = i,
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );

      key.currentState!.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(selected, -1);
    });

    testWidgets('one destination is not a choice', (tester) async {
      expect(
        () => DSSidebar(
          destinations: const [
            DSBottomNavItem(label: 'Home', icon: Icons.home_outlined),
          ],
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('the style objects', () {
    test('each interpolates rather than snapping', () {
      const sidebarA = DSSidebarStyle(width: 240, rowHeight: 40);
      const sidebarB = DSSidebarStyle(width: 320, rowHeight: 56);
      expect(sidebarA.lerp(sidebarB, 0.5).width, 280);
      expect(sidebarA.lerp(sidebarB, 0.5).rowHeight, 48);

      const swipeA = DSSwipeActionStyle(threshold: 0.2, iconSize: 16);
      const swipeB = DSSwipeActionStyle(threshold: 0.6, iconSize: 32);
      expect(swipeA.lerp(swipeB, 0.5).threshold, closeTo(0.4, 0.001));
      expect(swipeA.lerp(swipeB, 0.5).iconSize, 24);

      const progressA = DSProgressStyle(height: 4, strokeWidth: 2);
      const progressB = DSProgressStyle(height: 8, strokeWidth: 6);
      expect(progressA.lerp(progressB, 0.5).height, 6);
      expect(progressA.lerp(progressB, 0.5).strokeWidth, 4);

      // A merge takes only what the layer above set.
      expect(
        const DSSidebarStyle(
          width: 240,
        ).merge(const DSSidebarStyle(gap: 4)).width,
        240,
      );
    });
  });
}
