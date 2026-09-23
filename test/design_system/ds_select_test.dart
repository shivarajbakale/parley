import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The least composable component in the kit, and the only surface that was
/// not on the navigator.
///
/// Four of the claims here are WCAG criteria the old component failed
/// outright: it could not be reached by `Tab`, opened by `Space`, navigated by
/// arrows or closed by `Escape`, it published no role, and the Android back
/// button did not close it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const folders = ['Documents', 'Downloads', 'Germany', 'Music'];

  List<Widget> options() => [
    for (final folder in folders)
      DSSelectOption<String>(value: folder, label: folder),
  ];

  Future<void> pumpSelect(
    WidgetTester tester,
    Widget select, {
    Size size = const Size(390, 844),
    double textScale = 1,
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: Center(child: select)),
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

  testWidgets('two-line options are separated, and the header is not far', (
    tester,
  ) async {
    // The reported screenshot: six two-line zones running together with no
    // line between them, under a title sitting a long way above the first
    // one. Measured, the rows were flush — one row's subtitle ended on the
    // exact pixel the next row's label began — while the header stood 32
    // points off. The rhythm was inverted: all the air was in the one place
    // that did not need it.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Zone',
        value: 'Quiet west',
        options: const [
          DSSelectOption<String>(
            value: 'Quiet west',
            label: 'Quiet west',
            subtitle: 'No calls. 14 desks.',
          ),
          DSSelectOption<String>(
            value: 'Focus pods',
            label: 'Focus pods',
            subtitle: 'One person, door shut.',
          ),
          DSSelectOption<String>(
            value: 'Team north',
            label: 'Team north',
            subtitle: 'Talk freely. 20 desks.',
          ),
        ],
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    expect(
      find.byType(DSSelectSeparator),
      findsNWidgets(2),
      reason:
          'between every pair of options and nowhere else — a line under the '
          'last row draws a floor the list does not have',
    );

    final firstSubtitle = tester.getRect(find.text('No calls. 14 desks.'));
    final secondLabel = tester.getRect(find.text('Focus pods'));
    final gapBetweenRows = secondLabel.top - firstSubtitle.bottom;
    expect(
      gapBetweenRows,
      greaterThan(0),
      reason:
          'a two-line row whose subtitle touches the next row\'s label reads '
          'as one block of six lines, not as three options',
    );

    final title = tester.getRect(find.text('Zone').last);
    final firstLabel = tester.getRect(find.text('Quiet west').last);
    expect(
      firstLabel.top - title.bottom,
      lessThan(gapBetweenRows * 2),
      reason:
          'the title may stand off from its list, but not by more than twice '
          'what separates the rows inside it',
    );
  });

  testWidgets('the sheet header and the option rows share both edges', (
    tester,
  ) async {
    // The reported defect, measured on both axes. The header insets on
    // `space.lg` and the options used to inset on `space.md`, so the title
    // sat 4 points right of the folder icons; the × was a further 14 points
    // in because its 48-point tap target was laid flush against the padding
    // with a 20-point glyph centred inside it. 18 points out at the trailing
    // edge, on the one surface whose header and content are the same list.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        value: 'Documents',
        options: [
          for (final folder in folders)
            DSSelectOption<String>(
              value: folder,
              label: folder,
              leading: const Icon(Icons.inbox_outlined),
            ),
        ],
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Folder').last);
    final close = tester.getRect(find.byIcon(Icons.close));
    final check = tester.getRect(find.byIcon(Icons.check));
    final leading = tester.getRect(find.byIcon(Icons.inbox_outlined).first);

    expect(
      close.right,
      check.right,
      reason: 'the × and the check are both trailing ink on the same column',
    );
    expect(
      title.left,
      leading.left,
      reason: 'and the title is leading ink on the same column as the icons',
    );
  });

  testWidgets('the back button closes the select, not the screen', (
    tester,
  ) async {
    // The single defect plan 17 exists for. It was an `OverlayEntry`, so
    // `Navigator.maybePop` never saw it: back exited the screen underneath
    // while the menu stayed painted.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: 'Documents',
        onChanged: (_) {},
      ),
    );

    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();
    expect(find.text('Downloads'), findsOneWidget);

    await back();
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsNothing);
    expect(
      find.byType(DSSelect<String>),
      findsOneWidget,
      reason: 'the screen underneath must still be there',
    );
  });

  testWidgets('the trigger is a combobox whose expanded state tracks it', (
    tester,
  ) async {
    // "Name, role, value", and the value half is whether the surface is open.
    // None of this existed: the trigger was a GestureDetector.
    final handle = tester.ensureSemantics();
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: 'Documents',
        onChanged: (_) {},
      ),
    );

    SemanticsData? namedTrigger() {
      SemanticsData? hit;
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label == 'Folder' && data.hasAction(SemanticsAction.tap)) {
          hit = data;
        }
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(_rootSemantics(tester));
      return hit;
    }

    expect(namedTrigger(), isNotNull, reason: 'the trigger has a name');
    expect(namedTrigger()!.flagsCollection.isExpanded, Tristate.isFalse);

    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    // Open, the surface's own barrier blocks the trigger's node, so the
    // claim is read off the declaration rather than off the tree.
    final declared = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(DSSelect<String>),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((s) => s.properties.expanded != null);
    expect(declared.properties.expanded, isTrue);

    handle.dispose();
  });

  testWidgets('space opens it, arrows move, enter commits, escape closes', (
    tester,
  ) async {
    String? chosen;
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: 'Documents',
        onChanged: (value) => chosen = value,
      ),
    );

    // Tab reaches it at all, which a GestureDetector never did.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Downloads'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen, 'Downloads');
    expect(find.text('Germany'), findsNothing, reason: 'it closed');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Germany'), findsNothing);
  });

  testWidgets('typing "ge" lands on Germany', (tester) async {
    // One buffered keystroke timer, and it was missing entirely: a user who
    // opens a country picker and types "ge" expects to land on Germany.
    String? chosen;
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: 'Documents',
        onChanged: (value) => chosen = value,
      ),
    );
    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    await simulateKeyDownEvent(LogicalKeyboardKey.keyG, character: 'g');
    await simulateKeyUpEvent(LogicalKeyboardKey.keyG);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyE, character: 'e');
    await simulateKeyUpEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen, 'Germany');
  });

  testWidgets('at 400 wide it is a sheet; at 800 it is anchored', (
    tester,
  ) async {
    for (final (Size size, bool asSheet) in <(Size, bool)>[
      (const Size(400, 800), true),
      (const Size(800, 900), false),
    ]) {
      await pumpSelect(
        tester,
        DSSelect<String>(
          label: 'Folder',
          options: options(),
          value: 'Documents',
          onChanged: (_) {},
        ),
        size: size,
      );
      await tester.tap(find.byType(DSSelect<String>));
      await tester.pumpAndSettle();

      expect(
        find.byType(DSBottomSheet),
        asSheet ? findsOneWidget : findsNothing,
        reason: 'at ${size.width} wide',
      );

      await back();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('as a sheet, scrolling the options does not dismiss it', (
    tester,
  ) async {
    // A select degrades to a `DSBottomSheet` on a narrow screen, so it
    // inherits whatever that sheet does with a vertical drag. flutter-046
    // found the sheet moving one-for-one with any downward finger regardless
    // of where the body's list was, which on a long select is a picker that
    // closes itself while the user is looking for a row. The select never
    // passes `snapPoints`, so it was never on the broken path — this test is
    // what keeps that true if a future caller adds them.
    await pumpSelect(
      tester,
      DSSelect<int>(
        label: 'Country',
        value: null,
        options: <DSSelectOption<int>>[
          for (var i = 0; i < 60; i++)
            DSSelectOption<int>(value: i, label: 'Option $i'),
        ],
        onChanged: (_) {},
      ),
      size: const Size(400, 844),
    );
    await tester.tap(find.byType(DSSelect<int>));
    await tester.pumpAndSettle();
    expect(find.byType(DSBottomSheet), findsOneWidget);

    await tester.drag(find.text('Option 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Option 8'), const Offset(0, 250));
    await tester.pumpAndSettle();

    expect(
      find.byType(DSBottomSheet),
      findsOneWidget,
      reason: 'scrolling the list must not have dismissed the picker',
    );
  });

  testWidgets('at text scale 2.0 the list scrolls rather than clipping a row', (
    tester,
  ) async {
    // The `_maxPopoverHeight = 240` regression: a fixed pixel ceiling cannot
    // know how tall a row grew, so it cut one in half.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: 'Documents',
        onChanged: (_) {},
        presentation: DSOverlayPresentation.menu,
        responsive: false,
      ),
      size: const Size(800, 900),
      textScale: 2,
    );
    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    final row = tester.getRect(find.text('Downloads'));
    expect(row.height, greaterThan(0));
  });

  group('the states the list can be in', () {
    testWidgets('no options at all says so', (tester) async {
      await pumpSelect(
        tester,
        DSSelect<String>(
          label: 'Folder',
          options: const [],
          value: null,
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(DSSelect<String>));
      await tester.pumpAndSettle();
      expect(find.text('No options available.'), findsOneWidget);
    });

    testWidgets('a search with no matches offers a way to clear it', (
      tester,
    ) async {
      // Different message, different action: "no options" and "no matches for
      // xyz" are not the same state.
      await pumpSelect(
        tester,
        DSSelect<String>(
          label: 'Folder',
          options: options(),
          value: null,
          showSearch: true,
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(DSSelect<String>));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(DSTextField).last, 'zzz');
      await tester.pumpAndSettle();

      expect(find.textContaining('No matches for'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Documents'), findsWidgets);
    });
  });

  testWidgets('a disabled option shows its reason and cannot be picked', (
    tester,
  ) async {
    var picked = 0;
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: const [
          DSSelectOption<String>(value: 'Documents', label: 'Documents'),
          DSSelectOption<String>(
            value: 'Archive',
            label: 'Archive',
            enabled: false,
            disabledReason: 'Not available offline',
          ),
        ],
        value: 'Documents',
        onChanged: (_) => picked++,
      ),
    );
    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    expect(find.text('Not available offline'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(picked, 0, reason: 'the option is disabled');
  });

  testWidgets('fromValues builds only the rows the list asks for', (
    tester,
  ) async {
    // The whole reason the generated form exists: a caller with two hundred
    // countries should not pay for two hundred widgets to open a menu.
    final values = List<String>.generate(200, (i) => 'Country $i');
    await pumpSelect(
      tester,
      DSSelect<String>.fromValues(
        label: 'Country',
        values: values,
        optionBuilder: (value) =>
            DSSelectOption<String>(value: value, label: value),
        value: values.first,
        onChanged: (_) {},
      ),
      size: const Size(800, 900),
    );
    await tester.tap(find.byType(DSSelect<String>));
    await tester.pumpAndSettle();

    expect(
      find.byType(DSSelectOption<String>).evaluate().length,
      lessThan(20),
      reason: '200 options must not mean 200 mounted rows',
    );
  });

  group('DSMultiSelect', () {
    testWidgets('it stays open, and the trigger summarises', (tester) async {
      var value = <String>{'Documents'};
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Center(
                  child: DSMultiSelect<String>(
                    label: 'Tags',
                    options: options(),
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(DSMultiSelect<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();

      expect(value, {'Documents', 'Downloads'});
      expect(
        find.text('Germany'),
        findsOneWidget,
        reason: 'a multi-select does not close on a selection',
      );

      await back();
      await tester.pumpAndSettle();
      expect(find.byType(DSChip), findsNWidgets(2));
    });

    testWidgets('at maxSelection the unselected rows disable', (tester) async {
      // Visible before it is hit, rather than a tap that silently does
      // nothing.
      var value = <String>{'Documents', 'Downloads'};
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Center(
                  child: DSMultiSelect<String>(
                    label: 'Tags',
                    options: options(),
                    value: value,
                    maxSelection: 2,
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(DSMultiSelect<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Germany'));
      await tester.pumpAndSettle();
      expect(value, {'Documents', 'Downloads'});

      final handle = tester.ensureSemantics();
      final data = tester
          .getSemantics(find.widgetWithText(DSSelectOption<String>, 'Germany'))
          .getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });
  });

  testWidgets('the trigger is the field skin, not a second one', (
    tester,
  ) async {
    // `DSSelect` used to build its own container, its own border colour and
    // its own focus width of 1.5. A select and a text field in one form were
    // two implementations of one control.
    await pumpSelect(
      tester,
      Column(
        children: [
          const DSTextField(label: 'Name'),
          DSSelect<String>(
            label: 'Folder',
            options: options(),
            value: 'Documents',
            onChanged: (_) {},
          ),
        ],
      ),
    );

    expect(find.byType(DSFieldBox), findsNWidgets(2));
    final boxes = tester.widgetList<DSFieldBox>(find.byType(DSFieldBox));
    expect(boxes.first.style.radius, boxes.last.style.radius);
    expect(boxes.first.style.height, boxes.last.style.height);
  });

  testWidgets('helper and error text reach the trigger', (tester) async {
    // So a select and a text field in one form show errors identically.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: null,
        errorText: 'Pick a folder',
        onChanged: (_) {},
      ),
    );
    expect(find.text('Pick a folder'), findsOneWidget);
  });

  testWidgets('a select over a fixed list may give the helper line back', (
    tester,
  ) async {
    // The same affordance as DSTextField.reserveHelper, for the same reason:
    // a select whose options are a fixed list can produce no message, and a
    // line reserved for one is a line of white on every field of the form.
    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: null,
        onChanged: (_) {},
      ),
    );
    final double reserved = tester
        .getSize(find.byType(DSSelect<String>))
        .height;

    await pumpSelect(
      tester,
      DSSelect<String>(
        label: 'Folder',
        options: options(),
        value: null,
        reserveHelper: false,
        onChanged: (_) {},
      ),
    );
    final double collapsed = tester
        .getSize(find.byType(DSSelect<String>))
        .height;

    expect(find.byType(DSFieldHelper), findsNothing);
    expect(collapsed, lessThan(reserved));
  });

  test('the search delegate folds case and accents', () {
    const search = DSSelectSubstringSearch();
    expect(
      search.matches(
        'zurich',
        const DSSelectOption<String>(value: 'z', label: 'Zürich'),
      ),
      isTrue,
    );
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
