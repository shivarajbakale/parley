import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_screens.dart';
import 'golden/_harness.dart';
import 'probe/_probe.dart';

/// The gate that makes a new screen visible to the other gates.
///
/// `flutter-039` shipped two screens — a blog list and an article — that no
/// gate ever mounted. The probe's corpus and the goldens' map were both
/// hand-typed lists of five names, so the new screens were not *failing* any
/// gate; they were absent from every one, and five green checks said so.
///
/// This test is the ratchet: every `*_page.dart` under `lib/screens/` is
/// either registered in `appScreens` — and therefore walked by the probe and
/// recorded by the goldens — or written down in `ungradedScreens` with a
/// reason a person can argue with. There is no third state.
void main() {
  test('every screen is graded or documented as ungraded', () {
    final Directory screens = Directory('lib/screens');
    expect(
      screens.existsSync(),
      isTrue,
      reason: 'run this from the project root',
    );

    final List<String> onDisk =
        screens
            .listSync(recursive: true)
            .whereType<File>()
            .map((File f) => f.path.replaceAll(r'\', '/'))
            .where((String p) => p.endsWith('_page.dart'))
            .toList()
          ..sort();

    // The shell is not under a `_page.dart` name and is listed as a gap on
    // purpose, so it is added here rather than special-cased below.
    onDisk.add('lib/screens/home_screen.dart');

    final Set<String> registered = <String>{
      for (final AppScreen screen in appScreens) screen.source,
    };
    final Set<String> declared = ungradedScreens.keys.toSet();

    final List<String> unlisted = <String>[
      for (final String path in onDisk)
        if (!registered.contains(path) && !declared.contains(path)) path,
    ];

    expect(
      unlisted,
      isEmpty,
      reason:
          'These screens are in neither test/_screens.dart\'s `appScreens` nor '
          'its `ungradedScreens`, so no gate mounts them and nothing says '
          'why:\n  ${unlisted.join('\n  ')}\n\n'
          'Register the screen (the probe and the goldens both read that list) '
          'or write down why it is not graded yet.',
    );

    final List<String> stale = <String>[
      for (final String path in <String>{...registered, ...declared})
        if (!onDisk.contains(path)) path,
    ];
    expect(
      stale,
      isEmpty,
      reason:
          'Listed in test/_screens.dart but not on disk — a registry that '
          'names files that do not exist is a registry nobody is '
          'reading:\n  ${stale.join('\n  ')}',
    );

    final Set<String> both = registered.intersection(declared);
    expect(
      both,
      isEmpty,
      reason: 'graded and ungraded at once: ${both.join(', ')}',
    );
  });

  test('the goldens photograph the screenful the probe grades', () {
    // Two harnesses measuring two different phones is a gate that grades one
    // screen and a picture that shows another. It cost a booking form its
    // repeat row: above the fold at 844, under the pinned bar at 720, and
    // absent from the baseline that was signed off.
    expect(kPhoneFrame.height, ProbeCell.height);
  });
}
