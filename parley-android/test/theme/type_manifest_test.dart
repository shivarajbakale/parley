import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/parley_type.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The app may only ask for a font weight the bundled face actually ships.
///
/// A `TextStyle` naming a weight the font does not have is not an error and
/// does not warn. The engine picks a neighbouring face, and which neighbour it
/// picks is a property of the font-matching algorithm rather than a decision
/// anyone made — so the app renders at a weight nobody chose, identically on
/// every device, and looks fine.
///
/// This shipped: `TypeSpec` defaulted `titleWeight` and `labelWeight` to
/// `w600`, ten components hand-typed `FontWeight.w600` for emphasis, and
/// Satoshi bundles 300 / 400 / 500 / 700 / 900 with no Semibold. The comment
/// at the top of `app_typography.dart` even described the trap. Nothing
/// checked, so it lasted.
///
/// The manifest is read out of `pubspec.yaml` rather than restated here, so
/// adding a weight to the bundle is the one action that widens what the app
/// may ask for.
void main() {
  final families = _bundledWeights();
  // Every weight any bundled family ships, for checks that cannot see which
  // family a call site draws in.
  final manifest = <int>{for (final w in families.values) ...w};

  test('the pubspec bundles a readable set of weights', () {
    expect(manifest, isNotEmpty, reason: 'no fonts found in pubspec');
  });

  group('every weight the theme installs is in the bundle', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      test(name, () {
        final t = theme.textTheme;
        final roles = <String, TextStyle?>{
          'displayLarge': t.displayLarge,
          'displayMedium': t.displayMedium,
          'displaySmall': t.displaySmall,
          'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium,
          'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
        };
        roles.forEach((role, style) {
          final weight = style?.fontWeight;
          if (weight == null) return;
          final family = style!.fontFamily!;
          final shipped = families[family] ?? const <int>{};
          expect(
            shipped,
            contains(weight.value),
            reason:
                '$role asks for $family w${weight.value}, which is not '
                'bundled. $family ships: ${shipped.toList()..sort()}. The engine will '
                'substitute a neighbouring face and the choice will not be '
                'yours — pick a weight from the list, or add the file.',
          );
        });
      });
    }
  });

  group('every bundled weight is drawn by some identity', () {
    // The other direction, and the one nobody was checking. A face that no
    // identity asks for is shipped into every app this boilerplate produces,
    // downloaded by every user, and rendered nowhere.
    //
    // Satoshi Light sat like that for the whole life of the scale: bundled at
    // weight 300, never named. It is what the display steps are set in now.
    //
    // Graded through `DSTextRole`, not through the `TextTheme`. The first
    // version of this test walked the fifteen theme steps, and it would have
    // passed on a Light that nothing could reach: `displayLarge` and
    // `displaySmall` are steps no role names, so a weight sitting on them is
    // a weight in a stylesheet rather than one on a screen. A role is what a
    // call site can ask for, so a weight reachable from a role is a weight
    // the app can actually draw.
    for (final (name, spec) in [
      ('aurora', DesignSpec.aurora()),
      ('halo', DesignSpec.halo()),
      ('ledger', DesignSpec.ledger()),
      ('signal', DesignSpec.signal()),
    ]) {
      testWidgets(name, (tester) async {
        final drawn = <String>{};
        await tester.pumpWidget(
          Design(
            spec: spec,
            child: MaterialApp(
              // The identity's own theme: the identities no longer share a
              // family, so the app's theme would grade every one as halo.
              theme: spec.themeFor(Brightness.light),
              home: Builder(
                builder: (context) {
                  for (final role in DSTextRole.values) {
                    final style = role.styleOf(context);
                    final weight = style.fontWeight;
                    if (weight != null) {
                      drawn.add('${style.fontFamily} ${weight.value}');
                    }
                  }
                  // Parley's two faces outside the role table: the user's
                  // own words and figures (lib/theme/parley_type.dart).
                  for (final style in [
                    ParleyType.voice(context),
                    ParleyType.voiceRow(context),
                    ParleyType.figure(context),
                    ParleyType.mono(context),
                  ]) {
                    drawn.add('${style.fontFamily} ${style.fontWeight!.value}');
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        expect(
          drawn,
          isNotEmpty,
          reason: 'no role resolved — the builder never ran',
        );
        // Per identity the set is a subset; the bundle has to be covered by
        // the three of them together, which the group below asserts.
        _drawnByIdentity[name] = drawn;
      });
    }

    testWidgets('together they cover the bundle', (tester) async {
      final drawn = <String>{
        for (final faces in _drawnByIdentity.values) ...faces,
      };
      final bundled = <String>{
        for (final e in families.entries)
          for (final w in e.value) '${e.key} $w',
      };
      expect(
        _drawnByIdentity,
        hasLength(4),
        reason: 'run the whole group — this reads what the four above found',
      );
      expect(
        bundled.difference(drawn),
        isEmpty,
        reason:
            'these faces are bundled and no role in any identity resolves to '
            'them: ${(bundled.difference(drawn).toList()..sort())}. Give the '
            'weight a role, or drop the file from pubspec.yaml and '
            'assets/fonts.',
      );
    });
  });

  test('no source file asks for a weight outside the bundle', () {
    final offenders = <String>[];
    final pattern = RegExp(r'FontWeight\.w(\d{3})');
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final lines = entry.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // A doc comment naming the weight it warns about is not a use of it.
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in pattern.allMatches(line)) {
          final value = int.parse(m.group(1)!);
          if (!manifest.contains(value)) {
            offenders.add('${entry.path}:${i + 1} — FontWeight.w$value');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these ask for a weight no bundled family ships '
          '(${manifest.toList()..sort()}):\n  ${offenders.join('\n  ')}',
    );
  });
}

/// The weights declared for each font family in `pubspec.yaml`.
///
/// Parsed line by line rather than with a YAML package: the shape is fixed,
/// and a dev-dependency that exists only to read one list is a dependency in
/// every app this boilerplate produces.
Map<String, Set<int>> _bundledWeights() {
  final families = <String, Set<int>>{};
  Set<int>? current;
  for (final raw in File('pubspec.yaml').readAsLinesSync()) {
    final line = raw.trimRight();
    final family = RegExp(r'- family:\s*(.+)$').firstMatch(line);
    if (family != null) {
      current = families.putIfAbsent(family.group(1)!.trim(), () => <int>{});
      continue;
    }
    final match = RegExp(r'weight:\s*(\d+)').firstMatch(line);
    if (match != null) current?.add(int.parse(match.group(1)!));
  }
  return families;
}

/// What each identity's roles resolved to, filled in by the group above.
final Map<String, Set<String>> _drawnByIdentity = <String, Set<String>>{};
