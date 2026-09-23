@Tags(<String>['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/spec/shape_spec.dart';

import '_probe.dart';

/// Each rule, against a surface built to break it.
///
/// `ui_probe_test.dart` says the eight rules pass on the real corpus. On its
/// own that is the weaker half of the claim: a rule that can never fail passes
/// everything, and a gate made of rules like that is the reason
/// `docs/principles/premium.md` exists. So every rule here is handed the
/// defect it was written for and has to find it, and is handed a clean surface
/// and has to stay quiet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ProbeCell cell = ProbeCell(
    width: 320,
    textScale: 1.0,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
  );

  ProbeSurface surface(String name, Widget child, {Finder? subject}) =>
      ProbeSurface(
        name: name,
        build: () => Scaffold(body: child),
        subject: subject,
        subjectDescription: subject == null ? null : 'the fixture subject',
      );

  group('overflow', () {
    testWidgets('finds a row wider than its box', (WidgetTester tester) async {
      final ProbeSurface broken = surface(
        'fixture/overflow',
        const Row(
          children: <Widget>[
            SizedBox(width: 300, height: 20),
            SizedBox(width: 300, height: 20),
          ],
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleOverflow(tester, broken, cell);
      expect(found, hasLength(1));
      expect(found.single.detail, contains('overflowed by'));
    });

    testWidgets('says nothing about a row that fits', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/overflow-clean',
        const Row(children: <Widget>[SizedBox(width: 100, height: 20)]),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleOverflow(tester, fine, cell), isEmpty);
    });
  });

  group('short-measure', () {
    // `screen/` rather than `fixture/`: the rule is about a page's gutter, and
    // it only claims to know where that is on a surface that is a page.
    testWidgets('finds a band that stops short with nothing beside it', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'screen/short-measure',
        const DSGutter(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 180,
              child: DSCard(child: SizedBox(height: 60)),
            ),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleShortMeasure(tester, broken, cell);
      expect(found, hasLength(1));
      expect(found.single.detail, contains('short on the right'));
    });

    testWidgets('says nothing about a band that fills the page', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'screen/short-measure-clean',
        const DSGutter(child: DSCard(child: SizedBox(height: 60))),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleShortMeasure(tester, fine, cell), isEmpty);
    });

    testWidgets('says nothing about a deliberate pair', (
      WidgetTester tester,
    ) async {
      final ProbeSurface pair = surface(
        'screen/short-measure-pair',
        const DSGutter(
          child: Row(
            children: <Widget>[
              Expanded(child: DSCard(child: SizedBox(height: 60))),
              SizedBox(width: 12),
              Expanded(child: DSCard(child: SizedBox(height: 60))),
            ],
          ),
        ),
      );
      await mountProbe(tester, pair, cell);

      expect(ruleShortMeasure(tester, pair, cell), isEmpty);
    });
  });

  group('double-gutter', () {
    // A plain `Padding` rather than a `DSGutter`: the kit's own container says
    // it has applied the gutter, which is exactly what stops the row applying
    // a second one. This is the arrangement that shipped.
    testWidgets('finds a row inset inside a container that already inset it', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'screen/double-gutter',
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: DSListTile(title: 'Lock now'),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleDoubleGutter(tester, broken, cell);
      expect(found, hasLength(1));
      expect(found.single.detail, contains('a second'));
    });

    testWidgets('says nothing when the container announces its gutter', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'screen/double-gutter-clean',
        const DSGutter(child: DSListTile(title: 'Lock now')),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleDoubleGutter(tester, fine, cell), isEmpty);
    });

    testWidgets('says nothing about a row inside a card', (
      WidgetTester tester,
    ) async {
      final ProbeSurface carded = surface(
        'screen/double-gutter-card',
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: DSCard(child: DSListTile(title: 'Lock now')),
        ),
      );
      await mountProbe(tester, carded, cell);

      expect(ruleDoubleGutter(tester, carded, cell), isEmpty);
    });
  });

  group('overlap', () {
    // Two labels stacked on top of one another, with nothing between them.
    Widget collision() => const Stack(
      children: <Widget>[
        Positioned(left: 20, top: 40, child: Text('Getting Started')),
        Positioned(left: 20, top: 44, child: Text('Continue')),
      ],
    );

    testWidgets('finds two runs of text drawn through each other', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface('fixture/overlap', collision());
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleOverlap(tester, broken, cell);
      expect(found, hasLength(1));
      expect(found.single.detail, contains('painted over each other'));
    });

    testWidgets('says nothing about text behind a chrome surface', (
      WidgetTester tester,
    ) async {
      // The pinned bar over a scrolling page: the label on the bar sits over
      // the paragraph beneath it, and the paragraph is under an opaque tint
      // or a blur. A reader sees one of them. This is the kit's design, and a
      // rule that called it a defect could only be satisfied by deleting it.
      final ProbeSurface fine = surface(
        'fixture/overlap-chrome',
        const Stack(
          children: <Widget>[
            Positioned(left: 20, top: 40, child: Text('Getting Started')),
            Positioned(
              left: 0,
              right: 0,
              top: 30,
              child: AppChromeSurface(
                shape: AppShape.bar,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleOverlap(tester, fine, cell), isEmpty);
    });

    testWidgets('still finds two labels on the same chrome surface', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'fixture/overlap-on-chrome',
        AppChromeSurface(
          shape: AppShape.bar,
          child: SizedBox(height: 80, child: collision()),
        ),
      );
      await mountProbe(tester, broken, cell);

      expect(ruleOverlap(tester, broken, cell), hasLength(1));
    });
  });

  group('baseline', () {
    testWidgets('finds children on three different lines', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'fixture/baseline',
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The shape defect 1 took: two cells of different heights, their
            // tops lined up, and the labels inside them 24 points apart.
            SizedBox(
              width: 60,
              height: 48,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text('Paid', style: TextStyle(fontSize: 12)),
              ),
            ),
            SizedBox(
              width: 60,
              height: 24,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text('Due', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      );
      await mountProbe(tester, broken, cell);

      expect(ruleBaseline(tester, broken, cell), isNotEmpty);
    });

    testWidgets('says nothing about a centred row', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/baseline-clean',
        const Row(
          children: <Widget>[
            SizedBox(
              width: 60,
              height: 48,
              child: Center(
                child: Text('Paid', style: TextStyle(fontSize: 12)),
              ),
            ),
            SizedBox(
              width: 60,
              height: 24,
              child: Center(child: Text('Due', style: TextStyle(fontSize: 12))),
            ),
          ],
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleBaseline(tester, fine, cell), isEmpty);
    });
  });

  group('fold', () {
    const Key subjectKey = Key('subject');

    testWidgets('finds a subject pushed past the halfway line', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'fixture/fold',
        const Column(
          children: <Widget>[
            SizedBox(height: 600),
            SizedBox(key: subjectKey, height: 40),
          ],
        ),
        subject: find.byKey(subjectKey),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleFold(tester, broken, cell);
      expect(found, hasLength(1));
      expect(found.single.detail, contains('below the halfway line'));
    });

    testWidgets('finds a subject that is not there at all', (
      WidgetTester tester,
    ) async {
      // The failure a declaration invites: the finder stops matching, and a
      // rule that took silence for success would report the page as clean.
      final ProbeSurface broken = surface(
        'fixture/fold-missing',
        const SizedBox(height: 40),
        subject: find.byKey(subjectKey),
      );
      await mountProbe(tester, broken, cell);

      expect(
        ruleFold(tester, broken, cell).single.detail,
        contains('is not on the surface at all'),
      );
    });

    testWidgets('says nothing about a subject at the top', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/fold-clean',
        const SizedBox(key: subjectKey, height: 40),
        subject: find.byKey(subjectKey),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleFold(tester, fine, cell), isEmpty);
    });
  });

  group('nesting', () {
    testWidgets('finds a card inside a card', (WidgetTester tester) async {
      final ProbeSurface broken = surface(
        'fixture/nesting',
        const DSCard(child: DSCard(child: Text('Twice'))),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleNesting(tester, broken, cell);
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('elevation step'));
    });

    testWidgets('says nothing about one card', (WidgetTester tester) async {
      final ProbeSurface fine = surface(
        'fixture/nesting-clean',
        const DSCard(child: Text('Once')),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleNesting(tester, fine, cell), isEmpty);
    });
  });

  group('row-air', () {
    testWidgets('finds a row padded past what the spec asks for', (
      WidgetTester tester,
    ) async {
      // A row with room to spare, wrapped in the padding Material's default
      // used to add on top of the kit's. The content is one line, so
      // `listRowMinHeight` is what the row should be and the wrapper is the
      // height nothing asked for.
      final ProbeSurface broken = surface(
        'fixture/row-air',
        const DSListTile(title: 'A row with air around it'),
      );
      await mountProbe(tester, broken, cell);

      // The rule reads the rendered box, so the defect has to be rendered:
      // a `DSListTileStyle` with a vertical padding far past the floor is the
      // same shape of mistake, arriving from the style layer instead of from
      // Material.
      final ProbeSurface padded = surface(
        'fixture/row-air-padded',
        const DSListTile(
          title: 'A row with air around it',
          style: DSListTileStyle(verticalPadding: 40),
        ),
      );
      await mountProbe(tester, padded, cell);

      final List<ProbeViolation> found = ruleRowAir(tester, padded, cell);
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('height nothing in the kit asked'));

      // And the row built from the spec's own numbers is silent.
      await mountProbe(tester, broken, cell);
      expect(ruleRowAir(tester, broken, cell), isEmpty);
    });

    testWidgets('says nothing about a row the spec sized', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/row-air-clean',
        const DSListTile(title: 'Signed in as', subtitle: 'ada@rocketship.dev'),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleRowAir(tester, fine, cell), isEmpty);
    });

    testWidgets('does not call a row below the fold a broken rule', (
      WidgetTester tester,
    ) async {
      // The anti-vacuity clause exists because a rule that reports nothing
      // reads exactly like a rule that passed: if a surface has rows and the
      // walk measured none of them, that is the rule failing, not the kit
      // passing. Written as "mounted any rows" it fired on two real catalog
      // surfaces whose only row was under the fold — which is a row the rule
      // is right to skip. It counts rows *on screen* now.
      final ProbeSurface below = surface(
        'fixture/row-air-below-fold',
        const Padding(
          padding: EdgeInsets.only(top: ProbeCell.height + 100),
          child: DSListTile(title: 'Far below the fold'),
        ),
      );
      await mountProbe(tester, below, cell);

      expect(
        find.byType(DSListTile),
        findsOneWidget,
        reason: 'the row has to be mounted for the clause to be tempted',
      );
      expect(ruleRowAir(tester, below, cell), isEmpty);
    });
  });

  group('control-air', () {
    testWidgets('finds a button taller than its own token', (
      WidgetTester tester,
    ) async {
      // The defect arrives from the style layer here, because that is the one
      // place a height can be set without the spec's knowledge — which is
      // exactly the shape of the mistake the rule is named for. A 90-point
      // pill around a one-line label is height nothing in the kit asked for.
      final ProbeSurface padded = surface(
        'fixture/control-air-button',
        const DSButton(
          label: 'Continue',
          onPressed: _noop,
          style: DSButtonStyle(height: 90),
        ),
      );
      await mountProbe(tester, padded, cell);

      final List<ProbeViolation> found = ruleControlAir(tester, padded, cell);
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('height nothing in the kit asked'));
      expect(found.first.key, 'Continue');
    });

    testWidgets('finds a floating action button past its size', (
      WidgetTester tester,
    ) async {
      final ProbeSurface padded = surface(
        'fixture/control-air-fab',
        const DSFab(
          icon: Icons.add,
          semanticLabel: 'Add',
          onPressed: _noop,
          style: DSFabStyle(size: 120),
        ),
      );
      await mountProbe(tester, padded, cell);

      final List<ProbeViolation> found = ruleControlAir(tester, padded, cell);
      expect(found, isNotEmpty);
      expect(
        found.first.detail,
        contains('the floating action button "Add"'),
      );
    });

    testWidgets('says nothing about controls the spec sized', (
      WidgetTester tester,
    ) async {
      // All three button steps and both FAB forms, straight from the kit. A
      // rule that fires on these is a rule with a tolerance in it.
      final ProbeSurface fine = surface(
        'fixture/control-air-clean',
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DSButton(
              label: 'Small',
              size: DSButtonSize.sm,
              onPressed: _noop,
            ),
            DSButton(label: 'Medium', onPressed: _noop),
            DSButton(
              label: 'Large',
              size: DSButtonSize.lg,
              onPressed: _noop,
            ),
            DSFab(icon: Icons.add, semanticLabel: 'Add', onPressed: _noop),
            DSFab(
              icon: Icons.edit_outlined,
              label: 'Compose',
              onPressed: _noop,
            ),
          ],
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleControlAir(tester, fine, cell), isEmpty);
    });

    testWidgets('does not call a button below the fold a broken rule', (
      WidgetTester tester,
    ) async {
      final ProbeSurface below = surface(
        'fixture/control-air-below-fold',
        const Padding(
          padding: EdgeInsets.only(top: ProbeCell.height + 100),
          child: DSButton(label: 'Far below the fold', onPressed: _noop),
        ),
      );
      await mountProbe(tester, below, cell);

      expect(
        find.byType(DSButton),
        findsOneWidget,
        reason: 'the button has to be mounted for the clause to be tempted',
      );
      expect(ruleControlAir(tester, below, cell), isEmpty);
    });
  });

  group('width-band', () {
    test('finds one overlay kind at two widths', () {
      overlayWidths.clear();
      addTearDown(overlayWidths.clear);

      // What the walk records, recorded by hand: the same kind of surface,
      // in the same cell of the matrix, resolving to two different widths.
      overlayWidths['DSDialog'] = <ProbeCell, Set<double>>{
        cell: <double>{280, 400},
      };

      final List<ProbeViolation> found = ruleWidthBand();
      expect(found, hasLength(1));
      expect(found.single.detail, contains('280.0pt, 400.0pt'));
    });

    testWidgets('records the width of an overlay that is on screen', (
      WidgetTester tester,
    ) async {
      overlayWidths.clear();
      addTearDown(overlayWidths.clear);

      final ProbeSurface withDialog = surface(
        'fixture/width-band',
        const Center(
          child: DSDialog(title: 'Delete this?', message: 'It will not undo.'),
        ),
      );
      await mountProbe(tester, withDialog, cell);
      recordOverlayWidths(tester, cell);

      expect(
        overlayWidths['DSDialog']?[cell],
        hasLength(1),
        reason: 'one dialog on one surface is one width',
      );
      expect(ruleWidthBand(), isEmpty);
    });
  });

  group('target', () {
    testWidgets('finds a control under the tap floor', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface broken = surface(
        'fixture/target',
        Center(
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(width: 20, height: 20, child: Text('Go')),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleTarget(tester, broken, cell);
      // Disposed here rather than in a tear-down: the framework checks for a
      // live handle before tear-downs run, so a handle released there fails
      // the test it was helping.
      handle.dispose();
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('under the'));
    });

    testWidgets('says nothing about a control at the floor', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface fine = surface(
        'fixture/target-clean',
        Center(
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(width: 96, height: 96, child: Text('Go')),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      final List<ProbeViolation> found = ruleTarget(tester, fine, cell);
      handle.dispose();
      expect(found, isEmpty);
    });

    testWidgets('still measures the height of a full-width control', (
      WidgetTester tester,
    ) async {
      // The reason the clip is read per axis rather than per box. A tab spans
      // the whole width of its bar, so its left and right edges sit on the
      // screen's; a whole-box test called that "cut off" and never looked at
      // the 20-point height, which is the defect.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface broken = surface(
        'fixture/target-wide',
        Center(
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(
              width: double.infinity,
              height: 20,
              child: Text('Overview'),
            ),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleTarget(tester, broken, cell);
      handle.dispose();
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('under the'));
    });

    testWidgets('says nothing about the part of a control the screen cuts', (
      WidgetTester tester,
    ) async {
      // A 96-point control with 20 points of it on screen is a fact about a
      // scroll offset. The screen is the outermost clip and nothing declares
      // it as one, so this measured 20 and reported a defect that no cell of
      // the matrix could have fixed.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface fine = surface(
        'fixture/target-cut',
        Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: ProbeCell.height - 20,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  width: 96,
                  height: 96,
                  child: Text('Below'),
                ),
              ),
            ),
          ],
        ),
      );
      await mountProbe(tester, fine, cell);

      final List<ProbeViolation> found = ruleTarget(tester, fine, cell);
      handle.dispose();
      expect(found, isEmpty);
    });

    testWidgets('says nothing about a control a scrolling strip cuts', (
      WidgetTester tester,
    ) async {
      // The same reasoning as the screen's own edge, one clip further in. A
      // scrollable `DSTabBar`'s last tab is 26 points wide at 320pt because
      // the rest of it is scrolled off, and the semantics tree does not say
      // so: `parentSemanticsClipRect` there is an ancestor's, wider than the
      // strip, while the node's rect has already been cut. The strip's own
      // bounds come from the render tree instead.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface fine = surface(
        'fixture/target-strip',
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final String label in <String>['All', 'Unread', 'Sent'])
                  GestureDetector(
                    onTap: () {},
                    child: SizedBox(width: 160, height: 96, child: Text(label)),
                  ),
              ],
            ),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      final List<ProbeViolation> found = ruleTarget(tester, fine, cell);
      handle.dispose();
      expect(found, isEmpty);
    });

    testWidgets('still finds a small control inside a scrolling strip', (
      WidgetTester tester,
    ) async {
      // The exemption is for the box the strip is cutting, not for everything
      // in it. A 20-point control sitting in the open inside a scroller is
      // still a 20-point control.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface broken = surface(
        'fixture/target-strip-small',
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: () {},
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: Text('Go'),
                  ),
                ),
                const SizedBox(width: 600),
              ],
            ),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleTarget(tester, broken, cell);
      handle.dispose();
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('under the'));
    });

    testWidgets('says nothing about a text field', (WidgetTester tester) async {
      // A field's semantics merge into the editable text's, so the node's rect
      // is the run of text — around 25 points tall — while what a finger
      // lands on is the decoration drawn around it. The tree does not describe
      // that box, so the rule measured the text and reported the field.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface fine = surface(
        'fixture/target-field',
        const Center(
          child: SizedBox(width: 240, child: DSTextField(label: 'Email')),
        ),
      );
      await mountProbe(tester, fine, cell);

      final List<ProbeViolation> found = ruleTarget(tester, fine, cell);
      handle.dispose();
      expect(found, isEmpty);
    });
  });

  group('dual-axis', () {
    testWidgets('finds a page that scrolls both ways', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'fixture/dual-axis',
        ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            SizedBox(
              width: 600,
              child: ListView(
                children: <Widget>[
                  for (int i = 0; i < 40; i++)
                    const SizedBox(height: 40, child: Text('row')),
                ],
              ),
            ),
          ],
        ),
      );
      await mountProbe(tester, broken, cell);

      expect(ruleDualAxis(tester, broken, cell), isNotEmpty);
    });

    testWidgets('says nothing about a strip inside a page', (
      WidgetTester tester,
    ) async {
      // The composition this rule must not fail: a horizontal run of chips
      // inside a vertical page is a control with its own axis, and it is
      // everywhere.
      final ProbeSurface fine = surface(
        'fixture/dual-axis-clean',
        ListView(
          children: <Widget>[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (int i = 0; i < 20; i++)
                    const SizedBox(width: 80, child: Text('chip')),
                ],
              ),
            ),
            for (int i = 0; i < 40; i++) const SizedBox(height: 40),
          ],
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleDualAxis(tester, fine, cell), isEmpty);
    });
  });

  group('contrast', () {
    testWidgets('finds pale text on a pale surface', (
      WidgetTester tester,
    ) async {
      final ProbeSurface broken = surface(
        'fixture/contrast',
        const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Text(
            'Barely there',
            style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleContrast(tester, broken, cell);
      expect(found, isNotEmpty);
      expect(found.first.detail, contains('4.5:1 is the floor'));
    });

    testWidgets('says nothing about black on white', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/contrast-clean',
        const ColoredBox(
          color: Color(0xFFFFFFFF),
          child: Text(
            'Perfectly legible',
            style: TextStyle(color: Color(0xFF111111), fontSize: 14),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleContrast(tester, fine, cell), isEmpty);
    });

    testWidgets('says nothing about an inactive control', (
      WidgetTester tester,
    ) async {
      // WCAG 2.2 SC 1.4.3 exempts "text that is part of an inactive user
      // interface component" in as many words, and it is not a loophole: a
      // disabled control is supposed to recede, and every fix this rule
      // implied on one was to make the off state harder to tell from the on
      // one.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ProbeSurface fine = surface(
        'fixture/contrast-disabled',
        Semantics(
          container: true,
          enabled: false,
          child: const ColoredBox(
            color: Color(0xFFFFFFFF),
            child: Text(
              'Unavailable',
              style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      final List<ProbeViolation> found = ruleContrast(tester, fine, cell);
      handle.dispose();
      expect(found, isEmpty);
    });

    testWidgets('finds a string that fails at one end of a gradient', (
      WidgetTester tester,
    ) async {
      // The defect this covers is a *silent* one. Before the rule could read a
      // gradient it resolved the background by walking up for a
      // `BoxDecoration.color`; a gradient has none, so the walk continued and
      // graded the string against the black box behind — 21:1, no violation —
      // while half of what it is actually painted on is white.
      final ProbeSurface broken = surface(
        'fixture/contrast-gradient',
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF000000)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
              ),
            ),
            child: Text(
              'Readable at one end only',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleContrast(tester, broken, cell);
      expect(found, isNotEmpty);
      // The stop it names is the one that fails, not the first one declared.
      expect(found.first.detail, contains('#FFFFFF'));
    });

    testWidgets('says nothing when every stop clears the floor', (
      WidgetTester tester,
    ) async {
      final ProbeSurface fine = surface(
        'fixture/contrast-gradient-clean',
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF0B1B12)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF102A1E), Color(0xFF0B1B12)],
              ),
            ),
            child: Text(
              'Legible over the whole ramp',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleContrast(tester, fine, cell), isEmpty);
    });

    testWidgets('a transparent stop composites through to what is behind it', (
      WidgetTester tester,
    ) async {
      // A scrim is a gradient with a transparent end. That end is not a
      // background — it is a hole — and grading against it directly would fail
      // every scrim in the kit for the part of itself that shows the layer
      // below. The stop has to be composited like any other translucent layer.
      final ProbeSurface fine = surface(
        'fixture/contrast-gradient-scrim',
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF000000)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0x00000000), Color(0xCC000000)],
              ),
            ),
            child: Text(
              'White on a scrim over black',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleContrast(tester, fine, cell), isEmpty);
    });

    testWidgets('reads through a stack when nothing is painted under the text', (
      WidgetTester tester,
    ) async {
      // Every card in the kit puts its body in a `Stack` so a selection badge
      // can sit on top of it, and the rule used to give up at the first stack
      // it met. That made it silent about every `DSCard` on every screen —
      // including the dashboard hero, the one gradient surface the kit has.
      // The body is the stack's *first* child, so nothing in the stack is
      // behind it and the walk can carry on to what is.
      final ProbeSurface broken = surface(
        'fixture/contrast-stack-bottom',
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
          child: Stack(
            children: <Widget>[
              Text(
                'Under the badge, over the card',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
              ),
              Positioned(top: 0, right: 0, child: Icon(Icons.check)),
            ],
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      expect(ruleContrast(tester, broken, cell), isNotEmpty);
    });

    testWidgets('says nothing about text a stack sibling paints under', (
      WidgetTester tester,
    ) async {
      // The other half of the same rule, and the reason it was ever blanket:
      // what is behind a later child is a sibling layer, not an ancestor, and
      // walking past it reports the colour of the wrong thing. A selected
      // segment sitting on its own thumb measured as white on white.
      final ProbeSurface quiet = surface(
        'fixture/contrast-stack-upper',
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF101010)),
                ),
              ),
              Text(
                'Legible on the thumb under it',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
              ),
            ],
          ),
        ),
      );
      await mountProbe(tester, quiet, cell);

      expect(ruleContrast(tester, quiet, cell), isEmpty);
    });

    testWidgets('reads through a painter that draws in front of its child', (
      WidgetTester tester,
    ) async {
      // `CustomPaint` draws `painter` behind its child and `foregroundPainter`
      // in front of it. A node with only the second one cannot be what the
      // text is sitting on, and treating it as unreadable is what made this
      // rule silent on every real screen: `Material` wraps every card, button
      // and sheet in a `RenderCustomPaint` whose foreground painter draws the
      // shape's border.
      final ProbeSurface broken = surface(
        'fixture/contrast-foreground-painter',
        CustomPaint(
          foregroundPainter: _BorderPainter(),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
            child: Text(
              'Under a border, on white',
              style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, broken, cell);

      expect(ruleContrast(tester, broken, cell), isNotEmpty);
    });

    testWidgets('says nothing when a painter draws behind the text', (
      WidgetTester tester,
    ) async {
      // The half that still has to give up. A pill drawn rather than
      // decorated is a real background this cannot read, and reporting the
      // colour behind it is how a selected segment on its own thumb measured
      // as white on white.
      final ProbeSurface quiet = surface(
        'fixture/contrast-background-painter',
        DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
          child: CustomPaint(
            painter: _BorderPainter(),
            child: const Text(
              'On something drawn, not decorated',
              style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
            ),
          ),
        ),
      );
      await mountProbe(tester, quiet, cell);

      expect(ruleContrast(tester, quiet, cell), isEmpty);
    });

    test('the ratio is the WCAG one', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.02),
      );
    });
  });

  group('tour-art-semantics', () {
    testWidgets('finds a drawing a screen reader would read out', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      // A sequence composed by hand out of raw canvases: the drawn figures
      // are read aloud as a list of sample amounts, saying again what the
      // headline already said. The indicator is what makes this a run of
      // slides rather than a specimen on its own.
      final ProbeSurface broken = surface(
        'screen/fixture-tour',
        const Column(
          children: <Widget>[_LoudArt(), DSTourDots(count: 3, position: 0)],
        ),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleTourArtSemantics(
        tester,
        broken,
        cell,
      );
      expect(found, hasLength(1));
      expect(found.single.detail, contains('read aloud'));
      handle.dispose();
    });

    testWidgets('says nothing about the real slide', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ProbeSurface fine = surface(
        'screen/fixture-tour-clean',
        DSTour(
          stops: <DSTourStop>[
            DSTourStop(
              art: (bool active) => const DSTourCanvas(child: _LoudArt()),
              headline: 'One',
              body: 'The first claim.',
            ),
            DSTourStop(
              art: (bool active) => const DSTourCanvas(child: _LoudArt()),
              headline: 'Two',
              body: 'The second claim.',
            ),
          ],
          onFinish: () {},
          finishLabel: 'Get started',
        ),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleTourArtSemantics(tester, fine, cell), isEmpty);
      handle.dispose();
    });

    testWidgets('leaves a catalog specimen alone', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      // The same loud drawing with no indicator beside it: a component page
      // showing the canvas on its own, where there is no headline for it to
      // duplicate and reading it out is the only way to know what it draws.
      final ProbeSurface specimen = surface(
        'catalog/fixture-canvas',
        const _LoudArt(),
      );
      await mountProbe(tester, specimen, cell);

      expect(ruleTourArtSemantics(tester, specimen, cell), isEmpty);
      handle.dispose();
    });
  });

  group('tour-progress-label', () {
    testWidgets('finds an indicator that says nothing', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ProbeSurface broken = surface(
        'screen/fixture-dots',
        const ExcludeSemantics(child: DSTourDots(count: 3, position: 0)),
      );
      await mountProbe(tester, broken, cell);

      final List<ProbeViolation> found = ruleTourProgressLabel(
        tester,
        broken,
        cell,
      );
      expect(found, hasLength(1));
      expect(found.single.detail, contains('Page 1 of 3'));
      handle.dispose();
    });

    testWidgets('says nothing about the real indicator', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ProbeSurface fine = surface(
        'screen/fixture-dots-clean',
        const DSTourDots(count: 3, position: 0),
      );
      await mountProbe(tester, fine, cell);

      expect(ruleTourProgressLabel(tester, fine, cell), isEmpty);
      handle.dispose();
    });
  });
}

/// A tour drawing with its semantics left switched on — the defect
/// `tour-art-semantics` exists to find.
class _LoudArt extends StatelessWidget {
  const _LoudArt();

  @override
  Widget build(BuildContext context) =>
      const DSTourCanvas(child: Text(r'$1,345.20'));
}

void _noop() {}

/// A painter that draws something, so a `CustomPaint` in the fixtures above
/// has a real painter rather than a null one. What it draws does not matter —
/// the rule reads which slot it is in, not what comes out of it.
class _BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x11000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
