import 'package:flutter/material.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The design tokens, drawn — colour, depth, corners, type and space.
///
/// The component gallery answers "what does the kit own?". This answers the
/// question a designer asks first: "what is it made of?". Every value here is
/// read from the `DesignSpec` in scope rather than typed, so re-theming the
/// identity re-draws this page, and a page that disagreed with the app would
/// be a page reading a different spec.
///
/// Colours are shown light and dark side by side because a token is a pair:
/// a swatch that only works in one brightness is half a decision.
///
/// It is a demo surface, deleted with the rest of `lib/screens/design_system/`.
class FoundationsPage extends StatelessWidget {
  const FoundationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DSPage(
      title: 'Foundations',
      slivers: [
        _section(context, 'Colour', const _ColourSection()),
        _section(context, 'Elevation', const _ElevationSection()),
        _section(context, 'Corners and borders', const _ShapeSection()),
        _section(context, 'Type scale', const _TypeSection()),
        _section(context, 'Spacing', const _SpaceSection()),
      ],
    );
  }

  Widget _section(BuildContext context, String label, Widget child) {
    final space = context.design.space;
    final gutter = DSGutter.of(context);
    return SliverToBoxAdapter(
      child: DSSection(
        label: label,
        contentPadding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          0,
          gutter,
          space.xl,
        ),
        child: child,
      ),
    );
  }
}

// ── Colour ────────────────────────────────────────────────────────────────

typedef _Token = (String name, Color Function(Palette p) read);

const _colourGroups = <(String, List<_Token>)>[
  (
    'Grounds',
    [('background', _background), ('card', _card), ('muted', _muted)],
  ),
  (
    'Text',
    [('foreground', _foreground), ('mutedForeground', _mutedForeground)],
  ),
  (
    'Brand',
    [
      ('primary', _primary),
      ('primaryForeground', _primaryForeground),
      ('secondary', _secondary),
      ('secondaryForeground', _secondaryForeground),
    ],
  ),
  ('Lines', [('border', _border), ('ring', _ring)]),
  (
    'Status',
    [
      ('destructive', _destructive),
      ('success', _success),
      ('warning', _warning),
    ],
  ),
  ('Overlay', [('overlay', _overlay)]),
];

// Tear-offs rather than closures, so the table above can be const.
Color _background(Palette p) => p.background;
Color _card(Palette p) => p.card;
Color _muted(Palette p) => p.muted;
Color _foreground(Palette p) => p.foreground;
Color _mutedForeground(Palette p) => p.mutedForeground;
Color _primary(Palette p) => p.primary;
Color _primaryForeground(Palette p) => p.primaryForeground;
Color _secondary(Palette p) => p.secondary;
Color _secondaryForeground(Palette p) => p.secondaryForeground;
Color _border(Palette p) => p.border;
Color _ring(Palette p) => p.ring;
Color _destructive(Palette p) => p.destructive;
Color _success(Palette p) => p.success;
Color _warning(Palette p) => p.warning;
Color _overlay(Palette p) => p.overlay;

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class _ColourSection extends StatelessWidget {
  const _ColourSection();

  @override
  Widget build(BuildContext context) {
    final spec = context.design.palette;
    final light = spec.light;
    final dark = spec.dark;
    final space = context.design.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSText(
          '15 roles. Each swatch is a pair: light on the left half, dark on '
          'the right.',
          role: DSTextRole.bodyDetail,
        ),
        for (final (group, tokens) in _colourGroups) ...[
          space.verticalLg,
          DSText(group, role: DSTextRole.eyebrow),
          space.verticalSm,
          _TokenGrid(
            children: [
              for (final (name, read) in tokens)
                _SwatchTile(name: name, light: read(light), dark: read(dark)),
            ],
          ),
        ],
        space.verticalLg,
        const DSText('Brand gradient', role: DSTextRole.eyebrow),
        space.verticalSm,
        Row(
          children: [
            for (final pal in [light, dark]) ...[
              if (pal == dark) space.horizontalSm,
              Expanded(
                child: SizedBox(
                  height: space.xxxl,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      gradient: pal.primaryGradient,
                      shape: context.shapeOf(AppShape.control),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        space.verticalLg,
        const DSText('Chart', role: DSTextRole.eyebrow),
        space.verticalSm,
        _TokenGrid(
          children: [
            for (var i = 0; i < light.chart.length; i++)
              _SwatchTile(
                name: 'chart${i + 1}',
                light: light.chart[i],
                dark: dark.chart[i],
              ),
          ],
        ),
      ],
    );
  }
}

/// One colour token: a swatch split light | dark, its name, both hex values.
class _SwatchTile extends StatelessWidget {
  final String name;
  final Color light;
  final Color dark;

  const _SwatchTile({
    required this.name,
    required this.light,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final shape = context.shapeOf(AppShape.control);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.4,
          child: DecoratedBox(
            // A hairline on top, so a swatch that matches the page still has
            // an edge.
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: shape.copyWith(
                side: BorderSide(color: context.palette.borderSoft),
              ),
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ColoredBox(color: light)),
                  Expanded(child: ColoredBox(color: dark)),
                ],
              ),
            ),
          ),
        ),
        space.verticalXs,
        DSText(_hex(light), role: DSTextRole.itemMeta, numeric: true),
        DSText(_hex(dark), role: DSTextRole.itemMeta, numeric: true),
        // Last, so a name that wraps pushes only itself down and the hex
        // lines stay level across the row.
        DSText(name, role: DSTextRole.itemTitle, maxLines: 3),
      ],
    );
  }
}

