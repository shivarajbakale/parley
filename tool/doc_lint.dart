// doc-lint — how much does a session cost before it does anything, and is any
// of it false?
//
// The Node implementation in `scripts/doc-lint.mjs` runs across ten scaffold
// source trees and at the repository root. This is the Dart implementation:
// the same nine rules (D1..D9), firing the same way, so a Flutter project can
// hold the budget where the work actually happens. The shared fixture corpus
// at `tool/fixtures/shared-doc-lint-cases.json` pins the two implementations
// against the same inputs — a rule added to one language and forgotten in the
// other goes red on both.
//
// Rules:
//
//   D1  AGENTS.md is within budget
//   D2  CLAUDE.md is within budget and is not a copy of AGENTS.md
//   D3  ARCHITECTURE.md exists and is within budget
//   D4  claude-progress.md is within budget
//   D5  the whole session prelude is within budget
//   D6  the instructions describe this project and not a different one
//   D7  the documents do not link to files that are not there
//   D8  every hard constraint names the failure it prevents
//   D9  every passing feature's evidence is where the register says it is
//
// `--strict` exits 1 on any violation. That is how it runs in `make check`,
// here and in every generated project — a budget nothing enforces is a budget
// that grows back.
//
//   dart run tool/doc_lint.dart             # lint from cwd
//   dart run tool/doc_lint.dart --strict    # exit 1 on any violation
//   dart run tool/doc_lint.dart --check     # alias for --strict (parity with Node)
//
// Dependency-free: `dart:io` and `dart:convert`, nothing from pub.

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------- budgets ---
// Sized from the lecture's 50-200 line entry file, then tightened per role: the
// contract is the only one an agent must hold in full, the pointer exists to
// stop being a copy, and the state file is a snapshot rather than a history.
// These match the Node implementation byte-for-byte; a divergence here is a
// divergence the corpus catches.
const Map<String, int> budgets = {
  'AGENTS.md': 150,
  'CLAUDE.md': 30,
  'ARCHITECTURE.md': 150,
  'claude-progress.md': 120,
};

// Everything a session is told to read before its first useful action.
const prelude = ['AGENTS.md', 'CLAUDE.md', 'claude-progress.md', 'feature_list.json'];
const int preludeBudgetBytes = 40 * 1024;

// Mutually exclusive stack choices. Naming the wrong one is not stale prose —
// it points an agent at a library the project cannot import. Mirrors the Node
// list; a divergence is corpus drift.
const Map<String, List<String>> stackChoices = {
  'typeorm': ['typeorm', '@nestjs/typeorm'],
  'sequelize': ['sequelize'],
  'mongoose': ['mongoose', '@nestjs/mongoose'],
  'prisma': ['prisma', '@prisma/client'],
  'drizzle': ['drizzle-orm'],
  'knex': ['knex'],
  'firebase': ['firebase', 'firebase-admin', '@firebase/app'],
  'auth0': ['auth0', '@auth0/auth0-react'],
  'passport': ['passport', '@nestjs/passport'],
  'better-auth': ['better-auth'],
  'clerk': ['@clerk/clerk-sdk-node', '@clerk/clerk-nextjs'],
  'supabase': ['@supabase/supabase-js', 'supabase_flutter'],
};

class Violation {
  final String rule;
  final String message;
  const Violation(this.rule, this.message);
  @override
  String toString() => '  [$rule] $message';
}

class LintStats {
  final Map<String, int> files = {};
  int preludeBytes = 0;
}

