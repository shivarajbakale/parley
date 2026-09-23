import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks a subtree as the label of one choice in a mutually exclusive set — a
/// tab, a segment of a segmented control.
///
/// A rendering no-op, and a sibling of `AppChromeOcclusion`: both are the kit
/// stating a fact about itself that a gate would otherwise have to infer.
///
/// This one is the distinction the probe's `clipped-text` rule already draws
/// in its own message — *"a label may be truncated; the words the reader came
/// for may not"* — and could not act on, because it decides by font size and
/// this kit sets a tab's label at the same 16 points as body copy. A segmented
/// control cannot grow to fit its longest label without ceasing to be a
/// segmented control: its whole shape is "these are the choices, side by
/// side", the truncation is the design, and the full word is one tap or one
/// screen-reader announcement away.
///
/// A list row's title is not this. That is the reader's own content in the
/// reader's own words, and it wraps — see `DSListTile.wrap`.
///
/// It lives in `lib/theme/` rather than in `lib/design_system/` because it is
/// not a component: it has no stories, no selection guidance and nothing to
/// draw, and the gallery gate is right to require all three of anything that
/// ships from there.
class AppChoiceLabel extends SingleChildRenderObjectWidget {
  const AppChoiceLabel({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAppChoiceLabel();
}

/// The render object [AppChoiceLabel] installs. Proxies everything.
class RenderAppChoiceLabel extends RenderProxyBox {}
