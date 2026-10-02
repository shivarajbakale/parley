import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The three things that float over a screen, and the layer that stops them
/// landing on each other.
///
/// The bug this file exists for is the first test: a screen with a pinned
/// action bar, a floating action button and a bottom navigation bar used to
/// put a snack bar on top of all three, because none of them knew the others
/// were there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double bottomPadding = 0,
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
            data: MediaQuery.of(context).copyWith(
              viewPadding: EdgeInsets.only(bottom: bottomPadding),
              padding: EdgeInsets.only(bottom: bottomPadding),
            ),
            child: inner!,
          ),
          home: child,
        ),
      ),
    );
    await tester.pump();
  }

  /// A screen with everything on it: content, a pinned bar, a button, a nav
  /// bar, and a button that raises a snack bar over the lot.
  Widget crowdedScreen({
    int rows = 12,
    double homeIndicator = 0,
    bool navBar = true,
  }) => DSBottomInsetsHost(
    child: Builder(
      builder: (context) => Scaffold(
        // The button goes in the scaffold's own slot, which places it above
        // whatever is in `bottomNavigationBar`. The insets are what the snack
        // bar reads; the button is what it has to clear.
        floatingActionButton: DSFab(
          icon: Icons.add,
          semanticLabel: 'New row',
          hideOnScroll: false,
          onPressed: () {},
        ),
        body: ListView.builder(
          padding: DSBottomInsets.of(context).scrollPadding,
          itemCount: rows,
          itemBuilder: (_, i) => DSListTile(title: 'Row ${i + 1}'),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSPinnedActionBar(
              children: [
                DSButton(
                  label: 'Publish',
                  onPressed: () => showDSSnackBar(context, message: 'Saved'),
                ),
              ],
            ),
            if (navBar)
              DSBottomNavBar(
                currentIndex: 0,
                onTap: (_) {},
                items: const [
                  DSBottomNavItem(label: 'Home', icon: Icons.home_outlined),
                  DSBottomNavItem(label: 'Library', icon: Icons.book_outlined),
                  DSBottomNavItem(label: 'You', icon: Icons.person_outline),
                ],
              ),
          ],
        ),
      ),
    ),
  );

  group('nothing lands on anything else', () {
    testWidgets('a snack bar arrives above the action bar, the button and '
        'the nav bar', (tester) async {
      await pump(tester, crowdedScreen(), bottomPadding: 34);
      // Two frames: the first lays the bars out, the second is the one the
      // host has their measured heights on.
      await tester.pump();

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      final snack = tester.getRect(find.byType(DSSnackBar));
      final bar = tester.getRect(find.byType(DSPinnedActionBar));
      final fab = tester.getRect(find.byType(DSFab));
      final nav = tester.getRect(find.byType(DSBottomNavBar));

      expect(snack.bottom, lessThanOrEqualTo(bar.top));
      expect(snack.bottom, lessThanOrEqualTo(fab.top));
      expect(snack.bottom, lessThanOrEqualTo(nav.top));
      expect(fab.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('the scroll view reserves room for everything under it', (
      tester,
    ) async {
      await pump(tester, crowdedScreen(rows: 30), bottomPadding: 34);
      await tester.pump();

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Row 30'),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('Row 30'));
      final bar = tester.getRect(find.byType(DSPinnedActionBar));
      expect(
        last.bottom,
        lessThanOrEqualTo(bar.top),
        reason: 'the last row is under the bar that is pinned over it',
      );
    });
  });

  group('a screen inside a tabbed shell', () {
    /// The shape every tab of this app has: the shell owns the navigation bar
    /// and the screen owns a scaffold of its own.
    ///
    /// `floating-chrome-host` asks any screen that floats something to install
    /// a host, because a screen has to work when it is mounted alone. That
    /// puts a host inside a host here, and it is the arrangement that hid the
    /// vault's button under the shell's bar: a `Scaffold` lifts its button
    /// above its *own* bottom widgets, the inner scaffold has none, and so the
    /// button was placed exactly where the bar is drawn. The tap went to the
    /// Settings tab.
    Widget shell({required VoidCallback onNew}) => DSBottomInsetsHost(
      child: Scaffold(
        extendBody: true,
        body: DSBottomInsetsHost(
          child: Builder(
            builder: (context) => Scaffold(
              extendBody: true,
              floatingActionButton: DSFab(
                icon: Icons.add,
                label: 'New login',
                hideOnScroll: false,
                onPressed: onNew,
              ),
              body: ListView(
                padding: DSBottomInsets.of(context).scrollPadding,
                children: const [DSListTile(title: 'Row 1')],
              ),
            ),
          ),
        ),
        bottomNavigationBar: DSBottomNavBar(
          currentIndex: 0,
          onTap: (_) {},
          items: const [
            DSBottomNavItem(label: 'Vault', icon: Icons.lock_outline),
            DSBottomNavItem(label: 'Generator', icon: Icons.casino_outlined),
            DSBottomNavItem(label: 'Settings', icon: Icons.settings_outlined),
          ],
        ),
      ),
    );

    testWidgets('the button clears the shell\'s navigation bar', (
      tester,
    ) async {
      await pump(tester, shell(onNew: () {}), bottomPadding: 34);
      // Three frames: lay the bar out, let the outer host publish its height,
      // let the inner host read it through and lift the button.
      await tester.pump();
      await tester.pump();

      final fab = tester.getRect(find.byType(DSFab));
      final nav = tester.getRect(find.byType(DSBottomNavBar));
      expect(
        fab.bottom,
        lessThanOrEqualTo(nav.top),
        reason: 'the button is drawn on the bar the shell owns',
      );
    });

    testWidgets('tapping the button reaches the button, not the tab under it', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, shell(onNew: () => taps++), bottomPadding: 34);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(DSFab, 'New login'));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('the snack bar', () {
    testWidgets('on a bare screen it rests one margin above the home '
        'indicator, not two', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: DSButton(
                label: 'Go',
                onPressed: () => showDSSnackBar(context, message: 'Saved'),
              ),
            ),
          ),
        ),
        bottomPadding: 34,
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      final snack = tester.getRect(find.byType(DSSnackBar));
      final screen = tester.getRect(find.byType(MaterialApp));
      final space = AppTheme.spec.space;

      expect(
        screen.bottom - snack.bottom,
        moreOrLessEquals(34 + space.md, epsilon: 0.5),
        reason:
            'the bar used to clear the home indicator twice — once from '
            'the insets and once from a SafeArea of its own — which parked it '
            'a finger up the screen',
      );

      hideDSSnackBar(tester.element(find.text('Go')));
      await tester.pumpAndSettle();
    });

    testWidgets('a second message replaces the first rather than stacking', (
      tester,
    ) async {
      await pump(
        tester,
        DSBottomInsetsHost(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSButton(
                      label: 'First',
                      onPressed: () =>
                          showDSSnackBar(context, message: 'Draft saved'),
                    ),
                    DSButton(
                      label: 'Second',
                      onPressed: () =>
                          showDSSnackBar(context, message: 'Draft published'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.byType(DSSnackBar), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.byType(DSSnackBar), findsOneWidget);
      expect(find.text('Draft published'), findsOneWidget);
      expect(find.text('Draft saved'), findsNothing);

      hideDSSnackBar(tester.element(find.text('First')));
      await tester.pumpAndSettle();
    });

    testWidgets('it does not take focus from what the user was doing', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);

      await pump(
        tester,
        DSBottomInsetsHost(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(focusNode: node),
                    DSButton(
                      label: 'Announce',
                      onPressed: () => showDSSnackBar(
                        context,
                        message: 'Saved',
                        actionLabel: 'Undo',
                        onAction: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      node.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Announce'));
      await tester.pumpAndSettle();

      expect(find.byType(DSSnackBar), findsOneWidget);
      expect(
        node.hasFocus,
        isTrue,
        reason: 'a transient message that moves focus interrupts the user',
      );

      hideDSSnackBar(tester.element(find.text('Announce')));
      await tester.pumpAndSettle();
    });

    testWidgets('its timer waits while a screen reader is on', (tester) async {
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        DSBottomInsetsHost(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: DSButton(
                  label: 'Announce',
                  onPressed: () => showDSSnackBar(
                    context,
                    message: 'Saved',
                    duration: const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Announce'));
      await tester.pumpAndSettle();
      // Well past the duration it was given: a message read aloud takes
      // longer than a message read, so the timer never started.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DSSnackBar), findsOneWidget);

      hideDSSnackBar(tester.element(find.text('Announce')));
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('every tone reports in a pair the identity derived', (
      tester,
    ) async {
      await pump(tester, const Scaffold(body: SizedBox.shrink()));
      final context = tester.element(find.byType(Scaffold));

      for (final tone in DSTone.values) {
        final (fill, foreground) = DSSnackBarStyle.toneColors(context, tone);
        expect(
          _contrast(fill, foreground),
          greaterThanOrEqualTo(4.5),
          reason: '$tone: a message nobody can read is not a message',
        );
      }
    });
  });

  group('the floating action button', () {
    testWidgets('a label-less button with no name refuses to build', (
      tester,
    ) async {
      expect(
        () => DSFab(icon: Icons.add, onPressed: () {}),
        throwsAssertionError,
      );
    });

    testWidgets('an extended button collapses while the content scrolls and '
        'keeps its whole name', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        DSBottomInsetsHost(
          child: Scaffold(
            body: ListView.builder(
              itemCount: 40,
              itemBuilder: (_, i) => DSListTile(title: 'Row ${i + 1}'),
            ),
            floatingActionButton: DSFab(
              icon: Icons.edit_outlined,
              label: 'Compose',
              onPressed: () {},
            ),
          ),
        ),
      );

      final wide = tester.getSize(find.byType(DSFab)).width;
      expect(find.text('Compose'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(DSFab)).width,
        lessThan(wide),
        reason: 'it collapses to its glyph while the content moves forward',
      );
      expect(
        find.bySemanticsLabel('Compose'),
        findsOneWidget,
        reason: 'a collapsed button is still the same button',
      );

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DSFab)).width, wide);
      handle.dispose();
    });
  });

  group('the pinned action bar', () {
    testWidgets('loading disables every button in it', (tester) async {
      var pressed = 0;
      await pump(
        tester,
        Scaffold(
          bottomNavigationBar: DSPinnedActionBar(
            loading: true,
            layout: DSActionBarLayout.spread,
            children: [
              DSButton(
                label: 'Cancel',
                variant: DSButtonVariant.ghost,
                onPressed: () => pressed++,
              ),
              DSButton(
                label: 'Publish',
                loading: true,
                onPressed: () => pressed++,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(
        pressed,
        0,
        reason: 'a live Cancel beside a dead Publish is a bar read twice',
      );
    });

    testWidgets('it lays its own buttons out, in four arrangements', (
      tester,
    ) async {
      for (final layout in DSActionBarLayout.values) {
        await pump(
          tester,
          Scaffold(
            bottomNavigationBar: DSPinnedActionBar(
              layout: layout,
              leading: const Text('£42.00'),
              helperText: 'You can edit this later.',
              children: [
                DSButton(label: 'Cancel', onPressed: () {}),
                if (layout != DSActionBarLayout.leadingAndAction)
                  DSButton(label: 'Publish', onPressed: () {}),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$layout');
        expect(find.text('You can edit this later.'), findsOneWidget);
      }
    });
  });

  group('the style objects', () {
    test('each interpolates rather than snapping', () {
      const a = DSSnackBarStyle(maxWidth: 400, iconSize: 16);
      const b = DSSnackBarStyle(maxWidth: 600, iconSize: 24);
      expect(a.lerp(b, 0.5).maxWidth, 500);
      expect(a.lerp(b, 0.5).iconSize, 20);

      const fabA = DSFabStyle(size: 40, margin: 8);
      const fabB = DSFabStyle(size: 56, margin: 24);
      expect(fabA.lerp(fabB, 0.5).size, 48);
      expect(fabA.lerp(fabB, 0.5).margin, 16);

      const barA = DSActionBarStyle(gap: 8);
      const barB = DSActionBarStyle(gap: 16);
      expect(barA.lerp(barB, 0.5).gap, 12);

      // And a merge takes only what the layer above set.
      expect(
        const DSFabStyle(size: 40).merge(const DSFabStyle(margin: 4)).size,
        40,
      );
    });
  });
}

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
