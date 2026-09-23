@Tags(<String>['golden'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/home/dashboard_page.dart';
import 'package:parley_android/screens/home/library_page.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fixtures.dart';
import '_harness.dart';

/// Switchability, proved rather than claimed.
///
/// The spec layer's whole argument is that the design is one value: swap the
/// [DesignSpec] and the app changes, with nothing downstream edited. Every
/// other gate in this repository takes that on trust. `ui_lint` proves no
/// widget *names* a token namespace, and the completeness test proves no spec
/// field goes unread — but a widget can read `context.design.space.md` and
/// still draw the same picture under every identity if what it does with the
/// number is wrong, and a per-subject baseline cannot see that, because each
/// baseline is only ever compared against its own past.
///
/// So there are two halves here:
///
///   * **The sheets.** One contact sheet per identity per screen, which is
///     what makes a new identity something a person looks at rather than a
///     number they approve. Constraint 12: a screen is not done until someone
///     has seen it, and an identity nobody rendered is an identity nobody
///     designed.
///   * **The difference test.** The same screen rendered under every shipped
///     identity, pixel-compared. It fails when two identities draw the same
///     thing, which is the failure a dead derivation actually produces.
///
/// The difference test also renders one identity twice and requires those two
/// to be *identical*, because "these two images differ" is only evidence when
/// the renderer is known not to differ from itself.
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

  Widget scope(Widget child) => demoScope(prefs, child);

  // Two screens rather than one. A dashboard is where colour, elevation and
  // the meter family land; a library is where the chrome, the filter strip
  // and a scrolling list of rows do. An identity that changed only one of
  // those would be a recolour.
  final subjects = <String, Widget Function()>{
    'dashboard': () => Scaffold(body: DashboardPage(onOpenDrawer: () {})),
    'library': () => const Scaffold(body: LibraryPage()),
  };

  for (final spec in DesignSpec.shipped) {
    subjects.forEach((String subject, Widget Function() build) {
      testWidgets('${spec.name} — $subject', (tester) async {
        await expectGoldenSheet(
          tester,
          name: 'identity_${spec.name}_$subject',
          build: build,
          frame: kPhoneFrame,
          scope: scope,
          spec: spec,
        );
      });
    });
  }

  testWidgets('no two identities draw the same screen', (tester) async {
    final build = subjects['dashboard']!;
    final pixels = <String, Uint8List>{};
    for (final spec in DesignSpec.shipped) {
      pixels[spec.name] = await renderSheetPixels(
        tester,
        spec: spec,
        build: build,
        scope: scope,
      );
    }

    // The control. Without it, "these differ" could as easily be evidence
    // that the renderer is not deterministic as evidence that the design is
    // derived, and the test would prove nothing either way.
    final again = await renderSheetPixels(
      tester,
      spec: DesignSpec.shipped.first,
      build: build,
      scope: scope,
    );
    expect(
      pixelDifference(pixels[DesignSpec.shipped.first.name]!, again),
      0,
      reason:
          'the same identity rendered twice did not produce the same pixels, '
          'so no difference measured below means anything',
    );

    // A quarter of the sheet, not one pixel. Two identities that differ in a
    // single hairline would pass a bytes-differ check and would still be the
    // same design to anybody using the app; the ground, the type and the
    // chrome all move between these, so the real numbers are far above the
    // floor and a collapse toward a shared constant shows up long before it
    // reaches it.
    const floor = 0.25;
    final names = pixels.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final share = pixelDifference(pixels[names[i]]!, pixels[names[j]]!);
        expect(
          share,
          greaterThan(floor),
          reason:
              '${names[i]} and ${names[j]} render the same dashboard in '
              '${((1 - share) * 100).toStringAsFixed(1)}% of pixels — a '
              'widget on this screen is drawing something the spec does not '
              'decide',
        );
        debugPrint(
          'identity difference — ${names[i]} vs ${names[j]}: '
          '${(share * 100).toStringAsFixed(1)}% of pixels',
        );
      }
    }
  });
}
