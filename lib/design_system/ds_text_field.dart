// ds-tier: 1 — atom

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The paired scale. There are no variants — see [DSTextField].
enum DSTextFieldSize { sm, md, lg }

/// When a field's contents are checked, and by what.
///
/// The field owns no validation rules of its own: it holds the [validator] a
/// caller supplies, runs it through a `FormField` so `Form.validate()` still
/// works, and renders whatever string comes back in the reserved helper slot.
@immutable
class DSFieldValidation {
  const DSFieldValidation({
    this.validator,
    this.autovalidateMode,
    this.required = false,
  });

  final FormFieldValidator<String>? validator;

  /// Null means [AutovalidateMode.disabled] — a field that turns red while
  /// the user is still typing the first half of their email is a field that
  /// has decided they are wrong before they have finished.
  final AutovalidateMode? autovalidateMode;

  /// Draws the required mark beside the label and announces it. It does not
  /// add a rule: a required field with no [validator] is a caller's decision,
  /// and silently inventing an emptiness check would give the form two
  /// sources of truth.
  final bool required;
}

/// What kind of text this is — the keyboard, the autofill hint, the
/// capitalisation and the obscuring, as one coherent group.
///
/// The named constructors exist so an incoherent combination cannot be
/// expressed. The surface this replaces carried both `isPassword` and
/// `obscureText` with no assertion between them; [DSFieldInput.password] sets
/// the four things that must agree, once.
@immutable
class DSFieldInput {
  const DSFieldInput({
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.autofillHints,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.obscure = false,
  });

  /// Obscured, one line, no capitalisation, and the autofill hint a password
  /// manager looks for.
  const DSFieldInput.password({this.textInputAction})
    : keyboardType = TextInputType.visiblePassword,
      textCapitalization = TextCapitalization.none,
      inputFormatters = null,
      autofillHints = const [AutofillHints.password],
      maxLength = null,
      maxLines = 1,
      minLines = null,
      expands = false,
      obscure = true;

  /// An address, which is never capitalised and never more than one line.
  const DSFieldInput.email({this.textInputAction})
    : keyboardType = TextInputType.emailAddress,
      textCapitalization = TextCapitalization.none,
      inputFormatters = null,
      autofillHints = const [AutofillHints.email],
      maxLength = null,
      maxLines = 1,
      minLines = null,
      expands = false,
      obscure = false;

  const DSFieldInput.multiline({
    this.maxLines = 5,
    this.minLines = 3,
    this.maxLength,
    this.textInputAction,
  }) : keyboardType = TextInputType.multiline,
       textCapitalization = TextCapitalization.sentences,
       inputFormatters = null,
       autofillHints = null,
       expands = false,
       obscure = false;

  /// The numeric keyboard and nothing else. Digit filtering stays with the
  /// caller: `FilteringTextInputFormatter.digitsOnly` is not a constant, and a
  /// field that silently drops the decimal point of a price is worse than one
  /// that asks the caller to say what a number means here.
  const DSFieldInput.number({this.maxLength, this.textInputAction})
    : keyboardType = TextInputType.number,
      textCapitalization = TextCapitalization.none,
      inputFormatters = null,
      autofillHints = null,
      maxLines = 1,
      minLines = null,
      expands = false,
      obscure = false;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// WCAG 2.2 SC 1.3.5: the purpose of an input must be programmatically
  /// determinable. First class here rather than something a caller reaches
  /// for through a raw `TextField`.
  final Iterable<String>? autofillHints;

  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool obscure;
}

/// The conveniences a field can draw for itself.
///
/// Off by default, all of them: a caller writing a name field should carry
/// none of this, which is the interface-segregation fix the forty-field
/// constructor could not express.
@immutable
class DSFieldAffordances {
  const DSFieldAffordances({
    this.showClearButton = false,
    this.showPasswordToggle = true,
    this.showCharCount = false,
    this.autofocus = false,
    this.readOnly = false,
  });

  final bool showClearButton;

  /// Only ever drawn when [DSFieldInput.obscure] is set, so leaving it on
  /// costs a plain field nothing.
  final bool showPasswordToggle;

  final bool showCharCount;
  final bool autofocus;

  /// Read-only is not disabled: the text stays at full contrast and stays
  /// selectable and copyable. Only the caret goes.
  final bool readOnly;
}