/// The gate as a function of a directory, so a test can point it at a fixture
/// tree instead of at the repository it is running in. A lint that can only
/// be exercised by breaking the project is a lint nobody exercises.
LintResult lint(Directory root) {
  final violations = <Violation>[];
  final notes = <String>[];
  void fail(String rule, String message) =>
      violations.add(Violation(rule, message));

  String abs(String rel) => '${root.path}/$rel';
  bool exists(String rel) => File(abs(rel)).existsSync();
  String? read(String rel) {
    final f = File(abs(rel));
    if (!f.existsSync()) return null;
    return f.readAsStringSync();
  }

  int lines(String text) => text.split('\n').length;
  String truncate(String s, int n) => s.length > n ? '${s.substring(0, n)}…' : s;

  // A project that is not harnessed at all is not this rule set's business.
  if (!exists('AGENTS.md') && !exists('CLAUDE.md')) {
    return LintResult(violations, notes, null);
  }

  // Claude Code loads `.claude/CLAUDE.md` as well as a root `CLAUDE.md`, and
  // several projects here keep their real instructions in the former.
  // On a case-insensitive filesystem `.claude/CLAUDE.md` and `.claude/claude.md`
  // are one file with two names. Deduplicate by canonical path.
  final claudeCandidates = ['CLAUDE.md', '.claude/CLAUDE.md', '.claude/claude.md'];
  final seenReal = <String>{};
  final claudeFiles = <String>[];
  for (final c in claudeCandidates) {
    final f = File(abs(c));
    if (!f.existsSync()) continue;
    final key = f.resolveSymbolicLinksSync();
    if (seenReal.contains(key)) continue;
    seenReal.add(key);
    claudeFiles.add(c);
  }

  final agents = read('AGENTS.md');
  final stats = LintStats();

  // ----------------------------------------------------------------- D1 ---
  if (agents == null) {
    fail('D1', 'no AGENTS.md — the contract every agent reads first is missing');
  } else {
    stats.files['AGENTS.md'] = lines(agents);
    if (lines(agents) > budgets['AGENTS.md']!) {
      fail(
        'D1',
        'AGENTS.md is ${lines(agents)} lines, budget ${budgets['AGENTS.md']}. '
            'It is the one file read in full every session, so what it holds has to be the contract and not the history.',
      );
    }
  }

  // ----------------------------------------------------------------- D2 ---
  for (final rel in claudeFiles) {
    final claude = read(rel)!;
    stats.files[rel] = lines(claude);
    if (lines(claude) > budgets['CLAUDE.md']!) {
      fail(
        'D2',
        '$rel is ${lines(claude)} lines, budget ${budgets['CLAUDE.md']}. '
            'It is auto-loaded on top of AGENTS.md, so it should carry only what is specific to this harness — the skills, the hooks, the env switches — and link out for the rest.',
      );
    }
    if (agents != null) {
      final shared = _sharedParagraphs(claude, agents);
      if (shared.isNotEmpty) {
        fail(
          'D2',
          '$rel repeats ${shared.length} paragraph(s) verbatim from AGENTS.md, so both are loaded and one is redundant. '
              'First: "${truncate(shared.first, 90)}"',
        );
      }
    }
  }

  // ----------------------------------------------------------------- D3 ---
  final archCandidates = ['ARCHITECTURE.md', 'docs/ARCHITECTURE.md'];
  String? arch;
  for (final c in archCandidates) {
    if (exists(c)) {
      arch = c;
      break;
    }
  }
  if (arch == null) {
    fail(
      'D3',
      'no ARCHITECTURE.md — without a map of where things live and how a request flows, that knowledge ends up inlined into the instruction file, which is how an entry file grows past a thousand lines.',
    );
  } else {
    final text = read(arch)!;
    stats.files[arch] = lines(text);
    if (lines(text) > budgets['ARCHITECTURE.md']!) {
      fail('D3', '$arch is ${lines(text)} lines, budget ${budgets['ARCHITECTURE.md']}.');
    }
    // The failure mode specific to this document: reproducing files that exist.
    final fenced = RegExp(r'```[\w]*\n([\s\S]*?)```').allMatches(text).map((m) {
      return m.group(1)!;
    }).toList();
    final big = fenced.where((f) => f.split('\n').length > 20).toList();
    if (big.isNotEmpty) {
      fail(
        'D3',
        '$arch contains ${big.length} code block(s) over 20 lines. A map points at the file; it does not reproduce it, because a copy of code is a copy that goes stale.',
      );
    }
  }

  // ----------------------------------------------------------------- D4 ---
  final progress = read('claude-progress.md');
  if (progress != null) {
    stats.files['claude-progress.md'] = lines(progress);
    if (lines(progress) > budgets['claude-progress.md']!) {
      final sessions = RegExp(r'^##\s+Session', multiLine: true).allMatches(progress).length;
      fail(
        'D4',
        'claude-progress.md is ${lines(progress)} lines across $sessions session entries, budget ${budgets['claude-progress.md']}. '
            'Its job is what is true now and what is next; the narrative of finished sessions belongs in docs/history/ and in the commit messages that already carry it.',
      );
    }
  }

  // ----------------------------------------------------------------- D5 ---
  for (final rel in prelude) {
    final f = File(abs(rel));
    if (f.existsSync()) stats.preludeBytes += f.lengthSync();
  }
  for (final rel in claudeFiles) {
    if (rel != 'CLAUDE.md') stats.preludeBytes += File(abs(rel)).lengthSync();
  }
  if (stats.preludeBytes > preludeBudgetBytes) {
    fail(
      'D5',
      'the session prelude is ${_kb(stats.preludeBytes)}, budget ${_kb(preludeBudgetBytes)} — '
          'read in full before the first useful action, every session.',
    );
  }

  // ----------------------------------------------------------------- D6 ---
  // The instructions describe this project, and not a different one. Flutter
  // carries its deps in pubspec.yaml; Node projects carry theirs in
  // package.json. Both shapes assert the same constraint; both paths run here
  // so the shared corpus can exercise each.
  final deps = <String>{};
  final scripts = <String>{};
  if (exists('pubspec.yaml')) {
    deps.addAll(_pubspecDeps(read('pubspec.yaml')!));
  }
  if (exists('package.json')) {
    final pkg = _safeJson(read('package.json'));
    if (pkg is Map) {
      final deps1 = pkg['dependencies'];
      if (deps1 is Map) {
        for (final key in deps1.keys) {
          deps.add(key.toString());
        }
      }
      final deps2 = pkg['devDependencies'];
      if (deps2 is Map) {
        for (final key in deps2.keys) {
          deps.add(key.toString());
        }
      }
      final scriptsMap = pkg['scripts'];
      if (scriptsMap is Map) {
        for (final key in scriptsMap.keys) {
          scripts.add(key.toString());
        }
      }
    }
  }
  final makeTargets = <String>{};
  final makeText = read('Makefile');
  if (makeText != null) {
    for (final m in RegExp(r'^([a-z][\w-]*):', multiLine: true).allMatches(makeText)) {
      makeTargets.add(m.group(1)!);
    }
  }

  final docList = <String>[
    ...claudeFiles,
    'AGENTS.md',
    if (arch != null) arch,
  ];

  for (final rel in docList) {
    final text = read(rel);
    if (text == null) continue;

    // D6a — a relative import naming a file that is not there.
    // D6b — a bare package import that is not a dependency.
    final codeBlocks = RegExp(
      r'```(?:ts|typescript|js|javascript|dart)\n([\s\S]*?)```',
    ).allMatches(text);
    for (final block in codeBlocks) {
      final code = block.group(1)!;

      for (final m in RegExp('from\\s+["\'](\\.[^"\']+)["\']').allMatches(code)) {
        if (_resolvesSomewhere(root, m.group(1)!)) continue;
        fail(
          'D6',
          '$rel: a code sample imports "${m.group(1)!}", which does not resolve to any file in this project. '
              'Following this instruction produces a module-not-found.',
        );
      }

      if (deps.isNotEmpty) {
        for (final m in RegExp('from\\s+["\']([^.\'"][^"\']*)["\']').allMatches(code)) {
          final spec = m.group(1)!;
          final name = spec.startsWith('@')
              ? spec.split('/').take(2).join('/')
              : spec.split('/').first;
          if (name.startsWith('node:') || _nodeBuiltins.contains(name)) continue;
          if (deps.contains(name)) continue;
          fail('D6', '$rel: a code sample imports "$name", which is not a dependency of this project.');
        }
        // Dart's `import 'package:foo/foo.dart';` carries the package name as
        // `package:foo` — different shape from a Node `from 'foo'`. Both paths
        // assert the same constraint: the package is not in the manifest.
        for (final m in RegExp('import\\s+["\']package:([^/"\']+)/').allMatches(code)) {
          final name = m.group(1)!;
          if (deps.contains(name)) continue;
          fail('D6', '$rel: a code sample imports "$name", which is not a dependency of this project.');
        }
      }
    }

    // D6c — a heading naming a stack choice the project did not make.
    if (deps.isNotEmpty) {
      for (final m in RegExp(r'^#{2,4}\s+(.+)$', multiLine: true).allMatches(text)) {
        final heading = m.group(1)!;
        for (final entry in stackChoices.entries) {
          final choice = entry.key;
          final packages = entry.value;
          final pattern = RegExp(
            r'\b' + choice.replaceAll('-', '[- ]?') + r'\b',
            caseSensitive: false,
          );
          if (!pattern.hasMatch(heading)) continue;
          if (packages.any(deps.contains)) continue;
          fail(
            'D6',
            '$rel: the heading "${heading.trim()}" documents $choice, which this project does not depend on. '
                'An agent reading it is being told to use a library that is not installed.',
          );
        }
      }
    }

    // D6d — a command the instructions tell you to run that does not exist.
    if (makeTargets.isNotEmpty) {
      for (final m in RegExp(r'`make\s+([a-z][\w-]*)`').allMatches(text)) {
        if (!makeTargets.contains(m.group(1)!)) {
          fail('D6', '$rel: documents `make ${m.group(1)!}`, which the Makefile does not define.');
        }
      }
    }
  }

  // ----------------------------------------------------------------- D7 ---
  for (final rel in docList + ['claude-progress.md']) {
    final text = read(rel);
    if (text == null) continue;
    final linkRe = RegExp(
      r'\[[^\]]*\]\(([^)#:]+\.(?:md|json|mjs|ts|sh|yaml|dart))(?:#[^)]*)?\)',
    );
    for (final m in linkRe.allMatches(text)) {
      final target = m.group(1)!;
      if (target.startsWith('http')) continue;
      final fromDir = File(abs(rel)).parent.path;
      final candidate = '$fromDir/${target.startsWith('/') ? target.substring(1) : target}';
      final candidates = <String>[
        candidate,
        '${root.path}/${target.startsWith('/') ? target.substring(1) : target}',
      ];
      var found = false;
      for (final p in candidates) {
        if (File(p).existsSync() || Directory(p).existsSync()) {
          found = true;
          break;
        }
      }
      if (!found) {
        fail('D7', '$rel links to $target, which is not there.');
      }
    }
  }

  // ----------------------------------------------------------------- D8 ---
  // A rule whose consequence nobody can name is a rule nobody can weigh, and
  // unweighable rules are how a file reaches a thousand lines.
  if (agents != null) {
    final section = _sectionUnder(
      agents,
      RegExp(r'^##\s+(hard\s+)?(constraints|rules)\b', caseSensitive: false),
    );
    if (section != null) {
      final bullets = <String>[];
      for (final line in section.split('\n')) {
        final bulletStart = RegExp(r'^\s*[-*]\s|^\s*\d+\.\s');
        if (bulletStart.hasMatch(line)) {
          bullets.add(line);
        } else if (bullets.isNotEmpty && line.trim().isNotEmpty) {
          bullets[bullets.length - 1] = '${bullets.last} ${line.trim()}';
        }
      }
      final unexplained = bullets.where((b) {
        return !RegExp(
          r'—|--|\bbecause\b|\bso that\b|\botherwise\b',
          caseSensitive: false,
        ).hasMatch(b);
      }).toList();
      if (unexplained.isNotEmpty) {
        fail(
          'D8',
          'AGENTS.md has ${unexplained.length} constraint(s) that do not say what goes wrong without them. '
              'First: "${truncate(unexplained.first.trim(), 90)}"',
        );
      }
      if (bullets.length > 15) {
        fail('D8', 'AGENTS.md lists ${bullets.length} constraints; past about 15 they stop being read as constraints.');
      }
    } else {
      notes.add('AGENTS.md has no constraints section for D8 to check');
    }
  }

  // ----------------------------------------------------------------- D9 ---
  // Only meaningful once evidence has been split out of the register.
  final evidenceDir = Directory(abs('docs/evidence'));
  if (evidenceDir.existsSync()) {
    final list = _safeJson(read('feature_list.json'));
    final features = <dynamic>[];
    if (list is List) {
      features.addAll(list);
    } else if (list is Map) {
      final fs = list['features'];
      if (fs is List) {
        features.addAll(fs);
      }
    }
    // A finished feature leaves the register for docs/history/completed-features.md,
    // so the pairing evidence has to satisfy is register OR archive — and a
    // project with no archive reads this as an empty set.
    final archiveText = read('docs/history/completed-features.md') ?? '';
    final archivedIds = RegExp(r'^\|\s*`([^`]+)`\s*\|', multiLine: true)
        .allMatches(archiveText)
        .map((m) => m.group(1)!)
        .toSet();
    final onDisk = <String>{};
    for (final entry in evidenceDir.listSync()) {
      if (entry is File && entry.path.endsWith('.md')) {
        onDisk.add(entry.uri.pathSegments.last.replaceAll('.md', ''));
      }
    }
    for (final f in features) {
      if (f is! Map) continue;
      final id = f['id'];
      final status = f['status'];
      if (id is! String || status != 'passing') continue;
      if (!onDisk.contains(id)) {
        fail('D9', '$id is passing but docs/evidence/$id.md is missing.');
      }
      if (archivedIds.contains(id)) {
        fail('D9', '$id is in both feature_list.json and the completed-features archive — two answers to whether it is done.');
      }
    }
    for (final id in onDisk) {
      final inFeatures = features.any((f) => f is Map && f['id'] == id);
      if (!inFeatures && !archivedIds.contains(id)) {
        fail('D9', 'docs/evidence/$id.md has no feature $id in the register or the archive.');
      }
    }
  } else {
    notes.add('no docs/evidence/ — D9 does not apply until evidence is split out of the register');
  }

  return LintResult(violations, notes, stats);
}

