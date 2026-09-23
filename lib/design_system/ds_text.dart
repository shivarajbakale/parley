// ds-tier: 1 — atom

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

// The style chain lives one tier down, where a tier-0 style class can reach
// it. Re-exported so that importing the widget still brings the roles with it.
export 'package:parley_android/design_system/ds_text_style.dart';

/// One run inside a [DSText.rich], with its own emphasis or tone.
///
/// The span form exists because without it every mixed-emphasis line — "Signed
/// in as **ada@example.com**", "3 of **12** done" — falls back to a raw
/// `Text.rich` and leaves the system for good. It is a value, not a widget:
/// [DSText] resolves the role once and the spans only say how they differ from
/// it.
@immutable
class DSTextSpan {
  const DSTextSpan(this.text, {this.emphasis = false, this.tone});

  final String text;

  /// One weight step up, from [TypeSpec.emphasisWeight] — the word in the line
  /// that carries the meaning.
  final bool emphasis;

  /// A different meaning for this run alone: the overdue date in a sentence
  /// that is otherwise ordinary.
  final DSTone? tone;
}

/// Every piece of text the app draws, named by what it is.
///
/// **Use when** you are about to write a `Text` — which is always, unless you
/// are inside `ds_text.dart` itself. Pass the [DSTextRole] that says what the
/// string is doing, and the step, the grey, the weight, the tracking, the
/// casing, the truncation, the text-scale ceiling and the screen-reader
/// announcement all come with it. **Instead:** a raw `Text` with a
/// `Theme.of(context).textTheme.x.copyWith(...)` — that is the same decision
/// re-made at every call site, and it is how the kit ended up with twenty-one
/// places that clip without an ellipsis and three `semanticsLabel`s in two
/// hundred and thirty-seven strings.
///
/// The role is required and there is no default. A default role would be
/// `body`, and `body` is the one role a wrong guess is invisible in: it is
/// what an unstyled `Text` already renders as, so the mistake would look
/// correct until the scale moved.
///
/// This is the file that owns Flutter's `Text` the way `ds_list_tile.dart`
/// owns `ListTile`. Everything above the atom tier composes this.
class DSText extends StatelessWidget {
  const DSText(
    this.data, {
    super.key,
    required this.role,
    this.tone,
    this.emphasis = false,
    this.numeric = false,
    this.maxLines,
    this.align,
    this.semanticsLabel,
    this.style,
  }) : spans = null;

  /// A line with runs that differ from each other — an emphasised name inside
  /// a sentence, a toned word inside a neutral one.
  const DSText.rich(
    this.spans, {
    super.key,
    required this.role,
    this.tone,
    this.emphasis = false,
    this.numeric = false,
    this.maxLines,
    this.align,
    this.semanticsLabel,
    this.style,
  }) : data = null;

  final String? data;
  final List<DSTextSpan>? spans;

  final DSTextRole role;

  /// Meaning, not colour. Defaults to the role's own grey, and to the tone the
  /// enclosing [DSScope] lends when there is one.
  final DSTone? tone;

  /// One weight step up. For the whole string; a single word inside it is a
  /// [DSTextSpan].
  final bool emphasis;

  /// Tabular figures, for digits that have to line up in a column the role
  /// does not already know about.
  final bool numeric;

  /// Overrides the role's line limit. Passing a limit to a role that wraps
  /// also brings the ellipsis with it — the two are never set apart.
  final int? maxLines;

  final TextAlign? align;

  /// What a screen reader says instead of [data] — an expansion of an
  /// abbreviation, the full date behind "2d".
  final String? semanticsLabel;

  final DSTextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = DSTextStyle.resolve(
      context,
      role: role,
      tone: tone,
      emphasis: emphasis,
      numeric: numeric,
      own: style,
    );

    final base = (resolved.textStyle ?? const TextStyle()).copyWith(
      // Null is the `control`/`count` case: the colour comes from whatever
      // surface encloses the label, which is the only way a filled button and
      // an outlined one can share a role.
      color: resolved.color,
    );

    final lines = maxLines ?? resolved.maxLines;
    final overflow = lines == null ? resolved.overflow : TextOverflow.ellipsis;

    Widget text;
    if (spans != null) {
      text = Text.rich(
        TextSpan(children: [for (final s in spans!) _span(context, s, base)]),
        style: base,
        maxLines: lines,
        overflow: overflow,
        softWrap: resolved.softWrap,
        textAlign: align,
        semanticsLabel: semanticsLabel,
      );
    } else {
      text = Text(
        role.uppercases ? AppTypography.eyebrowCase(context, data!) : data!,
        style: base,
        maxLines: lines,
        overflow: overflow,
        softWrap: resolved.softWrap,
        textAlign: align,
        semanticsLabel: semanticsLabel,
      );
    }

    // A role that truncates does not grow without limit. Applied here rather
    // than inside the style so the clamp covers the span form too.
    final ceiling = resolved.maxScale;
    if (ceiling != null) {
      text = MediaQuery.withClampedTextScaling(
        maxScaleFactor: ceiling,
        child: text,
      );
    }

    if (role.heading || role.live) {
      text = Semantics(
        header: role.heading,
        liveRegion: role.live,
        child: text,
      );
    }
    return text;
  }

  /// One run's departure from the line it sits in.
  InlineSpan _span(BuildContext context, DSTextSpan span, TextStyle base) {
    if (!span.emphasis && span.tone == null) return TextSpan(text: span.text);
    final palette = context.palette;
    return TextSpan(
      text: span.text,
      style: base.copyWith(
        fontWeight: span.emphasis ? context.design.type.emphasisWeight : null,
        color: switch (span.tone) {
          null || DSTone.neutral => null,
          DSTone.info => palette.primary,
          DSTone.success => palette.success,
          DSTone.warning => palette.warning,
          DSTone.error => palette.destructive,
        },
      ),
    );
  }
}