/// [DSTextField]'s appearance, as data — and where the three deleted skins
/// now live.
///
/// `filled` was `fillColor: palette.muted, outlineColor: transparent`;
/// `underlined` was a zero radius and a bottom-only border. What is removed is
/// the *default* offer of three, not the ability to build one.
@immutable
class DSTextFieldStyle extends DSComponentStyle<DSTextFieldStyle> {
  const DSTextFieldStyle({
    this.height,
    this.contentPadding,
    this.radius,
    this.fillColor,
    this.disabledFill,
    this.outlineColor,
    this.focusedOutline,
    this.errorOutline,
    this.disabledOutline,
    this.outlineWidth,
    this.focusedWidth,
    this.labelStyle,
    this.textStyle,
    this.disabledTextColor,
    this.hintStyle,
    this.helperStyle,
    this.helperSlotHeight,
    this.iconSize,
    this.iconColor,
    this.labelGap,
    this.helperGap,
  }) : assert(
         helperSlotHeight == null || helperSlotHeight >= 16,
         'helperSlotHeight is the reserved space that stops a form moving '
         'under the user when a validator fails. Setting it to zero — or '
         'below one line of helper text — reintroduces the jump one call '
         'site at a time, which is the defect the slot exists to fix',
       );

  /// A floor rather than a fixed size: at a large text scale the field grows
  /// with its content, and icons stay where they are.
  final double? height;

  final EdgeInsetsGeometry? contentPadding;
  final BorderRadius? radius;
  final Color? fillColor;
  final Color? disabledFill;
  final Color? outlineColor;
  final Color? focusedOutline;
  final Color? errorOutline;

  /// Disabled and read-only share it. Both are "you cannot type here"; only
  /// one of them also means "and you should not read this".
  final Color? disabledOutline;

  final double? outlineWidth;
  final double? focusedWidth;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final Color? disabledTextColor;
  final TextStyle? hintStyle;
  final TextStyle? helperStyle;

  /// Reserved whether or not there is helper text. Twenty device-independent
  /// pixels of nothing is the price of a form that does not move under the
  /// user, and it is cheaper than every alternative.
  final double? helperSlotHeight;

  final double? iconSize;
  final Color? iconColor;
  final double? labelGap;
  final double? helperGap;

  @override
  DSTextFieldStyle merge(DSTextFieldStyle? other) {
    if (other == null) return this;
    return DSTextFieldStyle(
      height: other.height ?? height,
      contentPadding: other.contentPadding ?? contentPadding,
      radius: other.radius ?? radius,
      fillColor: other.fillColor ?? fillColor,
      disabledFill: other.disabledFill ?? disabledFill,
      outlineColor: other.outlineColor ?? outlineColor,
      focusedOutline: other.focusedOutline ?? focusedOutline,
      errorOutline: other.errorOutline ?? errorOutline,
      disabledOutline: other.disabledOutline ?? disabledOutline,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      focusedWidth: other.focusedWidth ?? focusedWidth,
      labelStyle: other.labelStyle ?? labelStyle,
      textStyle: other.textStyle ?? textStyle,
      disabledTextColor: other.disabledTextColor ?? disabledTextColor,
      hintStyle: other.hintStyle ?? hintStyle,
      helperStyle: other.helperStyle ?? helperStyle,
      helperSlotHeight: other.helperSlotHeight ?? helperSlotHeight,
      iconSize: other.iconSize ?? iconSize,
      iconColor: other.iconColor ?? iconColor,
      labelGap: other.labelGap ?? labelGap,
      helperGap: other.helperGap ?? helperGap,
    );
  }

  @override
  DSTextFieldStyle copyWith({
    double? height,
    EdgeInsetsGeometry? contentPadding,
    BorderRadius? radius,
    Color? fillColor,
    Color? disabledFill,
    Color? outlineColor,
    Color? focusedOutline,
    Color? errorOutline,
    Color? disabledOutline,
    double? outlineWidth,
    double? focusedWidth,
    TextStyle? labelStyle,
    TextStyle? textStyle,
    Color? disabledTextColor,
    TextStyle? hintStyle,
    TextStyle? helperStyle,
    double? helperSlotHeight,
    double? iconSize,
    Color? iconColor,
    double? labelGap,
    double? helperGap,
  }) => DSTextFieldStyle(
    height: height ?? this.height,
    contentPadding: contentPadding ?? this.contentPadding,
    radius: radius ?? this.radius,
    fillColor: fillColor ?? this.fillColor,
    disabledFill: disabledFill ?? this.disabledFill,
    outlineColor: outlineColor ?? this.outlineColor,
    focusedOutline: focusedOutline ?? this.focusedOutline,
    errorOutline: errorOutline ?? this.errorOutline,
    disabledOutline: disabledOutline ?? this.disabledOutline,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    focusedWidth: focusedWidth ?? this.focusedWidth,
    labelStyle: labelStyle ?? this.labelStyle,
    textStyle: textStyle ?? this.textStyle,
    disabledTextColor: disabledTextColor ?? this.disabledTextColor,
    hintStyle: hintStyle ?? this.hintStyle,
    helperStyle: helperStyle ?? this.helperStyle,
    helperSlotHeight: helperSlotHeight ?? this.helperSlotHeight,
    iconSize: iconSize ?? this.iconSize,
    iconColor: iconColor ?? this.iconColor,
    labelGap: labelGap ?? this.labelGap,
    helperGap: helperGap ?? this.helperGap,
  );

