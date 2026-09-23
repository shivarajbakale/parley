import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A dialog can now express more than yes, no and dismissed.
///
/// `Future<bool?>` and two hardcoded full-width Material buttons were the two
/// halves of the same limitation: a dialog that asks *which* folder, or
/// collects a name, or offers three options, was not expressible, and the
/// button contract stopped at the dialog's edge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext) open, {
    TargetPlatform platform = TargetPlatform.android,
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the route is named by its title, and scopes itself', (
    tester,
  ) async {
    // The reason the file gives for not blurring behind a dialog, kept as a
    // test rather than as a comment: `namesRoute` and `scopesRoute` are what
    // would have been paid for a material.
    final handle = tester.ensureSemantics();
    await pumpHost(
      tester,
      (context) => showDSDialog<void>(
        context: context,
        title: 'Discard draft?',
        message: 'This note has not been saved yet.',
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    bool found(bool Function(SemanticsData) test) {
      var hit = false;
      void walk(SemanticsNode node) {
        if (test(node.getSemanticsData())) hit = true;
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(_rootSemantics(tester));
      return hit;
    }

    expect(
      found((d) => d.flagsCollection.namesRoute),
      isTrue,
      reason: 'the title is the route\'s accessible name',
    );
    expect(found((d) => d.flagsCollection.scopesRoute), isTrue);
    handle.dispose();
  });

  test('a dialog without a title asserts', () {
    expect(
      () => DSDialog(title: '', message: 'anything'),
      throwsA(isA<AssertionError>()),
    );
  });

  group('order is a platform fact', () {
    // Material puts the confirming action on the trailing edge of a row.
    // Apple used to stack automatically (HIG: confirm above cancel). After
    // flutter-034 the row is the default on both platforms; the Apple stack
    // survives only as the explicit `DSDialogActionsLayout.stack` opt-in.
    testWidgets('on Material the confirming action is trailing', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context) => showDSConfirm(
          context: context,
          title: 'Discard draft?',
          confirmLabel: 'Discard',
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancel = tester.getRect(find.widgetWithText(DSButton, 'Cancel'));
      final confirm = tester.getRect(find.widgetWithText(DSButton, 'Discard'));
      expect(confirm.left, greaterThan(cancel.left));
      expect(confirm.top, cancel.top, reason: 'a row, not a stack');
    });

    testWidgets('on Apple the default `auto` layout rows like Material does '
        '(flutter-034)', (tester) async {
      await pumpHost(
        tester,
        platform: TargetPlatform.iOS,
        (context) => showDSConfirm(
          context: context,
          title: 'Delete 3 items?',
          confirmLabel: 'Delete',
          destructive: true,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancel = tester.getRect(find.widgetWithText(DSButton, 'Cancel'));
      final confirm = tester.getRect(find.widgetWithText(DSButton, 'Delete'));
      expect(confirm.left, greaterThan(cancel.left));
      expect(
        confirm.top,
        cancel.top,
        reason: 'auto now rows on both platforms',
      );
    });

    testWidgets('on Apple, `DSDialogActionsLayout.stack` is the HIG opt-in ('
        'flutter-034)', (tester) async {
      // The convention this surface owns: callers always write
      // `[cancel, confirm]` (see `DSDialogActions`). On Apple the renderer
      // reverses so confirm lands above cancel, cancel lands last, both
      // match what HIG has shipped since iOS 13.
      await pumpHost(
        tester,
        platform: TargetPlatform.iOS,
        (context) => showDSDialog<void>(
          context: context,
          title: 'Delete 3 items?',
          actions: DSDialogActions(
            layout: DSDialogActionsLayout.stack,
            children: [
              DSButton(
                label: 'Cancel',
                variant: DSButtonVariant.ghost,
                onPressed: () {},
              ),
              DSButton(
                label: 'Delete',
                variant: DSButtonVariant.destructive,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final cancel = tester.getRect(find.widgetWithText(DSButton, 'Cancel'));
      final confirm = tester.getRect(find.widgetWithText(DSButton, 'Delete'));
      // Apple order: confirm above, cancel below.
      expect(confirm.bottom, lessThanOrEqualTo(cancel.top));
    });

    for (final scale in const [1.0, 2.0]) {
      testWidgets(
        'Apple and Material lay a destructive confirm out identically at '
        'textScale $scale (flutter-034)',
        (tester) async {
          // The thesis of the change, stated as a measurement: with `auto`
          // the footer geometry is a function of the labels and the width,
          // and of nothing else. Whatever the layout resolves to at a given
          // scale, both platforms resolve to the same one.
          Future<(Rect, Rect)> layoutOn(TargetPlatform platform) async {
            await pumpHost(
              tester,
              platform: platform,
              textScale: scale,
              (context) => showDSConfirm(
                context: context,
                title: 'Delete 3 items?',
                confirmLabel: 'Delete',
                destructive: true,
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
            return (
              tester.getRect(find.widgetWithText(DSButton, 'Cancel')),
              tester.getRect(find.widgetWithText(DSButton, 'Delete')),
            );
          }

          final (appleCancel, appleConfirm) = await layoutOn(
            TargetPlatform.iOS,
          );
          final (materialCancel, materialConfirm) = await layoutOn(
            TargetPlatform.android,
          );

          expect(appleCancel, materialCancel);
          expect(appleConfirm, materialConfirm);
          // Cancel leads on both, which is the half the old Apple branch
          // reversed.
          expect(
            appleCancel.top,
            lessThanOrEqualTo(appleConfirm.top),
            reason: 'cancel leads',
          );
        },
      );
    }

    testWidgets(
      'a 320-point phone at textScale 2.0 overflows in caller order, not '
      'the HIG order (flutter-034)',
      (tester) async {
        // Where the labels genuinely stop fitting, `OverflowBar` promotes the
        // row to a column — and that column is the caller's own order, cancel
        // first. It is a measurement, not the platform rule: only the
        // explicit `stack` opt-in reverses to confirm-above-cancel.
        await pumpHost(
          tester,
          platform: TargetPlatform.iOS,
          textScale: 2,
          size: const Size(320, 568),
          (context) => showDSConfirm(
            context: context,
            title: 'Delete 3 items?',
            confirmLabel: 'Delete',
            destructive: true,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final cancel = tester.getRect(find.widgetWithText(DSButton, 'Cancel'));
        final confirm = tester.getRect(find.widgetWithText(DSButton, 'Delete'));
        expect(
          confirm.top,
          greaterThanOrEqualTo(cancel.bottom),
          reason: 'overflowed to a column',
        );
      },
    );
  });

  testWidgets('a destructive confirm does not focus the destructive action', (
    tester,
  ) async {
    // The rule both platforms state, encoded rather than documented: the
    // dangerous action must not be one Return away.
    await pumpHost(
      tester,
      (context) => showDSConfirm(
        context: context,
        title: 'Delete 3 items?',
        confirmLabel: 'Delete',
        destructive: true,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final delete = tester.widget<DSButton>(
      find.widgetWithText(DSButton, 'Delete'),
    );
    final cancel = tester.widget<DSButton>(
      find.widgetWithText(DSButton, 'Cancel'),
    );
    expect(delete.autofocus, isFalse);
    expect(cancel.autofocus, isTrue);
  });

  testWidgets('an async confirm locks the barrier while it runs', (
    tester,
  ) async {
    // A dialog that vanishes under a stray tap mid-request leaves the user
    // with no idea whether the thing happened.
    final completer = Completer<void>();
    await pumpHost(
      tester,
      (context) => showDSConfirm(
        context: context,
        title: 'Publish?',
        confirmLabel: 'Publish',
        onConfirm: () => completer.future,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final route =
        ModalRoute.of(tester.element(find.text('Publish?')))! as DSOverlayRoute;
    expect(route.barrierDismissible, isTrue);

    await tester.tap(find.widgetWithText(DSButton, 'Publish'));
    await tester.pump();

    expect(route.barrierDismissible, isFalse);
    expect(
      tester.widget<DSButton>(find.widgetWithText(DSButton, 'Publish')).loading,
      isTrue,
    );

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Publish?'), findsNothing);
  });

  testWidgets('two long labels at text scale 2.0 stack rather than truncate', (
    tester,
  ) async {
    await pumpHost(
      tester,
      textScale: 2,
      size: const Size(320, 844),
      (context) => showDSConfirm(
        context: context,
        title: 'Discard draft?',
        confirmLabel: 'Discard this draft',
        cancelLabel: 'Keep editing it',
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final cancel = tester.getRect(
      find.widgetWithText(DSButton, 'Keep editing it'),
    );
    final confirm = tester.getRect(
      find.widgetWithText(DSButton, 'Discard this draft'),
    );
    expect(
      confirm.top,
      isNot(cancel.top),
      reason: 'they no longer fit in a row, so they stack',
    );
  });

  testWidgets('showDSDialog<T> returns the value its content chose', (
    tester,
  ) async {
    // `Future<bool?>` could not express this at all.
    String? picked;
    await pumpHost(tester, (context) async {
      picked = await showDSDialog<String>(
        context: context,
        title: 'Choose a folder',
        content: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop('Downloads'),
            child: const Text('Downloads'),
          ),
        ),
      );
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(picked, 'Downloads');
  });

  testWidgets('the icon well is a component and reads the spec', (
    tester,
  ) async {
    // `Container(48, 48)` with `iconColor.withValues(alpha: 0.1)` at one call
    // site, at a fixed alpha that held in one theme and was checked in
    // neither. It is a component now, and `ComponentSpec.iconWellSize`
    // finally reaches it.
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec.copyWith(
          component: AppTheme.spec.component.copyWith(iconWellSize: 64),
        ),
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: DSDialogIcon(tone: DSTone.error)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Container).first).width, 64);
  });

  testWidgets('the tone well is drawn from the palette, in both themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                for (final tone in DSTone.values) {
                  final (fill, on) = DSDialogIcon.wellColorsFor(context, tone);
                  expect(
                    _contrast(on, fill),
                    greaterThanOrEqualTo(3.0),
                    reason: '$tone in $brightness',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }
  });

  test('the style object merges, lerps and never defaults a field', () {
    const empty = DSDialogStyle();
    expect(empty.padding, isNull, reason: 'defaults live in resolve');

    const a = DSDialogStyle(actionGap: 8, showIcon: false);
    const b = DSDialogStyle(actionGap: 16);
    expect(a.merge(b).actionGap, 16);
    expect(a.merge(b).showIcon, isFalse);
    expect(a.lerp(b, 0.5).actionGap, 12);
  });
}

/// WCAG relative-luminance contrast, for the well behind a dialog's glyph.
double _contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The root of the rendered semantics tree.
///
/// `tester.binding.pipelineOwner` is deprecated; the tree is rooted at
/// `rootPipelineOwner` and the node lives on one of its children.
SemanticsNode _rootSemantics(WidgetTester tester) {
  SemanticsNode? found;
  void visit(PipelineOwner owner) {
    found ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  return found!;
}
