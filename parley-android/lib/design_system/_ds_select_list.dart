// ds-tier: 2 — molecule

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/design_system/_ds_select_style.dart';
import 'package:parley_android/design_system/_ds_select_parts.dart';

/// One row's worth of what the list needs to navigate: what it is called,
/// what it stands for, and whether it can be picked.
///
/// Built from the widgets rather than kept beside them, so a caller's own row
/// subclassing [DSSelectOption] navigates like every other row.
@immutable
class DSSelectRow {
  const DSSelectRow(
    this.widget, {
    this.value,
    this.label = '',
    this.pickable = false,
  });

  final Widget widget;
  final Object? value;
  final String label;
  final bool pickable;

  static DSSelectRow from(Widget widget) {
    if (widget is DSSelectOption) {
      return DSSelectRow(
        widget,
        value: widget.value,
        label: widget.label,
        pickable: widget.enabled,
      );
    }
    return DSSelectRow(widget);
  }
}

/// Where a select's options come from.
///
/// Two forms, because each is right in a different case: a caller with one
/// unusual row writes it, and a caller with two hundred countries does not
/// hand-write two hundred widgets.
@immutable
class DSSelectOptions {
  const DSSelectOptions.composed(this.children) : values = null, builder = null;

  const DSSelectOptions.generated(this.values, this.builder) : children = null;

  final List<Widget>? children;
  final List<Object?>? values;
  final DSSelectOption<Object?> Function(Object?)? builder;

  int get length => children?.length ?? values!.length;

  /// The widget at [index], built on demand.
  ///
  /// The generated form builds a row only when the list asks for one, which
  /// is what makes a two-hundred-option select cost six rows to open.
  Widget at(int index) => children?[index] ?? builder!(values![index]);
}

/// The list inside the surface: search, keyboard navigation, type-ahead.
class DSSelectList extends StatefulWidget {
  const DSSelectList({
    super.key,
    required this.options,
    required this.selected,
    required this.multiple,
    required this.atMax,
    required this.style,
    required this.onPick,
    required this.showSearch,
    required this.searchDelegate,
    required this.loading,
    this.header,
    this.footer,
    this.empty,
    this.noResults,
    this.label,
  });

  final DSSelectOptions options;
  final Set<Object?> selected;
  final bool multiple;
  final bool atMax;
  final DSSelectStyle style;
  final void Function(Object? value) onPick;
  final bool showSearch;
  final DSSelectSearchDelegate searchDelegate;
  final bool loading;
  final Widget? header;
  final Widget? footer;
  final Widget? empty;
  final Widget? noResults;
  final String? label;

  @override
  State<DSSelectList> createState() => _SelectListState();
}

