import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The checkable half of `docs/principles/premium.md`.
///
/// Every claim here failed the day it was written, and every one of them was
/// green under `analyze`, `ui_lint`, the test suite and the goldens — which is
/// the point of the document and of this file. A golden fails on a *change*;
/// these assertions fail on a wrong first draft.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 358,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Scaffold(
                body: Center(
                  child: SizedBox(width: width, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('a row has something that can give', () {
    // 31 points of striped overflow bar over the end of the title, at the
    // width a phone actually offers, on a title of four words.
    const long = 'Icon, title, body, actions';

    testWidgets('a long section header ellipsises rather than overflowing', (
      tester,
    ) async {
      await pump(tester, const DSSectionHeader(label: long));
      expect(tester.takeException(), isNull);
      expect(find.text(long), findsOneWidget);
    });

    testWidgets('and still does at a doubled text scale, with a trailing', (
      tester,
    ) async {
      await pump(
        tester,
        const DSSectionHeader(label: long, trailing: Icon(Icons.more_horiz)),
        width: 320,
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('one surface, not three', () {
    // The three tests here used to protect `showDSCustomModal` from wrapping a
    // modal in a modal. That component is gone — plan 18 folded it into the
    // sheet and plan 19 into the dialog — so the claims move to the surfaces
    // that replaced it. The property is the same one: presenting a dialog
    // produces exactly one surface, at exactly one width.
    Future<void> open(WidgetTester tester, {required Widget content}) async {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDSDialog<void>(
                    context: context,
                    title: 'Rename project',
                    content: content,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('showDSDialog owns the surface its content sits on', (
      tester,
    ) async {
      await open(tester, content: const Text('rename'));

      expect(find.byType(DSOverlaySurface), findsOneWidget);
      expect(find.text('rename'), findsOneWidget);
    });

    testWidgets('a dialog without a title asserts', (tester) async {
      // The route is announced by its title; "dialog" is not an accessible
      // name. The old modal had no such rule, and a modal with no title was
      // reachable at any call site.
      expect(
        () => DSDialog(title: '', message: 'anything'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('one idiom, one width', () {
    testWidgets('a dialog caps at the identity\'s overlay width', (
      tester,
    ) async {
      // Wide enough that the cap, not the screen, is what limits it.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDSConfirm(
                    context: context,
                    title: 'Discard draft?',
                    message: 'This note has not been saved yet.',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(DSOverlaySurface)).width,
        AppTheme.spec.component.overlayMaxWidth,
      );
    });
  });
}
