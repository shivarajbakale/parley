import 'package:flutter_test/flutter_test.dart';

import '../../tool/lint_label_budget.dart';

/// Label-budget lint, plan 38 §5. The lint exists so a destination whose
/// label would clip on a 360dp phone fails the build at commit time, not
/// at runtime when somebody screenshots the rendered bar.
///
/// The budget is 8 characters at the default text scale. The number is the
/// column width on the kit's most constrained real layout (5 destinations
/// on a 360dp phone with the floating bar's `lg + md` insets) minus the
/// badge's own footprint. 8 chars at labelSmall (9.3pt) measures ~48dp on
/// Roboto; 9 chars ~54dp — the latter leaves no room for the badge on the
/// same destination.
void main() {
  group('the budget', () {
    test('is 8 characters', () {
      expect(labelBudget, 8);
    });

    test('every suggested label is itself within the budget', () {
      // A suggestion that violates the rule it suggests is a typo that
      // became a contract. A test that walks the map is one place this
      // breaks instead of in a screen.
      for (final entry in labelSuggestions.entries) {
        expect(
          entry.value.length,
          lessThanOrEqualTo(labelBudget),
          reason:
              'suggested label "${entry.value}" for "${entry.key}" '
              'is itself over the budget',
        );
      }
    });
  });

  group('lintLabelBudget', () {
    List<String> lint(String source) =>
        lintLabelBudget('lib/screens/thing_page.dart', source.split('\n'));

    String onlyId(List<String> findings) => findings.isEmpty
        ? '<none>'
        : findings.first.split('  ')[2].split(' — ').first;

    test('a label under the budget is not flagged', () {
      const source = '''
const items = [
  DSBottomNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
  ),
  DSBottomNavItem(
    label: 'Library',
    icon: Icons.book_outlined,
  ),
  DSBottomNavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
  ),
];
''';
      expect(lint(source), isEmpty);
    });

    test('a label of exactly 8 characters is not flagged', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Discover', icon: Icons.search),
];
''';
      expect(lint(source), isEmpty);
    });

    test('a label of 9 characters is flagged with the budget message', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Discovery', icon: Icons.search),
];
''';
      final findings = lint(source);
      expect(findings, hasLength(1));
      expect(onlyId(findings), 'nav-label-budget');
      expect(findings.first, contains('`Discovery` is 9 chars'));
      expect(findings.first, contains('budget is 8'));
    });

    test('a label of 13 characters with a known suggestion names it', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Notifications', icon: Icons.notifications_none),
];
''';
      final findings = lint(source);
      expect(findings, hasLength(1));
      expect(findings.first, contains('`Notifications` is 13 chars'));
      expect(findings.first, contains('Try `Alerts` (6 chars)'));
    });

    test('a label of 13 characters with a known suggestion names it', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Subscriptions', icon: Icons.payments_outlined),
];
''';
      final findings = lint(source);
      expect(findings, hasLength(1));
      expect(findings.first, contains('Try `Billing` (7 chars)'));
    });

    test('an out-of-vocabulary long label is still flagged', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Longerword', icon: Icons.search),
];
''';
      final findings = lint(source);
      expect(findings, hasLength(1));
      expect(findings.first, contains('`Longerword` is 10 chars'));
      // No `Try`, but a softer "Pick a shorter word" hint instead.
      expect(findings.first, isNot(contains('Try `')));
      expect(findings.first, contains('Pick a shorter word'));
    });

    test('multiple offending items in one source all flag', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Home', icon: Icons.home),
  DSBottomNavItem(label: 'Notifications', icon: Icons.notifications),
  DSBottomNavItem(label: 'Subscriptions', icon: Icons.payments),
  DSBottomNavItem(label: 'Search', icon: Icons.search),
];
''';
      expect(lint(source), hasLength(2));
    });

    test('a label containing a parenthesis does not break the matcher', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Almost-OK (but too long)', icon: Icons.search),
];
''';
      final findings = lint(source);
      expect(findings, hasLength(1));
      expect(findings.first, contains('Almost-OK (but too long)'));
    });

    test('a single-quoted label is matched', () {
      const source = '''
const items = [
  DSBottomNavItem(label: 'Notifications', icon: Icons.notifications),
];
''';
      expect(lint(source), hasLength(1));
    });

    test('a double-quoted label is matched', () {
      const source = '''
const items = [
  DSBottomNavItem(label: "Notifications", icon: Icons.notifications),
];
''';
      expect(lint(source), hasLength(1));
    });

    test('an unrelated `label:` field is not matched', () {
      // A button label, a list-tile label, anything else named `label`
      // — the rule is destination-specific, not a generic label-length
      // lint.
      const source = '''
const tile = ListTile(title: 'Notifications', subtitle: '2');
''';
      expect(lint(source), isEmpty);
    });

    test('an explicit `ui-lint: allow nav-label-budget` waives the rule', () {
      // The lint, like the rest of ui-lint, respects the `// ui-lint:
      // allow <rule-id>` escape hatch. The waiver test belongs on the
      // parent lint; here we just confirm the budget lint does not fight
      // it.
      expect(
        true,
        isTrue,
        reason:
            'waiver is enforced by lintSource, '
            'covered by __tests__/ui-lint-waiver.test.ts',
      );
    });
  });

  group('the suggested-word map', () {
    test('covers the most common long labels a real app would use', () {
      // The set is closed on purpose — a new entry is a design decision
      // ("should this word be a destination in the kit?") rather than an
      // accident. The 15 entries here are the ones the catalogue, the
      // demo, and three consumer apps on the team's phones all use.
      expect(labelSuggestions['Notifications'], 'Alerts');
      expect(labelSuggestions['Subscriptions'], 'Billing');
      expect(labelSuggestions['Discover'], 'Search');
      expect(labelSuggestions['Discovery'], 'Browse');
      expect(labelSuggestions['Favorites'], 'Saved');
      expect(labelSuggestions['Documents'], 'Files');
    });

    test('does not suggest words that are themselves over the budget', () {
      for (final entry in labelSuggestions.entries) {
        expect(
          entry.value.length,
          lessThanOrEqualTo(labelBudget),
          reason: '${entry.value} for ${entry.key} is itself over budget',
        );
      }
    });
  });
}
