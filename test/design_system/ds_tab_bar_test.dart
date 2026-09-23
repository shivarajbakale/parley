import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// DSTabBar — plan 25.
///
/// The bar shipped without a widget test, and the one thing a tab bar owes a
/// reader — the indicator sitting under the tab whose label is bold — was
/// what nothing held open. Driven by a `TabController` the indicator follows
/// `controller.animation`, which the bar listens to. Driven by
/// `index`/`onIndexChanged` it follows `_travel`, an `AnimationController`
/// that had no listener at all: the strip repainted only when some unrelated
/// `setState` happened to land, so on a screen whose tabs do not scroll the
/// underline stayed under the *previously* selected tab for as long as the
/// page sat still.
///
/// These tests read the painted pixels rather than the widget tree, because
/// the indicator is a `CustomPainter` and the defect was invisible to every
/// assertion that stops at the element.
void main() {
  final spec = AppTheme.spec;

  const labels = ['All', 'Mentions', 'Assigned', 'Archived'];

  Widget host({
    required int initial,
    DSTabLayout layout = DSTabLayout.fixed,
    double width = 390,
    Key? hostKey,
  }) => Design(
    spec: spec,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: _Host(
              key: hostKey,
              initial: initial,
              layout: layout,
              labels: labels,
            ),
          ),
        ),
      ),
    ),
  );

  /// The horizontal span of the painted underline, in the bar's own
  /// coordinates. Read two logical pixels off the bottom, which is inside the
  /// three-point indicator and clear of the hairline baseline.
  Future<(double, double)?> underline(WidgetTester tester) async {
    final element = find.byType(DSTabBar).evaluate().single;
    final rect = tester.getRect(find.byType(DSTabBar));
    final accent = (element as BuildContext).palette.primary;
    (double, double)? span;
    await tester.runAsync(() async {
      final image = await captureImage(element);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      final scale = image.width / rect.width;
      final y = image.height - 2;
      int? first, last;
      for (var x = 0; x < image.width; x++) {
        final i = ((y * image.width) + x) * 4;
        final pixel = Color.fromARGB(
          bytes[i + 3],
          bytes[i],
          bytes[i + 1],
          bytes[i + 2],
        );
        if ((pixel.r - accent.r).abs() < 0.05 &&
            (pixel.g - accent.g).abs() < 0.05 &&
            (pixel.b - accent.b).abs() < 0.05 &&
            pixel.a > 0.5) {
          first ??= x;
          last = x;
        }
      }
      if (first != null) span = (first / scale, last! / scale);
    });
    return span;
  }

  group('the indicator marks the selected tab', () {
    testWidgets('it sits under the tab the bar opens on', (tester) async {
      await tester.pumpWidget(host(initial: 2));
      await tester.pumpAndSettle();

      final span = await underline(tester);
      expect(span, isNotNull, reason: 'no underline was painted at all');
      final bar = tester.getRect(find.byType(DSTabBar));
      final label = tester.getRect(find.text('Assigned'));
      final centre = bar.left + (span!.$1 + span.$2) / 2;
      expect(
        (centre - label.center.dx).abs(),
        lessThan(4),
        reason:
            'the underline is ${centre - label.center.dx} points off the '
            'label it is supposed to mark',
      );
    });

    testWidgets('it follows every tap, with no controller to drive it', (
      tester,
    ) async {
      // The regression. Without a listener on the travel controller the
      // underline stayed where the *previous* selection left it — the bar
      // was one tap behind on every screen that owns its own index.
      await tester.pumpWidget(host(initial: 0));
      await tester.pumpAndSettle();

      for (final label in labels) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final span = await underline(tester);
        expect(span, isNotNull, reason: 'no underline while "$label" is on');
        final bar = tester.getRect(find.byType(DSTabBar));
        final text = tester.getRect(find.text(label));
        final centre = bar.left + (span!.$1 + span.$2) / 2;
        expect(
          (centre - text.center.dx).abs(),
          lessThan(4),
          reason:
              'tapped "$label" and the underline landed '
              '${(centre - text.center.dx).toStringAsFixed(1)} points away — '
              'it is marking a different tab',
        );
      }
    });

    testWidgets('the same holds on a scrollable strip', (tester) async {
      await tester.pumpWidget(
        host(initial: 0, layout: DSTabLayout.scrollable, width: 280),
      );
      await tester.pumpAndSettle();

      // Only the tabs the strip can show: a tab scrolled past the edge is
      // clipped, and a clipped underline has no centre to compare.
      final viewport = tester.getRect(find.byType(DSTabBar));
      for (final label in ['Mentions', 'All']) {
        final tab = tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(DSTab)),
        );
        if (tab.left < viewport.left - 0.01 ||
            tab.right > viewport.right + 0.01) {
          continue;
        }
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final span = await underline(tester);
        expect(span, isNotNull, reason: 'no underline while "$label" is on');
        final bar = tester.getRect(find.byType(DSTabBar));
        final text = tester.getRect(find.text(label));
        final centre = bar.left + (span!.$1 + span.$2) / 2;
        expect(
          (centre - text.center.dx).abs(),
          lessThan(4),
          reason:
              'tapped "$label" on the scrollable strip and the underline '
              'landed ${(centre - text.center.dx).toStringAsFixed(1)} points '
              'away',
        );
      }
    });
  });

  group('the strip only scrolls when it has to', () {
    ScrollPosition strip(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(DSTabBar),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    testWidgets('a tab already on screen does not move under the finger', (
      tester,
    ) async {
      // The regression: every tap used to be sent to `start - oneTabWidth`,
      // which slid the strip whether or not the tapped tab needed moving.
      // The tab under the finger at release was then not the tab that had
      // been tapped.
      await tester.pumpWidget(
        host(initial: 0, layout: DSTabLayout.scrollable, width: 240),
      );
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(DSTabBar));
      expect(
        strip(tester).maxScrollExtent,
        greaterThan(0),
        reason: 'the strip has to overflow for this test to mean anything',
      );

      for (final label in labels) {
        // The tab, not its label: a word can sit inside the viewport while
        // the target around it is cut by the edge, and it is the target the
        // bar scrolls for. A tab the strip has scrolled past cannot be
        // tapped at all — a finger cannot reach off the screen — so the
        // ones off the edge are simply not part of this claim.
        final tab = find.ancestor(
          of: find.text(label),
          matching: find.byType(DSTab),
        );
        final before = tester.getRect(tab);
        if (before.left < viewport.left - 0.01 ||
            before.right > viewport.right + 0.01) {
          continue;
        }
        final offset = strip(tester).pixels;

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(
          strip(tester).pixels,
          offset,
          reason: '"$label" was fully visible and the strip scrolled anyway',
        );
      }
    });

    testWidgets('a tab off the edge is still scrolled into view', (
      tester,
    ) async {
      // The other half of the rule: not moving a visible tab must not become
      // never moving. A selection the screen makes for itself — a deep link,
      // a paired view swiped to the last page — reaches the bar through
      // `index`, and the tab it names has to arrive on screen.
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        host(
          initial: 0,
          layout: DSTabLayout.scrollable,
          width: 240,
          hostKey: key,
        ),
      );
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(DSTabBar));
      final last = find.ancestor(
        of: find.text(labels.last),
        matching: find.byType(DSTab),
      );
      final before = tester.getRect(last);
      expect(
        before.right > viewport.right + 0.01,
        isTrue,
        reason:
            'the last tab has to start off the edge for this to mean '
            'anything',
      );

      key.currentState!.select(labels.length - 1);
      await tester.pumpAndSettle();

      final after = tester.getRect(last);
      expect(
        after.left >= viewport.left - 0.01 &&
            after.right <= viewport.right + 0.01,
        isTrue,
        reason:
            'selecting the last tab left it at '
            '${after.left.toStringAsFixed(1)}..${after.right.toStringAsFixed(1)} '
            'against a viewport of ${viewport.left}..${viewport.right}',
      );
    });
  });

  group('selection', () {
    testWidgets('a tap reports the tab that was tapped', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: DSTabBar(
                index: 0,
                onIndexChanged: taps.add,
                tabs: [for (final l in labels) DSTab(label: l)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archived'));
      await tester.pumpAndSettle();
      expect(taps, [3]);

      // Re-tapping the live tab is not a change, and a bar that reported it
      // would make every caller guard the callback.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(taps, [3]);
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.initial,
    required this.layout,
    required this.labels,
  });

  final int initial;
  final DSTabLayout layout;
  final List<String> labels;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _index = widget.initial;

  /// A selection the screen makes rather than the finger, which is how a deep
  /// link or a paired page view reaches the bar.
  void select(int index) => setState(() => _index = index);

  @override
  // The boundary is the test's, not the bar's: `captureImage` walks up to the
  // nearest repaint boundary, and without one here it would hand back the
  // whole screen and every offset below would be measured from the wrong
  // origin.
  Widget build(BuildContext context) => RepaintBoundary(
    child: DSTabBar(
      index: _index,
      layout: widget.layout,
      onIndexChanged: (i) => setState(() => _index = i),
      tabs: [for (final l in widget.labels) DSTab(label: l)],
    ),
  );
}
