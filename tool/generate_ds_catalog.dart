// ds-catalog generator — emits tool/fixtures/ds-catalog.json from
// lib/design_system/. The catalog is the source of truth for what `kit:`
// references can resolve to: the validator rejects a superplan that names a
// `kit` the catalog doesn't have.
//
// Heuristic categorisation:
//   - `kind` comes from the class name (Tab → navigation, Tile → row, Field → input,
//     Bar → chrome, Card → surface, etc.)
//   - `archetypeFit` is inferred from the name (List/Row/Tile → collection; Tab/Bar/AppBar →
//     any; Form/Field/Input → form; Section/Stat → focal; Detail/Section → detail; etc.)
//   - `useWhen` / `instead` come from the class doc comment's `**Use when**` /
//     `**Instead:**` lines, both of which `docs/references/design-system-reference-llms.txt`
//     already documents as the authoring convention.
//
// Run: `dart run tool/generate_ds_catalog.dart` (called by `make ds-catalog`).
// Read back by `dart run tool/super_plan.dart` (V8) and `dart run tool/superplan_lint.dart` (S6).

import 'dart:convert';
import 'dart:io';

const _out = 'tool/fixtures/ds-catalog.json';

// Suffixes that never name a citable component: `Style` is a theme
// extension, and `Painter` / `Host` / `Reporter` are plumbing a plan has no
// reason to name.
//
// `State` is deliberately absent. A Flutter `State` subclass extends
// `State<Foo>`, which the widget check in `_parseClass` already rejects, so
// the suffix only ever removed real components — `DSEmptyState` and
// `DSErrorState` — and with them a planner's ability to cite the two most
// common screen states after loading.
const _excludeSuffixes = <String>[
  'Style',
  'Painter',
  'PainterDelegate',
  'Host',
  'Reporter',
];

/// The generic shimmer wrapper, which is a component in its own right: it is
/// what a plan cites when a screen loads. Every other `…Skeleton` is the
/// loading state of the kit it is named after, reached through that parent
/// and never cited alone.
const _skeletonWrapper = 'DSSkeleton';

/// Whether [name] is plumbing rather than a component a superplan can cite.
bool excludeByName(String name) {
  if (name.endsWith('Skeleton') && name != _skeletonWrapper) return true;
  for (final s in _excludeSuffixes) {
    if (name.endsWith(s)) return true;
  }
  return false;
}

final _kindRules = <RegExp, String>{
  RegExp(r'Tab|Pill|Indicator|Underline'): 'navigation',
  RegExp(r'Bar|NavBar|Sidebar|BottomSlots|Header|Footer|AppBar|Pinned'):
      'chrome',
  RegExp(r'Button|Fab|IconButton|Pressable'): 'button',
  RegExp(r'Tile|Row|Item|Cell|ControlTile|SettingsRow'): 'row',
  RegExp(r'Field|TextField|Select|Input|Checkbox|Radio|Switch|Slider|Stepper'):
      'input',
  RegExp(r'Card|Well|Surface|Sheet|Dialog|Overlay|BottomSheet|Compact'):
      'surface',
  // `Stat(?!e)` so the rule reads `DSStatTile` and not `DSEmptyState`:
  // a state is feedback, which the rule below it already knows.
  RegExp(r'Section|Stat(?!e)|Metric|SettingsSection'): 'grouping',
  RegExp(r'Avatar|Illustration|Image|Icon'): 'media',
  RegExp(r'Skeleton|Progress|Loading|Spinner'): 'feedback',
  RegExp(r'SnackBar|Message|EmptyState|ErrorState|PullQuote'): 'feedback',
  RegExp(r'Search|Filter|Sort'): 'search',
  RegExp(r'Badge|Chip|Pill|Tag|Dot'): 'tag',
  RegExp(r'Theme|Mode|Picker'): 'theme',
  RegExp(r'Focus|Tap|Haptic|Status'): 'a11y',
  RegExp(r'Menu|Submenu|Popup'): 'overlay',
};

