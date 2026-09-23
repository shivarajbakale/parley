// ds-tier: 3 — organism

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_bottom_sheet.dart';
import 'package:parley_android/design_system/ds_chip.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/design_system/_ds_select_list.dart';
import 'package:parley_android/design_system/_ds_select_parts.dart';
import 'package:parley_android/design_system/_ds_select_style.dart';

export '_ds_select_style.dart';
export '_ds_select_parts.dart';

/// A control that shows the current choice and, when opened, presents the
/// available choices.
///
/// The surface is a [DSOverlayRoute]. It used to be an `OverlayEntry`, which
/// meant the Android back button exited the screen underneath while the menu
/// stayed painted, there was no focus trap, no route semantics and no
/// `Navigator.pop` — and the trigger was a `GestureDetector`, which is WCAG
/// 2.1.1 failed outright.
class DSSelect<T> extends StatefulWidget {
  const DSSelect({
    super.key,
    required List<Widget> options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'Select an item',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.clearable = false,
    this.showSearch,
    this.presentation,
    this.responsive = true,
    this.trigger,
    this.valueSlot,
    this.leading,
    this.header,
    this.footer,
    this.empty,
    this.noResults,
    this.searchDelegate,
    this.style,
    this.reserveHelper = true,
  }) : _options = options,
       _values = null,
       _optionBuilder = null,
       assert(
         reserveHelper || (helperText == null && errorText == null),
         'reserveHelper: false is for a select that can say nothing under '
         'itself. This one carries a helper or an error, and collapsing the '
         'line means the message shoves the rest of the form down the moment '
         'it arrives — the jump the reserved slot exists to stop.',
       );

  /// The generated form, for a list nobody hand-writes.
  ///
  /// One builder returning a [DSSelectOption], not three builders returning
  /// three scalars — so a caller with two hundred countries is served and a
  /// caller with one unusual row is not blocked.
  const DSSelect.fromValues({
    super.key,
    required List<T> values,
    required DSSelectOption<T> Function(T) optionBuilder,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'Select an item',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.clearable = false,
    this.showSearch,
    this.presentation,
    this.responsive = true,
    this.trigger,
    this.valueSlot,
    this.leading,
    this.header,
    this.footer,
    this.empty,
    this.noResults,
    this.searchDelegate,
    this.style,
    this.reserveHelper = true,
  }) : _options = null,
       _values = values,
       _optionBuilder = optionBuilder,
       assert(
         reserveHelper || (helperText == null && errorText == null),
         'reserveHelper: false is for a select that can say nothing under '
         'itself. This one carries a helper or an error, and collapsing the '
         'line means the message shoves the rest of the form down the moment '
         'it arrives — the jump the reserved slot exists to stop.',
       );

  final List<Widget>? _options;
  final List<T>? _values;
  final DSSelectOption<T> Function(T)? _optionBuilder;

  final T? value;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String hintText;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool loading;

  /// Adds a "None" row, so a value that was chosen can be un-chosen.
  final bool clearable;

  final bool? showSearch;
  final DSOverlayPresentation? presentation;
  final bool responsive;
  final Widget? trigger;
  final Widget? valueSlot;
  final Widget? leading;
  final Widget? header;
  final Widget? footer;
  final Widget? empty;
  final Widget? noResults;
  final DSSelectSearchDelegate? searchDelegate;
  final DSSelectStyle? style;

  /// Whether the helper line under the trigger keeps its space when there is
  /// nothing in it. See [DSTextField.reserveHelper]: a select over a fixed
  /// list can say nothing, and reserving a line for it costs the slot plus
  /// its gap on every such field.
  final bool reserveHelper;

  @override
  State<DSSelect<T>> createState() => _DSSelectState<T>();
}

class _DSSelectState<T> extends State<DSSelect<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  bool _open = false;

  DSSelectOptions get _options => widget._options != null
      ? DSSelectOptions.composed(widget._options!)
      : DSSelectOptions.generated(
          widget._values!,
          (value) => widget._optionBuilder!(value as T),
        );

  /// What the trigger says when nothing is chosen, and what it says when
  /// something is.
  String? get _valueLabel {
    if (widget.value == null) return null;
    final options = _options;
    for (var i = 0; i < options.length; i++) {
      final row = DSSelectRow.from(options.at(i));
      if (row.value == widget.value) return row.label;
    }
    return null;
  }

  Future<void> _open$() async {
    if (!widget.enabled || widget.loading) return;
    setState(() => _open = true);
    final picked = await _showDSSelectSurface<T>(
      context: context,
      anchor: _fieldKey,
      options: _options,
      selected: widget.value == null ? const {} : {widget.value},
      multiple: false,
      label: widget.label,
      clearable: widget.clearable,
      showSearch: widget.showSearch,
      presentation: widget.presentation,
      responsive: widget.responsive,
      header: widget.header,
      footer: widget.footer,
      empty: widget.empty,
      noResults: widget.noResults,
      loading: false,
      searchDelegate: widget.searchDelegate,
      style: widget.style,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) {
      AppHaptics.selection();
      widget.onChanged(picked.cleared ? null : picked.value as T?);
    }
  }

  @override
  Widget build(BuildContext context) => DSSelectTrigger(
    fieldKey: _fieldKey,
    label: widget.label,
    hintText: widget.hintText,
    helperText: widget.helperText,
    errorText: widget.errorText,
    enabled: widget.enabled,
    loading: widget.loading,
    open: _open,
    onOpen: _open$,
    leading: widget.leading,
    trigger: widget.trigger,
    style: widget.style,
    reserveHelper: widget.reserveHelper,
    valueSlot:
        widget.valueSlot ?? (_valueLabel == null ? null : Text(_valueLabel!)),
  );
}

