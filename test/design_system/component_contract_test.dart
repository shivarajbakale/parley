import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The component contract: how a component is changed without being edited.
///
/// `docs/plans/00a-component-contract.plan.md` and `00b-composition.plan.md`
/// describe four layers that stack. The claim only means something if each
/// layer overrides what it sets and nothing else — a chain where a later layer
/// silently drops what an earlier one chose is worse than no chain, because
/// the widget that lost the value is not the widget anyone looks at.
///
/// `DSCard` is the worked example, so it is what these tests measure.
void main() {
  late DSCardStyle resolved;
  late BuildContext ctx;

  /// Resolves a card's style inside a real app, under an optional theme
  /// extension and an optional scope.
  Future<void> resolveUnder(
    WidgetTester tester, {
    DSCardVariant variant = DSCardVariant.elevated,
    DSCardStyle? extension,
    DSDensity? density,
    DSCardStyle? own,
    Widget Function(Widget child)? wrap,
  }) async {
    Widget probe = Builder(
      builder: (context) {
        ctx = context;
        resolved = DSCardStyle.resolve(context, variant, DSTone.neutral, own);
        return const SizedBox.shrink();
      },
    );
    if (wrap != null) probe = wrap(probe);
    if (density != null) {
      // Captured before the reassignment: a closure that reads `probe` would
      // read the Builder being assigned to it and rebuild itself forever.
      final inner = probe;
      probe = Builder(
        builder: (context) =>
            DSScope.merge(context, density: density, child: inner),
      );
    }
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: extension == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(extensions: [extension]),
          home: probe,
        ),
      ),
    );
  }

  group('the four layers stack', () {
    testWidgets('layer 1 is the identity, read from the palette', (t) async {
      await resolveUnder(t);
      expect(resolved.fillColor, ctx.palette.card);
      expect(resolved.elevation, DSElevation.medium);
      expect(resolved.padding, ctx.design.space.cardPadding);
    });

    testWidgets('each variant reads a different ground, not a different '
        'widget', (t) async {
      await resolveUnder(t, variant: DSCardVariant.filled);
      expect(resolved.fillColor, ctx.palette.muted);
      expect(resolved.elevation, DSElevation.none);
      expect(resolved.outlineColor, isNull);

      await resolveUnder(t, variant: DSCardVariant.outlined);
      expect(resolved.fillColor, ctx.palette.background);
      expect(resolved.outlineColor, ctx.palette.borderSoft);
    });

    testWidgets('layer 2 is a theme extension, and it overrides only what it '
        'sets', (t) async {
      await resolveUnder(
        t,
        extension: const DSCardStyle(elevation: DSElevation.none),
      );
      expect(resolved.elevation, DSElevation.none, reason: 'the layer applied');
      expect(
        resolved.fillColor,
        ctx.palette.card,
        reason: 'and nothing else moved',
      );
      expect(resolved.padding, ctx.design.space.cardPadding);
    });

    testWidgets('layer 3 is the container, and it beats the subtree', (
      t,
    ) async {
      await resolveUnder(
        t,
        density: DSDensity.compact,
        extension: const DSCardStyle(padding: EdgeInsets.all(99)),
      );
      expect(resolved.padding, EdgeInsets.all(ctx.design.space.md));
      expect(resolved.elevation, DSElevation.medium);
    });

    testWidgets('layer 4 is the instance, and it beats everything', (t) async {
      await resolveUnder(
        t,
        density: DSDensity.compact,
        extension: const DSCardStyle(elevation: DSElevation.none),
        own: const DSCardStyle(padding: EdgeInsets.zero),
      );
      expect(resolved.padding, EdgeInsets.zero);
      expect(
        resolved.elevation,
        DSElevation.none,
        reason: 'layer 2 still applies where layer 4 said nothing',
      );
      expect(
        resolved.fillColor,
        ctx.palette.card,
        reason: 'and layer 1 where neither did',
      );
    });
    testWidgets('the media surface takes a theme extension too', (t) async {
      late DSMediaSurfaceStyle mediaStyle;
      await t.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme.copyWith(
              extensions: <ThemeExtension<dynamic>>[
                const DSMediaSurfaceStyle(fit: BoxFit.fitWidth),
              ],
            ),
            home: Builder(
              builder: (context) {
                mediaStyle = DSMediaSurfaceStyle.resolve(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(mediaStyle.fit, BoxFit.fitWidth, reason: 'the layer applied');
      expect(
        mediaStyle.progressColor,
        isNotNull,
        reason: 'and nothing else moved',
      );
    });
  });

  group('DSScope', () {
    testWidgets('survives an intervening Builder and Wrap', (t) async {
      await resolveUnder(
        t,
        density: DSDensity.compact,
        wrap: (child) => Builder(
          builder: (_) => Wrap(children: [Center(child: child)]),
        ),
      );
      expect(
        resolved.padding,
        EdgeInsets.all(ctx.design.space.md),
        reason:
            'an InheritedWidget reaches past the widgets between, which '
            'is why the kit does not clone its children',
      );
    });

    testWidgets('an explicit argument beats it', (t) async {
      await t.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            home: Builder(
              builder: (context) => DSScope.merge(
                context,
                density: DSDensity.compact,
                child: const DSCard(
                  padding: EdgeInsets.all(40),
                  child: Text('x'),
                ),
              ),
            ),
          ),
        ),
      );
      // By predicate rather than by position: a Container with a margin
      // renders a Padding of its own, so `.first` finds the margin.
      expect(
        find.descendant(
          of: find.byType(DSCard),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == const EdgeInsets.all(40),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('merging keeps what the enclosing scope set', (t) async {
      late DSScope inner;
      await t.pumpWidget(
        MaterialApp(
          home: DSScope(
            size: DSSize.sm,
            tone: DSTone.warning,
            child: Builder(
              builder: (context) => DSScope.merge(
                context,
                density: DSDensity.compact,
                child: Builder(
                  builder: (context) {
                    inner = DSScope.maybeOf(context)!;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(inner.density, DSDensity.compact);
      expect(inner.size, DSSize.sm, reason: 'not dropped by the inner scope');
      expect(inner.tone, DSTone.warning);
    });

    testWidgets('a disabled container cannot be re-enabled from inside', (
      t,
    ) async {
      late DSScope inner;
      await t.pumpWidget(
        MaterialApp(
          home: DSScope(
            enabled: false,
            child: Builder(
              builder: (context) => DSScope.merge(
                context,
                enabled: true,
                child: Builder(
                  builder: (context) {
                    inner = DSScope.maybeOf(context)!;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        inner.enabled,
        isFalse,
        reason:
            'a control the user cannot reach is not a default a '
            'container may override',
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSCardStyle(
        elevation: DSElevation.medium,
        outlineColor: null,
      );
      final merged = base.merge(const DSCardStyle(elevation: DSElevation.none));
      expect(merged.elevation, DSElevation.none);
      expect(merged.padding, isNull, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSCardStyle(
        padding: EdgeInsets.all(0),
        fillColor: Color(0xFF000000),
      );
      const b = DSCardStyle(
        padding: EdgeInsets.all(20),
        fillColor: Color(0xFFFFFFFF),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.padding, const EdgeInsets.all(10));
      expect(mid.fillColor, isNot(const Color(0xFF000000)));
      expect(mid.fillColor, isNot(const Color(0xFFFFFFFF)));
      // Elevation is a role and roles do not interpolate: half a step of
      // depth is not a place on the ladder.
      expect(
        const DSCardStyle(
          elevation: DSElevation.none,
        ).lerp(const DSCardStyle(elevation: DSElevation.high), 0.9).elevation,
        DSElevation.high,
      );
    });

    testWidgets('a card actually paints what the chain resolved', (t) async {
      await t.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DSCard(
              style: DSCardStyle(elevation: DSElevation.none),
              child: Text('x'),
            ),
          ),
        ),
      );
      final container = t.widget<Container>(
        find
            .descendant(
              of: find.byType(DSCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as ShapeDecoration;
      expect(
        decoration.shadows,
        isEmpty,
        reason: 'the style reached the paint, not just the resolver',
      );
    });
  });

  group('the identity seam is complete', () {
    test('ComponentSpec.copyWith can override every field it declares', () {
      const spec = ComponentSpec();
      final changed = spec.copyWith(iconSizeSmall: 99, hairlineWidth: 7);
      expect(changed.iconSizeSmall, 99);
      expect(changed.hairlineWidth, 7);
      expect(changed.iconSize, spec.iconSize, reason: 'and nothing else moved');
    });
  });
}
