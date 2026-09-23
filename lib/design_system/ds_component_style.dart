// ds-tier: 0 — foundation

import 'package:flutter/material.dart';

/// The base every component's style object extends.
///
/// A design system that can only be changed by editing its widgets is a folder
/// of widgets. This is the type that makes the alternative possible: a value
/// object holding a component's appearance, resolvable from four places, so a
/// consumer who cannot edit `lib/design_system/` can still get the look they
/// need.
///
/// The chain, from `docs/plans/00a-component-contract.plan.md` §3, with each
/// layer overriding only what it sets:
///
///     1. ComponentSpec / DesignSpec  identity scope   "wells are 40dp here"
///     2. ThemeExtension<DSxStyle>    subtree scope    "cards are flat on this
///                                                      screen"
///     3. DSScope                     container scope  "controls in this footer
///                                                      are small"
///     4. style:                      instance scope   "this card has no shadow"
///     5. slots                       replacement      "draw this instead"
///
/// Four rules, and `tool/ui_lint.dart` fails the build on the first three.
///
/// **Every field is nullable.** A non-null default on the style object defeats
/// the merge: once a field has a value, nothing downstream can tell a
/// deliberate override from a default that was never set.
///
/// **Defaults live in `resolve`, read from the spec.** Never as field
/// initialisers, and never as `??` scattered through `build` — that is how a
/// component ends up with two answers to the same question.
///
/// **`lerp` is implemented, not stubbed.** A style that returns `this` makes
/// the whole theme animation snap on that one component while everything
/// around it fades.
///
/// **No behaviour on the style object.** It is data. A style class carrying a
/// callback is a controller with a bad name.
///
/// A worked example is `DSCardStyle` in `ds_card.dart`.
@immutable
abstract class DSComponentStyle<T extends DSComponentStyle<T>>
    extends ThemeExtension<T> {
  const DSComponentStyle();

  /// This style with every non-null field of [other] laid over it.
  ///
  /// Null means "not specified at this layer", which is the whole reason the
  /// fields are nullable: it is what lets four layers stack without the ones
  /// above having to know what the ones below chose.
  T merge(T? other);
}

/// The four layers, applied in order, in one place.
///
/// Every component's `resolve` ends in a call to this, so the order cannot
/// drift between components — a kit where one card reads its theme extension
/// after its scope and another reads it before has no chain at all, it has
/// fifteen.
///
/// [specDefaults] is layer 1 and is the only layer that may be non-null
/// throughout; [scope] is layer 3, the contribution a container makes through
/// `DSScope`; [own] is layer 4, the caller's `style:`.
T resolveStyle<T extends DSComponentStyle<T>>({
  required BuildContext context,
  required T specDefaults,
  T? scope,
  T? own,
}) => specDefaults
    .merge(Theme.of(context).extension<T>())
    .merge(scope)
    .merge(own);

/// The recipe that turns a semantic family into a surface big enough to read a
/// paragraph on.
///
/// `Palette.tint` of a status is a badge colour: sampled at OKLCH L .918 it is
/// pitched to hold a small filled chip. A message or a card is not small, and
/// five of them stacked at that weight read as five highlighter strokes. This
/// lays the container over the surface at [toneAlpha] — near L .947 on the
/// shipped identity, which the eye reads as paper that has been coloured
/// rather than as a block of colour — and derives the hairline from the same
/// two colours rather than from a third palette entry, so an identity that
/// re-hues a tone gets a matching ground and edge for free.
///
/// It lives here rather than on either component because a `success` message
/// and a `success` card on one screen have to be the same green. Two copies of
/// five constants is the drift the style chain exists to prevent.
///
/// The numbers are not free. `ds_message_test`'s C-8 gate wants every pair of
/// grounds 1.20:1 apart or 20° of hue apart in both themes, and washing every
/// tone at one rate walks them all toward the surface together. `neutral`
/// washes at [neutralAlpha] instead: it is the one ground with no hue to
/// separate on, and at the shared .65 it lands in the middle of the four that
/// do — 1.16:1 and 15° from `success`, which is the version that fails.
abstract final class DSToneWash {
  /// How much of the tone's container survives the wash toward the surface.
  static const double toneAlpha = 0.65;

  /// `neutral` keeps more of its ground, so it stays a step below the four
  /// tones that have a hue.
  static const double neutralAlpha = 0.85;

  /// How much of the accent shows in the hairline. Dark needs more of it: the
  /// same alpha over a dark fill is a smaller step in luminance.
  static const double borderAlphaLight = 0.26;
  static const double borderAlphaDark = 0.40;

  /// `neutral` takes less of it. Its accent is a grey, and a grey laid over a
  /// grey at the same alpha is a harder line than a hue laid over a tint at
  /// that alpha — one separates on value, which the eye reads as an edge, and
  /// the other on hue, which it reads as the same paper. At the shared .26 the
  /// one tone with nothing to report had the loudest outline of the five.
  static const double neutralBorderScale = 0.6;

  /// The ground, from the tone's container and the surface under it.
  static Color fill({
    required Color container,
    required Color surface,
    bool neutral = false,
  }) => Color.alphaBlend(
    container.withValues(alpha: neutral ? neutralAlpha : toneAlpha),
    surface,
  );

  /// The hairline that closes the shape, from the tone's accent and the [fill]
  /// it encloses — always a step from its own ground, never a line drawn
  /// beside it.
  static Color border({
    required Color accent,
    required Color fill,
    required Brightness brightness,
    bool neutral = false,
  }) => Color.alphaBlend(
    accent.withValues(
      alpha:
          (brightness == Brightness.dark ? borderAlphaDark : borderAlphaLight) *
          (neutral ? neutralBorderScale : 1),
    ),
    fill,
  );
}
