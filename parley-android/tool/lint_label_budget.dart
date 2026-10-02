// Label-budget lint — DSBottomNavItem's label is a budget.
//
// Plan 15 already wrote the rule in prose: "One or two words — a label that
// wraps at the default text size is a label for a different control." Plan
// 38 makes it mechanical: every `DSBottomNavItem(label: '...')` whose label
// exceeds the budget fails `ui-lint`, with a suggested shorter word for the
// most common offenders.
//
// The budget is 8 characters at the default text scale. The number is the
// column width on the kit's most constrained real layout (5 destinations
// on a 360dp phone with the floating bar's `lg + md` insets) minus the
// badge's own footprint (a count badge reserves up to 10dp of the column's
// right edge). 8 chars at labelSmall (9.3pt) measures ~48dp; 9 chars
// ~54dp — the latter leaves no room for the badge on the same destination.
//
// Out-of-vocabulary labels still fail the budget, just without a suggested
// shorter word. The rule is non-blocking by default; `--strict` (the same
// flag the other lint rules respect) fails the build.
//
// Run: `dart run tool/ui_lint.dart` (the budget rule is wired into the
// kit's `ui-lint` check; this file is its home so a test can exercise the
// map and the matcher without spinning up the full lint).

import 'dart:io';

/// The maximum number of characters in a destination label at the default
/// text scale. Plan 38 §5.
const int labelBudget = 8;

/// Long labels with a known shorter alternative. The suggested word is the
/// fix-it hint; the rule still fails the build (or the report, in
/// non-strict mode) for an out-of-vocabulary label.
const Map<String, String> _suggested = {
  'Notifications': 'Alerts',
  'Subscription': 'Plan',
  'Subscriptions': 'Billing',
  'Discover': 'Search',
  'Discovery': 'Browse',
  'Activity': 'Feed',
  'Favorites': 'Saved',
  'Documents': 'Files',
  'Resources': 'Links',
  'Conversations': 'Chats',
  'Communities': 'Groups',
  'Categories': 'Tags',
  'Everything': 'All',
  'Bookmarks': 'Saved',
  'Highlights': 'Pinned',
};

/// The suggested-word map. Exposed so a test can assert the suggestion set
/// has not silently shrunk, and so a downstream doc generator can render
/// the table.
Map<String, String> get labelSuggestions => _suggested;

/// The diagnostic. The shape matches the rest of `ui-lint`:
///   FAIL  <path>:<line>  nav-label-budget — <message>
String labelBudgetDiagnostic({
  required String path,
  required int line,
  required String label,
}) {
  final suggestion = _suggested[label];
  final base = '`$label` is ${label.length} chars; budget is $labelBudget. '
      'A label that fits at the default scale on a 360dp phone is one a '
      'screen-reader user can announce in one breath.';
  final fix = suggestion != null
      ? " Try `$suggestion` (${suggestion.length} chars)."
      : ' Pick a shorter word from the same domain — the kit\'s other '
            'destinations are 4–8 chars for a reason.';
  return 'FAIL  $path:${line + 1}  nav-label-budget — $base$fix';
}

/// The rule, as a function of the source. Returns the diagnostic strings,
/// one per offending `DSBottomNavItem(label: '...')` site.
///
/// `path` is included in the diagnostic; `lines` is the file already split
/// on `\n` so call sites that already have it (the parent `lintSource`)
/// don't pay for the split twice.
List<String> lintLabelBudget(String path, List<String> lines) {
  final findings = <String>[];
  final call = RegExp(r'DSBottomNavItem\s*\(');
  // `label:\s*['"]([^'"]+)['"]` — the label string, captured.
  final labelField = RegExp(
    r"""label\s*:\s*(?:r?['"])([^'"]+)(?:['"])""",
  );

  for (var i = 0; i < lines.length; i++) {
    if (!call.hasMatch(lines[i])) continue;
    // Find the closing `)` — naive paren count, with a guard for string
    // literals so a `label: 'foo)'` doesn't end the match early. The
    // budget lint only checks the `label` field, not the rest of the
    // constructor, so any false positive past the label is harmless.
    var depth = 0;
    var found = false;
    for (var j = i; j < lines.length && !found; j++) {
      var inString = false;
      var stringDelimiter = '';
      for (var k = 0; k < lines[j].length; k++) {
        final c = lines[j][k];
        if (inString) {
          if (c == stringDelimiter && (k == 0 || lines[j][k - 1] != r'\')) {
            inString = false;
          }
          continue;
        }
        if (c == "'" || c == '"') {
          inString = true;
          stringDelimiter = c;
          continue;
        }
        if (c == '(') depth++;
        if (c == ')') {
          depth--;
          if (depth == 0) {
            final block = lines.sublist(i, j + 1).join('\n');
            final m = labelField.firstMatch(block);
            if (m != null) {
              final label = m.group(1)!;
              if (label.length > labelBudget) {
                findings.add(
                  labelBudgetDiagnostic(
                    path: path,
                    line: i,
                    label: label,
                  ),
                );
              }
            }
            found = true;
            break;
          }
        }
      }
    }
  }

  return findings;
}

void main(List<String> args) {
  if (args.isEmpty || args[0] == '--help') {
    stderr.writeln(
      'lint_label_budget: scans the kit for DSBottomNavItem(labels) '
      'longer than $labelBudget characters.\n'
      '  Usage: dart run tool/lint_label_budget.dart <paths...>',
    );
    exit(args.isEmpty ? 1 : 0);
  }

  var scanned = 0;
  var violations = 0;
  for (final arg in args) {
    final file = File(arg);
    if (!file.existsSync()) continue;
    scanned++;
    final lines = file.readAsStringSync().split('\n');
    final findings = lintLabelBudget(arg, lines);
    for (final f in findings) {
      stderr.writeln(f);
      violations++;
    }
  }
  stdout.writeln(
    'lint_label_budget: $scanned file(s) scanned, $violations violation(s)',
  );
  exit(violations > 0 ? 1 : 0);
}
