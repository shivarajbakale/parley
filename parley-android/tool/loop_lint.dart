// loop-lint — was the definition of done written before the work, and did
// anything actually run against it?
//
// This is the Dart half of one contract. `scripts/loop-lint.mjs` is the other,
// and every Node scaffolder ships it; this project's check chain has no Node in
// it, so the rules are written twice. Two implementations of one contract
// drift, and `tool/fixtures/shared-loop-lint-cases.json` is what stops them
// drifting silently: both halves are run against the same bytes and have to
// reject the same things for the same reasons.
//
// What the gate is for: `make check` is a fixed chain. It cannot know that this
// feature's empty state has to render when the list is empty, or that a person
// was meant to look at the screen. So the feature-specific half of "done" gets
// settled at the end, by whoever is holding the diff, and it is settled in
// favour of the diff every time. A goal contract moves that decision to the
// front, into a file written first and diffed like any other.
//
//   docs/loops/<feature-id>.goal.json         outcome, scope, exclusions, checks
//   docs/loops/<feature-id>.loop-state.json   what each cycle did, and returned
//
// The rules:
//
//   L1  the goal contract is well-formed — outcome, scope, exclusions, checks
//   L2  every check names a command this project can actually run
//   L3  the goal names a feature the register knows about
//   L4  the loop state is well-formed and its cycles are numbered
//   L5  a claimed pass is backed by a result per check, and a loop has a contract
//   L6  the register and the loop do not disagree about whether this is done
//   L7  the shipped schema and this gate agree about the shape they both own
//   L8  once a project has opted into goal contracts, the feature in flight has one
//
// L8 is opt-in: `rules.require_goal_contracts: true` in feature_list.json. From
// then on every `in_progress` feature needs `docs/loops/<id>.goal.json`.
// `passing` features are history and are never asked for one retroactively.
//
// Inert in a project with no contracts, and bites on the first one. Inert is
// loud, though: a run that checked nothing prints WARN, because "0 violations"
// over zero files reads like a pass. A gate that
// demanded a contract for work already finished would fail on arrival and get
// switched off, which is worse than not having it.
//
// Run: `dart run tool/loop_lint.dart` (part of `make check`).

import 'dart:convert';
import 'dart:io';

const loopsDir = 'docs/loops';

/// The four files a fresh project ships. They are templates, not contracts, so
/// the rules skip them — a rule that failed on the seed the harness itself
/// installed would be red in every project on day one.
const templateFiles = <String>{
  'goal-template.json',
  'loop-state.schema.json',
  'maker-prompt.md',
  'checker-prompt.md',
};

const verdicts = <String>{'pass', 'fail'};

/// The keys the rules below actually demand, at each level of the shape. L7
/// compares the shipped schema against this, because a schema beside the files
/// it describes is a second description of one artifact, and this repository
/// has lost days to a gate holding its own copy of a list the tree maintains.
const schemaContract = <String, List<String>>{
  '': ['cycles', 'feature', 'satisfied'],
  'cycles[]': ['checker', 'maker', 'n'],
  'cycles[].checker': ['results', 'verdict'],
};

class Violation {
  final String rule;
  final String message;

  const Violation(this.rule, this.message);

  @override
  String toString() => '  [$rule] $message';
}

bool _nonEmpty(Object? value) => value is String && value.trim().isNotEmpty;

bool _stringList(Object? value) =>
    value is List && value.isNotEmpty && value.every(_nonEmpty);

