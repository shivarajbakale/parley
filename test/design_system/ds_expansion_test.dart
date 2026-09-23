import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A disclosure is two claims: the body is not there until it is asked for,
/// and a screen reader is told which of those two states it is in. Everything
/// else here is the style chain and the controlled/uncontrolled split.
void main() {
  late BuildContext ctx;
  late List<MethodCall> haptics;

  setUp(() {
    haptics = <MethodCall>[];
    AppHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('opening and closing', () {
    testWidgets('the body is off screen until the header is tapped', (
      tester,
    ) async {
      await pump(
        tester,
        const DSExpansion(title: 'Shipping', child: Text('Two to four days')),
      );

      // Built but collapsed to nothing: the AnimatedSize swaps the child out,
      // so the words are not in the tree at all.
      expect(find.text('Two to four days'), findsNothing);

      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();

      expect(find.text('Two to four days'), findsOneWidget);
    });

    testWidgets('initiallyExpanded opens it on arrival', (tester) async {
      await pump(
        tester,
        const DSExpansion(
          title: 'Delivery',
          initiallyExpanded: true,
          child: Text('Tracked'),
        ),
      );

      expect(find.text('Tracked'), findsOneWidget);
    });

    testWidgets('the tap ticks', (tester) async {
      await pump(
        tester,
        const DSExpansion(title: 'Shipping', child: Text('Body')),
      );

      expect(haptics, isEmpty);
      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    });

    testWidgets('a disabled panel does not open and does not tick', (
      tester,
    ) async {
      await pump(
        tester,
        const DSExpansion(
          title: 'Returns',
          enabled: false,
          child: Text('Body'),
        ),
      );

      await tester.tap(find.text('Returns'));
      await tester.pumpAndSettle();

      expect(find.text('Body'), findsNothing);
      expect(haptics, isEmpty);
    });
  });

  group('controlled', () {
    testWidgets('the parent owns the state and the panel reports the tap', (
      tester,
    ) async {
      var open = false;
      var reports = 0;

      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => DSExpansion(
                  title: 'Warranty',
                  expanded: open,
                  onExpansionChanged: (next) {
                    reports++;
                    setState(() => open = next);
                  },
                  child: const Text('Two years'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Two years'), findsNothing);
      await tester.tap(find.text('Warranty'));
      await tester.pumpAndSettle();

      expect(reports, 1);
      expect(find.text('Two years'), findsOneWidget);
    });
  });

  group('what a screen reader is told', () {
    testWidgets('the expanded flag rides on the node with the words', (
      tester,
    ) async {
      await pump(
        tester,
        const DSExpansion(title: 'Shipping', child: Text('Body')),
      );

      var node = tester.getSemantics(find.byType(MergeSemantics));
      expect(node.label, contains('Shipping'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isExpanded, Tristate.isFalse);

      await tester.tap(find.text('Shipping'));
      await tester.pumpAndSettle();

      node = tester.getSemantics(find.byType(MergeSemantics));
      expect(node.flagsCollection.isExpanded, Tristate.isTrue);
    });
  });

  group('motion', () {
    testWidgets('reduced motion opens with no animation', (tester) async {
      await pump(
        tester,
        const DSExpansion(title: 'Shipping', child: Text('Body')),
        reduceMotion: true,
      );

      await tester.tap(find.text('Shipping'));
      // One frame, no settle: with the duration at zero the body is already
      // laid out, and a test that has to settle is a test of the animation.
      await tester.pump();

      expect(find.text('Body'), findsOneWidget);
    });
  });

  group('the style chain', () {
    testWidgets('the spec supplies the header height and the divider', (
      tester,
    ) async {
      await pump(
        tester,
        const DSExpansion(title: 'Shipping', child: Text('Body')),
      );

      final resolved = DSExpansionStyle.resolve(ctx);
      expect(resolved.minHeaderHeight, ctx.design.component.minTapTarget);
      expect(find.byType(DSDivider), findsOneWidget);
    });

    testWidgets('an instance style turns the divider off', (tester) async {
      await pump(
        tester,
        const DSExpansion(
          title: 'Shipping',
          style: DSExpansionStyle(showDivider: false),
          child: Text('Body'),
        ),
      );

      expect(find.byType(DSDivider), findsNothing);
    });

    test('merge, copyWith and lerp walk every field', () {
      const base = DSExpansionStyle(gap: 8, iconSize: 20, showDivider: true);
      const patch = DSExpansionStyle(gap: 16);

      expect(base.merge(patch).gap, 16);
      expect(base.merge(patch).iconSize, 20);
      expect(base.merge(null), same(base));
      expect(base.copyWith(iconSize: 24).gap, 8);
      expect(base.copyWith(iconSize: 24).iconSize, 24);

      const other = DSExpansionStyle(gap: 24, iconSize: 40, showDivider: false);
      final half = base.lerp(other, 0.5);
      expect(half.gap, 16);
      expect(half.iconSize, 30);
      // A boolean switches at the halfway mark rather than interpolating.
      expect(half.showDivider, isFalse);
      expect(base.lerp(null, 0.5), same(base));
    });
  });
}