  @override
  DSTextFieldStyle lerp(DSTextFieldStyle? other, double t) {
    if (other == null) return this;
    return DSTextFieldStyle(
      height: lerpDouble(height, other.height, t),
      contentPadding: EdgeInsetsGeometry.lerp(
        contentPadding,
        other.contentPadding,
        t,
      ),
      radius: BorderRadius.lerp(radius, other.radius, t),
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t),
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t),
      focusedOutline: Color.lerp(focusedOutline, other.focusedOutline, t),
      errorOutline: Color.lerp(errorOutline, other.errorOutline, t),
      disabledOutline: Color.lerp(disabledOutline, other.disabledOutline, t),
      outlineWidth: lerpDouble(outlineWidth, other.outlineWidth, t),
      focusedWidth: lerpDouble(focusedWidth, other.focusedWidth, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      disabledTextColor: Color.lerp(
        disabledTextColor,
        other.disabledTextColor,
        t,
      ),
      hintStyle: TextStyle.lerp(hintStyle, other.hintStyle, t),
      helperStyle: TextStyle.lerp(helperStyle, other.helperStyle, t),
      helperSlotHeight: lerpDouble(helperSlotHeight, other.helperSlotHeight, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      labelGap: lerpDouble(labelGap, other.labelGap, t),
      helperGap: lerpDouble(helperGap, other.helperGap, t),
    );
  }

  /// Which scale applies. An explicit size wins; a null one takes the ambient
  /// [DSScope.size].
  static DSTextFieldSize sizeOf(BuildContext context, DSTextFieldSize? size) {
    if (size != null) return size;
    return switch (DSScope.sizeOf(context)) {
      DSSize.sm => DSTextFieldSize.sm,
      DSSize.lg => DSTextFieldSize.lg,
      DSSize.md || null => DSTextFieldSize.md,
    };
  }

  static DSTextFieldStyle resolve(
    BuildContext context,
    DSTextFieldSize? size, [
    DSTextFieldStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;
    final scale = sizeOf(context, size);

    final (height, padding, body, icon) = switch (scale) {
      DSTextFieldSize.sm => (
        design.component.fieldHeight - space.sm,
        space.md,
        text.bodyMedium,
        design.component.iconSizeSmall,
      ),
      DSTextFieldSize.md => (
        design.component.fieldHeight,
        space.lg - space.hairline,
        text.bodyLarge?.copyWith(fontSize: text.titleMedium?.fontSize),
        design.component.iconSize - space.xs,
      ),
      DSTextFieldSize.lg => (
        design.component.fieldHeight + space.sm,
        space.lg,
        // Each size reads bigger, not just padded: the typed text climbs
        // bodyMedium -> titleMedium -> titleLarge in size, at body weight.
        text.bodyLarge?.copyWith(fontSize: text.titleLarge?.fontSize),
        design.component.iconSize,
      ),
    };

    return resolveStyle(
      context: context,
      specDefaults: DSTextFieldStyle(
        height: height,
        // Vertical padding is what the field grows by at a large text scale;
        // at the default scale [height] is the larger of the two and this is
        // never reached.
        contentPadding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: space.sm,
        ),
        radius: BorderRadius.all(
          Radius.circular(context.radiusOf(AppShape.control)),
        ),
        fillColor: palette.fieldFill,
        disabledFill: palette.muted,
        // Gate K3 holds this at 3:1 against every rung of the ladder, which
        // is what makes the control's boundary visible under WCAG SC 1.4.11 —
        // and is what a field on `fieldFill` leans on entirely when that rung
        // and the page coincide. The `filled` skin this replaces measured
        // 1.09:1 and effectively had none.
        outlineColor: palette.border,
        focusedOutline: palette.primary,
        errorOutline: palette.destructive,
        disabledOutline: palette.borderSoft,
        outlineWidth: design.component.fieldOutlineWidth,
        focusedWidth: 2,
        labelStyle: DSTextRole.fieldLabel.styleOf(context),
        textStyle: body?.copyWith(color: palette.foreground),
        // `textSecondary` rather than `textTertiary`, which measured 2.59:1
        // on `well` in light. Gate K2 holds this one at 4.5:1 on all three
        // surface roles, and a disabled value a reader cannot make out is a
        // defect rather than an affordance — the same house rule as plan 08.
        disabledTextColor: palette.mutedForeground,
        // Secondary, not tertiary: placeholder text is text, and at tertiary
        // it renders 3.16:1 on the field's own fill — under the 4.5:1 body
        // floor, which `ui-probe`'s contrast rule reports as a defect.
        hintStyle: body?.copyWith(color: palette.mutedForeground),
        helperStyle: text.labelSmall?.copyWith(color: palette.mutedForeground),
        helperSlotHeight: space.lg + space.xs,
        iconSize: icon,
        iconColor: palette.mutedForeground,
        labelGap: space.xs + space.hairline,
        helperGap: space.xs + space.hairline,
      ),
      own: own,
    );
  }
}