/// The dialect this project's commands are written in. Flutter's chain has no
/// npm in it, so `make` and `dart run` are the two forms that can be confirmed
/// here — and anything else fails closed, because a form this cannot confirm is
/// a form it cannot vouch for, and reporting "ok" would restore the exact hole
/// the contract exists to close.
({bool ok, String reason}) resolveCommand(String command, Directory project) {
  final cmd = command.trim();
  if (cmd.isEmpty) return (ok: false, reason: 'is empty');

  final make = RegExp(r'^make\s+([a-zA-Z0-9_.-]+)$').firstMatch(cmd);
  if (make != null) {
    final target = make.group(1)!;
    final makefile = File('${project.path}/Makefile');
    if (!makefile.existsSync()) {
      return (ok: false, reason: 'there is no Makefile');
    }
    final declared = RegExp(
      '^\\.?${RegExp.escape(target)}\\s*:',
      multiLine: true,
    ).hasMatch(makefile.readAsStringSync());
    return declared
        ? (ok: true, reason: '')
        : (ok: false, reason: 'the Makefile has no `$target` target');
  }

  final dart = RegExp(r'^dart\s+run\s+([^\s]+)').firstMatch(cmd);
  if (dart != null) {
    final script = dart.group(1)!;
    return File('${project.path}/$script').existsSync()
        ? (ok: true, reason: '')
        : (ok: false, reason: '$script is not there');
  }

  if (RegExp(r'^flutter\s+(test|analyze)\b').hasMatch(cmd)) {
    return (ok: true, reason: '');
  }

  return (
    ok: false,
    reason:
        'loop-lint can confirm `make <target>`, `dart run <file>`, `flutter test` '
        'and `flutter analyze`. Rewrite it as one of those, or record it as an '
        '`observation` so it is clear a person is the instrument',
  );
}

/// L1.
List<Violation> goalShapeViolations(Object? goal, String file) {
  final out = <Violation>[];
  void at(String message) => out.add(Violation('L1', '$file: $message'));

  if (goal is! Map) {
    at('is not a JSON object');
    return out;
  }
  if (!_nonEmpty(goal['feature'])) at('has no `feature` id');
  if (!_nonEmpty(goal['outcome'])) {
    at('has no `outcome` — one sentence naming what is true when this is done');
  }
  if (!_stringList(goal['scope'])) at('has no `scope` list');
  if (!_stringList(goal['exclusions'])) {
    at(
      'has no `exclusions` — a contract that excludes nothing has not been '
      'thought about, and every scope argument it was supposed to settle is '
      'still ahead of you',
    );
  }
  final checks = goal['verification'];
  if (checks is! List || checks.isEmpty) {
    at('has no `verification` checks');
    return out;
  }

  final seen = <String>{};
  for (var i = 0; i < checks.length; i++) {
    final check = checks[i];
    final label = 'verification[$i]';
    if (check is! Map) {
      at('$label is not an object');
      continue;
    }
    if (!_nonEmpty(check['id'])) {
      at('$label has no `id`');
    } else if (!seen.add(check['id'] as String)) {
      at('$label reuses the id `${check['id']}`');
    }
    if (!_nonEmpty(check['check'])) {
      at('$label has no `check` — what this proves, in a sentence');
    }
    final hasCommand = _nonEmpty(check['command']);
    final hasObservation = _nonEmpty(check['observation']);
    if (hasCommand && hasObservation) {
      at(
        '$label has both a `command` and an `observation` — pick the instrument',
      );
    } else if (!hasCommand && !hasObservation) {
      at('$label has neither a `command` nor an `observation`');
    }
  }
  return out;
}

/// L4. The cycle numbering is not bookkeeping: an out-of-order `n` is what a
/// loop state looks like when it was written at the end from memory.
List<Violation> loopStateShapeViolations(Object? state, String file) {
  final out = <Violation>[];
  void at(String message) => out.add(Violation('L4', '$file: $message'));

  if (state is! Map) {
    at('is not a JSON object');
    return out;
  }
  if (!_nonEmpty(state['feature'])) at('has no `feature` id');
  if (state['satisfied'] is! bool) at('has no boolean `satisfied`');
  final cycles = state['cycles'];
  if (cycles is! List || cycles.isEmpty) {
    at('has no `cycles` — a loop that ran zero times is not a loop');
    return out;
  }

  for (var i = 0; i < cycles.length; i++) {
    final cycle = cycles[i];
    final label = 'cycles[$i]';
    if (cycle is! Map) {
      at('$label is not an object');
      continue;
    }
    if (cycle['n'] != i + 1) {
      at('$label is numbered ${jsonEncode(cycle['n'])}, expected ${i + 1}');
    }
    if (!_nonEmpty(cycle['maker'])) at('$label has no `maker` note');
    final checker = cycle['checker'];
    if (checker is! Map) {
      at('$label has no `checker`');
      continue;
    }
    if (!verdicts.contains(checker['verdict'])) {
      at(
        '$label.checker.verdict is ${jsonEncode(checker['verdict'])}, '
        'expected "pass" or "fail"',
      );
    }
    if (checker['results'] is! List) {
      at('$label.checker has no `results` array');
    }
  }
  return out;
}