// ── Elevation ─────────────────────────────────────────────────────────────

class _ElevationSection extends StatelessWidget {
  const _ElevationSection();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final palette = context.palette;
    final space = design.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSText(
          'Five steps. Shadows are tuned per brightness, so switch the '
          'appearance to see the other half.',
          role: DSTextRole.bodyDetail,
        ),
        space.verticalLg,
        // A recessed ground, so a raised sample reads as raised. On the page's
        // own colour a surface card is invisible and only its shadow shows.
        DecoratedBox(
          decoration: ShapeDecoration(
            color: palette.muted,
            shape: context.shapeOf(AppShape.card),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(space.lg),
            child: _TokenGrid(
              children: [
                for (final level in DSElevation.values)
                  _TokenTile(
                    label: level.name,
                    meta: '${design.elevation.levelOf(level)}',
                    decoration: ShapeDecoration(
                      color: palette.card,
                      shape: context.shapeOf(AppShape.card),
                      shadows: design.elevation.resolve(
                        elevation: design.elevation.levelOf(level),
                        brightness: palette.brightness,
                        shadowColor: palette.overlay,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Corners and borders ───────────────────────────────────────────────────

class _ShapeSection extends StatelessWidget {
  const _ShapeSection();

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final palette = context.palette;
    final space = design.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSText(
          'Corner style: ${design.shape.style.name}, scale '
          '${design.shape.scale}. Radii are per role, never per widget.',
          role: DSTextRole.bodyDetail,
        ),
        space.verticalLg,
        _TokenGrid(
          children: [
            for (final role in AppShape.values)
              _TokenTile(
                label: role.name,
                meta: role == AppShape.pill
                    ? 'stadium'
                    : '${context.radiusOf(role)}',
                decoration: ShapeDecoration(
                  color: palette.muted,
                  shape: context
                      .shapeOf(role)
                      .copyWith(side: BorderSide(color: palette.border)),
                ),
              ),
          ],
        ),
        space.verticalXl,
        const DSText('Strokes', role: DSTextRole.eyebrow),
        space.verticalSm,
        for (final (name, color) in [
          ('outline', palette.border),
          ('outlineSoft', palette.borderSoft),
        ]) ...[
          DSText(name, role: DSTextRole.itemMeta),
          space.verticalXs,
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: context
                  .shapeOf(AppShape.control)
                  .copyWith(side: BorderSide(color: color)),
            ),
            child: SizedBox(height: space.xxl),
          ),
          space.verticalMd,
        ],
      ],
    );
  }
}

/// Equal columns that span the full width, so every tile's edges line up with
/// the text above and below. The last row is padded with empty cells rather
/// than stretched, so a short row keeps the column rhythm.
class _TokenGrid extends StatelessWidget {
  final List<Widget> children;

  const _TokenGrid({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _grid(
      context,
      // Three across on a phone; two when the text is large enough that a
      // token name would not fit a third of the row.
      columns:
          constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
              context.design.space.xxxl * 6
          ? 2
          : 3,
    ),
  );

  Widget _grid(BuildContext context, {required int columns}) {
    final space = context.design.space;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = children.sublist(
        i,
        (i + columns).clamp(0, children.length),
      );
      if (rows.isNotEmpty) rows.add(space.verticalLg);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) space.horizontalMd,
              Expanded(
                child: c < cells.length ? cells[c] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// A labelled sample for a token that is a surface rather than a colour.
class _TokenTile extends StatelessWidget {
  final String label;
  final String meta;
  final Decoration decoration;

  const _TokenTile({
    required this.label,
    required this.meta,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(decoration: decoration),
        ),
        space.verticalSm,
        DSText(label, role: DSTextRole.itemTitle, maxLines: 3),
        DSText(meta, role: DSTextRole.itemMeta, numeric: true),
      ],
    );
  }
}

// ── Type ──────────────────────────────────────────────────────────────────

class _TypeSection extends StatelessWidget {
  const _TypeSection();

  @override
  Widget build(BuildContext context) {
    final type = context.design.type;
    final space = context.design.space;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSText(
          '${type.family}, display ${type.displayFamily}. Base '
          '${type.baseSize}, ratio ${type.ratio}. Widgets ask for a role; '
          'the numbers below are what each role resolves to here.',
          role: DSTextRole.bodyDetail,
        ),
        for (final role in DSTextRole.values) ...[
          space.verticalLg,
          DSText(_specimen(role), role: role, maxLines: 2),
          space.verticalXs,
          DSText(
            _describe(context, role),
            role: DSTextRole.itemMeta,
            numeric: true,
          ),
        ],
      ],
    );
  }

  static String _specimen(DSTextRole role) => switch (role) {
    DSTextRole.metric || DSTextRole.count => '1,284',
    DSTextRole.metricUnit => 'km',
    DSTextRole.timestamp => '09:41',
    _ => 'The quick brown fox',
  };

  static String _describe(BuildContext context, DSTextRole role) {
    final style = DSTextStyle.resolve(context, role: role).textStyle;
    final size = style?.fontSize?.toStringAsFixed(1) ?? 'inherit';
    final weight = style?.fontWeight?.toString().split('.').last ?? 'inherit';
    final height = style?.height?.toStringAsFixed(2) ?? 'normal';
    return '${role.name}  ·  $size / $weight / line $height';
  }
}

// ── Space ─────────────────────────────────────────────────────────────────

class _SpaceSection extends StatelessWidget {
  const _SpaceSection();

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final palette = context.palette;
    final steps = <(String, double)>[
      ('hairline', space.hairline),
      ('xs', space.xs),
      ('sm', space.sm),
      ('md', space.md),
      ('lg', space.lg),
      ('xl', space.xl),
      ('xxl', space.xxl),
      ('xxxl', space.xxxl),
      ('gutter', DSGutter.of(context)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSText(
          'Unit ${space.unit}, density ${space.density}.',
          role: DSTextRole.bodyDetail,
        ),
        space.verticalLg,
        for (final (name, value) in steps)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: space.sm),
            child: Row(
              children: [
                SizedBox(
                  width: space.xxxl * 2,
                  child: DSText(name, role: DSTextRole.itemTitle, maxLines: 1),
                ),
                SizedBox(
                  width: value,
                  height: space.md,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: palette.primary),
                  ),
                ),
                space.horizontalSm,
                DSText(
                  value.toStringAsFixed(1),
                  role: DSTextRole.itemMeta,
                  numeric: true,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
