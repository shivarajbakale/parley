import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The gate that stops a component joining the kit with no test.
///
/// The kit already has three gates a new component must pass: the barrel must
/// export it (`ui_lint`'s barrel-drift rule), the generated reference must
/// carry hand-written `Use when` / `Instead` guidance (a component with no
/// entry fails `design_system_reference.dart`), and the catalog must show it.
/// All three are about *finding* the component. None of them asks whether it
/// works.
///
/// This one does: every file in `lib/design_system/` must have its primary
/// component named somewhere under `test/`. Deliberately a weak bar — naming a
/// widget in one `expect` satisfies it — because the alternative bars are
/// unmeasurable. What it actually prevents is the specific thing that keeps
/// happening: a component lands with its story, its reference entry and its
/// export, and the test is left for later.
///
/// It reads the source rather than a hand-maintained list, so the list cannot
/// go stale — a new file is in scope the moment it exists.
void main() {
  /// Files under `lib/design_system/` that are not components.
  ///
  /// Each entry is a claim that the file has nothing a widget test could
  /// mount, and each one carries the reason. Adding a line here is the escape
  /// hatch; adding one for a real component is how this gate stops working.
  const notComponents = <String, String>{
    'design_system.dart': 'the barrel — it declares nothing of its own',
    'ds_component_style.dart':
        'the base class every style object extends. It has no widget: it is '
        'exercised through every component that implements it, and '
        'component_contract_test.dart asserts that contract directly.',
    'ds_text_style.dart':
        'the text style chain — the DSTextRole enum, DSTextStyle and '
        'DSTextRole.styleOf. It has no widget of its own: DSText draws it, '
        'and it is a file rather than part of ds_text.dart because a tier-0 '
        'style class has to be able to name a role and the widget is a '
        'tier-1 atom. type_tokens_test.dart covers the roles as values and '
        'ds_text_test.dart covers what the widget makes of them.',
    'ds_page_header_style.dart':
        'DSPageHeader\'s style object, and nothing else. It lives in a file '
        'of its own because the two app bars resolve it and the header '
        'composes them, which was an import cycle for as long as the class '
        'sat beside the widget. ds_page_header_test.dart covers it.',
  };

  test('every component in the kit is named by at least one test', () {
    final sources =
        Directory('lib/design_system')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final tests = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // This file names no component itself, and counting it would let it
        // satisfy its own rule.
        .where((f) => !f.path.endsWith('component_coverage_test.dart'));

    final corpus = tests.map((f) => f.readAsStringSync()).join('\n');

    final classDecl = RegExp(r'^class (DS\w+)', multiLine: true);
    final missing = <String>[];
    final empty = <String>[];

    for (final source in sources) {
      final name = source.uri.pathSegments.last;
      // A leading underscore is the kit's own "private to the design system"
      // convention, the same one the barrel-drift rule uses.
      if (name.startsWith('_')) continue;
      if (notComponents.containsKey(name)) continue;

      final declared = classDecl
          .allMatches(source.readAsStringSync())
          .map((m) => m.group(1)!)
          // A style object is data, and it is covered by the component that
          // resolves it.
          .where((c) => !c.endsWith('Style'))
          .toList();

      if (declared.isEmpty) {
        empty.add(name);
        continue;
      }

      final named = declared.any((c) => RegExp('\\b$c\\b').hasMatch(corpus));
      if (!named) missing.add('$name (${declared.join(', ')})');
    }

    expect(
      empty,
      isEmpty,
      reason:
          'These files declare no public DS class, so either they are not '
          'components — add them to notComponents with the reason — or the '
          'class is misnamed:\n  ${empty.join('\n  ')}',
    );
    expect(
      missing,
      isEmpty,
      reason:
          'These components are exported, documented and shown in the '
          'catalog, and no test mounts them:\n  ${missing.join('\n  ')}',
    );
  });
}
