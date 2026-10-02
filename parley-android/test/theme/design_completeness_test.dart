import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every knob on the design reaches something.
///
/// `DesignSpec` is the app's one source of truth, and the promise it makes is
/// that changing a field changes the app. A field nothing reads breaks that
/// promise in the most expensive way there is: it looks like a knob, it is
/// documented like a knob, somebody sets it, and the screen does not move.
/// This feature found five of them — a chrome blur, two glass alphas, an
/// eyebrow's case and a duration ladder's top step — all of them written,
/// documented and connected to nothing.
///
/// The check is deliberately mechanical: a field counts as read when some
/// file under `lib/` names it as `something.field`, or when its own class
/// computes with it (`radiusOf` reads `radii`, `_at` reads `steps`). What it
/// cannot see is the rest of the chain — a getter that is itself unread — and
/// that is what the goldens and `make ui-probe` are for. It catches the dead
/// end, not the long detour.
void main() {
  final specDir = Directory('lib/theme/spec');

  /// Source lines with the comments removed, so a field named only in the
  /// paragraph explaining it does not count as a reader.
  List<String> code(String source) => [
    for (final line in source.split('\n'))
      if (!line.trimLeft().startsWith('//')) line,
  ];

  List<String> libSources() => [
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart')) f.readAsStringSync(),
  ];

  test('every field of every spec is read by something', () {
    expect(
      specDir.existsSync(),
      isTrue,
      reason: 'lib/theme/spec is where the design is declared',
    );

    final declaration = RegExp(r'^  final\s+[\w<>,\s?()]+?\s+(\w+);');
    final sources = libSources().map(code).toList();
    final unread = <String>[];

    for (final file in specDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final own = file.readAsStringSync().split('\n');
      final ownCode = code(file.readAsStringSync());

      for (var i = 0; i < own.length; i++) {
        final match = declaration.firstMatch(own[i]);
        if (match == null) continue;
        final name = match.group(1)!;

        // A qualified read anywhere in the app: `design.space`, `chrome
        // .barBlur`, `motion.enter`. `this.field` is excluded — the
        // constructor assigning a field is not a reader of it.
        final qualified = RegExp('(?<!this)\\.$name\\b');
        var read = sources.any((lines) => lines.any(qualified.hasMatch));

        // Or the class computes with it: a bare mention in its own file that
        // is not the declaration, a constructor parameter, or a `copyWith`
        // row. Those three shapes are how a field is *carried*, not read.
        if (!read) {
          final bare = RegExp('(?<![\\w.])$name(?![\\w])');
          read = ownCode.any((line) {
            final t = line.trim();
            if (t == own[i].trim()) return false;
            if (!bare.hasMatch(t)) return false;
            if (RegExp('^(required )?this\\.$name( = [^,]*)?,\$').hasMatch(t)) {
              return false;
            }
            if (RegExp('^$name: $name( \\?\\? this\\.$name)?,\$').hasMatch(t)) {
              return false;
            }
            if (RegExp('^[\\w<>,?\\s()]+\\?\\s+$name,\$').hasMatch(t)) {
              return false;
            }
            return true;
          });
        }

        if (!read) {
          unread.add('${file.uri.pathSegments.last}: $name');
        }
      }
    }

    expect(
      unread,
      isEmpty,
      reason:
          'these fields are on the spec and nothing reads them. A knob that '
          'moves nothing is worse than no knob: it is a promise the app does '
          'not keep. Either wire it to the widget it describes, or delete it',
    );
  });
}
