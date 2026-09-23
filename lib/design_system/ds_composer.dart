// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_icon_button.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How the composer looks, at every layer of the resolution chain.
@immutable
class DSComposerStyle extends DSComponentStyle<DSComposerStyle> {
  const DSComposerStyle({
    this.padding,
    this.gap,
    this.showHairline,
    this.hairlineColor,
    this.maxLines,
  }) : assert(
         maxLines == null || maxLines >= 1,
         'maxLines is the ceiling the field grows to before it scrolls '
         'itself. Below one there is nowhere to type',
       );

  final EdgeInsetsGeometry? padding;

  /// Between the field and whatever flanks it.
  final double? gap;

  /// The line that separates the bar from the transcript scrolling under it.
  final bool? showHairline;
  final Color? hairlineColor;

  /// How many lines the field grows to before it scrolls inside itself. The
  /// bar keeps its bottom edge; it is the top that moves.
  final int? maxLines;

  @override
  DSComposerStyle merge(DSComposerStyle? other) {
    if (other == null) return this;
    return DSComposerStyle(
      padding: other.padding ?? padding,
      gap: other.gap ?? gap,
      showHairline: other.showHairline ?? showHairline,
      hairlineColor: other.hairlineColor ?? hairlineColor,
      maxLines: other.maxLines ?? maxLines,
    );
  }

  @override
  DSComposerStyle copyWith({
    EdgeInsetsGeometry? padding,
    double? gap,
    bool? showHairline,
    Color? hairlineColor,
    int? maxLines,
  }) => DSComposerStyle(
    padding: padding ?? this.padding,
    gap: gap ?? this.gap,
    showHairline: showHairline ?? this.showHairline,
    hairlineColor: hairlineColor ?? this.hairlineColor,
    maxLines: maxLines ?? this.maxLines,
  );

  @override
  DSComposerStyle lerp(DSComposerStyle? other, double t) {
    if (other == null) return this;
    return DSComposerStyle(
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      gap: lerpDouble(gap, other.gap, t),
      showHairline: t < 0.5 ? showHairline : other.showHairline,
      hairlineColor: Color.lerp(hairlineColor, other.hairlineColor, t),
      maxLines: t < 0.5 ? maxLines : other.maxLines,
    );
  }

  static DSComposerStyle resolve(BuildContext context, [DSComposerStyle? own]) {
    final space = context.design.space;
    return resolveStyle(
      context: context,
      specDefaults: DSComposerStyle(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: space.pageGutter,
          vertical: space.sm,
        ),
        gap: space.sm,
        showHairline: true,
        hairlineColor: context.palette.borderSoft,
        maxLines: _defaultMaxLines,
      ),
      own: own,
    );
  }

  /// Five lines is about a third of a phone screen. Past that the transcript
  /// the user is replying to is gone, which is the thing they are looking at
  /// while they type.
  static const int _defaultMaxLines = 5;
}

/// The bar a conversation is written in.
///
/// **Use when** the screen is a thread and the user's turn is composed in
/// place: chat, an assistant, a comment stream, a support ticket.
/// **Instead:** `DSPinnedActionBar` when the pinned control is a decision
/// rather than an input — Buy, Save, Continue — and `DSTextField` on its own
/// inside a `DSPage` when the writing is a field in a form that gets
/// submitted and left.
///
/// It exists because three things have to agree and each is easy to get
/// singly wrong: the field grows with the text but the bar keeps its bottom
/// edge; the send affordance is dead until there is something to send, so the
/// user is never asked to discover that by tapping; and the whole bar clears
/// the keyboard, the home indicator and any navigation bar under it.
///
/// The controller is optional. Passed one, the composer never clears it — the
/// caller owns the text, and an assistant that fails to send should not have
/// swallowed what the user typed. Owning its own, it clears on send, which is
/// what a chat does.
class DSComposer extends StatefulWidget {
  const DSComposer({
    super.key,
    this.controller,
    this.focusNode,
    required this.onSend,
    this.hintText = 'Message',
    this.enabled = true,
    this.sending = false,
    this.leading,
    this.sendSemanticLabel = 'Send',
    this.style,
  });

  /// The text. Optional: without one the composer owns a controller and
  /// clears it on send.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Given the trimmed text. Never called with an empty string — the send
  /// affordance is disabled until there is something to give it.
  final ValueChanged<String> onSend;

  final String hintText;

  /// The whole bar, field included. A conversation that has ended — archived,
  /// read-only, over — disables the composer rather than removing it, so the
  /// transcript keeps its shape.
  final bool enabled;

  /// A send is in flight. The field stays live so the user can keep typing;
  /// only the send affordance waits.
  final bool sending;

  /// An attach button, a model picker, whatever the app puts before the
  /// field. Sized by the caller.
  final Widget? leading;

  final String sendSemanticLabel;

  final DSComposerStyle? style;

  @override
  State<DSComposer> createState() => _DSComposerState();
}

class _DSComposerState extends State<DSComposer> {
  TextEditingController? _owned;
  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(DSComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    // Only what this state made. Disposing the caller's controller is how a
    // parent that rebuilds gets a use-after-dispose on the next keystroke.
    _owned?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    AppHaptics.light();
    widget.onSend(text);
    if (widget.controller == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSComposerStyle.resolve(context, widget.style);
    final component = context.design.component;
    final canSend = widget.enabled && !widget.sending && _hasText;

    final field = DSTextField(
      controller: _controller,
      focusNode: widget.focusNode,
      hintText: widget.hintText,
      enabled: widget.enabled,
      onSubmitted: canSend ? (_) => _send() : null,
      // A composer says nothing under its field — no helper, no validation,
      // no counter — so it has nothing to reserve the slot *for*. Reserved,
      // it was 22 points of invisible box under the border: the bar stood a
      // third taller than the thing in it, and the send button, aligned to
      // the field's box rather than to what the field draws, sat that far
      // below the border it belongs to.
      reserveHelper: false,
      // `minLines: 1` is load-bearing. A `TextField` given `maxLines: 5` and
      // no `minLines` is five lines tall from the first frame, empty — the
      // composer would open holding a third of the screen and never move.
      // With both, it opens at one line and grows to five.
      input: DSFieldInput(
        minLines: 1,
        maxLines: resolved.maxLines,
        textInputAction: TextInputAction.newline,
      ),
    );

    final bar = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          SizedBox(width: resolved.gap),
        ],
        Expanded(child: field),
        SizedBox(width: resolved.gap),
        DSIconButton(
          icon: Icons.arrow_upward,
          semanticLabel: widget.sendSemanticLabel,
          onPressed: canSend ? _send : null,
          variant: DSIconButtonVariant.filled,
          loading: widget.sending,
        ),
      ],
    );

    return DSBottomSlotReporter(
      slot: DSBottomSlot.actionBar,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.card,
          border: resolved.showHairline!
              ? Border(
                  top: BorderSide(
                    color: resolved.hairlineColor!,
                    width: component.hairlineWidth,
                  ),
                )
              : null,
        ),
        child: SafeArea(
          top: false,
          // Above the keyboard the home indicator is not on the screen — the
          // keyboard is covering it — and a composer spends most of its life
          // exactly there. A fixed inset is 34 points of empty bar under the
          // field.
          bottom: MediaQuery.viewInsetsOf(context).bottom <= 0,
          child: Padding(padding: resolved.padding!, child: bar),
        ),
      ),
    );
  }
}
