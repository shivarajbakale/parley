import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_ds_catalog.dart';

/// The catalog is what a superplan's `kit:` references resolve against, so a
/// component the generator drops is a component no plan can legally name —
/// and nothing else in `make check` notices, because the drift gate only
/// compares the catalog to itself. These tests hold the generator's two
/// judgement calls: what counts as plumbing, and where a doc clause ends.
void main() {
  _tiersBelongToComponents();
  group('what counts as plumbing', () {
    test('a theme extension and the render plumbing are not components', () {
      expect(excludeByName('DSButtonStyle'), isTrue);
      expect(excludeByName('DSChartPainter'), isTrue);
      expect(excludeByName('DSBottomInsetsHost'), isTrue);
      expect(excludeByName('DSBottomSlotReporter'), isTrue);
    });

    test('a state is a component, not a Flutter State subclass', () {
      // `State` was once a blanket exclusion. A Flutter `State` subclass
      // extends `State<Foo>` and is already rejected for not being a widget,
      // so the suffix only removed the two states a screen actually shows.
      expect(excludeByName('DSEmptyState'), isFalse);
      expect(excludeByName('DSErrorState'), isFalse);
    });

    test('the shimmer wrapper is citable, its per-kit variants are not', () {
      expect(excludeByName('DSSkeleton'), isFalse);
      expect(excludeByName('DSCardSkeleton'), isTrue);
      expect(excludeByName('DSMediaTileSkeleton'), isTrue);
    });
  });

  group('the kind a name implies', () {
    test('a state is feedback, not grouping', () {
      expect(kindOf('DSEmptyState'), 'feedback');
      expect(kindOf('DSErrorState'), 'feedback');
    });

    test('the grouping rule still reads a stat', () {
      expect(kindOf('DSStatTile'), 'row');
      expect(kindOf('DSSection'), 'grouping');
    });
  });

  group('where a doc clause ends', () {
    test('a wrapped clause runs to its full stop, not to the line break', () {
      final s = summariseDoc('''
Nothing to show — and which kind of nothing.

**Use when** the list is
legitimately empty. **Instead:** [DSErrorState] when something failed,
`DSSkeleton` while it is still coming.
''');
      expect(s.useWhen, 'the list is legitimately empty');
      expect(
        s.instead,
        '[DSErrorState] when something failed, `DSSkeleton` while it is '
        'still coming',
      );
    });

    test('a clause with no full stop stops at the paragraph', () {
      final s = summariseDoc('''
A summary.

**Use when** the row is text-led

Another paragraph entirely.
''');
      expect(s.useWhen, 'the row is text-led');
    });

    test('the summary is the first paragraph, on one line', () {
      final s = summariseDoc('''
Something failed, and what
to do about it.

The rest.
''');
      expect(s.summary, 'Something failed, and what to do about it.');
    });
  });

  group('the catalog on disk', () {
    late List<Map<String, Object?>> components;

    setUpAll(() {
      final raw = File('tool/fixtures/ds-catalog.json').readAsStringSync();
      components = ((jsonDecode(raw) as Map)['components'] as List)
          .cast<Map<String, Object?>>();
    });

    test('the states a screen shows are citable kit', () {
      final kits = components.map((c) => c['kit']).toSet();
      expect(kits, containsAll(['DSEmptyState', 'DSErrorState', 'DSSkeleton']));
    });

    test('no clause was cut mid-sentence', () {
      for (final c in components) {
        for (final field in ['useWhen', 'instead']) {
          final v = c[field] as String?;
          if (v == null) continue;
          expect(
            v.endsWith(','),
            isFalse,
            reason: '${c['kit']}.$field ends on a comma: "$v"',
          );
        }
      }
    });
  });
}