/// Several values from a known set.
///
/// The kit's first multiple-selection control: `Set<T>` appeared nowhere in
/// `design_system/` before this. It is a separate component rather than a
/// flag on [DSSelect] because it differs in four ways that all have to be
/// decided — the menu stays open, the trigger summarises rather than names,
/// the row carries a checkbox rather than a trailing check, and it needs
/// select-all and clear.
class DSMultiSelect<T> extends StatefulWidget {
  const DSMultiSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText = 'Select items',
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.showSearch,
    this.presentation,
    this.responsive = true,
    this.minSelection,
    this.maxSelection,
    this.showSelectAll = false,
    this.triggerChipLimit,
    this.trigger,
    this.leading,
    this.header,
    this.footer,
    this.empty,
    this.noResults,
    this.searchDelegate,
    this.style,
  });

  final List<Widget> options;
  final Set<T> value;
  final ValueChanged<Set<T>> onChanged;
  final String? label;
  final String hintText;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool loading;
  final bool? showSearch;
  final DSOverlayPresentation? presentation;
  final bool responsive;
  final int? minSelection;

  /// At the maximum the unselected rows disable rather than ignoring the tap:
  /// the constraint is visible before it is hit, which is the accessible
  /// behaviour.
  final int? maxSelection;

  final bool showSelectAll;
  final int? triggerChipLimit;
  final Widget? trigger;
  final Widget? leading;
  final Widget? header;
  final Widget? footer;
  final Widget? empty;
  final Widget? noResults;
  final DSSelectSearchDelegate? searchDelegate;
  final DSSelectStyle? style;

  @override
  State<DSMultiSelect<T>> createState() => _DSMultiSelectState<T>();
}

class _DSMultiSelectState<T> extends State<DSMultiSelect<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  bool _open = false;

  /// The selection, as something the open surface can listen to.
  ///
  /// The surface is a route and therefore a different subtree: a `setState`
  /// here does not reach it, and the menu stays open across a selection, so
  /// it has to be told.
  late final ValueNotifier<Set<T>> _live = ValueNotifier<Set<T>>(widget.value);

  @override
  void didUpdateWidget(covariant DSMultiSelect<T> old) {
    super.didUpdateWidget(old);
    if (!setEquals(old.value, widget.value)) _live.value = widget.value;
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  List<DSSelectRow> get _rows => [
    for (final option in widget.options) DSSelectRow.from(option),
  ];

  Future<void> _open$() async {
    if (!widget.enabled || widget.loading) return;
    setState(() => _open = true);
    await _showDSMultiSurface<T>(
      context: context,
      anchor: _fieldKey,
      options: DSSelectOptions.composed(widget.options),
      state: this,
    );
    if (!mounted) return;
    setState(() => _open = false);
  }

  void toggle(Object? value) {
    final next = Set<T>.of(widget.value);
    if (next.contains(value)) {
      if (widget.minSelection != null && next.length <= widget.minSelection!) {
        return;
      }
      next.remove(value);
    } else {
      if (widget.maxSelection != null && next.length >= widget.maxSelection!) {
        return;
      }
      next.add(value as T);
    }
    AppHaptics.selection();
    _live.value = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final style = DSSelectStyle.resolve(context, widget.style);
    final limit = widget.triggerChipLimit ?? style.triggerChipLimit!;
    final chosen = [
      for (final row in _rows)
        if (widget.value.contains(row.value)) row.label,
    ];

    final Widget? summary = chosen.isEmpty
        ? null
        : Wrap(
            spacing: context.design.space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final label in chosen.take(limit))
                DSChip(label: label, size: DSChipSize.sm),
              if (chosen.length > limit) Text('+${chosen.length - limit}'),
            ],
          );

    return DSSelectTrigger(
      fieldKey: _fieldKey,
      label: widget.label,
      hintText: widget.hintText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      enabled: widget.enabled,
      loading: widget.loading,
      open: _open,
      onOpen: _open$,
      leading: widget.leading,
      trigger: widget.trigger,
      style: widget.style,
      valueSlot: summary,
      valueSemantics: chosen.isEmpty ? null : '${chosen.length} selected',
    );
  }
}

