import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/screens/design_system/catalog/catalog.dart';
import 'package:parley_android/theme/app_theme.dart';

/// Every control in the kit says what it is.
///
/// A tappable node with no accessible name is not a small omission. VoiceOver
/// reads it as "button" and stops; TalkBack offers "double-tap to activate"
/// and never says what would be activated. The user is told something is
/// there and not what it does, which is worse than the control being absent —
/// absent, they would look elsewhere.
///
/// The corpus is the gallery catalog rather than a hand-written list, because
/// the catalog is already gated to hold exactly the components the kit ships
/// (`test/screens/design_system_gallery_test.dart`). A component added without
/// stories fails there; a component added with stories and no labels fails
/// here. Neither can be satisfied by remembering to update a list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The name a screen reader would announce for [node].
  ///
  /// Both `label` and `tooltip` count, and this is not a technicality:
  /// `IconButton(tooltip: …)` puts its text in `SemanticsData.tooltip` and
  /// leaves `label` empty, so a rule reading only `label` reports the kit's
  /// *deliberately* labelled dismiss buttons as silent. Anything merged
  /// underneath counts too — a button whose child is a `Text` is named by
  /// that text, which is how most of the kit is already named.
  String nameOf(SemanticsNode node) {
    final data = node.getSemanticsData();
    // A slider's `value` counts, and only a slider's. Material's `RangeSlider`
    // assembles its two thumb nodes itself and exposes no label hook for
    // either — only the value formatter, which it calls for both — so
    // `DSRangeSlider` puts the thumb's name at the front of its value and a
    // screen reader announces "Minimum price, £20". Reading only `label` here
    // would report a control that names itself correctly as silent.
    final slider = data.flagsCollection.isSlider ? data.value : '';
    final buffer = StringBuffer('${data.label} ${data.tooltip} $slider');
    node.visitChildren((child) {
      buffer.write(' ${nameOf(child)}');
      return true;
    });
    return buffer.toString().trim();
  }

  /// A node the user can act on. `tap` covers buttons, rows and switches;
  /// `increase`/`decrease` cover the slider and the stepper, which are
  /// operated without a tap and are just as anonymous without a name.
  bool isControl(SemanticsData data) =>
      data.hasAction(SemanticsAction.tap) ||
      data.hasAction(SemanticsAction.increase) ||
      data.hasAction(SemanticsAction.decrease);

  /// A node that presents itself as a control: it says "button", or it carries
  /// a state a user is expected to change.
  bool looksLikeAControl(SemanticsData data) {
    final flags = data.flagsCollection;
    // A control the user is told is unavailable owes no action.
    if (flags.isEnabled == Tristate.isFalse) return false;
    return flags.isButton ||
        flags.isToggled != Tristate.none ||
        flags.isChecked != CheckedState.none;
  }

  List<String> silentControlsIn(WidgetTester tester) {
    final silent = <String>[];
    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      // A node under a merging ancestor is not sent to the platform on its own
      // — it has already been folded into the node above it, which is the one
      // the screen reader stops at. Counting it would fail a control that is
      // named correctly: `Slider` and `Switch` both publish an inner node that
      // carries the actions and none of the words, and it is invisible to
      // VoiceOver precisely because the wrapper merges.
      if (!node.isMergedIntoParent && isControl(data) && nameOf(node).isEmpty) {
        silent.add(
          'a ${node.rect.width.toStringAsFixed(0)}×'
          '${node.rect.height.toStringAsFixed(0)} control',
        );
      }
      // A node that says "button" and publishes no action is announced and
      // cannot be operated: VoiceOver's double-tap and TalkBack's click both
      // arrive as `SemanticsAction.tap`, and there is nothing there to take
      // them.
      if (!node.isMergedIntoParent &&
          looksLikeAControl(data) &&
          !isControl(data)) {
        silent.add(
          'an inert ${node.rect.width.toStringAsFixed(0)}×'
          '${node.rect.height.toStringAsFixed(0)} control named '
          '"${data.label}"',
        );
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    // Reached through the render tree's own pipeline owners rather than
    // through `binding.pipelineOwner`, which is deprecated, and rather than
    // through `getSemantics`, which answers with the node a *widget*
    // contributes to and gives back a leaf when asked about the root.
    tester.binding.rootPipelineOwner.visitChildren((owner) {
      final root = owner.semanticsOwner?.rootSemanticsNode;
      if (root != null) walk(root);
    });
    return silent;
  }

  for (final component in catalogComponents) {
    testWidgets('${component.name} names every control it renders', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // Tall enough that every story is laid out rather than lazily skipped:
      // a control that is never built is a control this test cannot see.
      tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              children: [
                for (final story in component.stories)
                  Builder(builder: story.builder),
              ],
            ),
          ),
        ),
      );
      // Long frames rather than `pumpAndSettle`: several stories carry a
      // shimmer or a repeating entrance, and settling is not guaranteed to
      // terminate on an animation that repeats.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final silent = silentControlsIn(tester);
      handle.dispose();

      expect(
        silent,
        isEmpty,
        reason:
            '${component.name} renders ${silent.length} control(s) a screen '
            'reader cannot name: ${silent.join(", ")}. Give the control a '
            '`semanticLabel`, or wrap the label and the control in a '
            '`MergeSemantics` so the two are announced as one thing.',
      );
    });
  }
}