/// The layer a component occupies is a fact about the component.
///
/// The `ds-tier` marker is one line at the top of a file, and every class in
/// that file used to inherit it — so all 154 catalog entries were labelled by
/// their filename. A chevron was a molecule for sharing a file with a list
/// tile; a separator was an organism for sharing one with a select. The
/// catalog is what the plan tools and the component-selection guidance read,
/// so those labels were not decoration.
void _tiersBelongToComponents() {
  final catalog =
      jsonDecode(File('tool/fixtures/ds-catalog.json').readAsStringSync())
          as Map<String, dynamic>;
  final components = (catalog['components'] as List)
      .cast<Map<String, dynamic>>();
  String tierOf(String kit) =>
      components.firstWhere((c) => c['kit'] == kit)['tier'] as String;
  String fileOf(String kit) =>
      components.firstWhere((c) => c['kit'] == kit)['file'] as String;

  group('a component carries its own tier', () {
    test('a small part is an atom even in a molecule\'s file', () {
      // Each of these draws one thing and is used by the component it sits
      // beside. Sharing a file is not composition.
      for (final part in const [
        'DSChevron',
        'DSListTileMeta',
        'DSListTileWell',
        'DSTabCount',
        'DSSegmentCount',
        'DSStatTileDelta',
        'DSStatTileMark',
        'DSDialogIcon',
        'DSMetricBarLegend',
        'DSMediaMeta',
        'DSCardHelperText',
      ]) {
        expect(
          tierOf(part),
          'atom',
          reason: '$part is in ${fileOf(part)} and took that file\'s label',
        );
      }
      // And a separator is an atom wherever it lives, including the two files
      // whose other classes are an organism and a molecule.
      expect(tierOf('DSSelectSeparator'), 'atom');
      expect(tierOf('DSMenuSeparator'), 'atom');
    });

    test('a class with no marker of its own still takes its file\'s', () {
      // The override is the exception, not the new rule: 134 of the 154
      // entries have no marker and are labelled by their file exactly as
      // before.
      expect(tierOf('DSListTile'), 'molecule');
      expect(tierOf('DSSelect'), 'organism');
      expect(tierOf('DSPage'), 'template');
      expect(tierOf('DSPressable'), 'foundation');
    });

    test('and the distribution moved by exactly the parts that were '
        'mislabelled', () {
      final counts = <String, int>{};
      for (final c in components) {
        counts[c['tier'] as String] = (counts[c['tier'] as String] ?? 0) + 1;
      }
      // Was {molecule: 78, atom: 52, organism: 14, foundation: 5, template: 5}.
      // Eighteen parts moved down and nothing moved up. Two of the twenty
      // markers changed no label — ds_chip.dart is itself tier 1, so its
      // count and avatar were already atoms — and they are written anyway,
      // because a marker that says what a class is does not become wrong
      // when the file around it is moved.
      //
      // Three more moved down in flutter-076, and the floor rule is what
      // found them: DSSwitch drew its whole surface with a CustomPainter and
      // composed nothing but a foundation, so molecule to atom; DSSidebar and
      // DSSidebarHeader assemble atoms exactly as DSBottomNavBar does one
      // tier below them, so organism to molecule. Atoms 70 to 71, organisms
      // 13 to 11, molecules 61 to 62 — the sidebar file contributes three
      // entries to the molecules and the switch takes one away. Nothing
      // moved up, which is still the direction that would mean a component
      // had escaped a check rather than earned a layer.
      //
      // ds_select.dart split into itself, `_ds_select_style.dart`,
      // `_ds_select_parts.dart` and `_ds_select_list.dart`. `DSSelectOption`
      // and `DSSelectSection` had been carrying the whole file's organism
      // marker with them; in the atom-tier parts file they read as what they
      // always were. `DSSelectList` and `DSSelectTrigger` are new to the
      // catalog rather than relabelled — as `_SelectList` and
      // `_SelectTrigger` their names never matched a `DS` class, so the
      // generator had never seen them. Atoms 71 to 73, organisms 11 to 9,
      // molecules 62 to 64, total 154 to 156.
      //
      // Then `DSRevealItem` was removed with `ds_stagger.dart`: nothing in
      // the kit animates content in any more. One atom fewer, 73 to 72,
      // total 156 to 155.
      //
      // Then the Note demo went, and `ds_editor_bar.dart` with it:
      // `DSSaveIndicator` an atom and `DSEditorBar` a molecule. Atoms 72 to
      // 71, molecules 64 to 63, total 155 to 153.
      // `DSGround` joined as an atom: the page's colour wash, and
      // `DSGroundSlice` beside it, the band that paints its slice. Atoms 71 to
      // 73, total 153 to 155.
      expect(counts['atom'], 73);
      expect(counts['molecule'], 63);
      expect(counts['organism'], 9);
      expect(counts['foundation'], 5);
      expect(counts['template'], 5);
      expect(components, hasLength(155));
    });
  });
}