/// What a single select's surface pops: a value, or the fact that the "None"
/// row was chosen.
@immutable
class _Picked {
  const _Picked(this.value, {this.cleared = false});

  final Object? value;
  final bool cleared;
}

/// Presents the list, and returns what was chosen.
Future<_Picked?> _showDSSelectSurface<T>({
  required BuildContext context,
  required GlobalKey anchor,
  required DSSelectOptions options,
  required Set<Object?> selected,
  required bool multiple,
  required String? label,
  required bool clearable,
  required bool? showSearch,
  required DSOverlayPresentation? presentation,
  required bool responsive,
  required Widget? header,
  required Widget? footer,
  required Widget? empty,
  required Widget? noResults,
  required bool loading,
  required DSSelectSearchDelegate? searchDelegate,
  required DSSelectStyle? style,
}) {
  final resolved = DSSelectStyle.resolve(context, style);
  final requested = presentation ?? resolved.presentation!;
  final actual = resolveDSPresentation(
    context,
    requested,
    responsive: responsive,
    style: null,
  );
  final search = showSearch ?? options.length > resolved.searchThreshold!;

  return showDSOverlay<_Picked>(
    context: context,
    anchor: anchor,
    presentation: actual,
    // Already resolved above: the surface has to know which one it got, so
    // that a sheet gets a header and a popover does not.
    responsive: false,
    semanticLabel: label,
    maxHeight: actual == DSOverlayPresentation.sheet
        ? null
        : resolved.optionHeight! * resolved.maxVisibleOptions!,
    builder: (context) {
      final list = DSSelectList(
        options: clearable
            ? DSSelectOptions.composed([
                const DSSelectOption<Object?>(
                  value: _ClearValue(),
                  label: 'None',
                ),
                for (var i = 0; i < options.length; i++) options.at(i),
              ])
            : options,
        selected: selected,
        multiple: multiple,
        atMax: false,
        style: resolved,
        showSearch: search,
        searchDelegate: searchDelegate ?? const DSSelectSubstringSearch(),
        loading: loading,
        header: header,
        footer: footer,
        empty: empty,
        noResults: noResults,
        label: label,
        onPick: (value) => Navigator.of(context).pop(
          value is _ClearValue
              ? const _Picked(null, cleared: true)
              : _Picked(value),
        ),
      );

      if (actual == DSOverlayPresentation.sheet) {
        return DSBottomSheet(
          fit: DSSheetFit.content,
          scrollable: false,
          header: label == null ? null : DSSheetHeader(title: label),
          child: list,
        );
      }
      return DSOverlaySurface(
        presentation: actual,
        showDragHandle: false,
        child: list,
      );
    },
  );
}

/// The "None" row's value, which cannot collide with a caller's own.
@immutable
class _ClearValue {
  const _ClearValue();
}

/// Presents a multi-select's list, which reports each change as it happens
/// and does not close.
Future<void> _showDSMultiSurface<T>({
  required BuildContext context,
  required GlobalKey anchor,
  required DSSelectOptions options,
  required _DSMultiSelectState<T> state,
}) {
  final widget = state.widget;
  final resolved = DSSelectStyle.resolve(context, widget.style);
  final requested = widget.presentation ?? resolved.presentation!;
  final actual = resolveDSPresentation(
    context,
    requested,
    responsive: widget.responsive,
    style: null,
  );
  final search =
      widget.showSearch ?? options.length > resolved.searchThreshold!;

  return showDSOverlay<void>(
    context: context,
    anchor: anchor,
    presentation: actual,
    responsive: false,
    semanticLabel: widget.label,
    maxHeight: actual == DSOverlayPresentation.sheet
        ? null
        : resolved.optionHeight! * resolved.maxVisibleOptions!,
    builder: (context) {
      // Rebuilt from the owner's selection on every toggle: the menu stays
      // open, so the surface has to reflect a value that changed under it.
      return ValueListenableBuilder<Set<T>>(
        valueListenable: state._live,
        builder: (context, selection, _) {
          final atMax =
              widget.maxSelection != null &&
              selection.length >= widget.maxSelection!;
          final list = DSSelectList(
            options: options,
            selected: selection,
            multiple: true,
            atMax: atMax,
            style: resolved,
            showSearch: search,
            searchDelegate:
                widget.searchDelegate ?? const DSSelectSubstringSearch(),
            loading: widget.loading,
            header: widget.header,
            footer: widget.footer,
            empty: widget.empty,
            noResults: widget.noResults,
            label: widget.label,
            onPick: state.toggle,
          );
          if (actual == DSOverlayPresentation.sheet) {
            return DSBottomSheet(
              fit: DSSheetFit.content,
              scrollable: false,
              header: widget.label == null
                  ? null
                  : DSSheetHeader(title: widget.label!),
              child: list,
            );
          }
          return DSOverlaySurface(
            presentation: actual,
            showDragHandle: false,
            child: list,
          );
        },
      );
    },
  );
}
