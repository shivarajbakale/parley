import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A closed four-field model became six item widgets.
///
/// `DSPopupMenuItem` could describe a value, a label, a glyph and
/// `isDestructive`, and nothing else: no separator, no section, no checkable
/// item, no shortcut, no disabled item with a reason — every one of which is
/// a normal menu. It also drew its own depth, `elevation: 3`, beside a select
/// on the kit's two-layer ramp: two popovers, two depths, on one screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMenu(
    WidgetTester tester,
    Widget menu, {
    Size size = const Size(800, 900),
    Alignment alignment = Alignment.topLeft,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Align(alignment: alignment, child: menu),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> back() async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            const MethodCall('popRoute'),
          ),
          (_) {},
        );
  }

  testWidgets('a destructive item above the last separator asserts', (
    tester,
  ) async {
    // A destructive item is placed as well as coloured: last, below a
    // separator. Leaving that to the caller produces menus that disagree.
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [
          DSMenuItem(label: 'Delete', tone: DSTone.error, onPressed: () {}),
          const DSMenuSeparator(),
          DSMenuItem(label: 'Rename', onPressed: () {}),
        ],
      ),
    );
    await tester.tap(find.byType(DSMenu));
    await tester.pump();
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('a check item toggles and the menu stays open', (tester) async {
    // The point of it: turning on three view options should not mean opening
    // the menu three times.
    var hidden = false;
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: StatefulBuilder(
                builder: (context, setState) => DSMenu(
                  semanticLabel: 'View options',
                  items: [
                    DSMenuCheckItem(
                      label: 'Show hidden files',
                      value: hidden,
                      onChanged: (value) => setState(() => hidden = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show hidden files'));
    await tester.pumpAndSettle();

    expect(hidden, isTrue);
    expect(
      find.text('Show hidden files'),
      findsOneWidget,
      reason: 'a check item does not close the menu',
    );
    await back();
    await tester.pumpAndSettle();
  });

  testWidgets('a disabled item is focusable, inert, and says why', (
    tester,
  ) async {
    // A disabled control focus skips cannot be discovered by a screen reader
    // user at all, and one with no reason is one the user taps again.
    final handle = tester.ensureSemantics();
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [
          DSMenuItem(label: 'Rename', onPressed: () {}),
          const DSMenuItem(
            label: 'Move',
            disabledReason: 'Not available offline',
          ),
        ],
      ),
    );
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();

    expect(find.text('Not available offline'), findsOneWidget);

    final data = tester
        .getSemantics(find.widgetWithText(DSMenuItem, 'Move'))
        .getSemanticsData();
    expect(data.label, contains('Not available offline'));
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);

    handle.dispose();
  });

  testWidgets('the surface is a menu and the rows carry menu roles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [
          const DSMenuSection(label: 'View'),
          DSMenuCheckItem(
            label: 'Show hidden files',
            value: true,
            onChanged: (_) {},
          ),
          DSMenuRadioItem<String>(
            label: 'Most recent',
            value: 'recent',
            groupValue: 'recent',
            onChanged: (_) {},
          ),
          DSMenuItem(label: 'Rename', onPressed: () {}),
        ],
      ),
    );
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();

    final roles = <SemanticsRole>{};
    void walk(SemanticsNode node) {
      roles.add(node.getSemanticsData().role);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(_rootSemantics(tester));

    expect(roles, contains(SemanticsRole.menu));
    expect(roles, contains(SemanticsRole.menuItem));
    expect(roles, contains(SemanticsRole.menuItemCheckbox));
    expect(roles, contains(SemanticsRole.menuItemRadio));

    handle.dispose();
  });

  testWidgets('the trigger reports whether the menu is open', (tester) async {
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [DSMenuItem(label: 'Rename', onPressed: () {})],
      ),
    );

    Semantics declaration() => tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(DSMenu),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((s) => s.properties.expanded != null);

    expect(declaration().properties.expanded, isFalse);
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();
    expect(declaration().properties.expanded, isTrue);
  });

  testWidgets('the item flashes before the menu goes', (tester) async {
    // A menu that vanishes on touch-down leaves the action unconfirmed.
    var pressed = false;
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [DSMenuItem(label: 'Rename', onPressed: () => pressed = true)],
      ),
    );
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rename'));
    await tester.pump();

    expect(
      find.text('Rename'),
      findsOneWidget,
      reason: 'the row is still on screen for at least one frame',
    );
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('the menu flips above a trigger at the bottom edge', (
    tester,
  ) async {
    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [
          for (var i = 0; i < 6; i++)
            DSMenuItem(label: 'Action $i', onPressed: () {}),
        ],
      ),
      alignment: Alignment.bottomLeft,
    );
    final trigger = tester.getRect(find.byType(DSMenu));
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();

    final menu = tester.getRect(find.byType(DSMenuSurface));
    expect(menu.bottom, lessThanOrEqualTo(trigger.top + 0.5));
  });

  testWidgets('a menu and a select float at the same depth', (tester) async {
    // The regression this plan exists to fix: `elevation: 3` beside
    // `AppShadows.resolve(high)` — two popovers, two depths, side by side.
    List<BoxShadow> shadowsOf(Finder finder) => tester
        .widgetList<DecoratedBox>(
          find.descendant(of: finder, matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .firstWhere((d) => d.shadows != null && d.shadows!.isNotEmpty)
        .shadows!;

    await pumpMenu(
      tester,
      DSMenu(
        semanticLabel: 'Actions',
        items: [DSMenuItem(label: 'Rename', onPressed: () {})],
      ),
    );
    await tester.tap(find.byType(DSMenu));
    await tester.pumpAndSettle();
    final menuShadows = shadowsOf(find.byType(DSOverlaySurface));
    await back();
    await tester.pumpAndSettle();

    await pumpMenu(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: const [
          DSSelectOption<String>(value: 'Documents', label: 'Documents'),
        ],
        value: 'Documents',
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();
    final selectShadows = shadowsOf(find.byType(DSOverlaySurface));

    expect(menuShadows.length, 2, reason: 'two layers, always');
    expect(menuShadows, selectShadows);
  });

  testWidgets('DSSubmenu is declared and refuses to be used', (tester) async {
    // Declared so the API does not have to change when it lands, deferred so
    // its hover intent, flip logic and focus model are designed rather than
    // improvised.
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: const MaterialApp(
          home: Scaffold(
            body: DSSubmenu(label: 'Share with', items: []),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  test('the style object merges, lerps and never defaults a field', () {
    const empty = DSMenuStyle();
    expect(empty.minWidth, isNull, reason: 'defaults live in resolve');

    const a = DSMenuStyle(minWidth: 200, showIcons: false);
    const b = DSMenuStyle(minWidth: 240);
    expect(a.merge(b).minWidth, 240);
    expect(a.merge(b).showIcons, isFalse);
    expect(a.lerp(b, 0.5).minWidth, 220);
  });
}

/// The root of the rendered semantics tree.
///
/// `tester.binding.pipelineOwner` is deprecated; the tree is rooted at
/// `rootPipelineOwner` and the node lives on one of its children.
SemanticsNode _rootSemantics(WidgetTester tester) {
  SemanticsNode? found;
  void visit(PipelineOwner owner) {
    found ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  return found!;
}
