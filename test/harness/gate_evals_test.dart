import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ui_lint.dart';

/// The harness evaluated against itself: does every gate rule have proof it
/// can fail?
///
/// A rule nobody has watched fire is indistinguishable from a rule whose
/// pattern stopped matching. Seven `ui_lint` rules were in that state when
/// this file was written — `raw-card`, `raw-dialog` and five others were
/// declared, enforced in `make check`, and never once exercised. So this does
/// two things:
///
///   1. runs each seeded defect in `tool/fixtures/gate-evals.json` through the
///      real rule and requires the named id to fire;
///   2. reads the rule ids each gate *declares* and fails on any that neither
///      that corpus nor the gate's own test mentions — so a rule added next
///      month without a failing case goes red here, not never.
void main() {
  final corpus =
      jsonDecode(File('tool/fixtures/gate-evals.json').readAsStringSync())
          as Map<String, dynamic>;
  final uiCases = (corpus['ui-lint'] as List).cast<Map<String, dynamic>>();

  List<String> idsOf(List<String> findings) =>
      findings.map((f) => f.split('  ')[2].split(' — ').first).toList();

  group('seeded defects fire', () {
    for (final c in uiCases) {
      test('ui-lint ${c['rule']}: ${c['why']}', () {
        final findings = lintSource(
          c['path'] as String,
          c['source'] as String,
          applyDebt: false,
        );
        expect(idsOf(findings), contains(c['rule']));
      });
    }
  });

  group('every declared rule has a failing case', () {
    test('ui-lint', () {
      final declared = RegExp(r"^\s*id: '([a-z0-9-]+)',", multiLine: true)
          .allMatches(File('tool/ui_lint.dart').readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, isNotEmpty, reason: 'rule ids no longer parse');
      final seeded = uiCases.map((c) => c['rule']).toSet();
      final unitTest = File('test/tool/ui_lint_test.dart').readAsStringSync();
      final unproven = declared
          .where((id) => !seeded.contains(id) && !unitTest.contains(id))
          .toList();
      expect(
        unproven,
        isEmpty,
        reason:
            'declared in tool/ui_lint.dart but never seen failing — add a '
            'case to tool/fixtures/gate-evals.json',
      );
    });

    // The lettered gates share a shape: `'X1'` literals in the tool, asserted
    // either in the gate's test or in the shared corpus that test replays.
    const lettered = {
      'plan_lint': ('P', <String>[]),
      'doc_lint': ('D', ['tool/fixtures/shared-doc-lint-cases.json']),
      'loop_lint': ('L', ['tool/fixtures/shared-loop-lint-cases.json']),
      'superplan_lint': ('S', <String>[]),
    };
    lettered.forEach((gate, spec) {
      final (letter, corpora) = spec;
      test(gate, () {
        final declared = RegExp("'($letter\\d+)'")
            .allMatches(File('tool/$gate.dart').readAsStringSync())
            .map((m) => m.group(1)!)
            .toSet();
        expect(declared, isNotEmpty, reason: 'rule ids no longer parse');
        final evidence = [
          File('test/tool/${gate}_test.dart').readAsStringSync(),
          for (final path in corpora) File(path).readAsStringSync(),
        ].join('\n');
        final unproven = declared
            .where((id) => !RegExp('\\b$id\\b').hasMatch(evidence))
            .toList();
        expect(unproven, isEmpty, reason: '$gate rules with no failing case');
      });
    });
  });
}
