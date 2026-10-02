// loop-lint tests — the Dart half of the shared corpus.
//
// `tool/loop_lint.dart` and `scripts/loop-lint.mjs` are the same seven-rule
// gate written twice. This test runs the Dart half against
// `tool/fixtures/shared-loop-lint-cases.json`, the same corpus the Node half
// runs against in `__tests__/flutter-loop-lint-gate.test.ts`. A rule added to
// one language and forgotten in the other goes red on both sides.
//
// Two layers:
//
//   1. This project's own dialect — `dart run` and `flutter test` resolve, npm
//      does not. That half cannot live in the shared corpus, because a case
//      that passed here only because the Node side cannot parse the command
//      would be a corpus hiding the drift it exists to catch.
//   2. The full shared corpus, every case, against this implementation.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/loop_lint.dart';

Directory _tempTree() => Directory.systemTemp.createTempSync('loop-lint-test-');

/// The corpus writes `"@schema"` where the real shipped schema belongs, so the
/// cases cannot carry a stale copy of the file L7 is about.
String get _shippedSchema =>
    File('docs/loops/loop-state.schema.json').readAsStringSync();

void _writeTree(Directory root, Map<String, dynamic> files) {
  for (final entry in files.entries) {
    final f = File('${root.path}/${entry.key}');
    f.parent.createSync(recursive: true);
    final body = entry.value as String;
    f.writeAsStringSync(body == '@schema' ? _shippedSchema : body);
  }
}

Map<String, dynamic> _goal({
  String feature = 'feature-002',
  List<Map<String, dynamic>>? verification,
}) => {
  'feature': feature,
  'outcome': 'A merchant can archive an order without opening it.',
  'scope': ['the archive action on the list'],
  'exclusions': ['bulk archive'],
  'verification':
      verification ??
      [
        {'id': 'gate', 'check': 'the chain is green', 'command': 'make check'},
      ],
};

