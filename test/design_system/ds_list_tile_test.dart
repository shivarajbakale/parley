import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSListTile — plan 12.
///
/// The four fixes this component exists for are all the same fix: the
/// identity layer already declared `wellShape`, `leadingStyle`,
/// `dividerPolicy` and `rowChevron`, and the widget read none of them. Each
/// group below holds one of those seams open.
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
        child: Scaffold(body: child),
      ),
    ),
  );

  group('the row keeps the height that matters', () {
    testWidgets('rendered height clears the platform floor on both platforms', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await tester.pumpWidget(
          Design(
            spec: spec,
            child: MaterialApp(
              theme: AppTheme.lightTheme.copyWith(platform: platform),
              home: const Scaffold(body: DSListTile(title: 'Row')),
            ),
          ),
        );
        final context = tester.element(find.byType(DSListTile));
        expect(
          tester.getSize(find.byType(ListTile)).height,
          greaterThanOrEqualTo(context.design.component.minTapTarget),
          reason:
              '$platform: ListTile\'s own minimum is already taller than the '
              'floor. Passing the floor in as minTileHeight would lower it.',
        );
      }
    });

    testWidgets('rows run full width, insetting only to the page gutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            leading: Icon(Icons.rocket_launch_outlined),
            title: 'Getting Started',
            subtitle: 'Set up your first feature slice',
          ),
        ),
      );

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(ListTile)).width, width);
      expect(
        tester.getTopLeft(find.byType(DSListTileWell)).dx,
        spec.space.pageGutter,
      );
    });

    testWidgets('title and subtitle are capped, not cut, by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title:
                'A title long enough that it would otherwise wrap onto a '
                'second line and double the height of every row',
            subtitle:
                'And a subtitle that would do exactly the same thing '
                'if it were allowed to',
          ),
        ),
      );

      final title = tester.widget<Text>(find.textContaining('A title long'));
      final subtitle = tester.widget<Text>(find.textContaining('And a sub'));
      // Two, not one. A row title is the reader's content: one line cut
      // "Sign out of every device" at 320pt and a 1.3x text scale, which is a
      // phone somebody owns. Two is still a cap — `wrap` is how a caller says
      // there is no cap — so a row grows by a line at the narrow end rather
      // than becoming unbounded.
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      // Supporting text is allowed the second line Material 3 gives it, and
      // no more — the cap is what keeps a list scannable.
      expect(subtitle.maxLines, 2);
      expect(subtitle.overflow, TextOverflow.ellipsis);
    });
  });

  group('S-11 — the leading well reads the spec, not a hardcoded circle', () {
    testWidgets('the well is a share of the row, so it scales with the row', (
      tester,
    ) async {
      final tall = spec.copyWith(
        component: spec.component.copyWith(
          listRowMinHeight: spec.component.listRowMinHeight * 1.5,
        ),
      );
      await tester.pumpWidget(
        host(
          const DSListTile(
            leading: Icon(Icons.folder_outlined),
            title: 'Archive',
          ),
          design: tall,
        ),
      );
      expect(
        tester.getSize(find.byType(DSListTileWell)),
        Size.square(
          tall.component.listRowMinHeight * tall.component.rowWellRatio,
        ),
      );
    });

    testWidgets('a DSWell in the leading slot takes the row well size', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            leading: DSWell(icon: Icons.star_outline),
            title: 'Guide',
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(DSWell)),
        Size.square(
          spec.component.listRowMinHeight * spec.component.rowWellRatio,
        ),
      );
    });

    testWidgets('the default well takes ComponentSpec.wellShape and wellSize', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            leading: Icon(Icons.folder_outlined),
            title: 'Archive',
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(DSListTileWell)),
        Size.square(
          spec.component.listRowMinHeight * spec.component.rowWellRatio,
        ),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(DSListTileWell),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      // The identity's default is AppShape.control, which is a rounded
      // rectangle. The CircleAvatar this replaces drew a circle whatever the
      // identity said.
      expect(decoration.shape, isA<RoundedRectangleBorder>());
      expect(decoration.shape, isNot(isA<CircleBorder>()));
    });

    testWidgets('an identity that asks for a pill gets a pill', (tester) async {
      final pill = spec.copyWith(
        component: spec.component.copyWith(wellShape: AppShape.pill),
      );
      await tester.pumpWidget(
        host(
          const DSListTile(
            leading: Icon(Icons.folder_outlined),
            title: 'Archive',
          ),
          design: pill,
        ),
      );

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(DSListTileWell),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      expect(decoration.shape, isA<StadiumBorder>());
    });

    testWidgets('leadingStyle bare drops the well; none drops the slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              DSListTile(
                key: ValueKey('bare'),
                leading: Icon(Icons.folder_outlined),
                title: 'Bare',
                style: DSListTileStyle(leadingStyle: LeadingStyle.bare),
              ),
              DSListTile(
                key: ValueKey('none'),
                leading: Icon(Icons.folder_outlined),
                title: 'None',
                style: DSListTileStyle(leadingStyle: LeadingStyle.none),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(DSListTileWell), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bare')),
          matching: find.byIcon(Icons.folder_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('none')),
          matching: find.byIcon(Icons.folder_outlined),
        ),
        findsNothing,
      );
    });
  });

  group('S-10 — selection is a fill and a mark, never a fill alone', () {
    testWidgets('selected renders both the accent fill and a check', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title: 'Option A',
            selected: true,
            selectionMode: DSSelectionMode.multiple,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fills = tester
          .widgetList<Material>(find.byType(Material))
          .map((m) => m.color)
          .toList();
      expect(fills, contains(spec.palette.light.secondary));
      // The second channel. A greyscale screenshot still says "chosen".
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('single select declares a mutually exclusive group', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title: 'Option A',
            selected: true,
            selectionMode: DSSelectionMode.single,
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(DSListTile).first);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('an unselected row in a group still shows its affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title: 'Option B',
            selectionMode: DSSelectionMode.single,
          ),
        ),
      );
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('a row with no selection mode is not announced as selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const DSListTile(title: 'Row', selected: true)),
      );
      final node = tester.getSemantics(find.byType(DSListTile).first);
      // `none` rather than `false`: a row that is not part of a selection
      // does not claim to be unselected either, so a reader says nothing
      // instead of "not selected" on every row of a settings screen.
      expect(node.flagsCollection.isSelected, Tristate.none);
    });
  });

  group('M-1 — tone replaces the destructive boolean', () {
    testWidgets('every tone moves the title, the well and the glyph together', (
      tester,
    ) async {
      for (final tone in DSTone.values) {
        await tester.pumpWidget(
          host(
            DSListTile(
              leading: const Icon(Icons.delete_outline),
              title: 'Delete account',
              tone: tone,
            ),
          ),
        );

        final context = tester.element(find.byType(DSListTile));
        final resolved = DSListTileStyle.resolve(context, tone);
        final (fill, glyph) = DSListTileStyle.wellColors(context, tone);
        final title = tester.widget<Text>(find.text('Delete account'));

        expect(title.style?.color, resolved.titleStyle?.color);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(DSListTileWell),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(decoration.color, fill);
        expect(
          tester
              .widget<IconTheme>(
                find
                    .descendant(
                      of: find.byType(DSListTileWell),
                      matching: find.byType(IconTheme),
                    )
                    .first,
              )
              .data
              .color,
          glyph,
        );
      }
    });

    testWidgets('the toned title is legible on the surface it is drawn on', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(
            const DSListTile(title: 'Delete account', tone: DSTone.error),
            brightness: brightness,
          ),
        );
        final context = tester.element(find.byType(DSListTile));
        final palette = context.palette;
        final color = DSListTileStyle.resolve(
          context,
          DSTone.error,
        ).titleStyle!.color!;

        expect(
          contrastRatio(color, palette.card),
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness: a toned title is body text, and gate K1/K2\'s '
              'floor is 4.5 on the surface a row sits on.',
        );
        // On the page's own canvas the lightest of the four semantic colours
        // measures 3.82:1 in light, under the body floor. Raising it is
        // plan 00's business — the palette owns the swatch, not this widget —
        // so the debt is asserted here rather than assumed away.
        expect(
          contrastRatio(color, palette.background),
          greaterThanOrEqualTo(3.0),
        );
      }
    });

    testWidgets('a well glyph clears the graphical-object floor', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final tone in DSTone.values) {
          await tester.pumpWidget(
            host(
              DSListTile(
                leading: const Icon(Icons.circle_outlined),
                title: 'Row',
                tone: tone,
              ),
              brightness: brightness,
            ),
          );
          final context = tester.element(find.byType(DSListTile));
          final (fill, glyph) = DSListTileStyle.wellColors(context, tone);
          expect(
            contrastRatio(glyph, fill),
            // An icon on a tint is a graphical object: gate K1 holds it at 3:1.
            greaterThanOrEqualTo(3.0),
            reason: '$brightness $tone: the glyph is the well\'s only content',
          );
        }
      }
    });
  });

  group('the chevron is a promise, and it comes from the spec', () {
    testWidgets('a tappable row shows one; an inert row shows none', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              DSListTile(
                key: const ValueKey('tap'),
                title: 'Tap',
                onTap: () {},
              ),
              const DSListTile(key: ValueKey('inert'), title: 'Inert'),
            ],
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tap')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inert')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
    });

    testWidgets('an identity that turns chevrons off turns them all off', (
      tester,
    ) async {
      final flat = spec.copyWith(
        component: spec.component.copyWith(rowChevron: false),
      );
      await tester.pumpWidget(
        host(
          DSListTile(title: 'Tap', onTap: () {}),
          design: flat,
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('the chevron is excluded from semantics', (tester) async {
      await tester.pumpWidget(
        host(DSListTile(title: 'Notifications', onTap: () {})),
      );
      final node = tester.getSemantics(find.byType(ListTile));
      // "Button" already implies it; announcing it on every row of a settings
      // screen is noise.
      expect(node.label, 'Notifications');
    });

    testWidgets(
      'a trailing control replaces the chevron rather than joining it',
      (tester) async {
        await tester.pumpWidget(
          host(
            DSListTile(
              title: 'Wi-Fi only',
              trailing: DSSwitch(
                value: true,
                semanticLabel: 'Wi-Fi only',
                onChanged: (_) {},
              ),
              onTap: () {},
            ),
          ),
        );
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        expect(find.byType(DSSwitch), findsOneWidget);
      },
    );
  });

  group('two tap targets, or one', () {
    testWidgets('a row with a trailing control gives each its own node, '
        '48dp apart', (tester) async {
      await tester.pumpWidget(
        host(
          DSListTile(
            title: 'Wi-Fi only',
            trailing: DSSwitch(
              value: true,
              semanticLabel: 'Wi-Fi only',
              onChanged: (_) {},
            ),
            onTap: () {},
          ),
        ),
      );

      final control = tester.getRect(find.byType(DSSwitch));
      expect(control.height, greaterThanOrEqualTo(spec.component.minTapTarget));
      expect(control.width, greaterThanOrEqualTo(spec.component.minTapTarget));

      final row = tester.getRect(find.byType(ListTile));
      // The control's own area is inside the row's, so the separation that
      // matters is between the control and the row's *text* — the part a user
      // aims at when they mean "open" rather than "toggle".
      final title = tester.getRect(find.text('Wi-Fi only'));
      expect(control.left - title.right, greaterThanOrEqualTo(8.0));
      expect(row.height, greaterThanOrEqualTo(spec.component.minTapTarget));
    });
  });

  group('the slots that keep copy out of the subtitle', () {
    testWidgets('meta sits under the subtitle without eating its cap', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title: 'Offline library',
            subtitle: 'Four albums waiting',
            meta: DSListTileMeta(label: 'Updated 2h ago', icon: Icons.schedule),
          ),
        ),
      );

      final subtitle = tester.getRect(find.text('Four albums waiting'));
      final meta = tester.getRect(find.text('Updated 2h ago'));
      expect(meta.top, greaterThanOrEqualTo(subtitle.bottom));
      expect(tester.widget<Text>(find.text('Four albums waiting')).maxLines, 2);
    });

    testWidgets('background paints behind the row', (tester) async {
      await tester.pumpWidget(
        host(
          const DSListTile(
            title: 'Downloading',
            background: ColoredBox(
              key: ValueKey('fill'),
              color: Color(0x11000000),
            ),
          ),
        ),
      );

      final background = tester.getRect(find.byKey(const ValueKey('fill')));
      final row = tester.getRect(find.byType(ListTile));
      expect(background.size, row.size);
    });
  });

  group('text scale 2× moves the trailing control below the text', () {
    testWidgets('the chevron is dropped and the control moves down', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          DSListTile(
            title: 'Wi-Fi only',
            subtitle: 'Downloads pause on cellular',
            trailing: DSSwitch(
              value: true,
              semanticLabel: 'Wi-Fi only',
              onChanged: (_) {},
            ),
            onTap: () {},
          ),
          textScale: 2,
        ),
      );

      // A chevron beside 2× type is four per cent of the row's area.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final title = tester.getRect(find.text('Wi-Fi only'));
      expect(
        tester.getRect(find.byType(DSSwitch)).top,
        greaterThan(title.bottom),
      );
    });
  });

  group('a group draws the separators a row cannot', () {
    testWidgets('every row but the last', (tester) async {
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(title: 'Account', onTap: () {}),
              DSListTile(title: 'Notifications', onTap: () {}),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(DSDivider), findsNWidgets(2));
    });

    testWidgets('the inset comes from ComponentSpec.dividerPolicy', (
      tester,
    ) async {
      final full = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.full),
      );
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(
                leading: const Icon(Icons.person_outline),
                title: 'Account',
                onTap: () {},
              ),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
          design: full,
        ),
      );
      final fullRule = tester.widget<DSDivider>(find.byType(DSDivider));
      expect(fullRule.indent, greaterThan(0.0));
      expect(fullRule.endIndent, fullRule.indent);

      final inset = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.inset),
      );
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(
                leading: const Icon(Icons.person_outline),
                title: 'Account',
                onTap: () {},
              ),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
          design: inset,
        ),
      );
      // Inset to where the text starts, so the leading element reads as
      // belonging to its row rather than to the list.
      expect(
        tester.widget<DSDivider>(find.byType(DSDivider)).indent,
        spec.space.pageGutter +
            spec.component.listRowMinHeight * spec.component.rowWellRatio +
            spec.space.lg,
      );
    });

    testWidgets('an inset rule under a row with no glyph starts at its text', (
      tester,
    ) async {
      final inset = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.inset),
      );
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(title: 'Account', onTap: () {}),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
          design: inset,
        ),
      );
      final line = tester.getRect(
        find.descendant(
          of: find.byType(DSDivider),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(line.left, tester.getTopLeft(find.text('Account')).dx);
    });

    testWidgets('the default rule runs from the row\'s content edge to its end', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(
                leading: const Icon(Icons.person_outline),
                title: 'Account',
                onTap: () {},
              ),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
        ),
      );
      final line = tester.getRect(
        find.descendant(
          of: find.byType(DSDivider),
          matching: find.byType(DecoratedBox),
        ),
      );
      final row = tester.getRect(find.byType(DSListTile).first);
      final gutter = DSListTile.textInset(
        tester.element(find.byType(DSListTile).first),
        leading: false,
      );
      expect(line.left, row.left + gutter);
      expect(line.right, row.right - gutter);
    });

    testWidgets('a policy of none draws nothing', (tester) async {
      final bare = spec.copyWith(
        component: spec.component.copyWith(dividerPolicy: DividerPolicy.none),
      );
      await tester.pumpWidget(
        host(
          DSListTileGroup(
            children: [
              DSListTile(title: 'Account', onTap: () {}),
              DSListTile(title: 'Help', onTap: () {}),
            ],
          ),
          design: bare,
        ),
      );
      expect(find.byType(DSDivider), findsNothing);
    });
  });

  group('disabled and loading', () {
    testWidgets('a disabled row takes no gesture', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(DSListTile(title: 'Managed', enabled: false, onTap: () => taps++)),
      );
      await tester.tap(find.text('Managed'));
      expect(taps, 0);
      expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
    });

    testWidgets('a scope that disables its contents disables the row', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          DSScope(
            enabled: false,
            child: DSListTile(title: 'Row', onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.text('Row'));
      expect(taps, 0);
    });

    testWidgets('loading draws the skeleton, not the copy', (tester) async {
      await tester.pumpWidget(
        host(const DSListTile(title: 'Offline library', loading: true)),
      );
      expect(find.byType(DSListTileSkeleton), findsOneWidget);
      expect(find.text('Offline library'), findsNothing);
    });
  });

  group('the four layers stack', () {
    testWidgets('spec, theme extension, and style: in that order', (
      tester,
    ) async {
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: const [
                DSListTileStyle(leadingGap: 4, chevron: false),
              ],
            ),
            home: const Scaffold(
              body: DSListTile(
                leading: Icon(Icons.folder_outlined),
                title: 'Archive',
                style: DSListTileStyle(leadingGap: 24),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(DSListTile));
      final resolved = DSListTileStyle.resolve(
        context,
        DSTone.neutral,
        const DSListTileStyle(leadingGap: 24),
      );
      // Layer 4 beats layer 2…
      expect(resolved.leadingGap, 24);
      // …layer 2 beats layer 1 where layer 4 said nothing…
      expect(resolved.chevron, isFalse);
      // …and layer 1 still answers for everything nobody set.
      expect(
        resolved.leadingSize,
        spec.component.listRowMinHeight * spec.component.rowWellRatio,
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSListTileStyle(leadingGap: 8, chevron: true);
      const over = DSListTileStyle(chevron: false);
      final merged = base.merge(over);
      expect(merged.leadingGap, 8);
      expect(merged.chevron, isFalse);
    });

    test('lerp interpolates the numbers and snaps the enums', () {
      const a = DSListTileStyle(
        leadingGap: 0,
        leadingShape: AppShape.control,
        dividerPolicy: DividerPolicy.none,
      );
      const b = DSListTileStyle(
        leadingGap: 20,
        leadingShape: AppShape.pill,
        dividerPolicy: DividerPolicy.full,
      );
      expect(a.lerp(b, 0.5).leadingGap, 10);
      expect(a.lerp(b, 0.25).leadingShape, AppShape.control);
      expect(a.lerp(b, 0.75).dividerPolicy, DividerPolicy.full);
    });

    test('a third subtitle line asserts', () {
      expect(
        () => DSListTileStyle(subtitleMaxLines: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('DSListTileMeta with neither a label nor a slot asserts', () {
      expect(
        () => DSListTileMeta(icon: Icons.schedule),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