/// The text input. One skin, one geometry.
///
/// See `docs/plans/10-ds-text-field.plan.md`. `DSTextFieldVariant` is gone:
/// `outlined`, `filled` and `underlined` were the same control painted three
/// ways, a form holding two of them looked broken, and `filled` had no visible
/// boundary at all. All three are still reachable through [DSTextFieldStyle].
///
/// The forty flat fields are now a core plus three config objects — a caller
/// writing a name field passes the core and nothing else.
///
/// Two things are structural rather than cosmetic:
///
///   * the helper slot is **reserved by default**, so an error appearing does
///     not move the button out from under the user's thumb mid-tap. A field
///     that can produce no message at all — no helper, no validation, no
///     error, no counter — has nothing to reserve *for*, and says so with
///     [reserveHelper]`: false`;
///   * the label is always rendered and is never replaced by [hintText], which
///     is an *example* (WCAG SC 3.3.2).
///
/// **Instead:** a choice from a known set is `DSSelect` or
/// `DSSegmentedButton`; a bounded number is `DSStepper`; a date is
/// `DSDateStrip` or `showDatePicker`; a search that filters as you type is
/// `DSSearchBar`, which owns its own debounce and clear.
class DSTextField extends StatefulWidget {
  const DSTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.loading = false,
    this.size,
    this.validation,
    this.input = const DSFieldInput(),
    this.affordances = const DSFieldAffordances(),
    this.style,
    this.focusNode,
    this.leadingIcon,
    this.trailingIcon,
    this.labelSlot,
    this.leading,
    this.trailing,
    this.prefix,
    this.suffix,
    this.helperSlot,
    this.reserveHelper = true,
  }) : assert(
         reserveHelper ||
             (helperText == null &&
                 errorText == null &&
                 helperSlot == null &&
                 validation == null),
         'reserveHelper: false is for a field that can say nothing under '
         'itself. This one can: it carries a helper, an error, a helper slot '
         'or a validation, and collapsing the line means '
         'the message shoves the rest of the form down the moment it arrives '
         '— which is the jump the reserved slot exists to stop. Drop the '
         'flag, or drop the message.',
       );

  final TextEditingController? controller;
  final String? label;

  /// An example of what to type. Never the label.
  final String? hintText;

  final String? helperText;

  /// The caller's own error, which wins over any [DSFieldValidation] result.
  /// There is exactly one error string on this widget: a second one on the
  /// validation object would be the `obscureText`/`isPassword` defect again,
  /// in a different place.
  final String? errorText;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// A spinner in the trailing slot. The field stays editable — a field that
  /// locks while something checks it loses whatever the user typed next.
  final bool loading;

  /// Null takes the ambient [DSScope.size].
  final DSTextFieldSize? size;

  final DSFieldValidation? validation;
  final DSFieldInput input;
  final DSFieldAffordances affordances;

  final DSTextFieldStyle? style;
  final FocusNode? focusNode;

  /// Stays `IconData` in the convenience: the field tints and sizes it, and a
  /// `Widget` here would lose both silently. [leading] is the hatch.
  final IconData? leadingIcon;

  /// Decorative — a validation tick, a lock. An icon that *does* something is
  /// a button, and goes in [trailing] with its own label and target.
  final IconData? trailingIcon;

  final Widget? labelSlot;
  final Widget? leading;
  final Widget? trailing;

  /// Inside the field, before the text — "$", "+44".
  final Widget? prefix;

  /// Inside the field, after the text — "kg", ".com".
  final Widget? suffix;

  /// The reserved slot's contents, for a helper with a link or a strength
  /// meter. The slot's height is still owned by the field.
  final Widget? helperSlot;

  /// Whether the helper line keeps its space when there is nothing in it.
  ///
  /// True is the structural default and the reason [DSFieldHelper] has a
  /// fixed height: a message that arrives under a field must not move the
  /// button out from under a thumb already travelling towards it.
  ///
  /// False is for the field that cannot produce a message — a `DSSelect` over
  /// a fixed list, a room name nothing validates. There is nothing to reserve
  /// for, and reserving anyway costs the slot's height plus its gap on every
  /// such field: on a five-field form that is a hundred points of white, and
  /// at a doubled text scale it is two hundred. The constructor asserts the
  /// field really is silent rather than trusting the caller.
  final bool reserveHelper;

  @override
  State<DSTextField> createState() => _DSTextFieldState();
}

