import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The kit's drawing layer.
///
/// Before this, `CustomPainter` appeared nowhere in `lib/`, `assets/` held five
/// font files and nothing else, and the whole visual answer to an empty screen
/// was a 24dp Material glyph blown up to 80 points. The tests below hold the
/// three properties that make a drawn illustration worth shipping in a
/// scaffolder: it is painted from the palette rather than baked into an asset,
/// it plays once and stops, and it can be replaced wholesale by a designer's
/// art without the kit depending on Lottie or Rive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(
    Widget child, {
    bool reducedMotion = false,
    Brightness brightness = Brightness.light,
    DesignSpec? spec,
  }) => Design(
    spec: spec ?? AppTheme.spec,
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: inner!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('the six kinds are drawn from the style, not from an asset', () {
    testWidgets('every kind paints, and every colour it uses is one the '
        'style resolved', (tester) async {
      for (final kind in DSIllustrationKind.values) {
        await tester.pumpWidget(host(DSIllustration(kind: kind)));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(DSIllustration));
        final style = DSIllustrationStyle.resolve(context);
        final used = _paintedColours(kind, style);

        expect(used, isNotEmpty, reason: '$kind painted nothing');
        expect(
          used.difference(<int>{
            _opaque(style.groundColor!),
            _opaque(style.bodyColor!),
            _opaque(style.accentColor!),
            _opaque(style.lineColor!),
          }),
          isEmpty,
          reason:
              '$kind painted a colour the style did not resolve — a literal '
              'in a painter is the one thing that cannot follow a brand hue',
        );
      }
    });

    testWidgets('a second identity draws the same kinds in other colours', (
      tester,
    ) async {
      final palettes = <String, Set<int>>{};
      for (final spec in <DesignSpec>[DesignSpec.halo(), DesignSpec.fallback]) {
        await tester.pumpWidget(
          host(
            const DSIllustration(kind: DSIllustrationKind.empty),
            spec: spec,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(DSIllustration));
        palettes[spec.name] = _paintedColours(
          DSIllustrationKind.empty,
          DSIllustrationStyle.resolve(context),
        );
      }

      expect(
        palettes['halo'],
        isNot(palettes['fallback']),
        reason:
            'the drawing did not move with the identity, which is the whole '
            'argument for painting it rather than shipping a PNG',
      );
    });

    test('no asset and no animation package was added to pay for it', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final package in <String>['lottie', 'rive', 'flutter_svg']) {
        expect(
          RegExp('^  $package:', multiLine: true).hasMatch(pubspec),
          isFalse,
          reason:
              '$package would be a dependency in every generated app, and it '
              'ships no art — the delegate is how an app that has art gets it',
        );
      }
      // `assets/images/` is allowed and `assets/illustrations/` is not. The
      // photographs in `images/` belong to the blog and catalog demos, which
      // are deleted wholesale when an app ships; the rule this test exists to
      // hold is that the *kit* never gains art, because a raster ships one
      // theme, one density and one brand hue.
      // The teeth of this test are the two checks around this one, and
      // neither is relaxed: no illustration package, and nothing under
      // `lib/design_system/` naming a file on disk.
      expect(
        Directory('assets').listSync().map((e) => e.path.split('/').last),
        unorderedEquals(<String>['fonts', 'images']),
      );
      for (final source in Directory(
        'lib/design_system',
      ).listSync(recursive: true).whereType<File>()) {
        expect(
          source.readAsStringSync(),
          isNot(contains('assets/')),
          reason:
              '${source.path} names an asset — a component that needs a file '
              'on disk cannot be restyled by the spec, and the delegate is '
              'how an app that has art gets it',
        );
      }
    });
  });

  group('a designer replaces all six without touching a call site', () {
    testWidgets('a delegate installed above the app wins over the painter', (
      tester,
    ) async {
      for (final kind in DSIllustrationKind.values) {
        await tester.pumpWidget(
          host(
            DSIllustrationScope(
              delegate: const _MarkerDelegate(),
              child: DSIllustration(kind: kind),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_MarkerDelegate.markerFor(kind)), findsOneWidget);
        expect(_kitPainter, findsNothing);
      }
    });

    testWidgets('one call site can still override the scope', (tester) async {
      await tester.pumpWidget(
        host(
          const DSIllustrationScope(
            delegate: _MarkerDelegate(),
            child: DSIllustration(
              kind: DSIllustrationKind.done,
              delegate: DSIllustrationPainterDelegate(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_kitPainter, findsOneWidget);
      expect(
        find.byKey(_MarkerDelegate.markerFor(DSIllustrationKind.done)),
        findsNothing,
      );
    });
  });

  group('the motion is one pass, and then it is over', () {
    testWidgets('a parent rebuilding does not replay the draw', (tester) async {
      final seen = <double>[];
      final rebuild = ValueNotifier<int>(0);
      addTearDown(rebuild.dispose);

      await tester.pumpWidget(
        host(
          ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, value, _) => DSIllustration(
              kind: DSIllustrationKind.empty,
              delegate: _RecordingDelegate(seen),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final midway = seen.last;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      rebuild.value = 1;
      await tester.pump();
      expect(
        seen.last,
        greaterThanOrEqualTo(midway),
        reason:
            'the draw restarted on a rebuild — which is the defect that makes '
            'an illustration flicker every time the list above it updates',
      );

      await tester.pumpAndSettle();
      expect(seen.last, 1);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });

    testWidgets('reduced motion paints the last frame and starts no ticker', (
      tester,
    ) async {
      final seen = <double>[];
      await tester.pumpWidget(
        host(
          DSIllustration(
            kind: DSIllustrationKind.search,
            delegate: _RecordingDelegate(seen),
          ),
          reducedMotion: true,
        ),
      );

      expect(seen, <double>[1]);
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason:
            'a controller was created under reduced motion — the user asked '
            'for less movement, not for a frame budget spent on none',
      );
    });

    test('every layer only ever gets more opaque — WCAG 2.3.1', () {
      var previous = List<double>.filled(DSIllustrationPainter.layerCount, 0);
      for (var step = 0; step <= 100; step++) {
        final now = DSIllustrationPainter.layerOpacities(step / 100);
        for (var layer = 0; layer < now.length; layer++) {
          expect(
            now[layer],
            greaterThanOrEqualTo(previous[layer]),
            reason:
                'layer $layer dipped at t = ${step / 100}, which is a flash',
          );
          expect(now[layer], inInclusiveRange(0, 1));
        }
        previous = now;
      }
      expect(
        DSIllustrationPainter.layerOpacities(1),
        everyElement(1.0),
        reason: 'the last frame has to be the whole drawing',
      );
    });

    test('the public surface has no way to ask for a second pass', () {
      final reference = File(
        'docs/references/design-system-reference-llms.txt',
      ).readAsStringSync();
      final entry = reference.substring(
        reference.indexOf('### `DSIllustration`'),
        reference.indexOf('### `DSMetricBar`'),
      );
      for (final forbidden in <String>['repeat', 'autoplay', 'assetPath']) {
        expect(
          entry.contains(forbidden),
          isFalse,
          reason:
              'a looping drawing above a call to action is the WCAG 2.2.2 '
              'failure this component exists to make impossible',
        );
      }
    });
  });

  group('accessibility', () {
    testWidgets('a drawing is decorative unless it is given a name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        host(const DSIllustration(kind: DSIllustrationKind.locked)),
      );
      await tester.pumpAndSettle();
      expect(_imageNodes(tester), isEmpty);

      await tester.pumpWidget(
        host(
          const DSIllustration(
            kind: DSIllustrationKind.locked,
            semanticLabel: 'A closed padlock',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_imageNodes(tester), <String>['A closed padlock']);

      handle.dispose();
    });

    testWidgets('the line layer clears its ground at 3:1 in both themes', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(
            const DSIllustration(kind: DSIllustrationKind.empty),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();

        final style = DSIllustrationStyle.resolve(
          tester.element(find.byType(DSIllustration)),
        );
        final ratio = contrastRatio(style.lineColor!, style.groundColor!);
        expect(
          ratio,
          greaterThanOrEqualTo(3),
          reason:
              'WCAG 1.4.11 — in $brightness the boundary reads at '
              '${ratio.toStringAsFixed(2)}:1 against its own ground, so the '
              'shape dissolves',
        );
      }
    });
  });

  group('the tier an empty state opts into', () {
    testWidgets('the box is at its final size on the very first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSIllustration(
            kind: DSIllustrationKind.done,
            size: DSIllustrationSize.large,
          ),
        ),
      );

      final expected = AppTheme.spec.component.illustrationSizeLg;
      expect(
        tester.getSize(find.byType(DSIllustration)),
        Size.square(expected),
        reason:
            'a drawing that arrives late and pushes the title down is the '
            'jump the shared status layout exists to prevent',
      );
    });

    testWidgets('an empty state draws the illustration in place of the glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DSEmptyState(
            illustration: DSIllustrationKind.empty,
            title: 'No documents yet',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DSIllustration), findsOneWidget);
      expect(find.byType(DSWell), findsNothing);
      expect(find.text('No documents yet'), findsOneWidget);
    });

    testWidgets('asking for both a drawing and a glyph is a call site that '
        'has not decided', (tester) async {
      expect(
        () => DSEmptyState(
          title: 'No documents yet',
          icon: Icons.folder_open_outlined,
          illustration: DSIllustrationKind.empty,
        ),
        throwsAssertionError,
      );
    });
  });

  group('the style object', () {
    test('it merges, interpolates and takes its defaults from the spec', () {
      const a = DSIllustrationStyle(size: 100, strokeWidth: 2);
      const b = DSIllustrationStyle(size: 200, strokeWidth: 6);
      expect(a.lerp(b, 0.5).size, 150);
      expect(a.lerp(b, 0.5).strokeWidth, 4);
      expect(
        a.lerp(b, 0.5).groundColor,
        isNull,
        reason: 'a field nothing set stays unset, or the merge means nothing',
      );

      expect(
        a.merge(const DSIllustrationStyle(strokeWidth: 3)).size,
        100,
        reason: 'a layer above only overrides what it actually set',
      );
      expect(a.copyWith(strokeWidth: 3).strokeWidth, 3);
    });

    testWidgets('the three sizes come from the spec, and the stroke follows '
        'the box', (tester) async {
      await tester.pumpWidget(
        host(const DSIllustration(kind: DSIllustrationKind.empty)),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DSIllustration));
      final component = AppTheme.spec.component;

      final small = DSIllustrationStyle.resolve(
        context,
        size: DSIllustrationSize.small,
      );
      final large = DSIllustrationStyle.resolve(
        context,
        size: DSIllustrationSize.large,
      );

      expect(small.size, component.illustrationSizeSm);
      expect(large.size, component.illustrationSizeLg);
      expect(
        small.strokeWidth! / large.strokeWidth!,
        closeTo(
          component.illustrationSizeSm / component.illustrationSizeLg,
          0.001,
        ),
        reason:
            'a small illustration is a smaller drawing, not the same drawing '
            'with heavier lines',
      );
    });

    testWidgets('the tone reaches the drawing rather than the label under it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const DSIllustration(kind: DSIllustrationKind.error)),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DSIllustration));

      final neutral = DSIllustrationStyle.resolve(context);
      final error = DSIllustrationStyle.resolve(context, tone: DSTone.error);
      expect(error.accentColor, isNot(neutral.accentColor));
      expect(error.bodyColor, isNot(neutral.bodyColor));
      expect(
        error.lineColor,
        neutral.lineColor,
        reason: 'a tone colours the drawing, it does not re-ink it',
      );
    });
  });
}

