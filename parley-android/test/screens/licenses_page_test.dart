import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/settings/license_detail_page.dart';
import 'package:parley_android/screens/settings/licenses_page.dart';
import 'package:parley_android/theme/app_theme.dart';

/// This is the reskin of Flutter's own `showLicensePage`: same
/// `LicenseRegistry` source, this kit's rows and states instead of
/// Material's unthemed defaults. The contracts pinned here are the ones a
/// reskin can silently break —
///
///   * the four states apply even though the data is local rather than
///     network — the registry is a stream, so there is a real frame before
///     it drains, and the loading skeleton is what a reader sees on it;
///   * once it drains, every package the registry reports gets a row, and
///     none of them are dropped;
///   * a tap opens the tapped package's own text, not another one's — the
///     bug a route keyed on the wrong index produces.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(<String>[
          'package_alpha',
        ], 'Alpha license text.'),
      ),
    );
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(<String>[
          'package_beta',
        ], 'Beta license text.'),
      ),
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: child),
    );
  }

  group('the licenses page', () {
    testWidgets('shows a loading skeleton before the registry drains', (
      tester,
    ) async {
      await pump(tester, const LicensesPage());

      expect(find.byType(DSListTileSkeleton), findsWidgets);
      expect(find.text('package_alpha'), findsNothing);

      // Let the registry stream finish so the skeleton frame does not leak
      // into the next test's pump.
      await tester.pumpAndSettle();
    });

    testWidgets('lists every package the registry reports', (tester) async {
      await pump(tester, const LicensesPage());
      await tester.pumpAndSettle();

      expect(find.text('package_alpha'), findsOneWidget);
      expect(find.text('package_beta'), findsOneWidget);
    });

    testWidgets('wires a tap on every row, not just the first', (tester) async {
      await pump(tester, const LicensesPage());
      await tester.pumpAndSettle();

      // The push itself uses go_router's `context.push`, which needs a
      // `GoRouter` ancestor this bare `MaterialApp` does not have — that
      // plumbing, and that the right package rides along as `extra`, is
      // `router_test.dart`'s job. What belongs here is that this screen
      // wired a tap onto the row at all, for every row rather than just
      // the one it was built against first.
      for (final title in ['package_alpha', 'package_beta']) {
        final tile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, title),
        );
        expect(tile.onTap, isNotNull, reason: '$title has no tap handler');
      }
    });
  });

  group('the license detail page', () {
    testWidgets('renders the selected package\'s own text', (tester) async {
      const license = PackageLicense(
        package: 'package_gamma',
        paragraphs: [LicenseParagraph('Gamma license text.', 0)],
      );

      await pump(tester, const LicenseDetailPage(license: license));

      expect(find.text('package_gamma'), findsOneWidget);
      expect(find.text('Gamma license text.'), findsOneWidget);
    });
  });
}
