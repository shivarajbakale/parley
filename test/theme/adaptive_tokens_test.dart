import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/app_materials.dart';
import 'package:parley_android/theme/app_platform.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The adaptive layer's whole promise is that one app renders two ways. A
/// `TargetPlatform` override is the seam that makes that testable on one
/// machine — which is also why nothing here may read `dart:io`.
void main() {
  /// Builds the widget tree under a chosen platform and set of accessibility
  /// settings, and hands the resulting context to [body].
  Future<void> underPlatform(
    WidgetTester tester,
    TargetPlatform platform,
    void Function(BuildContext context) body, {
    Brightness brightness = Brightness.light,
    bool highContrast = false,
    bool disableAnimations = false,
    Widget? child,
  }) async {
    // A clean teardown between platforms: reusing the element tree across two
    // pumps is how a "both sides" test quietly checks one side twice.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          highContrast: highContrast,
          disableAnimations: disableAnimations,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // Theme rather than MaterialApp: MaterialApp installs its own
          // MediaQuery from the test window, which would drop the
          // accessibility settings this helper exists to set.
          child: Theme(
            data:
                (brightness == Brightness.light
                        ? AppTheme.lightTheme
                        : AppTheme.darkTheme)
                    .copyWith(platform: platform),
            child: Builder(
              builder: (context) {
                body(context);
                return child ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  group('which platform this is', () {
    test('every target lands on exactly one side', () {
      expect(
        AppPlatform.sideOfTarget(TargetPlatform.iOS),
        AppPlatformSide.apple,
      );
      expect(
        AppPlatform.sideOfTarget(TargetPlatform.macOS),
        AppPlatformSide.apple,
      );
      for (final target in [
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          AppPlatform.sideOfTarget(target),
          AppPlatformSide.material,
          reason: '$target should take the Material side',
        );
      }
      // A new TargetPlatform must not silently default to one side: the
      // switch is exhaustive, so adding one is a compile error here first.
      expect(TargetPlatform.values, hasLength(6));
    });

    testWidgets('it reads the theme, not the device', (tester) async {
      // The test runs on macOS or Linux; the theme says iOS, and the theme
      // wins. `Platform.isIOS` would fail this and is banned for the reason.
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        expect(AppPlatform.isApple(context), isTrue);
        expect(AppPlatform.select(context, cupertino: 'a', material: 'm'), 'a');
      });
      await underPlatform(tester, TargetPlatform.android, (context) {
        expect(AppPlatform.isApple(context), isFalse);
        expect(AppPlatform.select(context, cupertino: 'a', material: 'm'), 'm');
      });
    });
  });

  group('shape', () {
    testWidgets('Apple gets a continuous curve, Android a circular arc', (
      tester,
    ) async {
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        expect(
          context.shapeOf(AppShape.card),
          isA<RoundedSuperellipseBorder>(),
        );
        expect(
          context.shapeOf(AppShape.control),
          isA<RoundedSuperellipseBorder>(),
        );
      });
      await underPlatform(tester, TargetPlatform.android, (context) {
        expect(context.shapeOf(AppShape.card), isA<RoundedRectangleBorder>());
        expect(
          context.shapeOf(AppShape.card),
          isNot(isA<RoundedSuperellipseBorder>()),
        );
      });
    });

    testWidgets('each side reads its own column of the radius table', (
      tester,
    ) async {
      // The shipped identity sets both columns of `AppShape.card` to the same
      // number, so asserting that the two platforms differ would be asserting
      // one identity's taste. What has to hold for *any* identity is that the
      // two columns are reachable and that a build reads the one belonging to
      // the side it is drawing for — which is what M3 Expressive's wider
      // Android scale needs in order to be expressible at all.
      const twoColumns = ShapeSpec(
        radii: {
          AppShape.card: (10, 20),
          AppShape.control: (10, 20),
          AppShape.tile: (10, 20),
          AppShape.dialog: (10, 20),
          AppShape.sheet: (10, 20),
          AppShape.pill: (999, 999),
          AppShape.bar: (0, 0),
        },
      );
      expect(twoColumns.radiusOf(AppShape.card, isApple: true), 10);
      expect(twoColumns.radiusOf(AppShape.card, isApple: false), 20);

      late double apple;
      late double material;
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        apple = context.radiusOf(AppShape.card);
      });
      await underPlatform(tester, TargetPlatform.android, (context) {
        material = context.radiusOf(AppShape.card);
      });
      final shape = AppTheme.spec.shape;
      expect(apple, shape.radiusOf(AppShape.card, isApple: true));
      expect(material, shape.radiusOf(AppShape.card, isApple: false));
    });

    testWidgets('a sheet rounds its top corners only', (tester) async {
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        final border =
            context.shapeOf(AppShape.sheet) as RoundedSuperellipseBorder;
        final radius = border.borderRadius.resolve(TextDirection.ltr);
        expect(radius.topLeft.x, greaterThan(0));
        // Rounding the bottom two leaves slivers of background under a sheet
        // that is flush with the screen edge.
        expect(radius.bottomLeft, Radius.zero);
      });
    });

    testWidgets('a pill is the same class on both sides', (tester) async {
      // At the full radius the two curves converge, so branching would ship
      // two classes drawing identical pixels — a branch that can only drift.
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await underPlatform(tester, platform, (context) {
          expect(context.shapeOf(AppShape.pill), isA<StadiumBorder>());
        });
      }
    });
  });

  group('springs', () {
    test('each constant lands in the band its name claims', () {
      // A hand-typed damping coefficient is unreadable, and one typo turns a
      // settle into a wobble that only shows up on a device.
      final motion = AppTheme.spec.motion;
      expect(MotionSpec.dampingRatio(motion.snappy), closeTo(0.90, 0.02));
      expect(MotionSpec.dampingRatio(motion.gentle), closeTo(1.00, 0.02));
      expect(MotionSpec.dampingRatio(motion.bouncy), closeTo(0.60, 0.02));

      // gentle is the one that must never overshoot.
      expect(
        MotionSpec.dampingRatio(motion.gentle),
        greaterThanOrEqualTo(1.0 - 0.02),
      );
      expect(
        MotionSpec.dampingRatio(motion.bouncy),
        lessThan(MotionSpec.dampingRatio(motion.snappy)),
      );
    });

    test('a simulation carries the gesture velocity through', () {
      // The drag hand-off is most of the reason to use a spring at all: the
      // surface keeps moving at the speed the finger left it at.
      final sim = AppTheme.spec.motion.simulation(velocity: 3.5);
      expect(sim.dx(0), closeTo(3.5, 0.001));
      expect(sim.x(0), 0);
      expect(sim.isDone(5), isTrue);
    });

    test('springiness reaches the spring a widget actually runs', () {
      // The knob used to move nothing: every widget read the spring off a
      // namespace the spec could not touch. Stiffer, and the damping ratio
      // held — the property that decides whether it overshoots.
      const base = MotionSpec();
      double settleTime(SpringSimulation sim) {
        var t = 0.0;
        while (t < 5 && !sim.isDone(t)) {
          t += 0.005;
        }
        return t;
      }

      final tighter = const MotionSpec(springiness: 2).simulation();
      expect(settleTime(tighter), lessThan(settleTime(base.simulation())));
      expect(
        MotionSpec.dampingRatio(
          const MotionSpec(springiness: 2).tuned(base.snappy),
        ),
        closeTo(MotionSpec.dampingRatio(base.snappy), 1e-9),
      );
    });

    testWidgets('springs are Android-only, and off under reduced motion', (
      tester,
    ) async {
      await underPlatform(tester, TargetPlatform.android, (context) {
        expect(context.springsAvailable, isTrue);
      });
      // A bouncing tab bar on iOS reads as a bug: the platform's own
      // animations are curve-based.
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        expect(context.springsAvailable, isFalse);
      });
      await underPlatform(tester, TargetPlatform.android, (context) {
        expect(context.springsAvailable, isFalse);
      }, disableAnimations: true);
    });
  });

  group('materials', () {
    testWidgets('glass on Apple, tonal on Android', (tester) async {
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        final material = AppMaterials.chrome(context);
        expect(material.isGlass, isTrue);
        expect(material.blurSigma, context.design.chrome.barBlur);
        expect(material.saturation, greaterThan(1));
        expect(material.specular, isNotNull);
        expect(material.tint.a, lessThan(1));
      });
      await underPlatform(tester, TargetPlatform.android, (context) {
        final material = AppMaterials.chrome(context);
        expect(material.isGlass, isFalse);
        expect(material.specular, isNull);
        // Opaque means opaque — a nearly-opaque tint still reads through.
        expect(material.tint.a, 1);
      });
    });

    testWidgets('two OS settings switch translucency off', (tester) async {
      // Both were asked for deliberately. High contrast needs the text edge
      // translucency removes; reduced motion removes the movement underneath
      // that is the entire point of glass.
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        expect(AppMaterials.translucencyAllowed(context), isFalse);
        expect(AppMaterials.chrome(context).isGlass, isFalse);
      }, highContrast: true);
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        expect(AppMaterials.chrome(context).isGlass, isFalse);
      }, disableAnimations: true);
    });

    testWidgets('a sheet lifts upward, onto what it covers', (tester) async {
      await underPlatform(tester, TargetPlatform.iOS, (context) {
        final material = AppMaterials.sheet(context);
        // Opaque even on Apple, unlike the rest of the chrome layer: a sheet
        // is always opened over a scrimmed page, so glass gave it a grey that
        // changed with whatever it covered.
        expect(material.isGlass, isFalse);
        expect(material.tint.a, 1);
        expect(material.shadow.every((s) => s.offset.dy < 0), isTrue);
      });
    });

    test('the saturation matrix is identity at 1 and grey at 0', () {
      final identity = AppMaterials.saturationMatrix(1);
      expect(identity, hasLength(20));
      expect(identity[0], closeTo(1, 1e-9));
      expect(identity[1], closeTo(0, 1e-9));

      // At 0 every output channel is the same luminance sum, so the result is
      // a grey of the right lightness rather than a darker one.
      final grey = AppMaterials.saturationMatrix(0);
      expect(grey[0] + grey[1] + grey[2], closeTo(1, 1e-9));
      expect(grey[0], closeTo(grey[5], 1e-9));
      expect(
        grey[1],
        greaterThan(grey[2]),
        reason: 'green carries most of perceived brightness',
      );
    });

    testWidgets('the widget draws a BackdropFilter only when it is glass', (
      tester,
    ) async {
      await underPlatform(
        tester,
        TargetPlatform.iOS,
        (_) {},
        child: const AppChromeSurface(child: Text('chrome')),
      );
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);

      await underPlatform(
        tester,
        TargetPlatform.android,
        (_) {},
        child: const AppChromeSurface(child: Text('chrome')),
      );
      await tester.pump();
      // Not a cosmetic difference: a BackdropFilter reads back the layer
      // under it every frame, and Android's chrome is a tonal surface.
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('shadows are two layers, not one', () {
    final elevation = AppTheme.spec.elevation;
    final ink = AppTheme.spec.palette.light.overlay;
    final ramps = <String, List<BoxShadow>>{
      for (final level in DSElevation.values)
        if (level != DSElevation.none)
          for (final brightness in Brightness.values)
            '\${level.name}\${brightness.name}': elevation.resolve(
              elevation: elevation.levelOf(level),
              brightness: brightness,
              shadowColor: ink,
            ),
      for (final brightness in Brightness.values)
        'sheet\${brightness.name}': elevation.sheet(
          brightness: brightness,
          shadowColor: ink,
        ),
    };

    test('every elevation is a contact layer plus an ambient one', () {
      // One blurred rectangle is the most recognisable tell of a UI that was
      // not designed. This fails a "simplification" back to a single layer.
      ramps.forEach((name, shadows) {
        expect(shadows, hasLength(2), reason: '$name should be two layers');
        final contact = shadows.first;
        final ambient = shadows.last;
        expect(
          contact.blurRadius,
          lessThan(ambient.blurRadius),
          reason: '$name: the contact layer is the tight one',
        );
        expect(
          ambient.offset.dy.abs(),
          greaterThanOrEqualTo(contact.offset.dy.abs()),
          reason: '$name: the ambient layer falls further',
        );
      });
    });

    test('none is still none, and intensity 0 removes every shadow', () {
      expect(
        elevation.resolve(
          elevation: elevation.none,
          brightness: Brightness.light,
          shadowColor: ink,
        ),
        isEmpty,
      );
      expect(
        elevation
            .copyWith(intensity: 0)
            .resolve(
              elevation: elevation.high,
              brightness: Brightness.light,
              shadowColor: ink,
            ),
        isEmpty,
      );
    });

    test('a sheet is lit from the same place, and casts upward', () {
      // A sheet arrives from the bottom, so the edge a reader sees is its top
      // one — a shadow pointing down falls off the screen.
      final down = elevation.resolve(
        elevation: elevation.high,
        brightness: Brightness.light,
        shadowColor: ink,
      );
      final up = elevation.sheet(
        brightness: Brightness.light,
        shadowColor: ink,
      );
      expect(up, hasLength(down.length));
      for (var i = 0; i < up.length; i++) {
        expect(up[i].offset.dy, -down[i].offset.dy);
        expect(up[i].blurRadius, down[i].blurRadius);
      }
    });

    test('dark carries more shadow than light, at the same level', () {
      // A shadow is the absence of light and there is less light to remove.
      final light = elevation.resolve(
        elevation: elevation.high,
        brightness: Brightness.light,
        shadowColor: ink,
      );
      final dark = elevation.resolve(
        elevation: elevation.high,
        brightness: Brightness.dark,
        shadowColor: ink,
      );
      expect(dark.first.color.a, greaterThan(light.first.color.a));
    });
  });

  group('page transitions branch', () {
    test('each platform gets the builder its users expect', () {
      final builders = AppTheme.lightTheme.pageTransitionsTheme.builders;

      // Apple: slide from the right, and the edge-swipe back gesture that
      // comes with the builder rather than with the route.
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.macOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );

      // Android: Material 3 Expressive's fade-forwards.
      expect(
        builders[TargetPlatform.android],
        isA<FadeForwardsPageTransitionsBuilder>(),
      );

      // A target left out does not fall back to the theme — it falls back to
      // Flutter's default for that platform, which is a transition nobody
      // chose. So every target is named.
      for (final target in TargetPlatform.values) {
        expect(builders[target], isNotNull, reason: '$target has no builder');
      }
    });

    test('the transition matches the side the platform is on', () {
      final builders = AppTheme.darkTheme.pageTransitionsTheme.builders;
      builders.forEach((target, builder) {
        final expectApple =
            AppPlatform.sideOfTarget(target) == AppPlatformSide.apple;
        expect(
          builder is CupertinoPageTransitionsBuilder,
          expectApple,
          reason: '$target disagrees with AppPlatform.sideOfTarget',
        );
      });
    });
  });

  test('the damping arithmetic is the standard one', () {
    // Guards the helper the constants are checked with, so a wrong helper
    // cannot make wrong constants look right.
    const spring = SpringDescription(mass: 2, stiffness: 8, damping: 4);
    expect(
      MotionSpec.dampingRatio(spring),
      closeTo(4 / (2 * math.sqrt(16)), 1e-12),
    );
  });
}