/// L5. A verdict is a claim; a result per check, with the exit code the command
/// returned, is the evidence for it. Without this a loop state is a field that
/// says "pass".
List<Violation> verdictViolations(Object? goal, Object? state, String file) {
  final out = <Violation>[];
  void at(String message) => out.add(Violation('L5', '$file: $message'));

  final checks = <String, Map>{};
  final declared = (goal is Map ? goal['verification'] : null);
  if (declared is List) {
    for (final check in declared) {
      if (check is Map && _nonEmpty(check['id'])) {
        checks[check['id'] as String] = check;
      }
    }
  }

  final cycles = (state is Map ? state['cycles'] : null);
  if (cycles is! List) return out;

  for (final cycle in cycles) {
    if (cycle is! Map) continue;
    final checker = cycle['checker'];
    final results = (checker is Map ? checker['results'] : null);
    final list = results is List ? results : const [];

    for (final result in list) {
      final id = result is Map ? result['id'] : null;
      if (!checks.containsKey(id)) {
        at(
          'cycle ${cycle['n']} records a result for `$id`, '
          'which the goal does not check',
        );
      }
    }
    if (checker is! Map || checker['verdict'] != 'pass') continue;

    final byId = <String, Map>{};
    for (final result in list) {
      if (result is Map && _nonEmpty(result['id'])) {
        byId[result['id'] as String] = result;
      }
    }
    for (final entry in checks.entries) {
      final result = byId[entry.key];
      if (result == null) {
        at('cycle ${cycle['n']} passed without running `${entry.key}`');
        continue;
      }
      if (_nonEmpty(entry.value['command'])) {
        if (result['exit'] != 0) {
          at(
            'cycle ${cycle['n']} passed while `${entry.key}` exited '
            '${jsonEncode(result['exit'])} — a passing verdict needs every '
            'command at 0',
          );
        }
      } else if (!_nonEmpty(result['note'])) {
        at(
          'cycle ${cycle['n']} passed `${entry.key}` with no note, and it is '
          'an observation a person makes',
        );
      }
    }
  }
  return out;
}

