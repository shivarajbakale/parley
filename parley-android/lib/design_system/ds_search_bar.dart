// ds-tier: 3 — organism

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:parley_android/design_system/ds_chip.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_status_state.dart';
import 'package:parley_android/design_system/ds_icon_button.dart';
import 'package:parley_android/design_system/ds_list_tile.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_progress_indicator.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// How a search bar looks, at every layer of the resolution chain.
@immutable
class DSSearchBarStyle extends DSComponentStyle<DSSearchBarStyle> {
  const DSSearchBarStyle({
    this.fieldStyle,
    this.leadingIcon,
    this.clearIcon,
    this.iconSize,
    this.chipGap,
    this.barToChips,
    this.countStyle,
    this.suggestionHeight,
    this.debounce,
  });

  /// The field skin, inherited from [DSTextField] rather than rebuilt.
  ///
  /// The bar used to construct its own `OutlineInputBorder` set, its own focus
  /// width of 1.5 and its own content padding — a third field implementation
  /// beside the text field's and the select's. A search field that focuses
  /// half a point thinner than every other field is a difference nobody chose.
  final DSTextFieldStyle? fieldStyle;

  final IconData? leadingIcon;
  final IconData? clearIcon;
  final double? iconSize;
  final double? chipGap;
  final double? barToChips;
  final TextStyle? countStyle;
  final double? suggestionHeight;

  /// How long the bar waits before reporting a settled query. Zero fires
  /// synchronously, which is what a local filter over twenty items wants.
  final Duration? debounce;

  @override
  DSSearchBarStyle merge(DSSearchBarStyle? other) {
    if (other == null) return this;
    return DSSearchBarStyle(
      fieldStyle: fieldStyle == null
          ? other.fieldStyle
          : fieldStyle!.merge(other.fieldStyle),
      leadingIcon: other.leadingIcon ?? leadingIcon,
      clearIcon: other.clearIcon ?? clearIcon,
      iconSize: other.iconSize ?? iconSize,
      chipGap: other.chipGap ?? chipGap,
      barToChips: other.barToChips ?? barToChips,
      countStyle: other.countStyle ?? countStyle,
      suggestionHeight: other.suggestionHeight ?? suggestionHeight,
      debounce: other.debounce ?? debounce,
    );
  }

  @override
  DSSearchBarStyle copyWith({
    DSTextFieldStyle? fieldStyle,
    IconData? leadingIcon,
    IconData? clearIcon,
    double? iconSize,
    double? chipGap,
    double? barToChips,
    TextStyle? countStyle,
    double? suggestionHeight,
    Duration? debounce,
  }) => DSSearchBarStyle(
    fieldStyle: fieldStyle ?? this.fieldStyle,
    leadingIcon: leadingIcon ?? this.leadingIcon,
    clearIcon: clearIcon ?? this.clearIcon,
    iconSize: iconSize ?? this.iconSize,
    chipGap: chipGap ?? this.chipGap,
    barToChips: barToChips ?? this.barToChips,
    countStyle: countStyle ?? this.countStyle,
    suggestionHeight: suggestionHeight ?? this.suggestionHeight,
    debounce: debounce ?? this.debounce,
  );

  @override
  DSSearchBarStyle lerp(DSSearchBarStyle? other, double t) {
    if (other == null) return this;
    return DSSearchBarStyle(
      // Two glyphs and a duration have no midpoint.
      leadingIcon: t < 0.5 ? leadingIcon : other.leadingIcon,
      clearIcon: t < 0.5 ? clearIcon : other.clearIcon,
      debounce: t < 0.5 ? debounce : other.debounce,
      fieldStyle: fieldStyle?.lerp(other.fieldStyle, t) ?? other.fieldStyle,
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      chipGap: lerpDouble(chipGap, other.chipGap, t),
      barToChips: lerpDouble(barToChips, other.barToChips, t),
      countStyle: TextStyle.lerp(countStyle, other.countStyle, t),
      suggestionHeight: lerpDouble(suggestionHeight, other.suggestionHeight, t),
    );
  }

