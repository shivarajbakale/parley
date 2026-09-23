import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/feature_plan.dart';
import '../../tool/plan_lint.dart';

/// The gate is pointed at a temporary tree rather than at this repository, so
/// each rule can be shown failing without breaking the project it protects. A
/// lint only ever exercised by damaging the real tree is a lint nobody
/// exercises.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('plan_lint_test');
    Directory('${root.path}/lib').createSync();
    File('${root.path}/feature_list.json').writeAsStringSync(
      jsonEncode({
        'features': [
          {'id': 'notes', 'status': 'in_progress'},
        ],
      }),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  Map<String, Object?> validPlan({String id = 'notes'}) => {
    'feature': {
      'id': id,
      'title': 'Notes',
      'problem': 'There is nowhere to keep what the reader finds.',
    },
    'surfaces': [
      {
        'id': 's',
        'name': 'Notes',
        'archetype': 'form',
        'primaryAction': 'Save',
        'panels': [
          {
            'fields': [
              {'label': 'Title', 'placeholder': 'Why the bar is chrome'},
            ],
          },
        ],
        'moments': {
          'peak': 'The title field is focused, so the first word goes in.',
          'end': 'Save returns to the note with the title on it.',
        },
        'states': {
          'loading': 'The fields render disabled.',
          'empty': 'A new note opens with the title focused.',
          'error': 'This note could not be saved.',
          'success': 'Save returns to the note.',
        },
      },
    ],
  };

  void writePlan(Map<String, Object?> plan, {String name = 'notes'}) => File(
    '${root.path}/$name.feature-plan.json',
  ).writeAsStringSync(jsonEncode(plan));

  void writeRendered(String md) =>
      File('${root.path}/FEATURE-PLAN.md').writeAsStringSync(md);

  String rulesOf(List<Violation> v) => v.map((x) => x.rule).join(',');

  test('a project with no plans has nothing to say', () {
    // Inert on a fresh scaffold. A gate that fails before anybody has planned
    // anything is a gate people disable on day one.
    expect(lintPlans(root), isEmpty);
  });

  test('a plan that will not validate fails P1', () {
    final plan = validPlan();
    (plan['feature'] as Map).remove('problem');
    writePlan(plan);
    final v = lintPlans(root);
    expect(rulesOf(v), 'P1');
    expect(v.single.message, contains('feature.problem'));
  });

  test('a plan that is not JSON fails P1 with the parse error', () {
    File('${root.path}/notes.feature-plan.json').writeAsStringSync('{ nope');
    final v = lintPlans(root);
    expect(rulesOf(v), 'P1');
    expect(v.single.message, contains('is not valid JSON'));
  });

  test('a valid, registered, freshly rendered plan passes', () {
    final plan = validPlan();
    writePlan(plan);
    writeRendered(renderFeaturePlanMarkdown(plan));
    expect(lintPlans(root), isEmpty);
  });

  test('a hand-edited FEATURE-PLAN.md fails P2', () {
    // The whole point of rendering it is that the document and the JSON cannot
    // diverge. One edited line and they have.
    final plan = validPlan();
    writePlan(plan);
    writeRendered(
      renderFeaturePlanMarkdown(
        plan,
      ).replaceFirst('# Notes', '# Notes (and a few other things)'),
    );
    final v = lintPlans(root);
    expect(rulesOf(v), 'P2');
    expect(v.single.message, contains('never hand-edit'));
  });

  test('a rendered plan with no source JSON fails P3', () {
    writeRendered('# Notes\n\nSome prose wearing a generated filename.\n');
    final v = lintPlans(root);
    expect(rulesOf(v), 'P3');
  });

  test('a plan nobody registered fails P4', () {
    writePlan(validPlan(id: 'sketches'), name: 'sketches');
    final v = lintPlans(root);
    expect(rulesOf(v), 'P4');
    expect(v.single.message, contains('"sketches"'));
  });

  test('a missing feature_list.json fails P4 rather than passing quietly', () {
    File('${root.path}/feature_list.json').deleteSync();
    writePlan(validPlan());
    final v = lintPlans(root);
    expect(rulesOf(v), 'P4');
    expect(v.single.message, contains('missing'));
  });

  test('an empty register still fails P4', () {
    // Readable-but-empty is the interesting case: a project with a plan and
    // nothing registered is exactly the drift P4 exists to catch, so the guard
    // is "did it parse", never "does it have rows".
    File(
      '${root.path}/feature_list.json',
    ).writeAsStringSync(jsonEncode({'features': <Object?>[]}));
    writePlan(validPlan());
    expect(rulesOf(lintPlans(root)), 'P4');
  });

  test('several plans coexist, and the rendered one only has to match one', () {
    final first = validPlan();
    final second = validPlan(id: 'notes');
    (second['feature'] as Map)['title'] = 'Notes, later';
    writePlan(first, name: 'notes');
    writePlan(second, name: 'notes-2');
    writeRendered(renderFeaturePlanMarkdown(second));
    expect(lintPlans(root), isEmpty);
  });
}