/// A painted colour as one integer.
///
/// Compared packed rather than as a [Color]: the reveal multiplies each
/// layer's alpha, and the float components that come back out of that are not
/// bit-identical to the ones that went in even at full opacity.
int _opaque(Color c) => c.withValues(alpha: 1).toARGB32();

/// Every colour the painter actually put on a canvas, alpha removed.
///
/// The reveal fades each layer in, so the alpha is a fact about the frame
/// rather than about the palette; what matters is that the hue came from the
/// resolved style and not from a literal in the painter.
Set<int> _paintedColours(DSIllustrationKind kind, DSIllustrationStyle style) {
  final canvas = _RecordingCanvas();
  DSIllustrationPainter(
    kind: kind,
    progress: 1,
    style: style,
  ).paint(canvas, Size.square(style.size!));
  return canvas.colours.map(_opaque).toSet();
}

/// The kit's own painter, wherever it is on screen. `CustomPaint` alone finds
/// Material's chrome as well.
final Finder _kitPainter = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is DSIllustrationPainter,
);

/// A canvas that records what it is asked to draw with.
class _RecordingCanvas implements Canvas {
  final List<Color> colours = <Color>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    for (final argument in invocation.positionalArguments) {
      if (argument is Paint) colours.add(argument.color);
    }
    return null;
  }
}

/// A delegate that draws nothing and records the progress it was handed.
class _RecordingDelegate extends DSIllustrationDelegate {
  const _RecordingDelegate(this.seen);

  final List<double> seen;

  @override
  Widget build(
    BuildContext context,
    DSIllustrationKind kind,
    double progress,
    DSIllustrationStyle style,
  ) {
    seen.add(progress);
    return const SizedBox.shrink();
  }
}

/// A delegate that puts one findable widget per kind on the screen — what an
/// app's Lottie or Rive delegate looks like from the outside.
class _MarkerDelegate extends DSIllustrationDelegate {
  const _MarkerDelegate();

  static Key markerFor(DSIllustrationKind kind) =>
      ValueKey<String>('art-$kind');

  @override
  Widget build(
    BuildContext context,
    DSIllustrationKind kind,
    double progress,
    DSIllustrationStyle style,
  ) => SizedBox.shrink(key: markerFor(kind));
}

/// The labels of every node in the semantics tree marked as an image.
List<String> _imageNodes(WidgetTester tester) {
  final labels = <String>[];
  void walk(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isImage) {
      labels.add(node.label);
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(tester.semantics.find(find.byType(MaterialApp)));
  return labels;
}
