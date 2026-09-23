import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A sheet whose body is taller than the room it has.
///
/// The Install sheet on a Claw App was a `Column` of radio tiles with its
/// button as the last row. On a small phone at a large text scale the rows
/// past the sheet's cap were painted off the bottom edge, nothing scrolled,
/// and the button was unreachable. The sheet now scrolls its body and pins
/// its footer; these tests hold both, and the keyboard case, at 320x568.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openTallSheet(
    WidgetTester tester, {
    double textScale = 2,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = const Size(320, 568) * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: DSButton(
                  label: 'Open',
                  onPressed: () => showDSBottomSheet<void>(
                    context: context,
                    header: const DSSheetHeader(title: 'Choose a model'),
                    footer: DSSheetFooter(
                      actions: DSButton(
                        label: 'Install',
                        fullWidth: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < 20; i++)
                          SizedBox(height: 56, child: Text('Model $i')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  void expectInsideSheet(WidgetTester tester, Finder finder) {
    final sheet = tester.getRect(find.byType(DSOverlaySurface));
    final rect = tester.getRect(finder);
    expect(rect.bottom, lessThanOrEqualTo(sheet.bottom + 0.5));
  }

  testWidgets('a tall body at 320x568 and 2x text does not overflow, and the '
      'pinned action stays hittable', (tester) async {
    await openTallSheet(tester);

    expect(tester.takeException(), isNull);
    final install = find.widgetWithText(DSButton, 'Install');
    expect(install.hitTestable(), findsOneWidget);
    expectInsideSheet(tester, install);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getRect(install).bottom, lessThanOrEqualTo(screen.height));

    // The body scrolls: the last row is reachable without moving the button.
    await tester.scrollUntilVisible(
      find.text('Model 19'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DSBottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Model 19').hitTestable(), findsOneWidget);
    expect(install.hitTestable(), findsOneWidget);

    await tester.tap(install);
    await tester.pumpAndSettle();
    expect(find.byType(DSBottomSheet), findsNothing);
  });

  testWidgets('with the keyboard up, the sheet fits above it', (tester) async {
    await openTallSheet(tester, textScale: 1.3, keyboard: 260);

    expect(tester.takeException(), isNull);
    final install = find.widgetWithText(DSButton, 'Install');
    expect(install.hitTestable(), findsOneWidget);
    expect(tester.getRect(install).bottom, lessThanOrEqualTo(568 - 260));
  });
}