class LintResult {
  final List<Violation> violations;
  final List<String> notes;
  final LintStats? stats;
  LintResult(this.violations, this.notes, this.stats);
}

// ----------------------------------------------------------------- helpers --

const _nodeBuiltins = <String>{
  'fs', 'path', 'os', 'url', 'util', 'crypto', 'http', 'https', 'net', 'events',
  'stream', 'child_process', 'assert', 'buffer', 'zlib', 'readline', 'process',
};

Object? _safeJson(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

/// Read `dependencies:` and `dev_dependencies:` package names from a
/// pubspec.yaml. The format is a flat list under each heading:
///   dependencies:
///     foo: ^1.0.0
///     bar: any
/// Comments (`#`) are skipped.
Set<String> _pubspecDeps(String text) {
  final deps = <String>{};
  var inDeps = false;
  for (final raw in text.split('\n')) {
    final stripped = raw.split('#').first;
    final trimmed = stripped.trim();
    if (trimmed.endsWith(':') &&
        (trimmed.startsWith('dependencies') || trimmed.startsWith('dev_dependencies'))) {
      inDeps = true;
      continue;
    }
    if (inDeps) {
      // A non-indented non-empty line ends the section.
      if (trimmed.isNotEmpty && !raw.startsWith(' ') && !raw.startsWith('\t')) {
        inDeps = false;
        continue;
      }
      final m = RegExp(r'^[\s-]*([A-Za-z0-9_]+)\s*:').firstMatch(stripped);
      if (m != null) {
        deps.add(m.group(1)!);
      }
    }
  }
  return deps;
}

/// A relative import with no extension can be .ts, .dart, /index.ts, and so on.
/// Same shape as the Node implementation, just without the Node-only extras.
bool _resolvesSomewhere(Directory root, String spec) {
  const bases = ['lib', '', 'test', 'tool'];
  const exts = [
    '', '.ts', '.dart', '.js', '.mjs', '.json',
    '/index.ts', '/index.dart', '/index.js',
  ];
  var cleaned = spec;
  while (cleaned.startsWith('../')) {
    cleaned = cleaned.substring(3);
  }
  if (cleaned.startsWith('./')) cleaned = cleaned.substring(2);
  for (final base in bases) {
    for (final ext in exts) {
      final candidate = base.isEmpty ? '$cleaned$ext' : '$base/$cleaned$ext';
      if (File('$root.path/$candidate').existsSync() ||
          Directory('$root.path/$candidate').existsSync()) {
        return true;
      }
    }
  }
  return false;
}

/// Paragraphs of `a` that also appear in `b`, ignoring whitespace and headings.
List<String> _sharedParagraphs(String a, String b) {
  List<String> norm(String t) {
    return t
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        // Short lines collide by accident; a shared heading is not duplication.
        .where((p) => p.length > 80 && !p.startsWith('#'))
        .toList();
  }

  final inB = norm(b).toSet();
  return norm(a).where((p) => inB.contains(p)).toList();
}

/// The body of the first section whose heading matches, up to the next `##`.
String? _sectionUnder(String text, RegExp headingRe) {
  final lines = text.split('\n');
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (headingRe.hasMatch(lines[i])) {
      start = i;
      break;
    }
  }
  if (start == -1) return null;
  final rest = lines.sublist(start + 1);
  var end = -1;
  for (var i = 0; i < rest.length; i++) {
    if (RegExp(r'^##\s').hasMatch(rest[i])) {
      end = i;
      break;
    }
  }
  return (end == -1 ? rest : rest.sublist(0, end)).join('\n');
}