class _DSTextFieldState extends State<DSTextField> {
  TextEditingController? _local;
  FocusNode? _localFocus;
  late bool _obscured = widget.input.obscure;

  TextEditingController get _controller =>
      widget.controller ?? (_local ??= TextEditingController());

  FocusNode get _focusNode => widget.focusNode ?? (_localFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant DSTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _local)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _localFocus)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
    if (old.input.obscure != widget.input.obscure) {
      _obscured = widget.input.obscure;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    _local?.dispose();
    _localFocus?.dispose();
    super.dispose();
  }

  /// The clear button and the counter are drawn from the text, and the
  /// `TextField` below rebuilds itself without rebuilding this widget — so
  /// without this listener both are stale.
  void _onText() {
    if (!widget.affordances.showClearButton &&
        !widget.affordances.showCharCount) {
      return;
    }
    if (mounted) setState(() {});
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSTextFieldStyle.resolve(
      context,
      widget.size,
      widget.style,
    );
    final validation = widget.validation;
    if (validation?.validator == null) {
      return _body(context, resolved, null);
    }
    return _ValidatedField(
      controller: _controller,
      validation: validation!,
      enabled: widget.enabled,
      fieldBuilder: (state) => _body(context, resolved, state),
    );
  }

  Widget _body(
    BuildContext context,
    DSTextFieldStyle resolved,
    FormFieldState<String>? state,
  ) {
    final error = widget.errorText ?? state?.errorText;
    final gap = resolved.labelGap!;

    // `expands` is the Editor archetype's field: one document, taking the
    // room the screen gives it. A `Column` hands its children an unbounded
    // main axis whatever its own constraints are, so a `TextField` with
    // `expands: true` inside this column was given infinite height and threw
    // during layout — the document could not be built out of this component
    // at all until the field became the flexible child.
    final bool fills = widget.input.expands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.labelSlot != null || widget.label != null) ...[
          widget.labelSlot ?? _label(context, resolved),
          SizedBox(height: gap),
        ],
        if (fills)
          Expanded(child: _field(context, resolved, state, error))
        else
          _field(context, resolved, state, error),
        // The counter lives in this slot too, so a field that shows one keeps
        // the line whatever the flag says — a count that appears and
        // disappears with the text is the jump in its purest form.
        if (widget.reserveHelper || widget.affordances.showCharCount) ...[
          SizedBox(height: resolved.helperGap!),
          _helper(context, resolved, error),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, DSTextFieldStyle resolved) =>
      DSFieldLabel(
        label: widget.label ?? '',
        style: resolved,
        enabled: widget.enabled,
        required: widget.validation?.required ?? false,
      );

  Widget _field(
    BuildContext context,
    DSTextFieldStyle resolved,
    FormFieldState<String>? state,
    String? error,
  ) {
    final input = widget.input;
    final readOnly = widget.affordances.readOnly;

    final (outline, width) = DSFieldBox.outlineFor(
      resolved,
      enabled: widget.enabled,
      focused: _focusNode.hasFocus,
      hasError: error != null,
      readOnly: readOnly,
    );

    final trailing = _trailing(context, resolved);
    final pad = resolved.contentPadding!.resolve(Directionality.of(context));

    return DSFieldBox(
      style: resolved,
      outlineColor: outline,
      outlineWidth: width,
      enabled: widget.enabled,
      onTap: () => DSFieldBox.focusInput(_focusNode, readOnly: readOnly),
      children: [
        if (widget.leading != null)
          widget.leading!
        else if (widget.leadingIcon != null)
          Icon(
            widget.leadingIcon,
            size: resolved.iconSize,
            color: widget.enabled
                ? resolved.iconColor
                : resolved.disabledTextColor,
          ),
        if (widget.leading != null || widget.leadingIcon != null)
          SizedBox(width: resolved.labelGap!),
        if (widget.prefix != null) widget.prefix!,
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
            // The label is drawn above the box rather than inside it, which
            // is the whole point of this component — and it left the box
            // itself anonymous, because nothing in the field's own subtree
            // holds the word. `InputDecoration.labelText` is not the fix: it
            // would draw a second label inside the field. [MergeSemantics]
            // folds the name into the node the field already publishes, so
            // VoiceOver says "Email, text field" instead of "text field".
            child: MergeSemantics(
              child: Semantics(
                label: widget.label ?? widget.hintText,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  readOnly: readOnly,
                  autofocus: widget.affordances.autofocus,
                  obscureText: _obscured,
                  maxLength: input.maxLength,
                  maxLines: input.expands ? null : input.maxLines,
                  minLines: input.expands ? null : input.minLines,
                  expands: input.expands,
                  // A field that fills the page starts its text at the top of
                  // it. Centred is right for one line in a box and wrong for
                  // a document: the first line would sit halfway down the
                  // screen with the cursor under it.
                  textAlignVertical: input.expands
                      ? TextAlignVertical.top
                      : null,
                  keyboardType: input.keyboardType,
                  textInputAction: input.textInputAction,
                  textCapitalization: input.textCapitalization,
                  inputFormatters: input.inputFormatters,
                  autofillHints: input.autofillHints,
                  cursorColor: resolved.focusedOutline,
                  style: widget.enabled
                      ? resolved.textStyle
                      : resolved.textStyle?.copyWith(
                          color: resolved.disabledTextColor,
                        ),
                  // The count is drawn once, in the reserved slot below, where it
                  // shares a row with the helper text. The decoration's own copy
                  // would be a second counter in a second format.
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  // Every border is named, not just `border`: an
                  // `InputDecoration` fills its null slots from
                  // `ThemeData.inputDecorationTheme`, so leaving
                  // `enabledBorder` and friends unset drew the app's stock
                  // outlined field *inside* this one — a second pill, at a
                  // second radius, in every golden.
                  decoration: InputDecoration(
                    isCollapsed: true,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.hintText,
                    hintStyle: resolved.hintStyle,
                  ),
                  onChanged: (value) {
                    state?.didChange(value);
                    widget.onChanged?.call(value);
                  },
                  onSubmitted: widget.onSubmitted,
                ),
              ),
            ),
          ),
        ),
        if (widget.suffix != null) widget.suffix!,
        if (trailing != null) trailing,
      ],
    );
  }

  /// The loading spinner, the generated affordances and the caller's own
  /// trailing widget, in that order. Every one of them is its own node with
  /// its own target.
  Widget? _trailing(BuildContext context, DSTextFieldStyle resolved) {
    final motion = context.design.motion;
    final target = context.design.component.minTapTarget;
    final children = <Widget>[
      if (widget.loading)
        SizedBox.square(
          dimension: resolved.iconSize!,
          child: CircularProgressIndicator(
            strokeWidth: resolved.outlineWidth! * 2,
            color: resolved.iconColor,
          ),
        ),
      if (widget.input.obscure && widget.affordances.showPasswordToggle)
        _iconButton(
          resolved,
          target,
          icon: _obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
        ),
      if (widget.affordances.showClearButton && _controller.text.isNotEmpty)
        _iconButton(
          resolved,
          target,
          icon: Icons.close,
          tooltip: 'Clear',
          onPressed: widget.enabled
              ? () {
                  _controller.clear();
                  widget.onChanged?.call('');
                }
              : null,
        ),
      if (widget.trailingIcon != null)
        Icon(
          widget.trailingIcon,
          size: resolved.iconSize,
          color: widget.enabled
              ? resolved.iconColor
              : resolved.disabledTextColor,
        ),
      if (widget.trailing != null) widget.trailing!,
    ];
    if (children.isEmpty) return null;

    // Fades rather than scales: a control that pops into a place the user's
    // thumb is already heading for is a mis-tap.
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.scaled(motion.instant),
      curve: motion.standard,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _iconButton(
    DSTextFieldStyle resolved,
    double target, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    icon: Icon(icon, size: resolved.iconSize),
    tooltip: tooltip,
    onPressed: onPressed,
    color: resolved.iconColor,
    padding: EdgeInsets.zero,
    // No `VisualDensity.compact` here: it takes 8dp off the minimum size,
    // which is exactly the difference between a 48dp target and a 40dp one.
    constraints: BoxConstraints.tightFor(width: target, height: target),
  );

  /// One slot, one height, whatever it holds.
  ///
  /// The error replaces the helper *in place*. This is the fix for a form
  /// whose fields moved the instant a validator failed.
  Widget _helper(
    BuildContext context,
    DSTextFieldStyle resolved,
    String? error,
  ) {
    final palette = context.palette;

    final Widget? message = switch ((widget.helperSlot, error)) {
      (final Widget slot?, _) => slot,
      (_, final String text?) => Text(
        text,
        style: resolved.helperStyle?.copyWith(color: resolved.errorOutline),
        overflow: TextOverflow.ellipsis,
      ),
      _ when widget.helperText != null => Text(
        widget.helperText!,
        style: resolved.helperStyle,
        overflow: TextOverflow.ellipsis,
      ),
      _ => null,
    };

    final int? max = widget.input.maxLength;
    final length = _controller.text.characters.length;
    final Widget? counter = !widget.affordances.showCharCount
        ? null
        : Text(
            max == null ? '$length' : '$length/$max',
            style: resolved.helperStyle?.copyWith(
              color: max == null || length < max * 0.9
                  ? null
                  : length >= max
                  ? palette.destructive
                  : palette.warning,
            ),
          );

    return DSFieldHelper(
      style: resolved,
      trailing: counter,
      hasError: error != null,
      switchKey: ValueKey(error ?? widget.helperText),
      child: message,
    );
  }
}