  static DSSearchBarStyle resolve(
    BuildContext context, [
    DSSearchBarStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    return resolveStyle(
      context: context,
      specDefaults: DSSearchBarStyle(
        // The field skin's own fill, unmodified.
        //
        // This used to override to `Palette.well` on the reasoning that a
        // search field is a control sitting *on* the page rather than content
        // in a form, and that the recess role is the ground the platform's own
        // search field uses. The tone the ladder actually hands it does not
        // support that: `well` measures 1.42:1 against the light canvas —
        // heavier than the card it sits above and heavier than the platform's
        // own 1.28:1 — while in dark it measures 1.07:1, which is no fill at
        // all. One role, two opposite failures, and the recess only ever
        // existed in one theme.
        //
        // `surface` is 1.21:1 light and 1.26:1 dark: the same control in both,
        // at the weight the platform uses. The outline still carries the
        // boundary SC 1.4.11 asks for — 3.38:1 light, 3.17:1 dark, both over
        // `ds_text_field_test`'s C-5 floor of 2.7.
        fieldStyle: DSTextFieldStyle.resolve(context, null),
        leadingIcon: Icons.search,
        clearIcon: Icons.close,
        iconSize: component.iconSizeSmall,
        chipGap: space.sm,
        barToChips: space.sm,
        // Gains tabular figures with the role: the result count is redrawn on
        // every keystroke, and without them "9 results" and "10 results" are
        // different widths, so the line jumps as the reader types.
        countStyle: DSTextRole.caption.styleOf(context),
        suggestionHeight: component.minTapTarget,
        debounce: design.motion.scaled(design.motion.normal),
      ),
      own: own,
    );
  }
}

/// The field a query is typed into, and the row of chips that scopes it.
///
/// See `docs/plans/26-ds-search-bar.plan.md`. **Controlled**: the caller owns
/// [value]. The bar used to hold a private `TextEditingController`, which made
/// a deep-linked query, a filter reset, a restored session and reading the
/// text without waiting for the debounce all impossible — four normal search
/// screen requirements, ruled out by one field.
///
/// **Two callbacks, honestly named.** [onChanged] fires immediately with the
/// raw value; [onQueryChanged] fires once the typing has settled. One callback
/// with a hidden timer is what made the debounce invisible, and an invisible
/// debounce is indistinguishable from a broken search.
///
/// **Use when** the user is entering a query. **Instead:** `DSTextField` for a
/// form field, `DSSelect` for choosing from a known list, `DSChipGroup` for
/// filters with no query.
class DSSearchBar extends StatefulWidget {
  const DSSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onQueryChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.focusNode,
    this.hintText = 'Search',
    this.errorText,
    this.debounce,
    this.searching = false,
    this.enabled = true,
    this.autofocus = false,
    this.resultCount,
    this.leading,
    this.trailing,
    this.scopes,
    this.suggestions,
    this.footer,
    this.noResults,
    this.countSlot,
    this.style,
  });

  final String value;

  /// Immediate and raw, on every keystroke.
  final ValueChanged<String> onChanged;

  /// Debounced. Null means the caller does not want a settled callback.
  final ValueChanged<String>? onQueryChanged;

  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  /// Optional, for a caller who needs selection or composing-region control —
  /// the one thing [value] alone cannot express.
  final TextEditingController? controller;

  final FocusNode? focusNode;
  final String hintText;
  final String? errorText;
  final Duration? debounce;

  /// The query is in flight. A spinner replaces the clear button and the
  /// previous results stay on screen, because clearing the list on every
  /// keystroke makes a search flash, and flashing is what makes a fast search
  /// feel slow.
  final bool searching;

  final bool enabled;
  final bool autofocus;
  final int? resultCount;
  final Widget? leading;
  final Widget? trailing;

  /// The chip row that scopes the query. A slot on the bar rather than a
  /// widget the caller places underneath, because the two otherwise drift.
  final Widget? scopes;

  final Widget? suggestions;
  final Widget? footer;
  final Widget? noResults;
  final Widget? countSlot;
  final DSSearchBarStyle? style;

  @override
  State<DSSearchBar> createState() => _DSSearchBarState();
}

