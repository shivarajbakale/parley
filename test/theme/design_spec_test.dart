import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

void main() {
  group('OKLCH', () {
    test('round-trips an in-gamut colour', () {
      // The property everything else in the palette gate rests on: if a
      // shipped colour cannot be read back as the OKLCH it was asked for,
      // no assertion about a ladder or a family means anything.
      for (final seed in const [
        Oklch(0.13, 0.014, 55),
        Oklch(0.755, 0.11, 205),
        Oklch(0.50, 0.08, 300),
        Oklch(0.96, 0.01, 90),
      ]) {
        final back = Oklch.fromColor(seed.toColor());
        expect(back.l, closeTo(seed.l, 0.002), reason: '$seed lightness');
        expect(back.c, closeTo(seed.c, 0.002), reason: '$seed chroma');
        expect(
          Oklch.hueDistance(back.h, seed.h),
          lessThan(0.6),
          reason: '$seed hue',
        );
      }
    });

    test('gamut mapping gives up chroma, never lightness or hue', () {
      // 0.4 chroma does not exist in sRGB at any hue. What comes back must
      // still be the same colour at the same weight, or a family sampled at
      // one lightness stops being one family at its most saturated hues.
      const asked = Oklch(0.62, 0.40, 150);
      final got = Oklch.fromColor(asked.toColor());
      expect(got.c, lessThan(asked.c));
      expect(got.l, closeTo(asked.l, 0.01));
      expect(Oklch.hueDistance(got.h, asked.h), lessThan(2.0));
    });

    test('hue distance takes the short way round', () {
      expect(Oklch.hueDistance(350, 10), closeTo(20, 0.001));
      expect(Oklch.hueDistance(10, 350), closeTo(20, 0.001));
      expect(Oklch.hueDistance(0, 180), closeTo(180, 0.001));
    });

    test('contrast ratio matches the WCAG endpoints', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
        closeTo(1, 0.001),
      );
    });
  });

  group('the seeds grow a family', () {
    const seeds = PaletteSeeds(
      brightness: Brightness.dark,
      canvasHue: 55,
      canvasChroma: 0.014,
      canvasLadder: [0.190, 0.277, 0.149],
      textLadder: [0.97, 0.755],
      outlineLightness: 0.42,
      accentHue: 135,
      accentChroma: 0.20,
      accentLightness: 0.86,
      accentWellLightness: 0.30,
      accentWellChroma: 0.070,
      categoryStartHue: 25,
      arcLightness: 0.660,
      arcChroma: 0.135,
      glyphLightness: 0.755,
      glyphChroma: 0.135,
    );

    test('the three surface roles point in the directions they name', () {
      // Not a monotonic ladder — that was the mistake this replaced. Five
      // steps all climbing meant "up" was the only direction available, so a
      // recess had to be spelled with the same token as a raised surface.
      // A card rises off the page and a well drops away from it, and the two
      // directions are what make the roles readable without a legend.
      final p = seeds.build();
      final canvas = Oklch.fromColor(p.background).l;
      final surface = Oklch.fromColor(p.card).l;
      final well = Oklch.fromColor(p.muted).l;
      expect(surface, greaterThan(canvas), reason: 'the card does not rise');
      expect(well, lessThan(canvas), reason: 'the well does not recess');
      // And far enough apart to survive a display. The ladder this replaced
      // had neighbours at 1.06:1.
      expect(contrastRatio(p.card, p.background), greaterThanOrEqualTo(1.15));
      expect(contrastRatio(p.muted, p.card), greaterThanOrEqualTo(1.15));
    });

    test('the on-accent colour is measured, not assumed', () {
      // A light accent needs dark type on it and a dark accent needs light.
      // Picking one and shipping it is wrong half the time.
      final light = seeds.copyWith(accentLightness: 0.90).build();
      final dark = seeds.copyWith(accentLightness: 0.45).build();
      expect(
        contrastRatio(light.primary, light.primaryForeground),
        greaterThan(4.5),
      );
      expect(
        contrastRatio(dark.primary, dark.primaryForeground),
        greaterThan(4.5),
      );
      expect(
        Oklch.fromColor(light.primaryForeground).l,
        lessThan(Oklch.fromColor(dark.primaryForeground).l),
      );
    });
  });

  group('the knobs move everything', () {
    test('space density scales the scale and keeps its ratios', () {
      const base = SpaceSpec();
      final airy = base.copyWith(density: 1.25);
      expect(airy.lg, closeTo(base.lg * 1.25, 0.001));
      expect(airy.xxl / airy.lg, closeTo(base.xxl / base.lg, 0.001));
      expect(airy.pageGutter, closeTo(base.pageGutter * 1.25, 0.001));
    });

    test('the eight named steps are all there', () {
      // Asserted here rather than in the constructor: a `const` constructor
      // cannot see a list's length, and the roles below index into it.
      expect(const SpaceSpec().steps, hasLength(8));
    });

    test('corner style changes the border class, not the radius', () {
      const radii = {AppShape.card: (12.0, 12.0)};
      OutlinedBorder borderFor(CornerStyle style) => ShapeSpec(
        style: style,
        radii: radii,
      ).border(AppShape.card, isApple: false);
      expect(borderFor(CornerStyle.rounded), isA<RoundedRectangleBorder>());
      expect(borderFor(CornerStyle.squircle), isA<RoundedSuperellipseBorder>());
      expect(borderFor(CornerStyle.cut), isA<BeveledRectangleBorder>());
    });

    test('platform corner style is the only one that differs by device', () {
      const spec = ShapeSpec();
      expect(
        spec.border(AppShape.card, isApple: true),
        isA<RoundedSuperellipseBorder>(),
      );
      expect(
        spec.border(AppShape.card, isApple: false),
        isA<RoundedRectangleBorder>(),
      );
      const rounded = ShapeSpec(style: CornerStyle.rounded);
      expect(
        rounded.border(AppShape.card, isApple: true).runtimeType,
        rounded.border(AppShape.card, isApple: false).runtimeType,
      );
    });

    test(
      'shape scale squares the app off at zero and leaves the pill alone',
      () {
        const flat = ShapeSpec(scale: 0);
        expect(flat.radiusOf(AppShape.card, isApple: true), 0);
        expect(flat.border(AppShape.pill, isApple: true), isA<StadiumBorder>());
      },
    );

    test('elevation intensity zero removes every shadow', () {
      const spec = ElevationSpec(intensity: 0);
      expect(
        spec.resolve(
          elevation: 8,
          brightness: Brightness.dark,
          shadowColor: const Color(0xFF000000),
        ),
        isEmpty,
      );
    });

    test('every elevation above zero is two layers', () {
      // One flat shadow at every level is a large part of what reads flat.
      const spec = ElevationSpec();
      for (final e in const [1.0, 2.0, 4.0, 8.0]) {
        expect(
          spec.resolve(
            elevation: e,
            brightness: Brightness.dark,
            shadowColor: const Color(0xFF000000),
          ),
          hasLength(2),
          reason: 'elevation $e',
        );
      }
    });

    test('springiness keeps the damping ratio', () {
      // Scaling damping linearly with stiffness over-damps a stiffened
      // spring into something that no longer springs.
      const motion = MotionSpec();
      final stiffer = const MotionSpec(springiness: 4).tuned(motion.bouncy);
      double ratio(SpringDescription s) =>
          s.damping / (2 * math.sqrt(s.mass * s.stiffness));
      expect(ratio(stiffer), closeTo(ratio(motion.bouncy), 0.001));
      expect(stiffer.stiffness, closeTo(motion.bouncy.stiffness * 4, 0.001));
    });

    test('speed scales every duration', () {
      const motion = MotionSpec(speed: 0.5);
      expect(motion.scaled(motion.normal).inMilliseconds, 150);
    });

    test('the type ratio re-proportions the whole scale', () {
      const tight = TypeSpec(ratio: 1.05);
      const wide = TypeSpec(ratio: 1.25);
      expect(
        tight.sizeOf('bodyMedium'),
        closeTo(wide.sizeOf('bodyMedium'), 0.001),
      );
      expect(
        wide.sizeOf('displayLarge'),
        greaterThan(tight.sizeOf('displayLarge') * 1.5),
      );
    });

    test('large type is tracked tighter than body', () {
      const spec = TypeSpec();
      final theme = spec.build();
      expect(
        theme.displayLarge!.letterSpacing!,
        lessThan(theme.bodyMedium!.letterSpacing!),
      );
    });

    test('an override wins over the generated scale', () {
      const override = TextTheme(bodyMedium: TextStyle(fontSize: 99));
      expect(
        const TypeSpec(override: override).build().bodyMedium!.fontSize,
        99,
      );
    });
  });

  group('the halo identity is grown, not typed', () {
    final spec = DesignSpec.halo();

    test('the accent is the anchor, to the byte', () {
      // The one colour a person chose. Everything else in the palette is
      // arithmetic from it, so this is the assertion that says the arithmetic
      // starts where the brand does.
      expect(spec.palette.light.primary.toARGB32(), 0xFF3961C6);
    });

    test('the dark accent is re-fitted rather than reused', () {
      // Same hue, lifted. The light accent on the dark card is unreadable at
      // its own lightness — which is what a palette that carries one accent
      // across both themes ships.
      final light = Oklch.fromColor(spec.palette.light.primary);
      final dark = Oklch.fromColor(spec.palette.dark.primary);
      expect(Oklch.hueDistance(light.h, dark.h), lessThan(2));
      expect(dark.l, greaterThan(light.l + 0.1));
      expect(
        contrastRatio(spec.palette.dark.primary, spec.palette.dark.card),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('a recess is the darkest role, in both themes', () {
      // The structural claim left standing once light mode's page went white.
      // "Raised toward light" cannot hold in a theme whose page *is* the
      // light: white is the end of the scale, so the card steps down from it
      // and the shadow carries the lift. What survives in both themes is the
      // recess — a well is the darkest of the three roles wherever it is
      // drawn, so "into the surface" is one move rather than two.
      for (final p in [spec.palette.light, spec.palette.dark]) {
        final canvas = Oklch.fromColor(p.background).l;
        final surface = Oklch.fromColor(p.card).l;
        final well = Oklch.fromColor(p.muted).l;
        expect(well, lessThan(canvas), reason: '${p.brightness} well vs page');
        expect(well, lessThan(surface), reason: '${p.brightness} well vs card');
      }
      // And in dark, where the page is not the extreme, the card still rises
      // toward light the way it always did.
      final dark = spec.palette.dark;
      expect(
        Oklch.fromColor(dark.card).l,
        greaterThan(Oklch.fromColor(dark.background).l),
      );
    });

    test('a light card is elevated by its edge and by its shadow', () {
      // Three tunings have now been tried on this pair. A grey card on a white
      // page read as a panel drawn on the paper. A white card on a grey page
      // read as a ground the app could not commit to, and it made the page —
      // the largest surface in the app — the one thing that was not white. A
      // flat ladder carried by the shadow alone read as one plane, because a
      // shadow says "raised" only where the eye is already hunting for an
      // edge.
      //
      // The page is white, because that is the ground this app is asked to
      // have, and the card is that same white. What was missing from the flat
      // attempt is supplied on the card rather than taken out of the page: a
      // soft hairline, so a run of cards has an edge to be found by before it
      // has a light to be lifted by. Both are asserted — either alone is a
      // tuning this identity has already backed out of.
      //
      // Revisited 2026-09-14 (user decision): a light cool-grey page under
      // white cards, after the gradient wash was taken out. The card keeps
      // its hairline and shadow; the page now steps back by tone as well.
      final p = spec.palette.light;
      expect(p.card.toARGB32(), 0xFFFFFFFF, reason: 'the card is white');
      expect(
        contrastRatio(p.card, p.background),
        greaterThanOrEqualTo(1.15),
        reason: 'the page is a light grey the card lifts off',
      );
      expect(spec.elevation.intensity, greaterThan(1.0));
      expect(
        spec.elevation.resolve(
          elevation: spec.elevation.low,
          brightness: Brightness.light,
          shadowColor: p.overlay,
        ),
        hasLength(2),
      );
    });

    test('the scheme is derived, never pasted', () {
      // The field this replaced made `toColorScheme()` return a hand-picked
      // scheme and skip every derivation under it, so moving a seed moved
      // nothing. Proving the scheme tracks the seeds is proving that is gone.
      final shifted = PaletteSpec.fromSeeds(
        light: spec.palette.lightSeeds!.copyWith(accentHue: 90),
        dark: spec.palette.darkSeeds!.copyWith(accentHue: 90),
      );
      expect(
        shifted.light.toColorScheme().primary,
        isNot(spec.palette.light.toColorScheme().primary),
      );
    });
  });

  group('reaching the spec from a widget', () {
    testWidgets('context.design returns what was wrapped', (tester) async {
      final wrapped = DesignSpec.halo().copyWith(name: 'under test');
      late DesignSpec seen;
      await tester.pumpWidget(
        Design(
          spec: wrapped,
          child: Builder(
            builder: (context) {
              seen = context.design;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.name, 'under test');
    });

    testWidgets('falls back rather than throwing when nothing wrapped', (
      tester,
    ) async {
      // A design-system widget has to render inside a bare harness that never
      // opted in; an exception there fails a test for a reason that is not
      // the reason it is checking.
      late DesignSpec seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = context.design;
            return const SizedBox();
          },
        ),
      );
      expect(seen.name, 'fallback');
    });

    testWidgets('context.palette follows the ambient brightness', (
      tester,
    ) async {
      final spec = DesignSpec.halo();
      late Palette light;
      late Palette dark;
      Widget probe(Brightness b, void Function(Palette) sink) => MaterialApp(
        theme: spec.themeFor(b),
        home: Design(
          spec: spec,
          child: Builder(
            builder: (context) {
              sink(context.palette);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(probe(Brightness.light, (p) => light = p));
      await tester.pumpWidget(probe(Brightness.dark, (p) => dark = p));
      // MaterialApp cross-fades between themes, so one frame after the swap
      // the ambient theme is still most of the way to the old one.
      await tester.pumpAndSettle();
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.background, isNot(dark.background));
    });
  });

  group('pageSettle', () {
    test('is critically damped, like every other spring in the spec', () {
      const spec = MotionSpec();
      expect(
        MotionSpec.dampingRatio(spec.pageSettle),
        closeTo(1.0, 0.001),
        reason:
            'an overshoot here wobbles the illustration the slide just '
            'carried',
      );
    });

    test('is softer and heavier than gentle', () {
      const spec = MotionSpec();
      expect(spec.pageSettle.stiffness, lessThan(spec.gentle.stiffness));
      expect(spec.pageSettle.mass, lessThan(spec.gentle.mass));
    });

    test('tuned() reaches it, and holds the ratio', () {
      const spec = MotionSpec(springiness: 1.25);
      final tuned = spec.tuned(spec.pageSettle);
      expect(tuned.stiffness, closeTo(spec.pageSettle.stiffness * 1.25, 0.001));
      expect(MotionSpec.dampingRatio(tuned), closeTo(1.0, 0.001));
    });

    test('copyWith carries it through', () {
      const spec = MotionSpec();
      expect(spec.copyWith(speed: 2).pageSettle, spec.pageSettle);
    });
  });
}
