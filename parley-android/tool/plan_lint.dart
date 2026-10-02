// plan-lint — the planning artifact is a checked artifact, not a note.
//
// The `plan-feature` skill says the plan JSON is the source of truth, that
// FEATURE-PLAN.md is generated and must never be hand-edited, and that the
// feature gets registered in feature_list.json. Without this gate all three
// are honour-system prose: the validator can only be reached by running the
// renderer by hand, which nothing requires.
//
// The rules:
//
//   P1  Every `*.feature-plan.json` at the project root passes the same
//       validator the renderer uses — a plan that cannot be drawn is not a plan.
//   P2  A committed FEATURE-PLAN.md matches a fresh render of its source plan.
//       This is the hand-edit check: the document that was approved and the
//       document the JSON produces have to be the same bytes.
//   P3  No orphan FEATURE-PLAN.md — a rendered plan with no source JSON cannot
//       be re-rendered, reviewed or diffed, so it is prose wearing a filename.
//   P4  Every root plan's `feature.id` is registered in feature_list.json.
//       A plan nobody tracked is a plan nobody will verify.
//
// Inert on a fresh scaffold — no plans, nothing to check. It bites the moment
// somebody plans, which is exactly when the drift starts.
//
// Run: `dart run tool/plan_lint.dart` (part of `make check`).

import 'dart:convert';
import 'dart:io';

import 'feature_plan.dart';

class Violation {
  final String rule;
  final String message;

  const Violation(this.rule, this.message);

  @override
  String toString() => '  [$rule] $message';
}

/// The gate as a function of a directory, so a test can point it at a fixture
/// tree instead of at the repository it is running in. A lint that can only be
/// exercised by breaking the project is a lint nobody exercises.
List<Violation> lintPlans(Directory root) {
  final violations = <Violation>[];
  void fail(String rule, String message) =>
      violations.add(Violation(rule, message));

  final planFiles =
      root
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.feature-plan.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String rel(File f) => f.uri.pathSegments.last;

  final rendered = File('${root.path}/FEATURE-PLAN.md');
  final hasRendered = rendered.existsSync();

  // --- P1: every plan validates ---------------------------------------------

  final plans = <MapEntry<File, Map>>[];
  for (final file in planFiles) {
    Object? plan;
    try {
      plan = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      fail('P1', '${rel(file)} is not valid JSON: ${e.message}');
      continue;
    }
    final errors = validateFeaturePlan(plan);
    if (errors.isNotEmpty) {
      for (final e in errors) {
        fail('P1', '${rel(file)}: $e');
      }
      continue;
    }
    plans.add(MapEntry(file, plan! as Map));
  }

  // --- P2/P3: the rendered document tracks its source ------------------------

  if (hasRendered) {
    final committed = rendered.readAsStringSync();
    if (plans.isEmpty && planFiles.isEmpty) {
      fail(
        'P3',
        'FEATURE-PLAN.md exists but no *.feature-plan.json sits beside it — '
            'the rendered plan cannot be regenerated or diffed. Write the source '
            'JSON (see the plan-feature skill) or delete the document.',
      );
    } else if (plans.isNotEmpty) {
      final matched = plans.any((entry) {
        try {
          return renderFeaturePlanMarkdown(entry.value) == committed;
        } catch (_) {
          return false;
        }
      });
      if (!matched) {
        final names = plans.map((e) => rel(e.key)).join(', ');
        fail(
          'P2',
          'FEATURE-PLAN.md does not match a fresh render of any of: $names. '
              'The document is generated — never hand-edit it. Edit the JSON and '
              're-render: dart run tool/feature_plan.dart <plan>.feature-plan.json '
              '-o FEATURE-PLAN.md',
        );
      }
    }
  }

  // --- P4: the plan is a tracked feature -------------------------------------

  if (plans.isNotEmpty) {
    final listFile = File('${root.path}/feature_list.json');
    if (!listFile.existsSync()) {
      fail(
        'P4',
        'feature_list.json is missing — a plan needs a feature to hang off.',
      );
    } else {
      // Readable-but-empty is the interesting case: a project with a plan and
      // nothing registered is exactly the drift P4 exists to catch, so the
      // guard is "did it parse", never "does it have rows".
      Set<String>? known;
      try {
        final decoded = jsonDecode(listFile.readAsStringSync());
        final features = decoded is List
            ? decoded
            : (decoded is Map
                  ? (decoded['features'] as List? ?? const [])
                  : const []);
        known = features
            .whereType<Map>()
            .map((f) => f['id'])
            .whereType<String>()
            .toSet();
      } on FormatException catch (e) {
        fail('P4', 'feature_list.json is not valid JSON: ${e.message}');
      }
      if (known != null) {
        for (final entry in plans) {
          final id = (entry.value['feature'] as Map)['id'];
          if (id is String && !known.contains(id)) {
            fail(
              'P4',
              '${rel(entry.key)} plans "$id", which is not registered in '
                  'feature_list.json — add the feature so the plan has something '
                  'to be verified against.',
            );
          }
        }
      }
    }
  }

  return violations;
}

/// The count of valid plans in [root], for the summary line.
int _validPlanCount(Directory root) => root
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.feature-plan.json'))
    .where((f) {
      try {
        return validateFeaturePlan(jsonDecode(f.readAsStringSync())).isEmpty;
      } catch (_) {
        return false;
      }
    })
    .length;

void main() {
  final root = Directory.current;
  if (!Directory('${root.path}/lib').existsSync()) {
    stderr.writeln('plan-lint: no lib/ directory — run from the project root.');
    exit(1);
  }

  final violations = lintPlans(root);
  if (violations.isNotEmpty) {
    stderr.writeln('plan-lint: ${violations.length} violation(s)\n');
    for (final v in violations) {
      stderr.writeln(v.toString());
    }
    stderr.writeln('');
    exit(1);
  }

  final checked = _validPlanCount(root);
  final synced = File('${root.path}/FEATURE-PLAN.md').existsSync()
      ? ', FEATURE-PLAN.md in sync'
      : '';
  stdout.writeln(
    checked == 0
        ? 'plan-lint: no feature plans to check (0 violations)'
        : 'plan-lint: $checked plan(s) valid$synced (0 violations)',
  );
}
