import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// K1–K11 — the palette gate.
///
/// A palette is the one part of a design that can be *checked* rather than
/// reviewed, and this is the check. Every rule below caught something real
/// in the identity this replaced: five surface steps whose neighbours sat at
/// 1.06, a ring and its own value label painted in one colour, a filled
/// success button at 1.82:1 in dark.
///
/// K5b (glyph on well) is not a separate check here — it is covered by K1's
/// `secondaryForeground`-on-`secondary` check, the same glyph-on-well pair
/// under a different name.
///
/// Run it alone with `make palette-lint`; it also runs inside `make test`,
/// which is what makes it a gate rather than a report.
void main() {
  // Every shipped identity, not only the one the app is wrapped in. An
  // identity that ships a contrast failure halo would have caught is the
  // exact failure a second identity introduces — the gates were written
  // against one palette, and a palette nobody gates is a palette that drifts
  // back into a table of hex codes.
  for (final spec in DesignSpec.shipped) {
    group(spec.name, () => _gates(spec));
  }
}

void _gates(DesignSpec spec) {
  final brightnesses = {'light': spec.palette.light, 'dark': spec.palette.dark};

  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void check(String rule, String what, Color fg, Color bg, double floor) {
    final ratio = contrastRatio(fg, bg);
    expect(
      ratio,
      greaterThanOrEqualTo(floor),
      reason:
          '$rule — $what: ${hex(fg)} on ${hex(bg)} is '
          '${ratio.toStringAsFixed(2)}:1, floor $floor:1',
    );
  }

  group('K1 — every on-colour reads on its colour', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        check(
          'K1',
          '$name primaryForeground',
          p.primaryForeground,
          p.primary,
          4.5,
        );
        check(
          'K1',
          '$name secondaryForeground',
          p.secondaryForeground,
          p.secondary,
          4.5,
        );
        check(
          'K1',
          '$name inverseForeground',
          p.inverseForeground,
          p.inverseBackground,
          4.5,
        );
        check('K1', '$name onDestructive', p.onDestructive, p.destructive, 4.5);
        check('K1', '$name onSuccess', p.onSuccess, p.success, 4.5);
        check('K1', '$name onWarning', p.onWarning, p.warning, 4.5);
        for (final (role, c) in [
          ('destructive', p.destructive),
          ('success', p.success),
          ('warning', p.warning),
          ('primary', p.primary),
        ]) {
          // Graphical object on a tint: the icon, the border.
          check('K1', '$name $role on its tint', c, p.tint(c), 3.0);
          // Text on a tint is the foreground, not the status colour.
          check(
            'K1',
            '$name foreground on $role tint',
            p.foreground,
            p.tint(c),
            4.5,
          );
        }
      });
    });
  });

  group('K2 — text reads on all three grounds', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        for (final (ground, bg) in [
          ('background', p.background),
          ('card', p.card),
          ('muted', p.muted),
        ]) {
          check('K2', '$name foreground on $ground', p.foreground, bg, 4.5);
          check(
            'K2',
            '$name mutedForeground on $ground',
            p.mutedForeground,
            bg,
            4.5,
          );
        }
      });
    });
  });

  // Borders are deliberately quiet: present, never loud. This trades the
  // WCAG 1.4.11 3:1 control-outline floor for a lighter look (user decision).
  group('K3 — the border is a quiet hairline', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        final ratio = contrastRatio(p.border, p.card);
        expect(
          ratio,
          inInclusiveRange(1.15, 1.6),
          reason: 'K3 $name border on card is ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });
  });

  group('K4 — status and chart colours are legible graphical objects', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        for (final (role, c) in [
          ('destructive', p.destructive),
          ('success', p.success),
          ('warning', p.warning),
        ]) {
          check('K4', '$name $role', c, p.card, 3.0);
        }
        expect(p.chart, hasLength(5));
        for (var i = 0; i < p.chart.length; i++) {
          check('K4', '$name chart${i + 1}', p.chart[i], p.card, 3.0);
        }
      });
    });
  });

  group('K5 — status colours are legible text', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        check('K5', '$name destructive', p.destructive, p.card, 4.5);
        check('K5', '$name success', p.success, p.card, 4.5);
        check('K5', '$name warning', p.warning, p.card, 4.5);
      });
    });
  });

  group('K6 — the three grounds are visibly apart', () {
    const floors = {'light': 1.15, 'dark': 1.22};
    brightnesses.forEach((name, p) {
      test(name, () {
        final floor = floors[name]!;
        if (p.card.toARGB32() == p.background.toARGB32()) {
          expect(contrastRatio(p.card, p.background), lessThan(1.02));
        } else {
          check('K6', '$name card vs background', p.card, p.background, floor);
        }
        check('K6', '$name muted vs card', p.muted, p.card, floor);
      });
    });
  });

  group('K9 — muted reads as a shape on the grounds it sits on', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        check('K9', '$name muted on card', p.muted, p.card, 1.15);
        check('K9', '$name primary on muted', p.primary, p.muted, 3.0);
      });
    });
  });

  group('K10 — no two neutrals are the same grey', () {
    const groundStep = 0.045;
    const markStep = 0.055;
    void ramp(
      String name,
      String group,
      double step,
      Map<String, Color> roles,
    ) {
      final entries = roles.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i], b = entries[j];
          if (a.value.toARGB32() == b.value.toARGB32()) continue;
          final delta =
              (Oklch.fromColor(a.value).l - Oklch.fromColor(b.value).l).abs();
          expect(
            delta,
            greaterThanOrEqualTo(step),
            reason:
                'K10 — $name $group: ${a.key} ${hex(a.value)} and ${b.key} '
                '${hex(b.value)} are ${delta.toStringAsFixed(3)} apart, floor $step',
          );
        }
      }
    }

    brightnesses.forEach((name, p) {
      test(name, () {
        ramp(name, 'grounds', groundStep, {
          'background': p.background,
          'card': p.card,
          'muted': p.muted,
        });
        ramp(name, 'marks', markStep, {
          'border': p.border,
          'mutedForeground': p.mutedForeground,
          'foreground': p.foreground,
        });
      });
    });
  });

  group('K8 — the ring is visible on every ground', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        check('K8', '$name ring on background', p.ring, p.background, 3.0);
        check('K8', '$name ring on card', p.ring, p.card, 3.0);
        check('K8', '$name ring on muted', p.ring, p.muted, 3.0);
      });
    });
  });

  group('K7 — peers that mean different things look different', () {
    void peers(String name, String group, Map<String, Color> roles) {
      final entries = roles.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i], b = entries[j];
          final ratio = contrastRatio(a.value, b.value);
          final hue = Oklch.hueDistance(
            Oklch.fromColor(a.value).h,
            Oklch.fromColor(b.value).h,
          );
          expect(
            ratio >= 1.20 || hue >= 20,
            isTrue,
            reason:
                'K7 — $name $group: ${a.key} ${hex(a.value)} and ${b.key} '
                '${hex(b.value)} are ${ratio.toStringAsFixed(2)}:1 and '
                '${hue.toStringAsFixed(1)}° apart',
          );
        }
      }
    }

    brightnesses.forEach((name, p) {
      test(name, () {
        peers(name, 'status', {
          'primary': p.primary,
          'destructive': p.destructive,
          'success': p.success,
          'warning': p.warning,
        });
        peers(name, 'chart', {
          for (var i = 0; i < p.chart.length; i++) 'chart${i + 1}': p.chart[i],
        });
      });
    });
  });

  group('K11 — primaryForeground reads on both gradient stops', () {
    brightnesses.forEach((name, p) {
      test(name, () {
        expect(p.primaryGradient.colors, hasLength(2));
        for (final (i, stop) in p.primaryGradient.colors.indexed) {
          check(
            'K11',
            '$name gradient stop $i',
            p.primaryForeground,
            stop,
            4.5,
          );
        }
      });
    });
  });

  test('changing one seed recolours the app', () {
    final seeds = spec.palette.lightSeeds!;
    final shifted = PaletteSpec.fromSeeds(
      light: seeds.copyWith(accentHue: seeds.accentHue + 120),
      dark: spec.palette.darkSeeds!.copyWith(
        accentHue: spec.palette.darkSeeds!.accentHue + 120,
      ),
    );
    expect(shifted.light.primary, isNot(spec.palette.light.primary));
    expect(shifted.light.secondary, isNot(spec.palette.light.secondary));
    expect(
      shifted.light.primaryGradient.colors.last,
      isNot(spec.palette.light.primaryGradient.colors.last),
    );
    final moved = PaletteSpec.fromSeeds(
      light: seeds.copyWith(canvasHue: seeds.canvasHue + 120),
      dark: spec.palette.darkSeeds!,
    );
    expect(moved.light.background, isNot(spec.palette.light.background));
  });

  for (final entry in brightnesses.entries) {
    test('${entry.key} — the scheme is built from the palette', () {
      final p = entry.value;
      final s = p.toColorScheme();
      expect(s.surface, p.background);
      expect(s.onSurface, p.foreground);
      expect(s.onSurfaceVariant, p.mutedForeground);
      expect(s.primary, p.primary);
      expect(s.onPrimary, p.primaryForeground);
      expect(s.primaryContainer, p.secondary);
      expect(s.onPrimaryContainer, p.secondaryForeground);
      expect(s.surfaceContainerLow, p.card);
      expect(s.surfaceContainerHighest, p.muted);
      expect(s.outline, p.border);
      expect(s.error, p.destructive);
      expect(s.scrim, p.overlay);
    });
  }
}
