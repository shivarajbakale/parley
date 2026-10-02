import 'package:flutter/widgets.dart';

/// The spacing scale, as data.
///
/// Eight steps grown from a base unit, and a [density] that multiplies all of
/// them at once. Density is the knob that makes a layout airy or compact
/// without a single widget being edited — the difference between an app that
/// feels editorial and one that feels utilitarian is very often only this.
@immutable
class SpaceSpec {
  /// The grid everything else is a multiple of.
  final double unit;

  /// Multipliers of [unit], smallest first: hairline, xs, sm, md, lg, xl,
  /// xxl, xxxl. Exactly eight — the named roles below index into it, and a
  /// shorter list throws on read. A test asserts the length rather than a
  /// `const` constructor, which cannot see a list's length.
  final List<double> steps;

  /// Scales the whole scale. 1.0 is the designed rhythm; 1.15 is airy; 0.9 is
  /// dense. Applied at read time so the ratios between steps are preserved.
  final double density;

  /// How far content stays from the edge of the screen. Its own value rather
  /// than a step, because the gutter answers to the device and the steps
  /// answer to each other.
  final double gutter;

  const SpaceSpec({
    this.unit = 4,
    this.steps = const [0.5, 1, 2, 3, 4, 6, 8, 12],
    this.density = 1,
    this.gutter = 16,
  });

  double _at(int i) => unit * steps[i] * density;

  double get hairline => _at(0);
  double get xs => _at(1);
  double get sm => _at(2);
  double get md => _at(3);
  double get lg => _at(4);
  double get xl => _at(5);
  double get xxl => _at(6);
  double get xxxl => _at(7);

  double get pageGutter => gutter * density;

  EdgeInsets get pagePadding => EdgeInsets.all(pageGutter);
  EdgeInsets get pageHorizontal => EdgeInsets.symmetric(horizontal: pageGutter);
  EdgeInsets get pageVertical => EdgeInsets.symmetric(vertical: pageGutter);
  EdgeInsets get cardPadding => EdgeInsets.all(lg);
  EdgeInsets get cardMargin =>
      EdgeInsets.symmetric(horizontal: pageGutter, vertical: xs);
  EdgeInsets get listItemPadding =>
      EdgeInsets.symmetric(horizontal: pageGutter, vertical: sm);
  EdgeInsets get sheetPadding => EdgeInsets.all(xl);
  EdgeInsets get sectionHeaderPadding =>
      EdgeInsets.fromLTRB(pageGutter, lg, pageGutter, xs);

  // ── Gaps ──
  //
  // A gap is a step of the scale rendered as a box, and it is the most common
  // read in the whole spec: a column of content is mostly gaps. They live here
  // rather than as constants in a namespace because a density of 0.9 has to
  // move the gaps too — a scale that compacts everything except the space
  // between things is not a density knob, it is a rounding error.

  SizedBox get verticalXs => SizedBox(height: xs);
  SizedBox get verticalSm => SizedBox(height: sm);
  SizedBox get verticalMd => SizedBox(height: md);
  SizedBox get verticalLg => SizedBox(height: lg);
  SizedBox get verticalXl => SizedBox(height: xl);
  SizedBox get verticalXxl => SizedBox(height: xxl);

  SizedBox get horizontalXs => SizedBox(width: xs);
  SizedBox get horizontalSm => SizedBox(width: sm);
  SizedBox get horizontalMd => SizedBox(width: md);
  SizedBox get horizontalLg => SizedBox(width: lg);

  SpaceSpec copyWith({
    double? unit,
    List<double>? steps,
    double? density,
    double? gutter,
  }) => SpaceSpec(
    unit: unit ?? this.unit,
    steps: steps ?? this.steps,
    density: density ?? this.density,
    gutter: gutter ?? this.gutter,
  );
}
