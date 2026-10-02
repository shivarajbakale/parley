// ds-tier: 1 — atom

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_checkbox.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/design_system/_ds_select_style.dart';

/// How the list decides what a query matches.
///
/// The default is a case- and diacritic-insensitive substring match on the
/// option's label. A caller with fuzzy matching, a remote query or a synonym
/// table implements this, and nothing else changes.
abstract class DSSelectSearchDelegate {
  const DSSelectSearchDelegate();

  bool matches(String query, DSSelectOption<Object?> option);

  /// Options fetched for [query] rather than filtered locally. Null means
  /// local filtering.
  Future<List<Widget>>? fetch(String query) => null;
}

/// Case- and diacritic-insensitive substring matching, which is what a caller
/// gets without asking.
class DSSelectSubstringSearch extends DSSelectSearchDelegate {
  const DSSelectSubstringSearch();

  static const _folded = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Lower-cased and stripped of the accents a keyboard is unlikely to type.
  /// Someone searching for "Zurich" should find "Zürich".
  static String fold(String value) {
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      buffer.write(_folded[char] ?? char);
    }
    return buffer.toString();
  }

  @override
  bool matches(String query, DSSelectOption<Object?> option) =>
      fold(option.label).contains(fold(query));
}

/// What the list knows and every row inside it reads.
///
/// This is what replaces the three parallel builder functions: a row no
/// longer has to be *described* to the list in scalars, because the row is a
/// widget and the list tells it only the two things it cannot know — whether
/// it is selected, and what to call when it is picked.
@immutable
class DSSelectListScope extends InheritedWidget {
  const DSSelectListScope({
    super.key,
    required this.selected,
    required this.active,
    required this.multiple,
    required this.atMax,
    required this.style,
    required this.onPick,
    required super.child,
  });

  final Set<Object?> selected;

  /// The row the keyboard is on. Distinct from selection: arrow keys move
  /// this, Return commits it.
  final Object? active;

  final bool multiple;

  /// Whether a multi-select has reached `maxSelection`, in which case the
  /// unselected rows disable rather than silently refusing the tap.
  final bool atMax;

  final DSSelectStyle style;
  final void Function(Object? value) onPick;

  static DSSelectListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSSelectListScope>();

  @override
  bool updateShouldNotify(DSSelectListScope old) =>
      !setEquals(old.selected, selected) ||
      old.active != active ||
      old.multiple != multiple ||
      old.atMax != atMax;
}

/// One row of a select's list.
///
/// A widget, not a record. The three parallel `Function(T)` builders this
/// replaces could describe a label, a glyph and a glyph colour, and nothing
/// else: no avatar, no trailing count, no two-line row, no colour swatch, no
/// disabled option with a reason. Each of those would have been a fourth
/// function, then a fifth.
class DSSelectOption<T> extends StatelessWidget {
  const DSSelectOption({
    super.key,
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.labelSlot,
    this.enabled = true,
    this.disabledReason,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;
  final bool enabled;

  /// Why this option cannot be picked. An option a user cannot pick and
  /// cannot see the reason for is worse than one that is absent.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final scope = DSSelectListScope.maybeOf(context);
    final design = context.design;
    final palette = context.palette;
    final type = Theme.of(context).textTheme;

    // Rendered outside a list — in a story, or in a caller's own surface.
    // The row still draws; it simply has nothing to report to.
    final style = scope?.style ?? DSSelectStyle.resolve(context);
    final selected = scope?.selected.contains(value) ?? false;
    final active = scope?.active == value;
    final multiple = scope?.multiple ?? false;
    final blocked = !enabled || (scope?.atMax ?? false) && !selected;

    final labelColor = blocked
        ? palette.mutedForeground
        : selected
        ? palette.foreground
        : palette.mutedForeground;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        labelSlot ??
            Text(
              label,
              style: type.bodyMedium?.copyWith(
                color: labelColor,
                fontWeight: selected
                    ? context.design.type.titleWeight
                    : context.design.type.bodyWeight,
              ),
            ),
        if (subtitle != null || (blocked && disabledReason != null))
          Text(
            blocked && disabledReason != null ? disabledReason! : subtitle!,
            style: type.bodySmall?.copyWith(color: palette.mutedForeground),
          ),
      ],
    );