class _SelectListState extends State<DSSelectList> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _listFocus = FocusNode(debugLabel: 'DSSelect list');

  Object? _active;
  String _typed = '';
  Timer? _typeAheadReset;

  @override
  void initState() {
    super.initState();
    _active = widget.selected.isEmpty ? null : widget.selected.first;
  }

  @override
  void dispose() {
    _typeAheadReset?.cancel();
    _query.dispose();
    _scroll.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  /// The rows that survive the current query, in order.
  List<DSSelectRow> get _rows {
    final text = _query.text.trim();
    final rows = <DSSelectRow>[
      for (var i = 0; i < widget.options.length; i++)
        DSSelectRow.from(widget.options.at(i)),
    ];
    if (text.isEmpty) return rows;
    return [
      for (final row in rows)
        if (row.widget is DSSelectOption &&
            widget.searchDelegate.matches(
              text,
              row.widget as DSSelectOption<Object?>,
            ))
          row,
    ];
  }

  List<DSSelectRow> get _pickable => [
    for (final row in _rows)
      if (row.pickable) row,
  ];

  void _move(int delta) {
    final rows = _pickable;
    if (rows.isEmpty) return;
    final current = rows.indexWhere((r) => r.value == _active);
    final next = (current + delta).clamp(0, rows.length - 1);
    setState(() => _active = rows[next < 0 ? 0 : next].value);
  }

  void _jump({required bool toEnd}) {
    final rows = _pickable;
    if (rows.isEmpty) return;
    setState(() => _active = (toEnd ? rows.last : rows.first).value);
  }

  /// A user who opens a country picker and types "ge" expects to land on
  /// Germany. One buffered keystroke timer, and it was missing entirely.
  void _typeAhead(String character) {
    _typeAheadReset?.cancel();
    _typeAheadReset = Timer(
      // ui-lint: allow bare-metric
      // ui-lint: allow hardcoded-duration — the WAI-ARIA type-ahead buffer,
      // not an animation. It is a property of how fast people type, so it does
      // not move when the app's motion scale does.
      const Duration(milliseconds: 1000),
      () => _typed = '',
    );
    _typed += character.toLowerCase();
    final match = _pickable.firstWhere(
      (row) => DSSelectSubstringSearch.fold(row.label).startsWith(_typed),
      orElse: () => const DSSelectRow(SizedBox.shrink()),
    );
    if (match.value != null) setState(() => _active = match.value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _jump(toEnd: false);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _jump(toEnd: true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        if (_active != null) widget.onPick(_active);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null && character.trim().isNotEmpty) {
      _typeAhead(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final design = context.design;
    final rows = _rows;
    final searching = _query.text.trim().isNotEmpty;

    final Widget body;
    if (widget.loading) {
      body = ListView(
        shrinkWrap: true,
        padding: style.listPadding,
        children: const [
          DSSelectOptionSkeleton(),
          DSSelectOptionSkeleton(),
          DSSelectOptionSkeleton(),
        ],
      );
    } else if (rows.isEmpty) {
      // "No options available" and "No matches for 'xyz'" are different
      // messages, and only the second offers a way to clear the search.
      body = Padding(
        padding: EdgeInsets.all(design.space.lg),
        child: searching
            ? (widget.noResults ??
                  DSEmptyState.noResults(
                    query: _query.text.trim(),
                    actionLabel: 'Clear search',
                    onAction: () => setState(_query.clear),
                  ))
            : (widget.empty ??
                  const DSEmptyState(title: 'No options available.')),
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        shrinkWrap: true,
        padding: style.listPadding,
        itemCount: rows.length,
        // Between two options, and nowhere else. A line under the last row
        // draws a floor the list does not have, and one against a section
        // header separates a label from the rows it labels.
        itemBuilder: (context, index) {
          final row = rows[index];
          final next = index + 1 < rows.length ? rows[index + 1] : null;
          final between =
              row.widget is DSSelectOption && next?.widget is DSSelectOption;
          if (!between) return row.widget;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [row.widget, const DSSelectSeparator()],
          );
        },
      );
    }

    return Focus(
      focusNode: _listFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: DSSelectListScope(
        selected: widget.selected,
        active: _active,
        multiple: widget.multiple,
        atMax: widget.atMax,
        style: style,
        onPick: widget.onPick,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.header != null) widget.header!,
            if (widget.showSearch)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  design.space.md,
                  design.space.xs,
                  design.space.md,
                  0,
                ),
                child: DSTextField(
                  controller: _query,
                  hintText: 'Search',
                  leadingIcon: Icons.search,
                  affordances: const DSFieldAffordances(showClearButton: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Flexible(child: body),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }
}

/// The field a select is opened from.
///
/// A [FocusableActionDetector] rather than a `GestureDetector`: `Tab` reaches
/// it, `Space` and `Enter` open it, and it publishes the `combobox` role with
/// `expanded` tracking the surface. None of that existed before.
class DSSelectTrigger extends StatelessWidget {
  const DSSelectTrigger({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.hintText,
    required this.helperText,
    required this.errorText,
    required this.enabled,
    required this.loading,
    required this.open,
    required this.onOpen,
    required this.leading,
    required this.trigger,
    required this.style,
    required this.valueSlot,
    this.valueSemantics,
    this.reserveHelper = true,
  });

  final GlobalKey fieldKey;
  final String? label;
  final String hintText;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final bool loading;
  final bool open;
  final VoidCallback onOpen;
  final Widget? leading;
  final Widget? trigger;
  final DSSelectStyle? style;
  final Widget? valueSlot;
  final String? valueSemantics;

  /// See [DSTextField.reserveHelper]. The trigger collapses the line and the
  /// gap above it together — half of each is still a gap.
  final bool reserveHelper;

  @override
  Widget build(BuildContext context) {
    final resolved = DSSelectStyle.resolve(context, style);
    final field = DSTextFieldStyle.resolve(context, null, resolved.fieldStyle);
    final palette = context.palette;
    final motion = context.design.motion;

    final (outline, width) = DSFieldBox.outlineFor(
      field,
      enabled: enabled,
      focused: open,
      hasError: errorText != null,
    );

    final Widget body =
        trigger ??
        DSFieldBox(
          style: field,
          outlineColor: outline,
          outlineWidth: width,
          enabled: enabled,
          children: [
            if (leading != null) ...[
              leading!,
              SizedBox(width: field.labelGap!),
            ],
            Expanded(
              child: loading
                  ? const DSSkeleton(child: Text('Loading'))
                  : DefaultTextStyle.merge(
                      style: field.textStyle?.copyWith(
                        color: valueSlot == null
                            ? palette.mutedForeground
                            : enabled
                            ? palette.foreground
                            : field.disabledTextColor,
                      ),
                      child: valueSlot ?? Text(hintText),
                    ),
            ),
            SizedBox(width: field.labelGap!),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : motion.scaled(motion.fast),
              child: Icon(
                resolved.chevronIcon,
                size: resolved.chevronSize,
                color: enabled
                    ? palette.mutedForeground
                    : field.disabledOutline,
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          DSFieldLabel(label: label!, style: field, enabled: enabled),
          SizedBox(height: field.labelGap!),
        ],
        Semantics(
          // The combobox role, with `expanded` tracking the surface, is what
          // tells a screen reader that this control opens something and
          // whether it is open right now.
          container: true,
          button: true,
          enabled: enabled,
          expanded: open,
          label: label ?? hintText,
          value: valueSemantics,
          onTap: enabled ? onOpen : null,
          child: ExcludeSemantics(
            child: FocusableActionDetector(
              enabled: enabled && !loading,
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.arrowDown): ActivateIntent(),
              },
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    onOpen();
                    return null;
                  },
                ),
              },
              child: DSPressable(
                enabled: enabled && !loading,
                focusShape: RoundedRectangleBorder(borderRadius: field.radius!),
                child: GestureDetector(
                  onTap: enabled && !loading ? onOpen : null,
                  child: KeyedSubtree(key: fieldKey, child: body),
                ),
              ),
            ),
          ),
        ),
        if (reserveHelper) ...[
          SizedBox(height: field.helperGap!),
          DSFieldHelper(
            style: field,
            hasError: errorText != null,
            switchKey: ValueKey(errorText ?? helperText),
            child: switch ((errorText, helperText)) {
              (final String error?, _) => Text(
                error,
                style: field.helperStyle?.copyWith(color: field.errorOutline),
                overflow: TextOverflow.ellipsis,
              ),
              (_, final String helper?) => Text(
                helper,
                style: field.helperStyle,
                overflow: TextOverflow.ellipsis,
              ),
              _ => null,
            },
          ),
        ],
      ],
    );
  }
}