/// The validation half of the field, so `Form.validate()`, `Form.reset()` and
/// `AutovalidateMode` all keep working without the field carrying Material's
/// `InputDecoration` — whose error text is drawn in a row that appears and
/// disappears, which is the height jump this widget exists to remove.
class _ValidatedField extends FormField<String> {
  _ValidatedField({
    required this.controller,
    required DSFieldValidation validation,
    required super.enabled,
    required Widget Function(FormFieldState<String>) fieldBuilder,
  }) : super(
         initialValue: controller.text,
         validator: validation.validator,
         autovalidateMode:
             validation.autovalidateMode ?? AutovalidateMode.disabled,
         builder: (state) => fieldBuilder(state),
       );

  final TextEditingController controller;

  @override
  FormFieldState<String> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends FormFieldState<String> {
  @override
  _ValidatedField get widget => super.widget as _ValidatedField;

  @override
  void reset() {
    widget.controller.text = widget.initialValue ?? '';
    super.reset();
  }

  @override
  void didChange(String? value) {
    super.didChange(value);
    // A no-op when the change came from the field itself; the case that
    // matters is `Form` moving the value without the text moving with it.
    if (widget.controller.text != (value ?? '')) {
      widget.controller.text = value ?? '';
    }
  }
}

/// The label above a field.
///
/// Public because a field is not only [DSTextField]: [DSSelect]'s trigger is
/// the same control with a different way of changing its value, and a second
/// label drawn a second way is how two controls in one form stop lining up.
class DSFieldLabel extends StatelessWidget {
  const DSFieldLabel({
    super.key,
    required this.label,
    required this.style,
    this.enabled = true,
    this.required = false,
  });