/// The catalog `kind` for [name], from the class name alone.
String kindOf(String name) {
  for (final entry in _kindRules.entries) {
    if (entry.key.hasMatch(name)) return entry.value;
  }
  return 'misc';
}

List<String> _archetypeFit(String kind, String name) {
  switch (kind) {
    case 'navigation':
      return ['focal', 'collection', 'detail', 'form', 'settings'];
    case 'chrome':
      if (name.contains('AppBar') || name.contains('Header')) {
        return ['focal', 'collection', 'detail'];
      }
      if (name.contains('Pinned')) return ['detail', 'form'];
      return ['focal', 'collection', 'detail', 'form', 'settings'];
    case 'button':
      if (name.contains('Fab')) return ['focal', 'collection'];
      return ['focal', 'collection', 'detail', 'form', 'settings'];
    case 'row':
    case 'grouping':
      if (name.contains('Settings') || name.contains('Stat')) {
        return ['settings', 'detail'];
      }
      return ['collection', 'detail', 'focal', 'settings'];
    case 'input':
      return ['form', 'settings', 'detail'];
    case 'surface':
      return ['focal', 'detail', 'settings'];
    case 'media':
      return ['focal', 'detail', 'collection'];
    case 'feedback':
      return ['focal', 'collection', 'detail', 'form', 'settings'];
    case 'search':
      return ['collection'];
    case 'tag':
      return ['collection', 'focal', 'form', 'settings'];
    case 'theme':
      return ['settings'];
    case 'overlay':
      return ['focal', 'collection', 'detail', 'form', 'settings'];
    case 'a11y':
    case 'misc':
    default:
      return ['focal', 'collection', 'detail', 'form', 'settings'];
  }
}

String _docToString(List<String> lines) {
  return lines
      .map((l) => l.startsWith('///') ? l.substring(3).trimLeft() : l)
      .join('\n')
      .trim();
}

/// One line, no double spaces, no trailing full stop.
String _collapse(String s) {
  final out = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out.endsWith('.') ? out.substring(0, out.length - 1) : out;
}

/// The summary, `**Use when**` and `**Instead:**` clauses of a doc comment.
({String useWhen, String instead, String summary}) summariseDoc(String doc) {
  String useWhen = '';
  String instead = '';
  String summary = '';

  if (doc.isEmpty) {
    return (useWhen: useWhen, instead: instead, summary: summary);
  }

  final paraBreak = doc.indexOf(RegExp(r'\n\n|\n(?=[A-Z*])'));
  summary = (paraBreak > 0 ? doc.substring(0, paraBreak) : doc)
      .replaceAll('\n', ' ')
      .trim();

  // A clause ends at a sentence or a paragraph, never at a wrapped line: the
  // kit's doc comments wrap at 80 columns, and cutting at the newline turned
  // `**Use when** the list is / legitimately empty.` into `the list is`.
  const clauseEnd = r'(.+?)(?:\.(?=\s|$)|\n\n)';

  final useWhenMatch = RegExp(
    r'\*\*Use when\*\*\s+' + clauseEnd,
    dotAll: true,
  ).firstMatch(doc);
  if (useWhenMatch != null) useWhen = _collapse(useWhenMatch.group(1)!);

  final insteadMatch = RegExp(
    r'\*\*Instead[:.]\*\*\s+' + clauseEnd,
    dotAll: true,
  ).firstMatch(doc);
  if (insteadMatch != null) instead = _collapse(insteadMatch.group(1)!);

  return (useWhen: useWhen, instead: instead, summary: summary);
}