class _DSSearchBarState extends State<DSSearchBar> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.value);
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  final GlobalKey _anchor = GlobalKey();

  Timer? _debounce;
  bool _focused = false;
  bool _suggesting = false;
  int? _announcedCount;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DSSearchBar old) {
    super.didUpdateWidget(old);
    // The caller owns the value, so a value it did not type — a deep link, a
    // reset, a restored session — has to arrive in the field.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
    if (widget.resultCount != null &&
        widget.resultCount != _announcedCount &&
        !widget.searching) {
      _announcedCount = widget.resultCount;
      // Politely: a screen reader user learns the search returned something
      // without focus moving out from under them.
      SemanticsService.sendAnnouncement(
        View.of(context),
        _countLabel(widget.resultCount!),
        Directionality.of(context),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _focus.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  String _countLabel(int count) => count == 1 ? '1 result' : '$count results';

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focus.hasFocus);
    if (_focus.hasFocus) {
      _openSuggestions();
    }
  }

  /// The suggestions surface is plan 17's popover, anchored to the bar — not a
  /// fourth overlay mechanism.
  Future<void> _openSuggestions() async {
    if (_suggesting || widget.suggestions == null || !widget.enabled) return;
    _suggesting = true;
    await showDSOverlay<void>(
      context: context,
      anchor: _anchor,
      presentation: DSOverlayPresentation.popover,
      barrierDismissible: true,
      semanticLabel: 'Search suggestions',
      builder: (context) => DSOverlaySurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: widget.suggestions!),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
    _suggesting = false;
  }

  void _handleChanged(String value) {
    widget.onChanged(value);
    final settle = widget.debounce ?? _resolvedDebounce;
    _debounce?.cancel();
    if (widget.onQueryChanged == null) return;
    if (settle == Duration.zero) {
      widget.onQueryChanged!(value);
      return;
    }
    _debounce = Timer(settle, () => widget.onQueryChanged?.call(value));
  }

  Duration get _resolvedDebounce =>
      DSSearchBarStyle.resolve(context, widget.style).debounce!;

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    widget.onQueryChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSSearchBarStyle.resolve(context, widget.style);
    final field = resolved.fieldStyle!;
    final space = context.design.space;
    final palette = context.palette;
    final enabled = widget.enabled && (DSScope.enabledOf(context) ?? true);
    final (outline, width) = DSFieldBox.outlineFor(
      field,
      enabled: enabled,
      focused: _focused,
      hasError: widget.errorText != null,
    );

    // One box and one node for the two things that live in the trailing slot,
    // so focus does not move out from under a user mid-query when the spinner
    // replaces the clear button.
    //
    // The slot is only as wide as what it holds. Reserved unconditionally it
    // was a full tap target of dead width inside every *empty* search field —
    // 48dp, 62dp with the field's own right inset — which is width the query
    // should have had, and which pushed the text off centre in any field
    // narrower than the page.
    final target = context.design.component.minTapTarget;
    final occupied = widget.searching || widget.value.isNotEmpty;
    final Widget affordance = occupied
        ? SizedBox(
            width: target,
            height: target,
            child: AnimatedSwitcher(
              duration: context.design.motion.scaled(
                context.design.motion.fast,
              ),
              child: widget.searching
                  ? Semantics(
                      container: true,
                      label: 'Searching',
                      liveRegion: true,
                      child: const Center(
                        child: DSProgressIndicator.circular(),
                      ),
                    )
                  : DSIconButton(
                      icon: resolved.clearIcon!,
                      semanticLabel: 'Clear search',
                      onPressed: enabled ? _clear : null,
                    ),
            ),
          )
        // Height only. With no width and no child the box takes the smallest
        // the row will give it, which is nothing — and the height is what
        // holds the field open at the tap target while the slot is empty.
        : SizedBox(height: target);

    final Widget bar = DSFieldBox(
      key: _anchor,
      style: field,
      outlineColor: outline,
      outlineWidth: width,
      enabled: enabled,
      onTap: () => DSFieldBox.focusInput(_focus),
      children: [
        widget.leading ??
            Icon(
              resolved.leadingIcon,
              size: resolved.iconSize,
              color: palette.mutedForeground,
            ),
        SizedBox(width: space.sm),
        Expanded(
          // The name goes on the field's own node. `hintText` is placeholder
          // text, which a screen reader stops reading the moment a character
          // is typed — so a bar named only by its hint is anonymous exactly
          // when the user is using it.
          // Sized to the box rather than to the glyphs: a dense field's own
          // node is the height of one line of text, so the bar announced a
          // 25-point tap target inside a 48-point control.
          //
          // The box is the *node*'s height, not the input's. Handed straight
          // to the field it became the decoration's height too, and a
          // collapsed decoration lays its input out at the top of whatever
          // height it is given — `textAlignVertical` has nothing to centre
          // inside once there is no decoration left. One line of text sat
          // 11.5dp above the centre of a 48dp box, which is a point of air
          // over it and twenty-three under it, and the leading icon — which
          // *is* centred — visibly failed to line up with the text beside it.
          // Aligning inside the box keeps both: the node is the box, the
          // input is centred in it.
          child: MergeSemantics(
            child: Semantics(
              container: true,
              label: widget.hintText,
              child: SizedBox(
                height: field.height,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  // ui-lint: allow raw-text-field — DSTextField is a field
                  // *and* its container: a label above, a helper line below,
                  // an outline and a height contract. The search bar is the
                  // container here — it owns the box, the fill, the leading
                  // glyph and the clear affordance — so the input inside it
                  // is a collapsed, borderless one. Nesting the component
                  // would draw a second field inside the first.
                  child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    controller: _controller,
                    focusNode: _focus,
                    enabled: enabled,
                    autofocus: widget.autofocus,
                    style: field.textStyle,
                    textInputAction: TextInputAction.search,
                    onChanged: _handleChanged,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      isDense: true,
                      // The box owns the fill. Without this the field inherits
                      // the global `inputDecorationTheme`'s `filled: true` and
                      // paints a second, inner fill over the box's — which was
                      // invisible only for as long as the two happened to be
                      // the same colour, and is a rectangle sitting inside the
                      // control the moment they are not.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hintText,
                      hintStyle: field.hintStyle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.trailing ?? affordance,
      ],
    );

    final Widget? count =
        widget.countSlot ??
        (widget.resultCount == null
            ? null
            : Text(
                _countLabel(widget.resultCount!),
                style: resolved.countStyle,
              ));

    return DSScope.merge(
      context,
      enabled: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bar,
          if (widget.errorText != null) ...[
            SizedBox(height: space.xs),
            Text(
              widget.errorText!,
              style: field.helperStyle?.copyWith(color: field.errorOutline),
            ),
          ],
          if (widget.scopes != null) ...[
            SizedBox(height: resolved.barToChips),
            widget.scopes!,
          ],
          if (count != null) ...[SizedBox(height: space.sm), count],
          if (widget.noResults != null &&
              widget.resultCount == 0 &&
              !widget.searching)
            widget.noResults!
          else if (widget.resultCount == 0 &&
              !widget.searching &&
              widget.value.isNotEmpty)
            DSEmptyState.noResults(
              query: widget.value,
              actionLabel: 'Clear search',
              onAction: _clear,
            ),
        ],
      ),
    );
  }
}

/// The chip row that scopes a query.
///
/// A `DSChipGroup` at the small size, so the chips beside a field are not the
/// same weight as the chips in the content under it.
class DSSearchScopes extends StatelessWidget {
  const DSSearchScopes({
    super.key,
    required this.children,
    this.mode = DSChipSelectionMode.single,
  });

  final List<Widget> children;
  final DSChipSelectionMode mode;

  @override
  Widget build(BuildContext context) => DSScope.merge(
    context,
    size: DSSize.sm,
    child: DSChipGroup(selectionMode: mode, children: children),
  );
}

/// A completion offered while typing.
class DSSearchSuggestion extends StatelessWidget {
  const DSSearchSuggestion({
    super.key,
    required this.label,
    required this.onPressed,
    this.highlight,
    this.icon,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback onPressed;

  /// The matched substring, emphasised in place. A suggestion list that does
  /// not show *why* a row matched reads as a list of unrelated words.
  final String? highlight;

  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final base = DSTextRole.body.styleOf(context);
    final match = highlight == null
        ? -1
        : label.toLowerCase().indexOf(highlight!.toLowerCase());

    return DSListTile(
      title: label,
      titleSlot: match < 0
          ? null
          : Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(text: label.substring(0, match)),
                  TextSpan(
                    text: label.substring(match, match + highlight!.length),
                    style: DSTextRole.body.styleOf(context, emphasis: true),
                  ),
                  TextSpan(text: label.substring(match + highlight!.length)),
                ],
              ),
            ),
      leading: leading ?? (icon == null ? null : Icon(icon)),
      trailing: trailing,
      onTap: onPressed,
      style: const DSListTileStyle(chevron: false),
    );
  }
}

/// A query the user ran before.
class DSSearchRecent extends StatelessWidget {
  const DSSearchRecent({
    super.key,
    required this.label,
    required this.onPressed,
    this.onRemove,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => DSListTile(
    title: label,
    leading: const Icon(Icons.history),
    onTap: onPressed,
    style: const DSListTileStyle(chevron: false),
    trailing: onRemove == null
        ? null
        : DSIconButton(
            icon: Icons.close,
            semanticLabel: 'Remove $label from recent searches',
            onPressed: onRemove,
          ),
  );
}