    return Semantics(
      // `option` in a single select, a checkbox in a multiple one — the two
      // roles a screen reader distinguishes, and neither of which existed
      // here before.
      inMutuallyExclusiveGroup: !multiple,
      checked: multiple ? selected : null,
      selected: multiple ? null : selected,
      enabled: !blocked,
      button: true,
      label: label,
      child: ExcludeSemantics(
        // A full-bleed row deliberately does not dip, for the reason
        // `DSListTile` documents: a row that shrinks away from its neighbours
        // detaches from the column it belongs to. `enabled: false` switches
        // off the scale and keeps the ring, which the option rows lost when
        // they skipped `DSPressable` to avoid the dip.
        child: DSPressable(
          enabled: false,
          focusShape: const RoundedRectangleBorder(),
          child: DSInkSurface(
            onTap: blocked ? null : () => scope?.onPick(value),
            // The row the keyboard is on is tinted, not outlined: an outline
            // inside a scrolling list reads as a second row boundary.
            tint: active ? palette.secondary : null,
            minTapTarget: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: style.optionHeight!),
              child: Padding(
                padding: style.optionPadding!,
                child: Row(
                  children: [
                    if (multiple) ...[
                      DSCheckbox(
                        value: selected,
                        semanticLabel: label,
                        onChanged: blocked ? null : (_) => scope?.onPick(value),
                      ),
                      SizedBox(width: style.optionGap!),
                    ],
                    if (leading != null) ...[
                      leading!,
                      SizedBox(width: style.optionGap!),
                    ],
                    Expanded(child: body),
                    if (trailing != null) ...[
                      SizedBox(width: style.optionGap!),
                      trailing!,
                    ],
                    if (!multiple && selected)
                      Icon(
                        style.checkIcon,
                        size: design.component.iconSizeInline,
                        color: palette.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A non-selectable group header inside a list.
class DSSelectSection extends StatelessWidget {
  const DSSelectSection({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style =
        DSSelectListScope.maybeOf(context)?.style ??
        DSSelectStyle.resolve(context);
    final design = context.design;

    return Semantics(
      header: true,
      child: Container(
        height: design.space.xxl,
        padding: style.optionPadding!,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          children: [
            Expanded(child: Text(label, style: style.sectionHeaderStyle)),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// A hairline between groups.
// ds-tier: 1 — atom — A hairline between two groups of options. It is a line.
class DSSelectSeparator extends StatelessWidget {
  const DSSelectSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final style =
        DSSelectListScope.maybeOf(context)?.style ??
        DSSelectStyle.resolve(context);
    final design = context.design;
    // The identity decides whether a list is separated by lines or by space,
    // and `DividerPolicy` is where it says so — the same switch `DSListTile`
    // reads. A `showSeparators` flag of this component's own would have been
    // a second answer to a question already answered.
    //
    // Inset to the row's text rather than to its text *plus* its leading
    // slot, which is what `DSListTile` does. A select's leading is optional
    // per row, so indenting past it would step the line in and out down the
    // list; every row here starts its label on the same line.
    final policy = design.component.dividerPolicy;
    if (policy == DividerPolicy.none) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: DSDivider(
        indent: style.optionPadding!.resolve(Directionality.of(context)).left,
        endIndent: style.optionPadding!
            .resolve(Directionality.of(context))
            .right,
        style: DSDividerStyle(color: style.separatorColor),
      ),
    );
  }
}

/// The row a list draws while its options are still arriving.
class DSSelectOptionSkeleton extends StatelessWidget {
  const DSSelectOptionSkeleton({super.key, this.showLeading = false});

  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    final style =
        DSSelectListScope.maybeOf(context)?.style ??
        DSSelectStyle.resolve(context);
    return DSSkeleton(
      child: SizedBox(
        height: style.optionHeight!,
        child: Padding(
          padding: style.optionPadding!,
          child: Row(
            children: [
              if (showLeading) ...[
                SizedBox.square(
                  dimension: context.design.component.iconSizeInline,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle),
                  ),
                ),
                SizedBox(width: style.optionGap!),
              ],
              const Expanded(child: Text('An option')),
            ],
          ),
        ),
      ),
    );
  }
}