  final String label;
  final DSTextFieldStyle style;
  final bool enabled;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: label),
        if (required)
          TextSpan(
            text: ' *',
            style: TextStyle(color: style.errorOutline),
            semanticsLabel: ' required',
          ),
      ],
    ),
    // A truncated field label is an unknown field, so it wraps and never
    // ellipsises.
    style: enabled
        ? style.labelStyle
        : style.labelStyle?.copyWith(color: style.disabledTextColor),
  );
}

/// The box a field is drawn in: the fill, the outline, the radius, the
/// minimum height and the horizontal inset.
///
/// **This is the field skin, and there is exactly one of it.** `DSSelect`
/// used to build its own — its own container, its own border colour, its own
/// focus width of `1.5`, its own fill — so a select and a text field in one
/// form were two implementations of one control, guaranteed to drift.
class DSFieldBox extends StatelessWidget {
  const DSFieldBox({
    super.key,
    required this.style,
    required this.children,
    required this.outlineColor,
    required this.outlineWidth,
    this.enabled = true,
    this.onTap,
  });

  final DSTextFieldStyle style;
  final List<Widget> children;
  final Color outlineColor;
  final double outlineWidth;
  final bool enabled;

  /// What a tap anywhere in the box does that no child claimed first.
  ///
  /// A text input inside the box is collapsed: its own gesture detector is
  /// one line of text tall and stops at the horizontal inset, so the air
  /// above and below the line, the inset and the leading icon were all drawn
  /// as the field and swallowed a touch. A child that handles its own taps —
  /// the input placing its caret, a clear button — still wins the arena,
  /// because it is deeper in the hit test.
  final VoidCallback? onTap;