({
  String name,
  String kind,
  List<String> archetypeFit,
  Map<String, Object?> entry,
})?
_parseClass(
  String fileName,
  String line,
  List<String> docLines, {
  required String tier,
}) {
  final m = RegExp(r'^class\s+(DS[A-Z][A-Za-z0-9]+)\b').firstMatch(line);
  if (m == null) return null;
  final name = m.group(1)!;
  final looksLikeWidget = RegExp(
    r'extends\s+(StatefulWidget|StatelessWidget|Widget|WidgetDelegate|ChangeNotifier|DSTabIndicator)\b',
  ).hasMatch(line);
  if (!looksLikeWidget) return null;

  if (excludeByName(name)) return null;

  final kind = kindOf(name);
  final doc = _docToString(docLines);
  final summary = summariseDoc(doc);

  final entry = <String, Object?>{
    'kit': name,
    'kind': kind,
    'archetypeFit': _archetypeFit(kind, name),
    'file': fileName,
    // The layer the file declares on its first line. It says what a component
    // may be built from: an atom composes foundations and atoms, a molecule
    // composes atoms, an organism composes molecules. `tool/ui_lint.dart`
    // fails an import that reaches above its own tier.
    'tier': tier,
    'summary': summary.summary.isEmpty
        ? 'A $kind widget from the kit.'
        : summary.summary,
    if (summary.useWhen.isNotEmpty) 'useWhen': summary.useWhen,
    if (summary.instead.isNotEmpty) 'instead': summary.instead,
  };

  return (
    name: name,
    kind: kind,
    archetypeFit: _archetypeFit(kind, name),
    entry: entry,
  );
}

void main() {
  final dsDir = Directory('lib/design_system');
  if (!dsDir.existsSync()) {
    stderr.writeln('ds-catalog: lib/design_system not found');
    exit(1);
  }

  final out = <String, Object?>{
    'version': 1,
    'generatedFrom': 'lib/design_system/',
    'components': <Map<String, Object?>>[],
  };

  final files =
      dsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var count = 0;
  for (final f in files) {
    final lines = f.readAsLinesSync();
    final tierMatch = lines.isEmpty
        ? null
        : RegExp(r'^// ds-tier: \d+ — (\w+)$').firstMatch(lines.first);
    final fileTier = tierMatch?.group(1) ?? 'undeclared';
    // A class may declare a tier of its own on the line above it. The file's
    // marker is the ceiling for its *imports*, which is a file-level fact
    // because Dart imports are; the layer a *component* occupies is a fact
    // about the component, and the two stopped agreeing the moment a file held
    // more than one class. Every catalog entry used to be labelled by its
    // filename, so a chevron was a molecule for sharing a file with a list
    // tile and a separator was an organism for sharing one with a select.
    // The per-class form takes a trailing reason the file-level one does not:
    // "// ds-tier: 1 — atom — A glyph that says the row leads somewhere". A
    // class that disagrees with its file has to say why on the spot, or the
    // next reader has only the disagreement.
    final classTier = RegExp(r'^\s*// ds-tier: \d+ — (\w+)(?: — .+)?$');
    String? pending;
    List<String> docBuf = [];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final own = classTier.firstMatch(line);
      if (own != null && i > 0) {
        pending = own.group(1);
        continue;
      }
      if (line.startsWith('/// ')) {
        docBuf.add(line);
        continue;
      }
      if (line.startsWith('///')) {
        docBuf.add(line);
        continue;
      }
      if (line.startsWith('@')) {
        continue;
      }
      if (line.trimLeft().startsWith('class ')) {
        final parsed = _parseClass(
          f.path.split('/').last,
          line,
          List.of(docBuf),
          tier: pending ?? fileTier,
        );
        if (parsed != null) {
          (out['components']! as List).add(parsed.entry);
          count += 1;
        }
        pending = null;
        docBuf = [];
      } else {
        if (line.trim().isNotEmpty && !line.startsWith('//')) {
          docBuf = [];
        }
      }
    }
  }

  (out['components']! as List).sort(
    (a, b) =>
        (a as Map)['kit'].toString().compareTo((b as Map)['kit'].toString()),
  );

  File(_out).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('ds-catalog: $count components → $_out');
}
