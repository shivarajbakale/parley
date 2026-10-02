import 'package:flutter_test/flutter_test.dart';

import '../../tool/ui_lint.dart';

/// A lint whose own behaviour is unverified is a lint that quietly stops
/// matching. These tests run the rules against strings, so they say what each
/// rule catches AND what it deliberately does not.
void main() {
  List<String> lintScreen(String source) =>
      lintSource('lib/screens/thing_page.dart', source);
  List<String> lintDs(String source) =>
      lintSource('lib/design_system/ds_thing.dart', source);
  // A DS file at a declared tier. The marker is the first line of every file
  // in the kit, and the rules that used to be exempt for the whole directory
  // now read it.
  List<String> lintTier(int tier, String source) => lintSource(
    'lib/design_system/ds_thing.dart',
    '// ds-tier: $tier — ${const ['foundation', 'atom', 'molecule'][tier]}\n'
        '$source',
  );

  String idsOf(List<String> findings) =>
      findings.map((f) => f.split('  ')[2].split(' — ').first).join(',');

  group('use the component', () {
    test('a screen may not hand-roll a paged sequence', () {
      expect(
        idsOf(lintScreen('  child: PageView.builder(itemCount: 3),')),
        'raw-tour',
      );
      expect(
        idsOf(lintScreen('  child: PageView(children: pages),')),
        'raw-tour',
      );
    });

    test('the tour, the shell and the stepped form may', () {
      // The kit's own paged sequence is one file, not the whole directory.
      expect(
        lintSource(
          'lib/design_system/ds_tour.dart',
          '  child: PageView(children: pages),',
        ),
        isEmpty,
      );
      expect(
        idsOf(lintTier(2, '  child: PageView(children: pages),')),
        'raw-tour',
      );
      expect(
        lintSource(
          'lib/screens/home_screen.dart',
          '  child: PageView(children: destinations),',
        ),
        isEmpty,
      );
      expect(
        lintSource(
          'lib/screens/design_system/form_page.dart',
          '  child: PageView(children: steps),',
        ),
        isEmpty,
      );
    });

    test('a screen may not hand-roll a control the kit owns', () {
      expect(
        idsOf(lintScreen('  child: ElevatedButton(onPressed: null),')),
        'raw-button',
      );
      expect(idsOf(lintScreen('  child: TextFormField(),')), 'raw-text-field');
      // A fetched picture has three states and the raw widget defaults to
      // one, which is why both call sites in the kit had a different subset.
      expect(
        idsOf(lintScreen("  child: Image.network(url),")),
        'raw-network-image',
      );
      expect(
        idsOf(lintScreen('  image: NetworkImage(url),')),
        'raw-network-image',
      );
      // The pull is dead on a list short enough to fit unless the scrollable
      // is forced always-scrollable, which is what DSRefresh is for.
      expect(
        idsOf(lintScreen('  child: RefreshIndicator(onRefresh: f),')),
        'raw-refresh-indicator',
      );
      expect(
        idsOf(lintScreen('  child: RefreshIndicator.adaptive(onRefresh: f),')),
        'raw-refresh-indicator',
      );
      // The disc on its own is the half of the widget with no gesture behind
      // it, so a screen reaching for it is building the pull by hand.
      expect(
        idsOf(lintScreen('  child: RefreshProgressIndicator(value: 0),')),
        'raw-refresh-indicator',
      );
      // Material's Divider defaults `height` to 16, so a stock rule adds 16
      // points of space wherever it lands.
      expect(idsOf(lintScreen('  child: Divider(),')), 'raw-divider');
      expect(idsOf(lintScreen('  child: VerticalDivider(),')), 'raw-divider');
      expect(lintScreen('  child: DSDivider(),'), isEmpty);
      expect(
        idsOf(lintScreen('  child: ListTile(title: t),')),
        'raw-list-tile',
      );
      expect(
        idsOf(lintScreen('  child: CircularProgressIndicator(),')),
        'raw-progress',
      );
      expect(
        idsOf(lintScreen('  showModalBottomSheet(context: context);')),
        'raw-bottom-sheet',
      );
    });

    test('an atom may — wrapping the raw widget is its job', () {
      expect(lintTier(1, '  child: ElevatedButton(onPressed: null),'), isEmpty);
      expect(lintTier(1, '  child: TextFormField(),'), isEmpty);
      expect(lintTier(0, '  child: TextFormField(),'), isEmpty);
    });

    test('a molecule may not — the atom below it already did', () {
      // The exemption used to be the directory, and this is what it hid: a
      // component two layers up reaching past the kit for the raw widget,
      // which is the same mistake a screen makes. `DSMessage` drew a Material
      // spinner on iOS behind this.
      expect(
        idsOf(lintTier(2, '  child: CircularProgressIndicator(),')),
        'raw-progress',
      );
      expect(idsOf(lintTier(2, '  child: TextFormField(),')), 'raw-text-field');
      expect(
        idsOf(lintTier(2, '  child: ElevatedButton(onPressed: null),')),
        'raw-button',
      );
    });

    test('a file with no tier is exempt from nothing', () {
      // Undeclared is not tier 0. A file that loses its marker loses the
      // exemption with it, which is what makes ds-tier-undeclared a finding
      // worth having rather than a formality.
      expect(idsOf(lintDs('  child: TextFormField(),')), 'raw-text-field');
    });

    test('the DS widget that wraps it is not itself a violation', () {
      // `DSListTile(` must not match the rule that forbids `ListTile(`.
      expect(lintScreen('  child: DSListTile(title: t),'), isEmpty);
      expect(lintScreen('  child: DSProgressIndicator.circular(),'), isEmpty);
      expect(lintScreen('  child: DSCard(child: c),'), isEmpty);
    });
  });

  group('the page owns the gutter', () {
    test('a screen may not spell the token', () {
      expect(
        idsOf(lintScreen('  padding: EdgeInsets.all(space.pageGutter),')),
        'screen-gutter',
      );
      expect(
        idsOf(lintScreen('  start: context.design.space.pageGutter,')),
        'screen-gutter',
      );
    });

    test('and reaches it through the page instead', () {
      expect(lintScreen('  child: DSGutter(child: card),'), isEmpty);
      expect(
        lintScreen('  padding: EdgeInsets.all(DSGutter.of(context)),'),
        isEmpty,
      );
    });

    test('a component may — insetting its own content is its job', () {
      // The tier ladder governs the kit. A row that pads its content while
      // its divider runs to the edge is the reason the page cannot own one
      // EdgeInsets for everything.
      expect(
        lintTier(1, '  padding: EdgeInsets.all(space.pageGutter),'),
        isEmpty,
      );
    });

    test('and so may a catalog story, which stages a page rather than being '
        'one', () {
      expect(
        lintSource(
          'lib/screens/design_system/catalog/navigation_stories.dart',
          '  padding: EdgeInsets.all(space.pageGutter),',
        ),
        isEmpty,
      );
    });
  });

  group('what floats at the bottom has to be under a host', () {
    test('a screen that pins a bar with no host fails', () {
      expect(
        idsOf(lintScreen('  bottomNavigationBar: DSPinnedActionBar(),')),
        'floating-chrome-host',
      );
      expect(
        idsOf(lintScreen('  floatingActionButton: DSFab(icon: i),')),
        'floating-chrome-host',
      );
      expect(
        idsOf(lintScreen('  bottomNavigationBar: DSBottomNavBar(),')),
        'floating-chrome-host',
      );
    });

    test('it reports once, not once per widget', () {
      // Two bars on one screen is one defect: the screen has no host.
      expect(
        lintScreen(
          '  bottomNavigationBar: DSPinnedActionBar(),\n'
          '  floatingActionButton: DSFab(icon: i),',
        ),
        hasLength(1),
      );
    });

    test('a host satisfies it', () {
      expect(
        lintScreen(
          '  return DSBottomInsetsHost(\n'
          '    child: Scaffold(bottomNavigationBar: DSPinnedActionBar()),\n'
          '  );',
        ),
        isEmpty,
      );
    });

    test('and so does DSPage, which installs one', () {
      expect(
        lintScreen('  return DSPage(footer: DSPinnedActionBar());'),
        isEmpty,
      );
    });

    test('and DSFormPage, which installs one too', () {
      expect(
        lintScreen('  return DSFormPage(footer: DSPinnedActionBar());'),
        isEmpty,
      );
    });

    test('a named constructor of either counts', () {
      // The check read `DSPage(` alone, so a screen on `DSPage.headline`,
      // `DSPage.surface` or `DSFormPage.hero` was reported for a host the
      // component it is built on installs.
      for (final call in [
        'DSPage.headline',
        'DSPage.surface',
        'DSFormPage.hero',
        'DSFormPage.fullBleed',
      ]) {
        expect(
          lintScreen('  return $call(footer: DSPinnedActionBar());'),
          isEmpty,
          reason: '$call installs the host',
        );
      }
    });

    test('a header is not a page, and does not satisfy it', () {
      // `DSPageHeader(` starts with the same six characters. A prefix match
      // that accepted it would excuse every screen with a title.
      expect(
        idsOf(
          lintScreen(
            '  return Scaffold(\n'
            '    body: DSPageHeader(title: t),\n'
            '    bottomNavigationBar: DSPinnedActionBar(),\n'
            '  );',
          ),
        ),
        'floating-chrome-host',
      );
    });

    test('the kit itself is not in scope — a component is not a screen', () {
      expect(lintTier(1, '  child: DSFab(icon: i),'), isEmpty);
    });
  });

  group('the kit declares its layers', () {
    test('a class may declare a layer below its file, with the reason', () {
      // The marker that fixed 20 catalog entries: a chevron was a molecule for
      // sharing a file with a list tile, a separator an organism for sharing
      // one with a select.
      expect(
        lintSource(
          'lib/design_system/ds_list_tile.dart',
          '// ds-tier: 2 — molecule\n'
              '// ds-tier: 1 — atom — A glyph that says the row leads on.\n'
              'class DSChevron extends StatelessWidget {}',
        ),
        isEmpty,
      );
    });

    test('but not a layer above it', () {
      // The file's marker is what the import rule can see. A class claiming
      // higher would be a component whose composition nothing checks.
      expect(
        idsOf(
          lintSource(
            'lib/design_system/ds_list_tile.dart',
            '// ds-tier: 2 — molecule\n'
                '// ds-tier: 3 — organism — A whole region, apparently.\n'
                'class DSThing extends StatelessWidget {}',
          ),
        ),
        'class-tier-above-file',
      );
    });

    test('and not without saying why', () {
      expect(
        idsOf(
          lintSource(
            'lib/design_system/ds_list_tile.dart',
            '// ds-tier: 2 — molecule\n'
                '// ds-tier: 1 — atom\n'
                'class DSThing extends StatelessWidget {}',
          ),
        ),
        'class-tier-reason',
      );
    });

    test('a misspelled class marker fails like a misspelled file one', () {
      expect(
        idsOf(
          lintSource(
            'lib/design_system/ds_list_tile.dart',
            '// ds-tier: 2 — molecule\n'
                '// ds-tier: 1 — molecule — wrong word for the number.\n'
                'class DSThing extends StatelessWidget {}',
          ),
        ),
        'class-tier-name',
      );
    });

    String imp(String name) =>
        "import 'package:parley_android/design_system/$name.dart';";
    // A tier declares itself with a marker and earns itself by composing the
    // tier below, so a fixture at tier 2 has to do both or it is testing the
    // floor rule by accident.
    const atom = 'class DSText extends StatelessWidget {}';
    const composesAtom =
        'class DSCard extends StatelessWidget {\n'
        '  Widget build(BuildContext context) => DSText();\n'
        '}';
    List<String> tiers(Map<String, String> kit) => tierFindings(
      kit,
    ).map((f) => f.split('  ')[1].split(' — ').first).toList();

    test('a clean kit says nothing', () {
      expect(
        tiers({
          'ds_scope.dart': '// ds-tier: 0 — foundation\n',
          'ds_text.dart': '// ds-tier: 1 — atom\n${imp('ds_scope')}\n$atom',
          'ds_card.dart':
              '// ds-tier: 2 — molecule\n${imp('ds_text')}\n$composesAtom',
          // The barrel is exports, and sits across the tiers rather than in
          // one of them.
          'design_system.dart': "export 'ds_card.dart';",
        }),
        isEmpty,
      );
    });

    test('a file with no marker is a finding', () {
      expect(
        tiers({'ds_card.dart': "import 'package:flutter/material.dart';"}),
        ['ds-tier-undeclared'],
      );
    });

    test('and the marker has to be the first line', () {
      // Buried under the imports it is a line nobody reads and nobody
      // updates. The rules that read the tier read the first line only.
      expect(
        tiers({
          'ds_card.dart':
              "import 'package:flutter/material.dart';\n"
              '// ds-tier: 2 — molecule\n',
        }),
        ['ds-tier-undeclared'],
      );
    });

    test('a tier off the ladder, and a name that disagrees with it', () {
      expect(tiers({'ds_card.dart': '// ds-tier: 7 — organism\n'}), [
        'ds-tier-unknown',
      ]);
      expect(
        tiers({
          'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
          'ds_card.dart':
              '// ds-tier: 2 — atom\n${imp('ds_text')}\n'
              '$composesAtom',
        }),
        ['ds-tier-name'],
      );
    });

    test('an import may reach its own tier or below, and no further', () {
      final kit = {
        'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
        'ds_card.dart':
            '// ds-tier: 2 — molecule\n${imp('ds_text')}\n$composesAtom',
      };
      // Down and sideways.
      expect(tiers(kit), isEmpty);
      expect(
        tiers({
          ...kit,
          'ds_chip.dart': '// ds-tier: 1 — atom\n${imp('ds_text')}',
        }),
        isEmpty,
      );
      // Up. A third file rather than ds_text, which the molecule already
      // imports: reversing that one would be a cycle as well as a reach up,
      // and this case is about the reach.
      expect(
        tiers({
          ...kit,
          'ds_badge.dart': '// ds-tier: 1 — atom\n${imp('ds_card')}',
        }),
        ['ds-tier-order'],
      );
    });

    test('and peers may not close a loop', () {
      // The shape "same tier or lower" cannot catch on its own, and the kit
      // had two of them.
      expect(
        tiers({
          'ds_skeleton.dart': '// ds-tier: 1 — atom\n${imp('ds_list_tile')}',
          'ds_list_tile.dart': '// ds-tier: 1 — atom\n${imp('ds_skeleton')}',
        }),
        ['ds-tier-cycle'],
      );
    });

    test('a layer is earned, not declared: a molecule composes an atom', () {
      // The ceiling rule cannot catch this. A file that composes nothing at
      // all reaches up to nothing, so it passes — which is how a component
      // that painted its whole surface with a CustomPainter sat at molecule.
      expect(
        tiers({
          'ds_scope.dart':
              '// ds-tier: 0 — foundation\n'
              'class DSScope extends InheritedWidget {}',
          'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
          'ds_card.dart':
              '// ds-tier: 2 — molecule\n${imp('ds_scope')}\n'
              'class DSCard extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => DSScope();\n'
              '}',
        }),
        ['ds-tier-floor'],
      );
    });

    test('and exactly the tier below, not merely something lower', () {
      // "Anything below" would pass a molecule standing on a foundation,
      // which is the case the rule exists for.
      final kit = {
        'ds_scope.dart':
            '// ds-tier: 0 — foundation\n'
            'class DSScope extends InheritedWidget {}',
        'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
      };
      expect(
        tiers({
          ...kit,
          'ds_page.dart':
              '// ds-tier: 3 — organism\n${imp('ds_text')}\n'
              'class DSPage extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => DSText();\n'
              '}',
        }),
        ['ds-tier-floor'],
      );
    });

    test('the floor stops at the atom, because an atom composes nothing', () {
      // The ladder's own wording: an atom *may* reach a foundation where a
      // molecule *is* atoms composed. An atom that paints a raw Flutter
      // widget and composes nothing is doing its job, and a floor on tier 1
      // would fail every one of them.
      expect(
        tiers({
          'ds_scope.dart': '// ds-tier: 0 — foundation\n',
          'ds_text.dart': '// ds-tier: 1 — atom\n',
        }),
        isEmpty,
      );
    });

    test('a class marker earns the floor its file cannot', () {
      // One file holding an atom and the molecule that composes it is the
      // shape flutter-072 made expressible, and this is what makes those
      // markers pay for themselves: without the marker both classes are the
      // file's tier and the molecule composes a peer.
      String kit(String marker) =>
          '// ds-tier: 2 — molecule\n'
          '$marker'
          'class DSTab extends StatelessWidget {}\n'
          'class DSTabBar extends StatelessWidget {\n'
          '  Widget build(BuildContext context) => DSTab();\n'
          '}';
      expect(tiers({'ds_tab_bar.dart': kit('')}), ['ds-tier-floor']);
      expect(
        tiers({'ds_tab_bar.dart': kit('// ds-tier: 1 — atom — one tab.\n')}),
        isEmpty,
      );
    });

    test('a name in a comment does not count as composing it', () {
      // The failure that would make this rule congratulate a file for
      // describing composition it does not do.
      expect(
        tiers({
          'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
          'ds_card.dart':
              '// ds-tier: 2 — molecule\n${imp('ds_text')}\n'
              '// Wraps a DSText() in a bordered box.\n'
              'class DSCard extends StatelessWidget {}',
        }),
        ['ds-tier-floor'],
      );
    });

    test('a generic constructor is still a constructor', () {
      // `DSSegmentedButton<ThemeMode>(` is how the kit's own picker composes
      // one, and a rule that missed it would report a component for not
      // composing the thing it visibly composes.
      expect(
        tiers({
          'ds_text.dart':
              '// ds-tier: 1 — atom\n'
              'class DSText extends StatelessWidget {}',
          'ds_card.dart':
              '// ds-tier: 2 — molecule\n${imp('ds_text')}\n'
              'class DSCard extends StatelessWidget {\n'
              '  Widget build(BuildContext c) => DSText<ThemeMode>();\n'
              '}',
        }),
        isEmpty,
      );
    });

    test('and a waiver that outlived its defect is itself a finding', () {
      // Same contract as _contractDebt: the list is only true while it
      // shrinks, so a file that starts composing an atom has to come off it
      // rather than sitting there reading as a known problem.
      expect(tierFloorDebt.keys, contains('ds_radio.dart'));
      expect(
        tiers({
          'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
          'ds_radio.dart':
              '// ds-tier: 2 — molecule\n${imp('ds_text')}\n'
              'class DSRadioGroup extends StatelessWidget {\n'
              '  Widget build(BuildContext c) => DSText();\n'
              '}',
        }),
        ['ds-tier-floor-stale'],
      );
    });

    test(
      'the two files the floor still waives, and why each is a question',
      () {
        // Two, and both are decisions rather than markers to move.
        //
        // `ds_radio.dart` composes its atoms through `List<Widget> children`,
        // so they arrive from the call site. The slot is declared `Widget`, so
        // this is not a limit of reading the source rather than the element
        // graph — a resolved graph would not see it either.
        //
        // `ds_theme_mode_picker.dart` composes a component of its own tier. The
        // ladder has no rung for one component configuring another at the same
        // layer, and inventing one is not a side effect of adding this rule.
        expect(tierFloorDebt, hasLength(2));
        for (final entry in tierFloorDebt.entries) {
          expect(
            entry.value.length,
            greaterThan(80),
            reason:
                '${entry.key} is waived without an argument. A one-line reason '
                'is how a waiver becomes permanent',
          );
        }
      },
    );

    test('an import of something outside the kit is not a tier question', () {
      expect(
        tiers({
          'ds_text.dart': '// ds-tier: 1 — atom\n$atom',
          'ds_card.dart':
              '// ds-tier: 2 — molecule\n'
              "import 'package:parley_android/theme/app_haptics.dart';\n"
              "${imp('ds_gone')}\n${imp('ds_text')}\n$composesAtom",
        }),
        isEmpty,
      );
    });
  });

  group('physical-direction — a layout that survives Arabic', () {
    test('a left or right inset is a finding', () {
      expect(
        idsOf(lintScreen('  padding: EdgeInsets.only(left: space.md),')),
        'physical-direction',
      );
      expect(
        idsOf(lintScreen('  padding: EdgeInsets.only(right: space.md),')),
        'physical-direction',
      );
      expect(
        idsOf(lintScreen('  alignment: Alignment.centerLeft,')),
        'physical-direction',
      );
      expect(
        idsOf(lintScreen('  alignment: Alignment.centerRight,')),
        'physical-direction',
      );
    });

    test('a zero is symmetric, so it is not', () {
      // `left: 0` beside `right: 0` pins both edges and mirrors to itself.
      expect(idsOf(lintScreen('  left: 0,')), '');
      expect(idsOf(lintScreen('  right: 0,')), '');
    });

    test('the directional twins pass', () {
      expect(
        idsOf(lintScreen('  padding: EdgeInsetsDirectional.only(start: s),')),
        '',
      );
      expect(
        idsOf(lintScreen('  alignment: AlignmentDirectional.centerStart,')),
        '',
      );
      expect(
        idsOf(lintScreen('  child: PositionedDirectional(start: 0),')),
        '',
      );
    });

    test('a field read named left is not a named argument', () {
      // `pad.left` is reading a resolved EdgeInsets, which is the correct
      // thing to do once the direction has been consumed.
      expect(idsOf(lintScreen('  final x = pad.left + pad.right;')), '');
    });
  });

  group('tokens', () {
    test('a hand-typed font weight fails, in the kit and on a screen', () {
      expect(
        idsOf(lintDs('  fontWeight: FontWeight.w700,')),
        'raw-font-weight',
      );
      expect(
        idsOf(lintScreen('  fontWeight: FontWeight.w500,')),
        'raw-font-weight',
      );
      // Every step of the ramp, not just the two the kit happened to type.
      expect(
        idsOf(lintDs('  fontWeight: FontWeight.w100,')),
        'raw-font-weight',
      );
    });

    test('the token that names what the weight is for passes', () {
      expect(
        lintDs('  fontWeight: context.design.type.emphasisWeight,'),
        isEmpty,
      );
      expect(lintDs('  fontWeight: type.labelWeight,'), isEmpty);
      // `FontWeight.bold` is not matched: it is a different spelling of the
      // same defect, but the rule reads the numbered ramp the spec is written
      // in, and widening it to the named constants belongs with a conversion
      // that has somewhere to send them.
      expect(lintDs('  fontWeight: FontWeight.bold,'), isEmpty);
    });

    test('the spec is where a literal weight is the definition', () {
      // A token has to be written down somewhere. These three files are where.
      for (final path in const [
        'lib/theme/spec/type_spec.dart',
        'lib/theme/spec/design_spec.dart',
        'lib/theme/app_typography.dart',
      ]) {
        expect(
          lintSource(path, '  emphasisWeight: FontWeight.w900,'),
          isEmpty,
          reason: '\$path declares the token rather than copying it',
        );
      }
      // And a neighbour in the same directory does not inherit the exemption.
      expect(
        idsOf(lintSource('lib/theme/app_theme.dart', '  w: FontWeight.w700,')),
        'raw-font-weight',
      );
    });

    test('a font feature written out by hand fails', () {
      expect(
        idsOf(lintDs('  fontFeatures: const [FontFeature.tabularFigures()],')),
        'raw-font-feature',
      );
      // Any feature, not only the one the kit had twelve copies of: a second
      // hand-rolled feature is the same decision made in a second place.
      expect(
        idsOf(lintDs('  fontFeatures: [FontFeature.slashedZero()],')),
        'raw-font-feature',
      );
      // The getter is the one spelling.
      expect(lintDs('  style: base?.copyWith(color: c).tabular,'), isEmpty);
    });

    test('a hand-typed duration, curve, radius, shadow or colour fails', () {
      // Two rules read the same defect from two directions: the duration
      // rule reads the constructor, the metric rule reads the number in it.
      expect(
        idsOf(lintDs('  duration: const Duration(milliseconds: 180),')),
        'hardcoded-duration,bare-metric',
      );
      expect(idsOf(lintDs('  curve: Curves.easeOut,')), 'hardcoded-curve');
      expect(
        idsOf(lintDs('  borderRadius: BorderRadius.circular(12),')),
        'hardcoded-radius,bare-metric',
      );
      expect(
        idsOf(lintDs('  boxShadow: [BoxShadow(color: c)],')),
        'hardcoded-shadow',
      );
      expect(idsOf(lintDs('  color: Colors.white,')), 'hardcoded-color');
      expect(idsOf(lintDs('  color: Color(0xFF112233),')), 'hardcoded-hex');
    });

    test('retired-palette-role fails a retired palette name', () {
      expect(
        idsOf(lintDs('  final c = palette.textSecondary;')),
        'retired-palette-role',
      );
    });

    test('retired-palette-role passes a current role', () {
      expect(
        idsOf(lintDs('  final c = palette.mutedForeground;')),
        isNot(contains('retired-palette-role')),
      );
    });

    test('retired-palette-role fails the short p. alias too', () {
      expect(idsOf(lintDs('  final c = p.canvas;')), 'retired-palette-role');
    });

    test('a hand-typed glyph or box size fails', () {
      expect(
        idsOf(lintDs('  child: Icon(icon, size: 20),')),
        'hardcoded-icon-size',
      );
      expect(idsOf(lintDs('  iconSize: 18,')), 'hardcoded-icon-size');
      // One finding per rule per line, not one per match.
      expect(
        idsOf(lintDs('  child: SizedBox(width: 40, height: 4),')),
        'hardcoded-box-size',
      );
      expect(
        idsOf(lintDs('  constraints: BoxConstraints(minHeight: 48),')),
        'hardcoded-box-size',
      );
    });

    test('the size token passes, and a line height is not a box', () {
      expect(
        lintDs('  size: context.design.component.iconSizeInline,'),
        isEmpty,
      );
      expect(lintDs('  width: component.grabberWidth,'), isEmpty);
      // `fontSize:` is type, and it has its own rule; the size rule must not
      // also claim it, or one defect is reported twice under the wrong name.
      expect(
        idsOf(lintDs('  style: TextStyle(fontSize: 14),')),
        'hardcoded-text-style',
      );
      // A TextStyle's `height` is a multiplier, not a dimension. It is
      // fractional, which is the only thing a line-based regex can see.
      expect(lintDs('  style: TextStyle(height: 1.35),'), isEmpty);
    });

    test('the gallery may size its own preview frames', () {
      // A story's 360x640 is a fake phone, not a dimension the kit ships.
      expect(
        lintSource(
          'lib/screens/design_system/catalog/state_stories.dart',
          '  child: SizedBox(height: 260),',
        ),
        isEmpty,
      );
    });

    test('the spec read passes', () {
      expect(lintDs('  duration: motion.scaled(motion.press),'), isEmpty);
      expect(lintDs('  curve: context.design.motion.enter,'), isEmpty);
      expect(
        lintDs('  borderRadius: BorderRadius.circular(context.radiusOf(r)),'),
        isEmpty,
      );
      expect(
        lintDs('  color: context.palette.overlay.withValues(alpha: 0.5),'),
        isEmpty,
      );
      expect(lintDs('  color: scheme.surfaceContainerLow,'), isEmpty);
    });

    test('a token namespace beside the spec fails', () {
      // The six `App*` namespaces are deleted; this is what stops one being
      // written again next to the spec that replaced it. A namespace is a
      // `static const`, and a `static const` cannot be swapped or themed —
      // so a screen reading one is a screen the identity cannot reach.
      for (final namespace in [
        'AppSpacing',
        'AppRadius',
        'AppMotion',
        'AppSprings',
        'AppShadows',
        'AppShapes',
        'AppColors',
      ]) {
        expect(
          idsOf(lintScreen('  final x = $namespace.lg;')),
          contains('token-namespace'),
          reason: '$namespace was not caught',
        );
      }
      // The kit's own behaviour namespaces are not tokens and stay legal.
      expect(lintDs('  AppHaptics.selection();'), isEmpty);
      expect(lintScreen('  AppPlatform.isApple(context);'), isEmpty);
      expect(lintDs('  style: AppTypography.eyebrow(context),'), isEmpty);
    });

    test('a bare number in a metric constructor fails, whole call', () {
      // The formatter puts a multi-argument EdgeInsets on four lines, so a
      // line-based rule sees none of them.
      expect(
        idsOf(
          lintScreen(
            '  padding: EdgeInsets.symmetric(\n'
            '    horizontal: 8,\n'
            '    vertical: 2,\n'
            '  ),',
          ),
        ),
        'bare-metric',
      );
      expect(
        idsOf(lintScreen('  padding: EdgeInsets.fromLTRB(16, 0, 16, 4),')),
        'bare-metric',
      );
      expect(
        idsOf(
          lintScreen('  borderRadius: BorderRadius.all(Radius.circular(8)),'),
        ),
        'bare-metric',
      );
    });

    test('the metric rule lets through what is not a design decision', () {
      // Zero is the absence of spacing rather than an amount of it.
      expect(lintScreen('  padding: EdgeInsets.only(bottom: 0),'), isEmpty);
      expect(lintScreen('  padding: EdgeInsets.zero,'), isEmpty);
      // The scale, multiplied, is still the scale.
      expect(lintScreen('  padding: EdgeInsets.all(space.lg * 2),'), isEmpty);
      // A date range is a quantity of time in the domain; the motion scale is
      // written in milliseconds.
      expect(
        lintScreen('  firstDate: today.subtract(const Duration(days: 3)),'),
        isEmpty,
      );
      // And the spec read passes, which is the whole point of the rule.
      expect(
        lintScreen('  padding: EdgeInsets.all(context.design.space.lg),'),
        isEmpty,
      );
    });

    test('Colors.transparent is not a colour choice', () {
      // It is the absence of one, and it reads identically in both themes.
      expect(lintDs('  color: Colors.transparent,'), isEmpty);
    });

    test('lib/theme is where the tokens are defined, so it is exempt', () {
      expect(
        lintSource(
          'lib/theme/app_motion.dart',
          '  static const fast = Duration(milliseconds: 200);',
        ),
        isEmpty,
      );
    });

    test('a duration outside the UI is latency, not animation', () {
      expect(
        lintSource(
          'lib/data/mock/mock_api.dart',
          '  await Future.delayed(const Duration(milliseconds: 400));',
        ),
        isEmpty,
      );
    });
  });

  group('layering', () {
    test('the design system may not reach up into app state', () {
      expect(
        idsOf(
          lintDs("import 'package:parley_android/providers/auth_provider.dart';"),
        ),
        'ds-reaches-up',
      );
      expect(
        lintDs("import 'package:parley_android/theme/app_motion.dart';"),
        isEmpty,
      );
    });

    test('a model may not import Flutter', () {
      expect(
        idsOf(
          lintSource(
            'lib/models/thing.dart',
            "import 'package:flutter/material.dart';",
          ),
        ),
        'model-imports-flutter',
      );
    });
  });

  group('the escape hatch', () {
    test('waives the line it names, and only that rule', () {
      expect(
        lintScreen(
          '  // ui-lint: allow raw-button — reason\n'
          '  child: ElevatedButton(onPressed: null),',
        ),
        isEmpty,
      );
      expect(
        idsOf(
          lintScreen(
            '  // ui-lint: allow raw-text-field — wrong rule\n'
            '  child: ElevatedButton(onPressed: null),',
          ),
        ),
        'raw-button',
      );
    });

    test('may sit anywhere in the comment block above, not just line -1', () {
      // An exception worth making is an exception worth explaining, and an
      // explanation rarely fits on one line.
      expect(
        lintScreen(
          '  // ui-lint: allow raw-button — the reason,\n'
          '  // which runs to a second line,\n'
          '  // and a third.\n'
          '  child: ElevatedButton(onPressed: null),',
        ),
        isEmpty,
      );
    });

    test('does not reach past a line of code', () {
      expect(
        idsOf(
          lintScreen(
            '  // ui-lint: allow raw-button\n'
            '  final x = 1;\n'
            '  child: ElevatedButton(onPressed: null),',
          ),
        ),
        'raw-button',
      );
    });
  });

  group('comments', () {
    test('a rule is not tripped by prose that names what it forbids', () {
      expect(lintDs('  // never write Colors.white here'), isEmpty);
      expect(
        lintDs('  /// Prefer AppMotion over Duration(milliseconds: 200).'),
        isEmpty,
      );
    });

    test('a block comment does not shift the line numbers after it', () {
      // A violation reported at the wrong line is a violation nobody finds.
      final findings = lintDs(
        '/* a\n'
        'multi\n'
        'line\n'
        'comment */\n'
        '  color: Colors.white,',
      );
      expect(findings.single, contains('ds_thing.dart:5'));
    });

    test('a // inside a string is not a comment', () {
      expect(
        idsOf(lintDs("  final url = 'https://x.dev'; color: Colors.white;")),
        'hardcoded-color',
      );
    });
  });

  group('glass stays on the chrome layer', () {
    test('a screen or a content widget may not reach for the material', () {
      expect(
        idsOf(lintScreen('  child: AppChromeSurface(child: c),')),
        'glass-off-chrome',
      );
      expect(
        idsOf(
          lintSource(
            'lib/design_system/ds_card.dart',
            '  final m = AppMaterials.chrome(context);',
          ),
        ),
        'glass-off-chrome',
      );
    });

    test('the chrome components may — that is what the allowlist is', () {
      expect(
        lintSource(
          'lib/design_system/ds_bottom_nav_bar.dart',
          '  final m = AppMaterials.chrome(context);',
        ),
        isEmpty,
      );
      expect(
        lintSource(
          'lib/design_system/ds_bottom_sheet.dart',
          '  child: AppChromeSurface(child: c),',
        ),
        isEmpty,
      );
    });

    test('the theme layer defines it, so it is not a violation there', () {
      expect(
        lintSource(
          'lib/theme/app_materials.dart',
          '  static AppMaterial chrome(BuildContext context) => x;',
        ),
        isEmpty,
      );
    });
  });

  group('the component contract', () {
    test('a Slot parameter that is not a Widget is not a slot', () {
      expect(idsOf(lintDs('  final IconData? iconSlot;')), 'slot-widget-type');
      expect(lintDs('  final Widget? iconSlot;'), isEmpty);
    });

    test('a bare Widget? must name a region from the closed list', () {
      expect(idsOf(lintDs('  final Widget? sparkle;')), 'slot-region-name');
      expect(lintDs('  final Widget? trailing;'), isEmpty);
      // Flutter's own universal name, allowed for the reason `_slotRegions`
      // gives: a kit whose components do not take a `child` reads as unlike
      // every widget around them.
      expect(lintDs('  final Widget? child;'), isEmpty);
    });

    test('booleans drop the is prefix, and only in the design system', () {
      expect(idsOf(lintDs('  final bool isLoading;')), 'bool-is-prefix');
      expect(lintDs('  final bool loading;'), isEmpty);
      expect(lintScreen('  final bool isLoading;'), isEmpty);
    });

    test('nothing may read colorScheme directly — kit or screen', () {
      expect(
        idsOf(lintDs('    final c = Theme.of(context).colorScheme;')),
        'ds-reads-scheme',
      );
      expect(
        idsOf(lintDs('    final c = colorScheme.primary;')),
        'ds-reads-scheme',
      );
      expect(lintDs('    final c = context.palette.card;'), isEmpty);
      // This assertion used to be `isEmpty`, with the comment "screens read
      // the scheme all day". They did: 51 reads across 15 files, against nine
      // in the kit. Holding the components to the palette while letting the
      // screens read past it protected the side the drift was never going to
      // show on — an identity that moved a grey moved every component and
      // left the pages they sit on behind.
      expect(
        idsOf(lintScreen('    final c = Theme.of(context).colorScheme;')),
        'ds-reads-scheme',
      );
      expect(
        idsOf(lintScreen('      color: theme.colorScheme.onSurfaceVariant,')),
        'ds-reads-scheme',
      );
      expect(
        lintScreen('      color: context.palette.mutedForeground,'),
        isEmpty,
      );
    });

    test('a style object with a non-nullable field cannot be merged', () {
      const source = '''
class DSThingStyle extends ThemeExtension<DSThingStyle> {
  final Color? background;
  final double gap;
  DSThingStyle merge(DSThingStyle? other) => this;
  static DSThingStyle resolve(BuildContext context) => const DSThingStyle();
  DSThingStyle lerp(DSThingStyle? other, double t) => other ?? this;
}
''';
      expect(idsOf(lintDs(source)), 'style-field-nullable');
    });

    test('a style object needs merge, resolve and a real lerp', () {
      const source = '''
class DSThingStyle extends ThemeExtension<DSThingStyle> {
  final Color? background;
  DSThingStyle lerp(DSThingStyle? other, double t) => this;
}
''';
      expect(
        idsOf(lintDs(source)).split(','),
        containsAll(<String>[
          'style-merge-missing',
          'style-resolve-missing',
          'style-lerp-stub',
        ]),
      );
    });

    test('a tap handler in the kit has to reach the floor', () {
      expect(
        idsOf(lintDs('    return GestureDetector(onTap: onTap, child: c);')),
        'pressable-floor',
      );
      expect(
        lintDs('    return DSPressable(child: DSInkSurface(onTap: onTap));'),
        isEmpty,
      );
      // One finding per file, not one per line: the fix is the same fix.
      expect(
        lintDs('    DSInkSurface(onTap: a);\n    DSInkSurface(onTap: b);'),
        hasLength(1),
      );
    });

    test('the ink layer has one owner', () {
      // A raw InkWell fails twice over: it is not the component, and a file
      // that reaches for it has not reached the press floor either.
      expect(
        idsOf(lintDs('    return InkWell(onTap: onTap, child: c);')),
        'raw-ink,pressable-floor',
      );
      expect(
        idsOf(lintDs('    return InkResponse(onTap: onTap, child: c);')),
        contains('raw-ink'),
      );
      // `Ink` paints into the material below the splash and belongs to the
      // same component, so it is named too — `DSInkSurface(tint:)` is the way
      // to tint a row under its ripple.
      expect(
        idsOf(lintDs('    return Ink(color: c, child: child);')),
        contains('raw-ink'),
      );
      // The one file that may: it is where DSInkSurface is written.
      expect(
        lintSource(
          'lib/design_system/ds_pressable.dart',
          '    return InkWell(onTap: onTap, child: c);',
        ),
        isEmpty,
      );
      // Names that merely start with `Ink`, and member calls, are not the
      // widget.
      expect(lintDs('    return InkyThing(child: c);'), isEmpty);
    });

    test(
      'the migration list only shrinks, and every rule is live for every file',
      () {
        // Four of these were spent by plans 22–31: the files they carried have
        // been rewritten against the contract rather than waived for longer,
        // and they stay at zero. `contract-debt-stale` is what fails the build
        // if a line outlives its defect.
        for (final id in const [
          'ds-reads-scheme',
          'bool-is-prefix',
          'pressable-floor',
          'slot-region-name',
        ]) {
          expect(
            contractDebt[id],
            isEmpty,
            reason: '$id was paid off; a file added back is a regression',
          );
        }

        // `raw-text-style` is the one migration still running, and this is its
        // ratchet. Both directions are a failure. Above the number means a
        // component started reading Material's steps again; below it means a
        // conversion landed and was not banked, so lower the number here in
        // the same change and the gain cannot be quietly spent elsewhere.
        //
        // Twenty-one call sites across seven files moved with this number's
        // first reading and not one golden changed — the roles were already
        // describing what those components built by hand.
        //
        // 44 to 41: `bodySupport` and `caption` are the two combinations the
        // counts demanded and the vocabulary did not carry, and three files
        // had no other read.
        //
        // 41 to 40: `ds_search_bar.dart`, whose two reads were a result count
        // and a suggestion's base style, and whose second one only surfaced
        // once the count went. The scanner behind the earlier counts matched
        // `text.bodyMedium` and missed `Theme.of(context).textTheme.bodyMedium`
        // written inline, which is the form eleven reads in this kit use.
        //
        // 40 to 41: not a conversion in either direction. `ds_select.dart`
        // split into itself plus `_ds_select_style.dart`,
        // `_ds_select_parts.dart` and `_ds_select_list.dart`; its two
        // `textTheme` reads went with `DSSelectStyle.resolve` and
        // `DSSelectSection`/`DSSelectOption`, landing one in each of the
        // first two files. Same reads, one more filename to carry them.
        //
        // 41 to 40: not a conversion either. `ds_editor_bar.dart` was
        // deleted with the Note demo, and its read went with it.
        expect(
          contractDebt['raw-text-style'],
          hasLength(40),
          reason:
              'the type migration moved. Files still reading textTheme:\n  '
              '${contractDebt['raw-text-style']!.join('\n  ')}',
        );

        // And the waiver is per file, not a switch: a file NOT on the list is
        // held to the rule, which is the half that makes a migration list
        // different from turning the rule off.
        expect(
          idsOf(
            lintSource(
              'lib/design_system/ds_form_page.dart',
              '    final t = Theme.of(context).textTheme;',
            ),
          ),
          'raw-text-style',
        );
        expect(
          lintSource(
            'lib/design_system/ds_avatar.dart',
            '    final t = Theme.of(context).textTheme;',
          ).where((f) => f.contains('raw-text-style')),
          isEmpty,
        );
        // The file that turns a role into a step is the one allowed to read
        // it, and since flutter-073 that is the style chain, not the widget.
        expect(
          lintSource(
            'lib/design_system/ds_text_style.dart',
            '    final text = Theme.of(context).textTheme;',
          ),
          isEmpty,
        );
        // The widget kept the name and lost the exemption with the recipes.
        expect(
          idsOf(
            lintSource(
              'lib/design_system/ds_text.dart',
              '    final text = Theme.of(context).textTheme;',
            ),
          ),
          'raw-text-style',
        );
        // Screens are not in scope yet — the kit teaches by example first.
        expect(
          lintSource(
            'lib/screens/thing_page.dart',
            '    final t = Theme.of(context).textTheme;',
          ),
          isEmpty,
        );
        const scheme = '    final c = Theme.of(context).colorScheme;';
        expect(
          idsOf(lintSource('lib/design_system/ds_avatar.dart', scheme)),
          'ds-reads-scheme',
        );
        expect(
          idsOf(
            lintSource(
              'lib/design_system/ds_avatar.dart',
              '    return GestureDetector(onTap: onTap, child: c);',
            ),
          ),
          'pressable-floor',
        );
      },
    );

    test('a file may say why it does not dip, in one line', () {
      expect(
        idsOf(
          lintSource(
            'lib/design_system/ds_avatar.dart',
            '    // ui-lint: allow pressable-floor — a full-bleed row that\n'
                '    // shrinks detaches from the column it belongs to.\n'
                '    return GestureDetector(onTap: onTap, child: c);',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('the current-step width channel', () {
    test('a currentFlex of 1 is flagged', () {
      expect(
        idsOf(
          lintSource(
            'lib/screens/checkout_screen.dart',
            '    style: const DSSegmentedProgressStyle(currentFlex: 1.0),',
          ),
        ),
        'current-flex-floor',
      );
    });

    test('a currentFlex above 1 is not', () {
      expect(
        idsOf(
          lintSource(
            'lib/screens/checkout_screen.dart',
            '    style: const DSSegmentedProgressStyle(currentFlex: 1.4),',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('message-icons-total — every tone keeps its glyph', () {
    const total = """
  static const Map<DSMessageTone, IconData> defaultIcons = {
    DSMessageTone.neutral: Icons.circle_outlined,
    DSMessageTone.info: Icons.info_outline,
    DSMessageTone.success: Icons.check_circle_outline,
    DSMessageTone.warning: Icons.warning_amber_outlined,
    DSMessageTone.error: Icons.error_outline,
  };
""";

    test('a total map passes', () {
      expect(
        idsOf(lintSource('lib/design_system/ds_message.dart', total)),
        isEmpty,
      );
    });

    test('dropping one tone fails', () {
      final short = total
          .split('\n')
          .where((l) => !l.contains('DSMessageTone.warning'))
          .join('\n');
      final findings = lintSource('lib/design_system/ds_message.dart', short);
      expect(idsOf(findings), contains('message-icons-total'));
      expect(findings.first, contains('warning'));
    });

    test('the rule only speaks about the file that owns the set', () {
      expect(
        idsOf(lintSource('lib/design_system/ds_avatar.dart', 'const x = 1;')),
        isEmpty,
      );
    });

    test('and a missing map is itself the failure', () {
      expect(
        idsOf(lintSource('lib/design_system/ds_message.dart', 'const x = 1;')),
        contains('message-icons-total'),
      );
    });
  });

  group('toggle-glyph — a toggle that is only a fill', () {
    test('selected with no selectedIcon fails', () {
      expect(
        idsOf(
          lintScreen("""
              DSIconButton(
                icon: Icons.bookmark_border,
                semanticLabel: 'Save',
                selected: _saved,
                onPressed: _toggle,
              ),
"""),
        ),
        contains('toggle-glyph'),
      );
    });

    test('selected with a selectedIcon passes', () {
      expect(
        idsOf(
          lintScreen("""
              DSIconButton(
                icon: Icons.bookmark_border,
                selectedIcon: Icons.bookmark,
                semanticLabel: 'Save',
                selected: _saved,
                onPressed: _toggle,
              ),
"""),
        ),
        isEmpty,
      );
    });

    test('a button that is not a toggle is not asked for a second glyph', () {
      expect(
        idsOf(
          lintScreen("""
              DSIconButton(
                icon: Icons.search,
                semanticLabel: 'Search',
                onPressed: _search,
              ),
"""),
        ),
        isEmpty,
      );
    });

    test('a nested widget does not end the call early', () {
      // The `selected:` belongs to the row, not to the button — but the
      // button's own arguments still have to be read to the closing paren.
      expect(
        idsOf(
          lintScreen("""
              DSIconButton(
                icon: Icons.bookmark_border,
                semanticLabel: 'Save',
                iconSlot: Icon(Icons.bookmark_border, size: 18),
                selected: true,
                onPressed: _toggle,
              ),
"""),
        ),
        contains('toggle-glyph'),
      );
    });
  });

  test('the rule set has not silently shrunk', () {
    // Deleting a rule to get a build green is the failure this guards.
    expect(ruleIds, hasLength(41));
    expect(
      ruleIds,
      containsAll(<String>[
        'hardcoded-icon-size',
        'hardcoded-box-size',
        // Plan 17's rule, in both halves: a surface presented off the
        // navigator, and a private route for one surface.
        'raw-overlay-entry',
        'raw-popup-route',
        'raw-network-image',
        // The two type decisions that repeat and have a token each, and the
        // rule that sends a component to a role rather than a Material step.
        'raw-font-weight',
        'raw-font-feature',
        'raw-text-style',
        // One spelling of the ink, in one file.
        'raw-ink',
        'raw-refresh-indicator',
        'raw-divider',
        'physical-direction',
        'raw-button',
        'hardcoded-color',
        'retired-palette-role',
        'ds-reaches-up',
        'glass-off-chrome',
        'slot-widget-type',
        'bool-is-prefix',
        'current-flex-floor',
        'ds-reads-scheme',
        'raw-tour',
        // One source of truth, in two halves: the namespace that must not
        // come back, and the number that must not be typed.
        'token-namespace',
      ]),
    );
  });

  group('catalog-gutter — the catalog page must own its gutter', () {
    List<String> lintCatalog(String source) =>
        lintSource('lib/screens/design_system/component_page.dart', source);

    test('a DSSection without contentPadding fails', () {
      expect(
        idsOf(
          lintCatalog("""
              DSSection(
                label: story.title,
                child: Builder(builder: story.builder),
              );
"""),
        ),
        'catalog-gutter',
      );
    });

    test('a DSSection with contentPadding: EdgeInsets.zero still fails', () {
      // An explicit zero is a deliberate intent to ship edge-to-edge, and the
      // lint is here to make that visible at review.
      expect(
        idsOf(
          lintCatalog("""
              DSSection(
                label: story.title,
                contentPadding: EdgeInsets.zero,
                child: Builder(builder: story.builder),
              );
"""),
        ),
        'catalog-gutter',
      );
    });

    test('a DSSection with a horizontal contentPadding passes', () {
      expect(
        lintCatalog("""
            DSSection(
              label: story.title,
              contentPadding: EdgeInsets.fromLTRB(
                DSGutter.of(context),
                0,
                DSGutter.of(context),
                space.lg,
              ),
              child: Builder(builder: story.builder),
            );
"""),
        isEmpty,
      );
    });

    test('the rule does not speak about DSSection built elsewhere', () {
      // A DSSection in a screen file is the page's own choice; the rule is
      // scoped to the catalog host.
      expect(
        lintScreen("""
            DSSection(
              label: story.title,
              child: Builder(builder: story.builder),
            );
"""),
        isNot(contains('catalog-gutter')),
      );
    });

    test('a multi-line call is read whole, not line by line', () {
      // contentPadding: is the last argument and sits on its own line — a
      // line-based rule would miss it. The rule walks the call to its close.
      expect(
        idsOf(
          lintCatalog("""
              DSSection(
                label: story.title,
                child: Builder(builder: story.builder),
              );
"""),
        ),
        'catalog-gutter',
      );
      expect(
        lintCatalog("""
              DSSection(
                label: story.title,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: DSGutter.of(context),
                ),
                child: Builder(builder: story.builder),
              );
"""),
        isEmpty,
      );
    });
  });

  group('header-earns-its-height', () {
    String lint(String source) => lintSource(
      'lib/screens/demo_page.dart',
      source,
      applyDebt: false,
    ).where((f) => f.contains('header-earns-its-height')).join('\n');

    test('a title-only expanded header fails', () {
      expect(
        lint('''
          Widget build(BuildContext context) => const CustomScrollView(
            slivers: [DSLargeAppBar(title: 'Display')],
          );
        '''),
        contains('header-earns-its-height'),
      );
    });

    test('a subtitle is payload', () {
      expect(
        lint('''
          Widget build(BuildContext context) => const CustomScrollView(
            slivers: [
              DSLargeAppBar(title: 'Blog', subtitle: 'Five short essays.'),
            ],
          );
        '''),
        isEmpty,
      );
    });

    test('an eyebrow, a below, a background and actions are payload', () {
      for (final payload in [
        "eyebrow: 'Engineering'",
        'below: DSTabBar()',
        'background: ColoredBox(color: Colors.red)',
        'actions: [DSIconButton()]',
      ]) {
        expect(
          lint('''
            Widget build(BuildContext context) => CustomScrollView(
              slivers: [DSLargeAppBar(title: 'Blog', $payload)],
            );
          '''),
          isEmpty,
          reason: '$payload should be payload',
        );
      }
    });

    test('a leading button is not payload', () {
      // Almost every screen has one, so counting it would make the rule
      // vacuous — which is how three top-level destinations came to spend a
      // hundred points on a word the nav bar was already showing.
      expect(
        lint('''
          Widget build(BuildContext context) => CustomScrollView(
            slivers: [DSLargeAppBar(title: 'Settings', leading: BackButton())],
          );
        '''),
        contains('header-earns-its-height'),
      );
    });

    test('an empty actions list is not payload', () {
      expect(
        lint('''
          Widget build(BuildContext context) => const CustomScrollView(
            slivers: [DSLargeAppBar(title: 'Settings', actions: [])],
          );
        '''),
        contains('header-earns-its-height'),
      );
    });

    test('DSPageHeader.sliver is held to the same rule', () {
      expect(
        lint('''
          Widget build(BuildContext context) => const CustomScrollView(
            slivers: [DSPageHeader.sliver(title: 'Display')],
          );
        '''),
        contains('header-earns-its-height'),
      );
    });

    test('the compact bar is never flagged', () {
      expect(
        lint('''
          Widget build(BuildContext context) => const CustomScrollView(
            slivers: [DSCompactAppBar(title: 'Display')],
          );
        '''),
        isEmpty,
      );
    });

    test('the design system itself is exempt', () {
      expect(
        lintSource(
          'lib/design_system/ds_page_header.dart',
          "DSLargeAppBar(title: title)",
          applyDebt: false,
        ).where((f) => f.contains('header-earns-its-height')),
        isEmpty,
      );
    });
  });
}