  /// The [onTap] a text input passes: focus the field, or bring its keyboard
  /// back if the field already has focus and the user dismissed it.
  static void focusInput(FocusNode node, {bool readOnly = false}) {
    if (!node.hasFocus) {
      node.requestFocus();
    } else if (!readOnly) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = _box(context);
    if (onTap == null || !enabled) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      // ui-lint: allow pressable-floor — this is not a control of its own but
      // the dead area of the input it frames. The input already has its focus
      // ring (the focused outline) and its feedback (the caret and keyboard);
      // a press ripple or haptic on a text box would be a second control.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The input already publishes the tappable node; a second one on the
        // box would be announced as a separate control.
        excludeFromSemantics: true,
        onTap: onTap,
        child: box,
      ),
    );
  }

  Widget _box(BuildContext context) {
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final pad = style.contentPadding!.resolve(Directionality.of(context));

    // Two layers, neither of them a Container: the fill paints the field's
    // outer bounds; the border paints on top of the fill, on a paint-only
    // layer that does not contribute to layout.
    //
    // `Container` adds `decoration.padding` to its own padding for layout
    // (and `ShapeDecoration.padding` is `side.width` on every side for
    // `RoundedRectangleBorder`), so putting the border on the same
    // `AnimatedContainer` as the fill would make the 1dp → 2dp focus change
    // grow the effective inset by 1dp on every side, squeezing the Row's
    // icons and growing the field's height by 2dp when the trailing
    // affordance is 48dp tall. The border is painted at the same outer
    // bounds as the fill instead, on an `AnimatedContainer` that fills the
    // stack, and the content's horizontal inset moves onto a `Padding`
    // wrapper around the Row so the visible gap between the border and the
    // leading icon is the same as before this fix.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.height!),
      child: Stack(
        // Centred, not the Stack's default topStart: the box is stretched to
        // `style.height` by the ConstrainedBox above, and a row shorter than
        // that floats to the top of it. A text field never showed this — its
        // TextField fills the height — but DSSelect's trigger is a Text and a
        // chevron, and its value sat 12 points above the box's centre.
        alignment: AlignmentDirectional.centerStart,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : motion.scaled(motion.fast),
              curve: motion.standard,
              decoration: ShapeDecoration(
                color: enabled ? style.fillColor : style.disabledFill,
                shape: RoundedRectangleBorder(
                  borderRadius: style.radius!,
                  side: BorderSide(color: outlineColor, width: outlineWidth),
                ),
                // The lowest step, and only while the field takes input: a
                // faint lift is what separates a field from a hairline box
                // now that the outline is quiet. A disabled field sits flat.
                shadows: enabled
                    ? context.design.elevation.resolve(
                        elevation: context.design.elevation.low,
                        brightness: context.palette.brightness,
                        shadowColor: context.palette.overlay,
                      )
                    : const [],
              ),
            ),
          ),
          Padding(
            // ui-lint: allow physical-direction — `pad` is the resolved
            // EdgeInsets, so its left and right are already this
            // Directionality's start and end.
            padding: EdgeInsets.only(left: pad.left, right: pad.right),
            child: Row(children: children),
          ),
        ],
      ),
    );
  }

  /// The outline a field is drawn with, given what state it is in.
  ///
  /// Static rather than duplicated at each field-shaped control: error beats
  /// focus beats read-only beats resting, and getting that order wrong is how
  /// a focused field with an error stops showing the error.
  static (Color, double) outlineFor(
    DSTextFieldStyle style, {
    required bool enabled,
    required bool focused,
    required bool hasError,
    bool readOnly = false,
  }) => switch (enabled) {
    false => (style.disabledOutline!, style.outlineWidth!),
    true when hasError => (style.errorOutline!, style.focusedWidth!),
    true when focused => (style.focusedOutline!, style.focusedWidth!),
    true when readOnly => (style.disabledOutline!, style.outlineWidth!),
    true => (style.outlineColor!, style.outlineWidth!),
  };
}

/// One slot, one height, whatever it holds: the helper line under a field, or
/// the error that replaces it in place.
///
/// The fixed height is the fix for a form whose fields moved the instant a
/// validator failed.
class DSFieldHelper extends StatelessWidget {
  const DSFieldHelper({
    super.key,
    required this.style,
    this.child,
    this.trailing,
    this.hasError = false,
    this.switchKey,
  });

  final DSTextFieldStyle style;

  /// The line itself: a helper, or the error that replaces it in place.
  final Widget? child;

  final Widget? trailing;
  final bool hasError;

  /// What identity the switcher animates on. Two different messages need two
  /// different keys or the cross-fade never runs.
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final motion = context.design.motion;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final height = MediaQuery.textScalerOf(
      context,
    ).scale(style.helperSlotHeight!);

    return SizedBox(
      height: height,
      child: Semantics(
        liveRegion: hasError,
        child: AnimatedSwitcher(
          duration: reduced ? Duration.zero : motion.scaled(motion.fast),
          switchInCurve: motion.enter,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: reduced ? Offset.zero : const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Row(
            key: switchKey,
            children: [
              if (child != null) Expanded(child: child!),
              if (child == null) const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
