@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/design_system/blog_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../_screens.dart';
import '_fixtures.dart';
import '_harness.dart';

/// Pixel baselines for the demo screens.
///
/// These have a shorter life than the design-system sheets on purpose:
/// `flutter-010` rebuilds every screen here onto named archetypes, and these
/// baselines will be replaced wholesale when it does. That is what a baseline
/// is for — the point is that the replacement is a deliberate, reviewed diff
/// rather than a change nobody saw.
///
/// Until then they do the job the galleries cannot: a screen is where the
/// chrome, the content and the page gutter meet, and it is the only place a
/// doubled text scale can push a real layout past its edges.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadGoldenFonts);
  setUpAll(loadGoldenImages);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  /// One scope for the whole sheet, from the shared fixture.
  Widget scope(Widget child) => demoScope(prefs, child);

  // Read from `test/_screens.dart` rather than typed here. The map this
  // replaces held five names that nothing tied to the screens the app has, so
  // two blog screens shipped with no baseline and no gate noticed.
  final fixture = ScreenFixture(
    items: demoItems,
    article: demoBlogArticles.first,
  );
  final screens = <String, Widget Function()>{
    for (final AppScreen screen in appScreens)
      screen.name: () => screen.build(fixture),
  };

  screens.forEach((String name, Widget Function() build) {
    testWidgets('$name — Apple and Material, light and dark', (tester) async {
      await expectGoldenSheet(
        tester,
        name: 'screen_$name',
        build: build,
        frame: kPhoneFrame,
        scope: scope,
      );
    });

    testWidgets('$name — at textScale 2.0', (tester) async {
      await expectGoldenSheet(
        tester,
        name: 'screen_${name}_text2x',
        build: build,
        frame: kPhoneFrame,
        variants: accessibilityMatrix,
        textScale: 2.0,
        scope: scope,
      );
    });
  });
}