void main() {
  group("L2 — this project's own command dialect", () {
    test(
      'resolves a make target that exists, and refuses one that does not',
      () {
        final root = _tempTree();
        _writeTree(root, {'Makefile': 'check:\n\ttrue\n'});
        expect(resolveCommand('make check', root).ok, isTrue);
        expect(resolveCommand('make ui-probe', root).ok, isFalse);
        root.deleteSync(recursive: true);
      },
    );

    test('resolves `dart run tool/<file>` only when the file is there', () {
      final root = _tempTree();
      _writeTree(root, {'tool/ui_lint.dart': '// present\n'});
      expect(resolveCommand('dart run tool/ui_lint.dart', root).ok, isTrue);
      expect(resolveCommand('dart run tool/nope.dart', root).ok, isFalse);
      root.deleteSync(recursive: true);
    });

    test(
      'accepts `flutter test` and `flutter analyze` — no file to point at',
      () {
        final root = _tempTree();
        expect(resolveCommand('flutter test', root).ok, isTrue);
        expect(resolveCommand('flutter analyze', root).ok, isTrue);
        root.deleteSync(recursive: true);
      },
    );

    test(
      'fails closed on a form it cannot confirm, rather than passing it',
      () {
        final root = _tempTree();
        // npm is the other dialect's, and there is no npm in this check chain.
        // A gate that shrugged at an unknown form would restore the exact hole
        // the contract exists to close.
        final npm = resolveCommand('npm test', root);
        expect(npm.ok, isFalse);
        expect(npm.reason, contains('record it as an `observation`'));
        root.deleteSync(recursive: true);
      },
    );
  });

  group('L8 — the feature in flight has a contract, once opted in', () {
    List<String> rulesFor(Map<String, dynamic> files) {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'docs/loops/loop-state.schema.json': '@schema',
        ...files,
      });
      final out = lintLoops(root).violations.map((v) => v.rule).toList();
      root.deleteSync(recursive: true);
      return out;
    }

    const optedIn =
        '{"rules":{"require_goal_contracts":true},"features":[{"id":"feature-002","status":"in_progress"}]}';

    test('does not ask a project without the flag for one', () {
      expect(
        rulesFor({
          'feature_list.json': '[{"id":"feature-002","status":"in_progress"}]',
        }),
        isNot(contains('L8')),
      );
    });

    test('flags an in_progress feature with no contract once opted in', () {
      expect(rulesFor({'feature_list.json': optedIn}), contains('L8'));
    });

    test('passes an opted-in project whose in_progress feature has one', () {
      expect(
        rulesFor({
          'feature_list.json': optedIn,
          'docs/loops/feature-002.goal.json': jsonEncode(_goal()),
        }),
        isNot(contains('L8')),
      );
    });
  });

  group('the rules, one at a time', () {
    test('a well-formed contract with no loop state yet is fine', () {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'feature_list.json': '[{"id":"feature-002","status":"in_progress"}]\n',
        'docs/loops/loop-state.schema.json': '@schema',
        'docs/loops/feature-002.goal.json': jsonEncode(_goal()),
      });
      expect(lintLoops(root).violations, isEmpty);
      root.deleteSync(recursive: true);
    });

    test('L1 fires on a check that carries both instruments', () {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'feature_list.json': '[{"id":"feature-002","status":"in_progress"}]\n',
        'docs/loops/loop-state.schema.json': '@schema',
        'docs/loops/feature-002.goal.json': jsonEncode(
          _goal(
            verification: [
              {
                'id': 'gate',
                'check': 'green',
                'command': 'make check',
                'observation': 'and someone looks',
              },
            ],
          ),
        ),
      });
      expect(
        lintLoops(root).violations.map((v) => v.message).join('\n'),
        contains('pick the instrument'),
      );
      root.deleteSync(recursive: true);
    });

    test('L1 fires on two checks sharing an id', () {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'feature_list.json': '[{"id":"feature-002","status":"in_progress"}]\n',
        'docs/loops/loop-state.schema.json': '@schema',
        'docs/loops/feature-002.goal.json': jsonEncode(
          _goal(
            verification: [
              {'id': 'gate', 'check': 'green', 'command': 'make check'},
              {'id': 'gate', 'check': 'still green', 'command': 'make check'},
            ],
          ),
        ),
      });
      expect(
        lintLoops(root).violations.map((v) => v.message).join('\n'),
        contains('reuses the id `gate`'),
      );
      root.deleteSync(recursive: true);
    });

    test('L5 fires on a result for a check the contract does not have', () {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'feature_list.json': '[{"id":"feature-002","status":"in_progress"}]\n',
        'docs/loops/loop-state.schema.json': '@schema',
        'docs/loops/feature-002.goal.json': jsonEncode(_goal()),
        'docs/loops/feature-002.loop-state.json': jsonEncode({
          'feature': 'feature-002',
          'satisfied': false,
          'cycles': [
            {
              'n': 1,
              'maker': 'did a thing',
              'checker': {
                'verdict': 'fail',
                'results': [
                  {'id': 'invented', 'exit': 1},
                ],
              },
            },
          ],
        }),
      });
      expect(
        lintLoops(root).violations.map((v) => v.message).join('\n'),
        contains('which the goal does not check'),
      );
      root.deleteSync(recursive: true);
    });

    test('says nothing at all about a project with no docs/loops', () {
      final root = _tempTree();
      _writeTree(root, {'Makefile': 'check:\n\ttrue\n'});
      final result = lintLoops(root);
      expect(result.hasLoopsDir, isFalse);
      expect(result.violations, isEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('the shared corpus', () {
    final corpus =
        jsonDecode(
              File(
                'tool/fixtures/shared-loop-lint-cases.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();

    test('has cases for every rule L1..L7', () {
      final covered = <String>{};
      for (final c in cases) {
        for (final v
            in (c['violations'] as List).cast<Map<String, dynamic>>()) {
          covered.add(v['rule'] as String);
        }
      }
      expect(covered, containsAll(['L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7']));
    });

    for (final c in cases) {
      test('${c['case']} — ${c['why']}', () {
        final root = _tempTree();
        _writeTree(root, (c['files'] as Map).cast<String, dynamic>());
        final violations = lintLoops(root).violations;
        final rendered = violations
            .map((v) => '[${v.rule}] ${v.message}')
            .join('\n');

        if (c['expect'] == 'pass') {
          expect(
            violations,
            isEmpty,
            reason: 'expected no violations, got:\n$rendered',
          );
        } else {
          for (final want
              in (c['violations'] as List).cast<Map<String, dynamic>>()) {
            final matching = violations.where(
              (v) =>
                  v.rule == want['rule'] &&
                  v.message.contains(want['match'] as String),
            );
            expect(
              matching,
              isNotEmpty,
              reason:
                  'expected ${want['rule']} matching "${want['match']}", got:\n$rendered',
            );
          }
        }
        root.deleteSync(recursive: true);
      });
    }
  });

  group('the shipped artifacts', () {
    test('this project ships the schema, and it satisfies L7', () {
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n',
        'docs/loops/loop-state.schema.json': '@schema',
      });
      expect(lintLoops(root).violations.where((v) => v.rule == 'L7'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('the shipped goal template is itself a contract that passes', () {
      // The template is skipped by name in a real project, so nothing else
      // would catch it going stale — and it is the file every contract is
      // copied from, which makes a broken one the most expensive kind.
      final template = File('docs/loops/goal-template.json').readAsStringSync();
      final decoded = jsonDecode(template) as Map<String, dynamic>;
      final root = _tempTree();
      _writeTree(root, {
        'Makefile': 'check:\n\ttrue\n\ntest:\n\ttrue\n',
        'feature_list.json': jsonEncode([
          {'id': decoded['feature'], 'status': 'in_progress'},
        ]),
        'docs/loops/loop-state.schema.json': '@schema',
        'docs/loops/${decoded['feature']}.goal.json': template,
      });
      // The template's commands are `make` targets on purpose: one template
      // ships to thirteen projects in two command dialects, and `make` is the
      // only form all of them resolve.
      final violations = lintLoops(root).violations;
      expect(
        violations,
        isEmpty,
        reason: violations.map((v) => v.toString()).join('\n'),
      );
      root.deleteSync(recursive: true);
    });
  });
}
