import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/form_data.dart';
import 'package:parley_android/screens/design_system/form_page.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The booking demo is the third tile on the Demos tab, and the
/// worked example the `add-form` skill points at. These tests pin the claims
/// the skill makes about a stepped form:
///
///   * a defaulted field is not a question — the flow opens answerable;
///   * validation waits for Next, and is scoped to the step the user is on;
///   * Back never loses what was typed;
///   * a choice that is not a text field is validated too, and says so in its
///     own helper slot;
///   * the last step is a review the user can correct from, and only there
///     does a submit exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
    await tester.pumpAndSettle();
  }

  Finder textFields() => find.byType(TextField);

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  Future<void> pickFirstZone(WidgetTester tester) async {
    final zone = DeskZone.values.firstWhere((z) => z.available);
    await tester.tap(find.byType(DSSelect<DeskZone>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zone.label).last);
    await tester.pumpAndSettle();
  }

  group('the booking flow', () {
    testWidgets('opens on the first step with the account filled in', (
      tester,
    ) async {
      await pump(tester, const FormPage());

      expect(find.text('Who is the desk for, and how many of you?'), findsOne);
      expect(
        (tester.widget(textFields().at(0)) as TextField).controller?.text,
        demoBookingName,
        reason:
            'the app knows who is booking; asking again is a question '
            'that did not need to be asked',
      );
      expect(
        find.text('Back'),
        findsNothing,
        reason:
            'the first step leaves by the header chevron, not a second '
            'way back beside the primary',
      );
    });

    testWidgets('nothing is red until Next is pressed', (tester) async {
      await pump(tester, const FormPage());

      await tester.enterText(textFields().at(1), 'a');
      await tester.pump();

      expect(find.text('Enter a valid email'), findsNothing);
    });

    testWidgets('Next will not leave a step whose fields are wrong', (
      tester,
    ) async {
      await pump(tester, const FormPage());

      await tester.enterText(textFields().at(0), '');
      await tapNext(tester);

      expect(find.text('Enter the name the desk is for'), findsOne);
      expect(
        find.text('Who is the desk for, and how many of you?'),
        findsOne,
        reason: 'an invalid step advanced anyway',
      );
    });

    testWidgets('Back does not lose what was typed', (tester) async {
      await pump(tester, const FormPage());

      await tester.enterText(textFields().at(0), 'Grace Hopper');
      await tapNext(tester);
      expect(find.text('Which day, and when do you arrive?'), findsOne);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(
        (tester.widget(textFields().at(0)) as TextField).controller?.text,
        'Grace Hopper',
      );
    });

    testWidgets('the zone is validated, in its own helper slot', (
      tester,
    ) async {
      await pump(tester, const FormPage(initialStep: 2));

      await tapNext(tester);

      expect(
        find.text('Pick a zone'),
        findsWidgets,
        reason:
            'the zone is not a text field, so nothing validates it '
            'unless the page does',
      );
      expect(find.text('One last look before it is booked.'), findsNothing);
    });

    testWidgets('the review names the answers and can be corrected from', (
      tester,
    ) async {
      await pump(tester, const FormPage(initialStep: 2));
      await pickFirstZone(tester);
      await tapNext(tester);

      expect(find.text('One last look before it is booked.'), findsOne);
      expect(find.text(demoBookingName), findsOne);
      expect(
        find.text('Confirm booking'),
        findsOne,
        reason: 'the submit exists only on the last step',
      );

      await tester.tap(find.text(demoBookingName));
      await tester.pumpAndSettle();

      expect(
        find.text('Who is the desk for, and how many of you?'),
        findsOne,
        reason: 'a review the user cannot correct from is a summary',
      );
    });

    testWidgets('confirming reaches the booked state, and back resets it', (
      tester,
    ) async {
      await pump(tester, const FormPage(initialStep: 2));
      await pickFirstZone(tester);
      await tapNext(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pump();
      // Longer than the shimmer period the submit waits out.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Desk booked'), findsOne);
      expect(find.text('Confirm booking'), findsNothing);

      await tester.tap(find.text('Book another'));
      await tester.pumpAndSettle();

      expect(find.text('Desk booked'), findsNothing);
      expect(
        find.text('Who is the desk for, and how many of you?'),
        findsOne,
        reason: 'booking another desk started somewhere other than step one',
      );
    });

    testWidgets('the route mounts the flow', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.form,
        routes: [
          GoRoute(path: AppRoutes.form, builder: (_, __) => const FormPage()),
        ],
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FormPage), findsOne);
    });
  });
}
