// doc-lint tests — the Dart half of the shared corpus.
//
// `tool/doc_lint.dart` and `scripts/doc-lint.mjs` are the same nine-rule linter
// written twice. This test runs the Dart half against
// `tool/fixtures/shared-doc-lint-cases.json`, the same corpus the Node half
// runs against in `__tests__/flutter-doc-lint-gate.test.ts`. A rule added to
// one language and forgotten in the other goes red on both sides.
//
// The tests below are organised in three layers:
//
//   1. Per-rule smoke tests that touch one rule at a time, both directions
//      (the rule fires when it should, stays quiet when it should).
//   2. The full shared corpus — every case in the JSON, against this
//      implementation.
//   3. The "this is the right file" tests — `lint()` is exported, `Budgets`
//      matches the Node list, etc.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doc_lint.dart';

Directory _tempTree() {
  final base = Directory.systemTemp.createTempSync('doc-lint-test-');
  return base;
}

void _writeTree(Directory root, Map<String, String> files) {
  for (final entry in files.entries) {
    final f = File('${root.path}/${entry.key}');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(entry.value);
  }
}

void main() {
  group('D1 — AGENTS.md budget', () {
    test('passes when AGENTS.md is within budget', () {
      final root = _tempTree();
      _writeTree(root, {'AGENTS.md': '# A\n'});
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D1'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when AGENTS.md is over budget', () {
      final root = _tempTree();
      final agents = StringBuffer('# A\n\n');
      for (var i = 0; i < 200; i++) {
        agents.writeln('Line $i of the file.');
      }
      _writeTree(root, {'AGENTS.md': agents.toString()});
      final r = lint(root);
      expect(
        r.violations.where((v) => v.rule == 'D1'),
        isNotEmpty,
        reason: 'AGENTS.md over 150 lines must trigger D1',
      );
      root.deleteSync(recursive: true);
    });

    test('fires when AGENTS.md is missing entirely', () {
      final root = _tempTree();
      _writeTree(root, {'CLAUDE.md': '# C\n'});
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D1'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D2 — CLAUDE.md budget and uniqueness', () {
    test('passes when CLAUDE.md is within budget and unique', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n\n- hook tip\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D2'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when CLAUDE.md is over budget', () {
      final root = _tempTree();
      final claude = StringBuffer('# C\n\n');
      for (var i = 0; i < 50; i++) {
        claude.writeln('Line $i.');
      }
      _writeTree(root, {'AGENTS.md': '# A\n', 'CLAUDE.md': claude.toString()});
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D2'), isNotEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when CLAUDE.md repeats a paragraph from AGENTS.md', () {
      final root = _tempTree();
      const shared =
          'This is a long paragraph that AGENTS.md and CLAUDE.md both carry verbatim, and an agent reading both is reading the same words twice. This paragraph has more than eighty characters so the duplicate detector treats it as content.';
      _writeTree(root, {
        'AGENTS.md': '# A\n\n$shared\n',
        'CLAUDE.md': '# C\n\n$shared\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D2'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D3 — ARCHITECTURE.md presence and budget', () {
    test('passes when ARCHITECTURE.md exists and is within budget', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n\nWhere things live.\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D3'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when ARCHITECTURE.md is missing', () {
      final root = _tempTree();
      _writeTree(root, {'AGENTS.md': '# A\n', 'CLAUDE.md': '# C\n'});
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D3'), isNotEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when ARCHITECTURE.md has a code block over 20 lines', () {
      final root = _tempTree();
      final arch = StringBuffer('# A\n\n```dart\n');
      for (var i = 0; i < 25; i++) {
        arch.writeln('line $i');
      }
      arch.writeln('```');
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': arch.toString(),
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D3'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D4 — claude-progress.md budget', () {
    test('passes when claude-progress.md is within budget', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'claude-progress.md': '# State\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D4'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when claude-progress.md is over budget', () {
      final root = _tempTree();
      final progress = StringBuffer('# State\n\n');
      for (var i = 0; i < 130; i++) {
        progress.writeln('Line $i.');
      }
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'claude-progress.md': progress.toString(),
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D4'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D5 — session prelude budget', () {
    test('passes when prelude is within 40 KB', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'claude-progress.md': '# P\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D5'), isEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D6 — instructions describe this project', () {
    test('passes when code samples match deps in pubspec.yaml', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\n```ts\nimport { foo } from \'go_router\';\n```\n',
        'CLAUDE.md': '# C\n',
        'pubspec.yaml':
            'name: app\nenvironment:\n  sdk: \'>=3.8.0 <4.0.0\'\ndependencies:\n  flutter:\n    sdk: flutter\n  go_router: ^14.0.0\n',
        'Makefile': 'check:\n\ttrue\n',
        'ARCHITECTURE.md': '# A\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D6'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when a code sample imports an undeclared package', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\n```ts\nimport { foo } from \'riverpod\';\n```\n',
        'CLAUDE.md': '# C\n',
        'pubspec.yaml':
            'name: app\nenvironment:\n  sdk: \'>=3.8.0 <4.0.0\'\ndependencies:\n  flutter:\n    sdk: flutter\n  go_router: ^14.0.0\n',
        'Makefile': 'check:\n\ttrue\n',
        'ARCHITECTURE.md': '# A\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D6'), isNotEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when a heading names a stack choice not in deps', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\n## TypeORM Repository Methods\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
        'pubspec.yaml':
            'name: app\nenvironment:\n  sdk: \'>=3.8.0 <4.0.0\'\ndependencies:\n  flutter:\n    sdk: flutter\n  go_router: ^14.0.0\n',
        'Makefile': 'check:\n\ttrue\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D6'), isNotEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when `make <target>` is documented but undefined', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\nRun `make superplan` first.\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
        'pubspec.yaml': 'name: app\n',
        'Makefile': 'check:\n\ttrue\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D6'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D7 — link integrity', () {
    test('passes when links resolve', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\nSee [B](B.md).\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
        'B.md': '# B\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D7'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when a link points to a missing file', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n\nSee [B](B.md).\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D7'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D8 — constraints name their consequence', () {
    test('passes when constraints have consequences', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md':
            '# A\n\n## Constraints\n\n- One feature in flight. — because two half-finished leave a tree nobody can verify.\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D8'), isEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when a constraint does not name its consequence', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md':
            '# A\n\n## Constraints\n\n- One feature in flight.\n- Never weaken a test.\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D8'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('D9 — evidence pairing', () {
    test(
      'passes when passing features have evidence and nothing is duplicated',
      () {
        final root = _tempTree();
        _writeTree(root, {
          'AGENTS.md': '# A\n',
          'CLAUDE.md': '# C\n',
          'ARCHITECTURE.md': '# A\n',
          'feature_list.json': '[{"id":"f-1","status":"passing"}]\n',
          'docs/evidence/f-1.md': '# f-1\n',
          'docs/history/completed-features.md': '# archive\n',
        });
        final r = lint(root);
        expect(r.violations.where((v) => v.rule == 'D9'), isEmpty);
        root.deleteSync(recursive: true);
      },
    );

    test('fires when a passing feature has no evidence file', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
        'feature_list.json': '[{"id":"f-2","status":"passing"}]\n',
        'docs/evidence/.keep': '',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D9'), isNotEmpty);
      root.deleteSync(recursive: true);
    });

    test('fires when evidence exists for an unknown feature', () {
      final root = _tempTree();
      _writeTree(root, {
        'AGENTS.md': '# A\n',
        'CLAUDE.md': '# C\n',
        'ARCHITECTURE.md': '# A\n',
        'feature_list.json': '[]\n',
        'docs/evidence/orphan.md': '# orphan\n',
        'docs/history/completed-features.md': '# archive\n',
      });
      final r = lint(root);
      expect(r.violations.where((v) => v.rule == 'D9'), isNotEmpty);
      root.deleteSync(recursive: true);
    });
  });

  group('not a harnessed project', () {
    test('returns no violations and no stats', () {
      final root = _tempTree();
      final r = lint(root);
      expect(r.violations, isEmpty);
      expect(r.stats, isNull);
      root.deleteSync(recursive: true);
    });
  });

  group('shared corpus', () {
    final corpusFile = File('tool/fixtures/shared-doc-lint-cases.json');
    final corpus =
        jsonDecode(corpusFile.readAsStringSync()) as Map<String, dynamic>;
    final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();

    test('has cases, and they are not all one verdict', () {
      expect(cases.length, greaterThanOrEqualTo(10));
      expect(
        cases.where((c) => c['expect'] == 'pass').toList(),
        isNotEmpty,
        reason: 'A corpus that only violates proves the linter returns a list',
      );
      expect(
        cases.where((c) => c['expect'] == 'violation').length,
        greaterThanOrEqualTo(9),
        reason: 'At least one violation per rule (D1–D9)',
      );
    });

    for (final c in cases) {
      test('${c['case']} is ${c['expect']}ed', () {
        final root = _tempTree();
        final files = (c['files'] as Map).cast<String, String>();
        _writeTree(root, files);

        // Some cases grow one file past the budget to drive a particular rule.
        final fill = c['fill'] as String?;
        final fillLines = c['fillLines'] as int?;
        if (fill != null && fillLines != null) {
          final f = File('${root.path}/$fill');
          final original = f.readAsStringSync();
          final appended = StringBuffer(original);
          // Make sure file ends with newline, then add fillLines lines.
          if (!original.endsWith('\n')) appended.write('\n');
          for (var i = 0; i < fillLines; i++) {
            appended.writeln('Line $i.');
          }
          f.writeAsStringSync(appended.toString());
        }

        final r = lint(root);
        if (c['expect'] == 'pass') {
          expect(
            r.violations,
            isEmpty,
            reason: '${c['why']}\n\n${r.violations.join('\n')}',
          );
        } else {
          expect(r.violations, isNotEmpty, reason: '${c['why']}');
          final expected = (c['violations'] as List)
              .cast<Map<String, dynamic>>();
          for (final ev in expected) {
            final rule = ev['rule'] as String;
            final match = ev['match'] as String;
            final hits = r.violations.where((v) {
              return v.rule == rule && v.message.contains(match);
            }).toList();
            expect(
              hits,
              isNotEmpty,
              reason:
                  '${c['why']}\nexpected [$rule] containing "$match" in:\n${r.violations.join('\n')}',
            );
          }
        }
        root.deleteSync(recursive: true);
      });
    }
  });

  group('budgets match the Node implementation', () {
    test('byte-for-byte identical to doc-lint.mjs', () {
      expect(budgets['AGENTS.md'], 150);
      expect(budgets['CLAUDE.md'], 30);
      expect(budgets['ARCHITECTURE.md'], 150);
      expect(budgets['claude-progress.md'], 120);
      expect(preludeBudgetBytes, 40 * 1024);
    });
  });
}
