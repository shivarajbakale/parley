@Tags(<String>['probe'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/_harness.dart' show loadGoldenFonts, loadGoldenImages;
import '_probe.dart';
import 'corpus.dart';
import 'debt.dart';

/// `make ui-probe` — the Level 3 gate.
///
/// Root `AGENTS.md` describes four validation levels, and level 3 "renders
/// pixels, which is the only way to catch dead space, dual-axis scroll,
/// clipped labels and rank inversions". Every scaffolder but this one had it.
/// The other ten run a browser; this one does not need to, because
/// `WidgetTester` already mounts a real render tree at a real size. What was
/// missing was not a renderer. It was a set of assertions applied to *every*
/// surface rather than to the ones somebody wrote a test for.
///
/// One test per surface, not one per rule: a surface is what a person opens,
/// and a failure that names the surface can be looked at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Without the app's own fonts every glyph renders as the fallback box, and
  // a box has different metrics than the letter it stands in for. A probe
  // measuring overflow and tap targets against the wrong metrics is measuring
  // a layout the app never has.
  setUpAll(loadGoldenFonts);
  setUpAll(loadGoldenImages);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_complete': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  /// Mounts one surface across the matrix and collects everything found.
  Future<void> probe(WidgetTester tester, ProbeSurface surface) async {
    // Semantics are off in a test unless something asks for them, and the
    // `target` rule reads the semantics tree — the handle is what makes the
    // tree exist at all.
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<ProbeViolation> found = <ProbeViolation>[];

    for (final ProbeCell cell in layoutMatrix) {
      await mountProbe(tester, surface, cell);
      found
        ..addAll(ruleOverflow(tester, surface, cell))
        ..addAll(ruleGutter(tester, surface, cell))
        ..addAll(ruleShortMeasure(tester, surface, cell))
        ..addAll(ruleDoubleGutter(tester, surface, cell))
        ..addAll(ruleClippedText(tester, surface, cell))
        ..addAll(ruleWordBreak(tester, surface, cell))
        ..addAll(ruleOverlap(tester, surface, cell))
        ..addAll(ruleEmptyPadding(tester, surface, cell))
        ..addAll(ruleBaseline(tester, surface, cell))
        ..addAll(ruleFold(tester, surface, cell))
        ..addAll(ruleDeadBand(tester, surface, cell))
        ..addAll(ruleRowAir(tester, surface, cell))
        ..addAll(ruleControlAir(tester, surface, cell))
        ..addAll(ruleNesting(tester, surface, cell))
        ..addAll(ruleTarget(tester, surface, cell))
        ..addAll(ruleDualAxis(tester, surface, cell))
        // In the layout loop rather than the appearance loop: neither reads
        // colour, and the layout loop walks eighteen cells where the
        // appearance loop walks four.
        ..addAll(ruleTourArtSemantics(tester, surface, cell))
        ..addAll(ruleTourProgressLabel(tester, surface, cell));
      recordOverlayWidths(tester, cell);
    }

    // Colour does not reflow, so the rule that reads colour gets its own
    // short matrix rather than a third dimension on the long one.
    for (final ProbeCell cell in appearanceMatrix) {
      await mountProbe(tester, surface, cell);
      found
        ..addAll(ruleOverflow(tester, surface, cell))
        ..addAll(ruleContrast(tester, surface, cell));
    }

    handle.dispose();

    // Everything is printed, matched or not. A debt that is only visible when
    // it grows is a debt nobody is paying down.
    for (final ProbeViolation violation in found) {
      printOnFailure(violation.toString());
    }

    final List<ProbeViolation> absolute = found
        .where((ProbeViolation v) => !gradedAgainstDebt.contains(v.rule))
        .toList();
    expect(
      absolute,
      isEmpty,
      reason:
          '${absolute.length} on ${surface.name}:\n\n'
          '${absolute.map((ProbeViolation v) => v.toString()).join('\n\n')}\n',
    );

    final Map<String, int> recorded =
        knownDebt[surface.name] ?? const <String, int>{};
    final List<String> mismatches = <String>[];
    for (final String rule in gradedAgainstDebt) {
      final Set<String> things = <String>{
        for (final ProbeViolation v in found)
          if (v.rule == rule) v.key,
      };
      final int owed = recorded[rule] ?? 0;
      final String detail = found
          .where((ProbeViolation v) => v.rule == rule)
          .map((ProbeViolation v) => v.toString())
          .join('\n\n');

      if (things.length > owed) {
        mismatches.add(
          '${surface.name} has ${things.length} $rule violations and '
          'test/probe/debt.dart records $owed. This surface got '
          'worse:\n\n$detail\n',
        );
      } else if (things.length < owed) {
        mismatches.add(
          '${surface.name} has ${things.length} $rule violations and '
          'test/probe/debt.dart still records $owed. Lower the number — a fix '
          'that is not banked is a fix the next change can spend.',
        );
      }
    }

    // Both rules are counted before anything fails. Asserted inside the loop,
    // the first rule to disagree would end the test and the second would go
    // unmeasured — which is how a surface can be found clean on a rule it was
    // never graded on.
    expect(mismatches, isEmpty, reason: mismatches.join('\n\n'));
  }

  group('catalog', () {
    for (final ProbeSurface surface in catalogSurfaces()) {
      testWidgets(surface.name, (WidgetTester tester) async {
        await probe(tester, surface);
      });
    }
  });

  group('screens', () {
    // One test per screen rather than a loop inside one: the first surface to
    // fail would end the test, and the screens after it would be reported as
    // neither passing nor failing — they would simply never have been
    // measured. `prefs` is set up per test, so the list is rebuilt per test.
    for (final String name in screenSurfaceNames) {
      testWidgets(name, (WidgetTester tester) async {
        await probe(
          tester,
          screenSurfaces(prefs).firstWhere((ProbeSurface s) => s.name == name),
        );
      });
    }
  });

  // The one rule that cannot be decided from a single surface. It reads what
  // the walk recorded, so it has to be declared after the tests that fill it —
  // `test` bodies run in declaration order, and this one runs last.
  test('width-band — one overlay kind resolves to one width', () {
    final List<ProbeViolation> found = ruleWidthBand();
    expect(
      found,
      isEmpty,
      reason: found.map((ProbeViolation v) => v.toString()).join('\n\n'),
    );
  });
}
