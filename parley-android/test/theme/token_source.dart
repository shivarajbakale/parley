// The tokens, read out of the spec once.
//
// `DESIGN.md` describes this design system to the outside world — to a tool
// that has never seen `lib/theme/spec/`. It needs an answer to the question
// "what colours, spaces, radii, type steps and component sizes does this app
// have", and a second hand-maintained copy of that list is exactly the drift
// the gate around it exists to prevent. So the list lives here, once, and the
// renderer imports it.
//
// It is a test-tree file rather than a `lib/` one because it is only ever read
// by a gate, and because reading it requires `dart:ui`: the tokens are `Color`s
// and `TextStyle`s grown at construction time, so the only place they can be
// *read* is inside a test binding. That is the same reason `design-md` and
// `palette-lint` are `flutter test`s and not `dart run` scripts.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Fields whose auto-derived group would be wrong. Everything else groups by
/// its first camel word, which is right for eighty-five of eighty-eight.
const componentOverrides = <String, (String, String)>{
  'minTapTarget': ('tap-target', 'min'),
  'listRowMinHeight': ('list-row', 'min-height'),
  'edgeFadeWidth': ('edge-fade', 'width'),
};

String fmtNum(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e9) return v.toInt().toString();
  var s = v.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String px(double v) => '${fmtNum(v)}px';

