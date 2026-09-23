import 'package:flutter/material.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The photographs the demo surfaces are illustrated with, as named constants
/// rather than string literals scattered through the stories.
///
/// They are bundled assets, not network images, for three reasons. The demo
/// has to look right with the wifi off, which is the state a reader first
/// opens it in. A `flutter test` has no network at all, so anything fetched
/// renders as an error box in every golden baseline. And a fixed asset is a
/// fixed number of bytes at a fixed size, so the image box never reflows the
/// row it sits in.
///
/// Roughly 330 KB for the five of them at 900×600. Delete this file and its
/// `assets/images/` folder with the rest of the design-system demo surface;
/// nothing under `lib/design_system/` references them.
///
/// Source: photographs from the Lorem Picsum collection, which redistributes
/// Unsplash photographs under the Unsplash License — free to use, including
/// commercially, with no attribution required. Replace them with the app's
/// own art; the paths are the only thing anything depends on.
abstract final class DemoPhotos {
  static const paletteWall = 'assets/images/palette-wall.jpg';
  static const crossing = 'assets/images/crossing.jpg';
  static const openBook = 'assets/images/open-book.jpg';
  static const flatLay = 'assets/images/flat-lay.jpg';
  static const explodedView = 'assets/images/exploded-view.jpg';

  /// Every photograph, in a stable order, for a story that wants a different
  /// picture per row without naming each one.
  static const all = <String>[
    paletteWall,
    crossing,
    openBook,
    flatLay,
    explodedView,
  ];
}

/// A bundled photograph, sized by whatever box it is given, with a coloured
/// swatch behind it.
///
/// The swatch is not decoration. It is what paints while the image decodes and
/// what stays if the asset is missing — the demo surfaces are meant to be
/// copied and edited, and the first thing an editor does is point one of these
/// at a file that is not there yet. A flat category colour is a legible answer
/// to that; a broken-image glyph on a hero is not.
///
/// It is flat rather than a gradient on purpose. The probe's `contrast` rule
/// resolves a layer's colour from `BoxDecoration.color`, and a gradient-only
/// decoration has none, so anything drawn over it is graded against the
/// surface behind it instead — a mismeasurement that once held `titleMedium`
/// up at 19pt to satisfy a floor against a colour that was never there.
class DemoPhoto extends StatelessWidget {
  const DemoPhoto({
    super.key,
    required this.asset,
    required this.fallbackHue,
    this.fallbackLabel,
  });

  /// A path from [DemoPhotos].
  final String asset;

  /// Demo index, currently unused for colour: the box takes `palette.muted`
  /// while the photograph loads and if it never arrives.
  final int fallbackHue;

  /// A word drawn on the fallback swatch, so a coloured box never sits on the
  /// page without something to read. Not drawn over the photograph: text on a
  /// photograph has no contrast anything can guarantee, and the row's own
  /// title is already beside it.
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    fit: BoxFit.cover,
    // The box is already at its final size, so there is nothing to reflow and
    // nothing to animate into. A cross-fade here would be a flicker on the
    // golden sheets, where every asset is precached and lands on frame one.
    errorBuilder: (context, _, _) => _fallback(context),
    frameBuilder: (context, child, frame, wasSync) =>
        wasSync || frame != null ? child : _fallback(context),
  );

  Widget _fallback(BuildContext context) {
    final palette = context.palette;
    final label = fallbackLabel;

    return DecoratedBox(
      decoration: BoxDecoration(color: palette.muted),
      child: label == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.design.space.xs,
                ),
                // Fitted rather than set at a role size: the box can be 72
                // points wide and the word is whatever the caller passed, and
                // at `headlineSmall` one of them broke mid-word — "Token / s"
                // — which is the `word-break` probe rule's whole reason for
                // existing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.mutedForeground,
                      fontWeight: context.design.type.emphasisWeight,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