/// L7.
List<Violation> schemaViolations(Object? schema, String file) {
  final out = <Violation>[];
  void at(String message) => out.add(Violation('L7', '$file: $message'));

  Object? dig(Object? node, List<String> path) {
    var current = node;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  final found = <String, Object?>{
    '': dig(schema, ['required']),
    'cycles[]': dig(schema, ['properties', 'cycles', 'items', 'required']),
    'cycles[].checker': dig(schema, [
      'properties',
      'cycles',
      'items',
      'properties',
      'checker',
      'required',
    ]),
  };

  for (final entry in schemaContract.entries) {
    final where = entry.key.isEmpty ? 'the root' : entry.key;
    final actual = found[entry.key];
    if (actual is! List) {
      at(
        '$where declares no `required` list, and the gate demands ${entry.value.join(', ')}',
      );
      continue;
    }
    final sorted = actual.map((e) => '$e').toList()..sort();
    if (sorted.join(',') != entry.value.join(',')) {
      final have = sorted.isEmpty ? 'nothing' : sorted.join(', ');
      at(
        '$where requires $have while the gate demands ${entry.value.join(', ')} '
        '— the schema and loop-lint have drifted',
      );
    }
  }
  return out;
}

// ------------------------------------------------------------------ register --

Map<String, String> _registerStatuses(Directory root) {
  final out = <String, String>{};
  final file = File('${root.path}/feature_list.json');
  if (!file.existsSync()) return out;
  Object? parsed;
  try {
    parsed = jsonDecode(file.readAsStringSync());
  } on FormatException {
    return out;
  }
  final features = parsed is List
      ? parsed
      : (parsed is Map && parsed['features'] is List
            ? parsed['features'] as List
            : const []);
  for (final feature in features) {
    if (feature is Map && _nonEmpty(feature['id'])) {
      out[feature['id'] as String] = '${feature['status']}';
    }
  }
  return out;
}

/// L8's inputs: whether the register opted into goal contracts, and which
/// features are in flight.
({bool requireGoals, List<String> inProgress}) _registerOptIn(Directory root) {
  final file = File('${root.path}/feature_list.json');
  if (!file.existsSync()) return (requireGoals: false, inProgress: const []);
  Object? parsed;
  try {
    parsed = jsonDecode(file.readAsStringSync());
  } on FormatException {
    return (requireGoals: false, inProgress: const []);
  }
  final rules = parsed is Map ? parsed['rules'] : null;
  final requireGoals = rules is Map && rules['require_goal_contracts'] == true;
  final features = parsed is List
      ? parsed
      : (parsed is Map && parsed['features'] is List
            ? parsed['features'] as List
            : const []);
  final inProgress = [
    for (final f in features)
      if (f is Map && f['status'] == 'in_progress' && _nonEmpty(f['id']))
        f['id'] as String,
  ];
  return (requireGoals: requireGoals, inProgress: inProgress);
}

/// An archived feature is gone from the register on purpose — the prelude does
/// not pay for finished work — so its contract is still legitimate.
Set<String> _archivedIds(Directory root) {
  final file = File('${root.path}/docs/history/completed-features.md');
  if (!file.existsSync()) return {};
  return RegExp(
    r'\b([a-z][a-z0-9]*(?:-[a-z0-9]+)*-\d{3,})\b',
  ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toSet();
}

// ---------------------------------------------------------------------- lint --

class LoopLintResult {
  final List<Violation> violations;
  final bool hasLoopsDir;
  final int goals;
  final int states;

  const LoopLintResult(
    this.violations,
    this.hasLoopsDir,
    this.goals,
    this.states,
  );
}

/// The gate as a function of a directory, so a test can point it at a fixture
/// tree instead of at the repository it runs in.
LoopLintResult lintLoops(Directory root) {
  final violations = <Violation>[];
  final dir = Directory('${root.path}/$loopsDir');
  if (!dir.existsSync()) return LoopLintResult(violations, false, 0, 0);

  final goals = <String, Object?>{};
  final states = <String, Object?>{};

  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (!name.endsWith('.json') || templateFiles.contains(name)) continue;
    final rel = '$loopsDir/$name';
    Object? parsed;
    try {
      parsed = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      violations.add(Violation('L1', '$rel does not parse: ${e.message}'));
      continue;
    }
    if (name.endsWith('.loop-state.json')) {
      states[name.substring(0, name.length - '.loop-state.json'.length)] =
          parsed;
    } else if (name.endsWith('.goal.json')) {
      goals[name.substring(0, name.length - '.goal.json'.length)] = parsed;
    } else {
      violations.add(
        Violation(
          'L1',
          '$rel is neither `<feature-id>.goal.json` nor '
              '`<feature-id>.loop-state.json`, so nothing pairs it with a feature',
        ),
      );
    }
  }

  final schemaFile = File('${dir.path}/loop-state.schema.json');
  if (!schemaFile.existsSync()) {
    violations.add(
      const Violation(
        'L7',
        '$loopsDir/loop-state.schema.json is missing — the shape these files are written against',
      ),
    );
  } else {
    try {
      violations.addAll(
        schemaViolations(
          jsonDecode(schemaFile.readAsStringSync()),
          '$loopsDir/loop-state.schema.json',
        ),
      );
    } on FormatException catch (e) {
      violations.add(
        Violation(
          'L7',
          '$loopsDir/loop-state.schema.json does not parse: ${e.message}',
        ),
      );
    }
  }

  final statuses = _registerStatuses(root);

  // L8 — the feature in flight has a contract, once the project has opted in.
  final register = _registerOptIn(root);
  if (register.requireGoals) {
    for (final id in register.inProgress) {
      if (!goals.containsKey(id)) {
        violations.add(
          Violation(
            'L8',
            '$id is `in_progress` with no $loopsDir/$id.goal.json — this project writes '
                'the definition of done before the work (copy goal-template.json)',
          ),
        );
      }
    }
  }
  final archived = _archivedIds(root);

  for (final key in goals.keys.toList()..sort()) {
    final goal = goals[key];
    final rel = '$loopsDir/$key.goal.json';
    final shape = goalShapeViolations(goal, rel);
    violations.addAll(shape);

    final named = goal is Map && _nonEmpty(goal['feature'])
        ? goal['feature'] as String
        : null;
    if (named != null && named != key) {
      violations.add(
        Violation(
          'L1',
          '$rel is named for `$key` but its `feature` is `$named`',
        ),
      );
    }

    if (shape.isEmpty) {
      for (final check in (goal as Map)['verification'] as List) {
        final command = (check as Map)['command'];
        if (!_nonEmpty(command)) continue;
        final resolved = resolveCommand(command as String, root);
        if (!resolved.ok) {
          violations.add(
            Violation(
              'L2',
              '$rel: check `${check['id']}` runs `$command`, but ${resolved.reason}',
            ),
          );
        }
      }
    }

    final id = named ?? key;
    if (statuses.isNotEmpty &&
        !statuses.containsKey(id) &&
        !archived.contains(id)) {
      violations.add(
        Violation(
          'L3',
          '$rel is a contract for `$id`, which is in neither feature_list.json nor '
              'docs/history/completed-features.md — nothing will ever verify it',
        ),
      );
    }

    if (statuses[id] == 'passing') {
      final state = states[key];
      if (state == null) {
        violations.add(
          Violation(
            'L6',
            '$id is `passing` in the register and has a goal contract but no loop state',
          ),
        );
      } else if (!(state is Map && state['satisfied'] == true)) {
        violations.add(
          Violation(
            'L6',
            '$id is `passing` in the register while $loopsDir/$key.loop-state.json '
                'says `satisfied: false`',
          ),
        );
      }
    }
  }

  for (final key in states.keys.toList()..sort()) {
    final state = states[key];
    final rel = '$loopsDir/$key.loop-state.json';
    if (!goals.containsKey(key)) {
      violations.add(
        Violation(
          'L5',
          '$rel has no $loopsDir/$key.goal.json — a loop with no contract checked nothing',
        ),
      );
      continue;
    }
    final goal = goals[key];
    final shape = loopStateShapeViolations(state, rel);
    violations.addAll(shape);

    final stateFeature = state is Map ? state['feature'] : null;
    final goalFeature = goal is Map ? goal['feature'] : null;
    if (_nonEmpty(stateFeature) &&
        _nonEmpty(goalFeature) &&
        stateFeature != goalFeature) {
      violations.add(
        Violation(
          'L4',
          '$rel names `$stateFeature` while its goal names `$goalFeature`',
        ),
      );
    }
    if (shape.isEmpty) violations.addAll(verdictViolations(goal, state, rel));

    if (state is Map && state['satisfied'] == true) {
      final cycles = state['cycles'];
      if (cycles is List && cycles.isNotEmpty) {
        final last = cycles.last;
        final verdict = last is Map && last['checker'] is Map
            ? (last['checker'] as Map)['verdict']
            : null;
        if (verdict != 'pass') {
          violations.add(
            Violation(
              'L5',
              '$rel is satisfied while its last cycle\'s verdict is ${jsonEncode(verdict)}',
            ),
          );
        }
      }
    }
  }

  return LoopLintResult(violations, true, goals.length, states.length);
}

void main(List<String> args) {
  final root = Directory(
    args.firstWhere((a) => !a.startsWith('--'), orElse: () => '.'),
  );
  final result = lintLoops(root);

  if (!result.hasLoopsDir) {
    stdout.writeln('loop-lint: WARN 0 checked — no $loopsDir/ here, nothing to check.');
    exit(0);
  }
  if (result.goals == 0 && result.states == 0 && result.violations.isEmpty) {
    stdout.writeln(
      'loop-lint: WARN 0 checked — no goal contracts yet. The gate is inert until the first one — '
      'see $loopsDir/goal-template.json.',
    );
    exit(0);
  }

  stdout.writeln(
    '\nloop-lint — ${result.goals} goal contract(s), ${result.states} loop state(s)\n',
  );
  for (final v in result.violations) {
    stdout.writeln(v.toString());
  }
  stdout.writeln('\n${result.violations.length} violation(s).');
  exit(result.violations.isEmpty ? 0 : 1);
}