/// sRGB hex, which is exactly what the app renders.
///
/// Not `oklch()`, though the format allows it and the palette is grown in
/// OKLCH: `oklch.dart` converts one way only, so emitting OKLCH would mean
/// writing an inverse transform that no gate covers, to express a value the
/// engine has already resolved. Eight digits when the colour carries alpha —
/// `#RRGGBBAA`, which is the format's order, not ARGB.
String hex(Color c) {
  final v = c.toARGB32();
  final rgb = (v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final a = (v >> 24) & 0xFF;
  if (a == 0xFF) return '#$rgb';
  return '#$rgb${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

String kebab(String camel) => camel
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}-${m[2]}')
    .toLowerCase();

/// The flat colour map for one brightness, in declaration order.
///
/// Keys are the field names on `Palette`, kebab-cased. M2 holds this to the
/// class: a colour added to `Palette` and not added here fails the build.
Map<String, Color> colorTokens(Palette p) => <String, Color>{
  'background': p.background,
  'foreground': p.foreground,
  'card': p.card,
  'muted': p.muted,
  'muted-foreground': p.mutedForeground,
  'primary': p.primary,
  'primary-foreground': p.primaryForeground,
  'secondary': p.secondary,
  'secondary-foreground': p.secondaryForeground,
  'border': p.border,
  'ring': p.ring,
  'destructive': p.destructive,
  'success': p.success,
  'warning': p.warning,
  'overlay': p.overlay,
  'primary-gradient-from': p.primaryGradient.colors.first,
  'primary-gradient-to': p.primaryGradient.colors.last,
  for (var i = 0; i < p.chart.length; i++) 'chart-${i + 1}': p.chart[i],
};

/// The eight scale steps plus the gutter, which answers to the device rather
/// than to the steps and so is its own value.
Map<String, double> spacingTokens(DesignSpec spec) {
  final s = spec.space;
  return {
    'hairline': s.hairline,
    'xs': s.xs,
    'sm': s.sm,
    'md': s.md,
    'lg': s.lg,
    'xl': s.xl,
    'xxl': s.xxl,
    'xxxl': s.xxxl,
    'page-gutter': s.pageGutter,
  };
}

/// Every `final double` on `ComponentSpec`, in declaration order. M2 holds
/// this list to the class.
Map<String, double> componentFields(ComponentSpec c) => {
  'buttonHeightSm': c.buttonHeightSm,
  'buttonHeight': c.buttonHeight,
  'buttonHeightLg': c.buttonHeightLg,
  'fieldHeight': c.fieldHeight,
  'minTapTarget': c.minTapTarget,
  'listRowMinHeight': c.listRowMinHeight,
  'wellSize': c.wellSize,
  'rowWellRatio': c.rowWellRatio,
  'rowWellGlyphRatio': c.rowWellGlyphRatio,
  'iconSizeMicro': c.iconSizeMicro,
  'iconSizeSmall': c.iconSizeSmall,
  'iconSizeInline': c.iconSizeInline,
  'iconSize': c.iconSize,
  'iconSizeLarge': c.iconSizeLarge,
  'glyphHero': c.glyphHero,
  'grabberWidth': c.grabberWidth,
  'grabberHeight': c.grabberHeight,
  'iconWellSize': c.iconWellSize,
  'leadingSlotSize': c.leadingSlotSize,
  'chipMaxWidth': c.chipMaxWidth,
  'overlayWidthFactor': c.overlayWidthFactor,
  'overlayMaxWidth': c.overlayMaxWidth,
  'dialogMinWidth': c.dialogMinWidth,
  'sheetMinHeight': c.sheetMinHeight,
  'menuMinWidth': c.menuMinWidth,
  'menuMaxWidth': c.menuMaxWidth,
  'checkboxSize': c.checkboxSize,
  'radioSize': c.radioSize,
  'controlStroke': c.controlStroke,
  'switchTrackWidth': c.switchTrackWidth,
  'switchTrackHeight': c.switchTrackHeight,
  'switchThumbSize': c.switchThumbSize,
  'switchPressedThumbSize': c.switchPressedThumbSize,
  'switchCompactTrackWidth': c.switchCompactTrackWidth,
  'switchCompactTrackHeight': c.switchCompactTrackHeight,
  'switchCompactThumbSize': c.switchCompactThumbSize,
  'switchCompactPressedThumbSize': c.switchCompactPressedThumbSize,
  'sliderTrackHeight': c.sliderTrackHeight,
  'sliderThumbSize': c.sliderThumbSize,
  'sliderPressedThumbSize': c.sliderPressedThumbSize,
  'sliderTickSize': c.sliderTickSize,
  'controlHeight': c.controlHeight,
  'controlHeightSm': c.controlHeightSm,
  'controlHeightLg': c.controlHeightLg,
  'trackInset': c.trackInset,
  'tabHeight': c.tabHeight,
  'tabIndicatorHeight': c.tabIndicatorHeight,
  'minTabWidth': c.minTabWidth,
  'edgeFadeWidth': c.edgeFadeWidth,
  'headerExpandedHeight': c.headerExpandedHeight,
  'headerCollapsedTitleStart': c.headerCollapsedTitleStart,
  'headerCompactHeight': c.headerCompactHeight,
  'headerCompactHeightApple': c.headerCompactHeightApple,
  'wellSizeSm': c.wellSizeSm,
  'wellSizeLg': c.wellSizeLg,
  'illustrationSizeSm': c.illustrationSizeSm,
  'illustrationSize': c.illustrationSize,
  'illustrationSizeLg': c.illustrationSizeLg,
  'illustrationStroke': c.illustrationStroke,
  'avatarSizeSm': c.avatarSizeSm,
  'avatarSizeMd': c.avatarSizeMd,
  'avatarSizeLg': c.avatarSizeLg,
  'avatarSizeXl': c.avatarSizeXl,
  'avatarRing': c.avatarRing,
  'badgeHeight': c.badgeHeight,
  'dotSize': c.dotSize,
  'dotCountHeight': c.dotCountHeight,
  'dotMaxWidth': c.dotMaxWidth,
  'snackMaxWidth': c.snackMaxWidth,
  'fabSize': c.fabSize,
  'sidebarWidth': c.sidebarWidth,
  'swipeThreshold': c.swipeThreshold,
  'progressHeight': c.progressHeight,
  'progressStroke': c.progressStroke,
  'heroMinHeight': c.heroMinHeight,
  'heroMarkSize': c.heroMarkSize,
  'heroPlateStroke': c.heroPlateStroke,
  'chartHeight': c.chartHeight,
  'chartHeightSm': c.chartHeightSm,
  'sparklineHeight': c.sparklineHeight,
  'chartLineWidth': c.chartLineWidth,
  'chartDotRadius': c.chartDotRadius,
  'chartBarWidth': c.chartBarWidth,
  'chartValueAxisWidth': c.chartValueAxisWidth,
  'chartCategoryAxisHeight': c.chartCategoryAxisHeight,
  'chartScrubLineWidth': c.chartScrubLineWidth,
  'hairlineWidth': c.hairlineWidth,
  'fieldOutlineWidth': c.fieldOutlineWidth,
  'surfaceOutlineWidth': c.surfaceOutlineWidth,
  'selectedOutlineWidth': c.selectedOutlineWidth,
  'focusRingWidth': c.focusRingWidth,
  'focusRingGap': c.focusRingGap,
};

(String group, String token) componentSlot(String field) {
  final override = componentOverrides[field];
  if (override != null) return override;
  final m = RegExp(r'^([a-z0-9]+)([A-Z].*)?$').firstMatch(field);
  if (m == null) return ('misc', kebab(field));
  final rest = m.group(2);
  if (rest == null) return (m.group(1)!, 'size');
  return (m.group(1)!, kebab(rest[0].toLowerCase() + rest.substring(1)));
}

/// Component groups, insertion-ordered by first appearance of the group.
Map<String, Map<String, double>> componentGroups(ComponentSpec c) {
  final groups = <String, Map<String, double>>{};
  componentFields(c).forEach((field, value) {
    final (group, token) = componentSlot(field);
    (groups[group] ??= <String, double>{})[token] = value;
  });
  return groups;
}

const typeRoles = <String>[
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
  'titleMedium',
  'titleSmall',
  'bodyLarge',
  'bodyMedium',
  'bodySmall',
  'labelLarge',
  'labelMedium',
  'labelSmall',
];

Map<String, TextStyle> typeTokens(DesignSpec spec) {
  final theme = spec.type.build();
  final byRole = <String, TextStyle?>{
    'displayLarge': theme.displayLarge,
    'displayMedium': theme.displayMedium,
    'displaySmall': theme.displaySmall,
    'headlineLarge': theme.headlineLarge,
    'headlineMedium': theme.headlineMedium,
    'headlineSmall': theme.headlineSmall,
    'titleLarge': theme.titleLarge,
    'titleMedium': theme.titleMedium,
    'titleSmall': theme.titleSmall,
    'bodyLarge': theme.bodyLarge,
    'bodyMedium': theme.bodyMedium,
    'bodySmall': theme.bodySmall,
    'labelLarge': theme.labelLarge,
    'labelMedium': theme.labelMedium,
    'labelSmall': theme.labelSmall,
  };
  final out = <String, TextStyle>{};
  for (final role in typeRoles) {
    final style = byRole[role];
    if (style != null) out[kebab(role)] = style;
  }
  // The sixteenth role. Material's TextTheme stops at labelSmall and has no
  // slot for it, so it is carried separately here as it is in the spec.
  out['micro'] = spec.type.micro;
  return out;
}

/// Field names declared in `path`, optionally bounded to one class.
///
/// Reading the source as text is the only way to ask "did the spec grow a
/// field": `dart:mirrors` does not exist in Flutter, so a generated document
/// cannot otherwise notice that something was added to the class it claims to
/// describe.
Set<String> declaredFields(
  String path,
  RegExp declaration, {
  String? fromClass,
  String? untilClass,
}) {
  final lines = File(path).readAsLinesSync();
  var active = fromClass == null;
  final out = <String>{};
  for (final line in lines) {
    if (fromClass != null && line.startsWith('class $fromClass')) {
      active = true;
      continue;
    }
    if (active && untilClass != null && line.startsWith('class $untilClass')) {
      break;
    }
    if (!active) continue;
    final m = declaration.firstMatch(line);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}