String _kb(int n) => '${(n / 1024).toStringAsFixed(1)} KB';

// ------------------------------------------------------------------- main ---
// Only when run as a command. `lint()` is imported by the test suite, and a
// module that calls process.exit on import takes the test runner down with it.
void main(List<String> args) {
  final strict = args.contains('--strict') || args.contains('--check');
  final root = Directory.current;

  if (!Directory('${root.path}/lib').existsSync()) {
    stderr.writeln('doc-lint: no lib/ directory — run from the project root.');
    exit(1);
  }

  final result = lint(root);
  final violations = result.violations;
  final notes = result.notes;
  final stats = result.stats;

  if (violations.isNotEmpty) {
    if (stats != null) {
      stdout.writeln('\ndoc-lint — what a session costs before it does anything\n');
      final size = _kb(stats.preludeBytes);
      final mark = '${violations.length.toString().padLeft(2)} ✗';
      stdout.writeln('  $mark  .                                         prelude ${size.padLeft(9)}');
      stdout.writeln('');
      for (final v in violations) {
        stdout.writeln(v.toString());
      }
    } else {
      for (final v in violations) {
        stdout.writeln(v.toString());
      }
    }
    for (final note in notes) {
      stdout.writeln('  ℹ  $note');
    }
    stdout.writeln('\n${violations.length} violation(s).');
    if (strict) exit(1);
  } else {
    final size = stats != null ? _kb(stats.preludeBytes) : '—';
    stdout.writeln(
      stats == null
          ? 'doc-lint: not a harnessed project (0 violations)'
          : 'doc-lint: 0 violation(s) — prelude $size',
    );
  }
}
