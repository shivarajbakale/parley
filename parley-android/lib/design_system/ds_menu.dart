// ds-tier: 2 — molecule

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_icon_button.dart';
import 'package:parley_android/design_system/ds_overlay.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// [DSMenu]'s appearance, as data.
@immutable
class DSMenuStyle extends DSComponentStyle<DSMenuStyle> {
  const DSMenuStyle({
    this.minWidth,
    this.maxWidth,
    this.itemHeight,
    this.itemPadding,
    this.iconSize,
    this.iconGap,
    this.labelStyle,
    this.shortcutStyle,
    this.sectionStyle,
    this.separatorColor,
    this.maxVisibleItems,
    this.showIcons,
  });

  final double? minWidth;
  final double? maxWidth;
  final double? itemHeight;
  final EdgeInsetsGeometry? itemPadding;
  final double? iconSize;
  final double? iconGap;
  final TextStyle? labelStyle;
  final TextStyle? shortcutStyle;
  final TextStyle? sectionStyle;
  final Color? separatorColor;

  /// A menu shows eight rows before it scrolls where a select shows six. A
  /// menu that scrolls is usually a menu that should have had sections.
  final int? maxVisibleItems;

  /// Icon-free menus are a legitimate house style and were unreachable.
  final bool? showIcons;

  @override
  DSMenuStyle merge(DSMenuStyle? other) {
    if (other == null) return this;
    return DSMenuStyle(
      minWidth: other.minWidth ?? minWidth,
      maxWidth: other.maxWidth ?? maxWidth,
      itemHeight: other.itemHeight ?? itemHeight,
      itemPadding: other.itemPadding ?? itemPadding,
      iconSize: other.iconSize ?? iconSize,
      iconGap: other.iconGap ?? iconGap,
      labelStyle: other.labelStyle ?? labelStyle,
      shortcutStyle: other.shortcutStyle ?? shortcutStyle,
      sectionStyle: other.sectionStyle ?? sectionStyle,
      separatorColor: other.separatorColor ?? separatorColor,
      maxVisibleItems: other.maxVisibleItems ?? maxVisibleItems,
      showIcons: other.showIcons ?? showIcons,
    );
  }

  @override
  DSMenuStyle copyWith({
    double? minWidth,
    double? maxWidth,
    double? itemHeight,
    EdgeInsetsGeometry? itemPadding,
    double? iconSize,
    double? iconGap,
    TextStyle? labelStyle,
    TextStyle? shortcutStyle,
    TextStyle? sectionStyle,
    Color? separatorColor,
    int? maxVisibleItems,
    bool? showIcons,
  }) => DSMenuStyle(
    minWidth: minWidth ?? this.minWidth,
    maxWidth: maxWidth ?? this.maxWidth,
    itemHeight: itemHeight ?? this.itemHeight,
    itemPadding: itemPadding ?? this.itemPadding,
    iconSize: iconSize ?? this.iconSize,
    iconGap: iconGap ?? this.iconGap,
    labelStyle: labelStyle ?? this.labelStyle,
    shortcutStyle: shortcutStyle ?? this.shortcutStyle,
    sectionStyle: sectionStyle ?? this.sectionStyle,
    separatorColor: separatorColor ?? this.separatorColor,
    maxVisibleItems: maxVisibleItems ?? this.maxVisibleItems,
    showIcons: showIcons ?? this.showIcons,
  );

  @override
  DSMenuStyle lerp(DSMenuStyle? other, double t) {
    if (other == null) return this;
    return DSMenuStyle(
      minWidth: lerpDouble(minWidth, other.minWidth, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      itemHeight: lerpDouble(itemHeight, other.itemHeight, t),
      itemPadding: EdgeInsetsGeometry.lerp(itemPadding, other.itemPadding, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      iconGap: lerpDouble(iconGap, other.iconGap, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      shortcutStyle: TextStyle.lerp(shortcutStyle, other.shortcutStyle, t),
      sectionStyle: TextStyle.lerp(sectionStyle, other.sectionStyle, t),
      separatorColor: Color.lerp(separatorColor, other.separatorColor, t),
      maxVisibleItems: t < 0.5 ? maxVisibleItems : other.maxVisibleItems,
      showIcons: t < 0.5 ? showIcons : other.showIcons,
    );
  }

  static DSMenuStyle resolve(BuildContext context, [DSMenuStyle? own]) {
    final design = context.design;
    final palette = context.palette;
    final type = Theme.of(context).textTheme;

    final specDefaults = DSMenuStyle(
      minWidth: design.component.menuMinWidth,
      maxWidth: design.component.menuMaxWidth,
      itemHeight: design.component.minTapTarget,
      itemPadding: EdgeInsets.symmetric(horizontal: design.space.md),
      iconSize: design.component.iconSizeInline,
      iconGap: design.space.sm,
      labelStyle: type.bodyMedium,
      shortcutStyle: type.labelSmall
          ?.copyWith(color: palette.mutedForeground)
          .tabular,
      sectionStyle: type.labelSmall?.copyWith(color: palette.mutedForeground),
      separatorColor: palette.borderSoft,
      maxVisibleItems: 8,
      showIcons: true,
    );

    return resolveStyle<DSMenuStyle>(
      context: context,
      specDefaults: specDefaults,
      own: own,
    );
  }
}

/// What every row inside a menu reads.
@immutable
class DSMenuScope extends InheritedWidget {
  const DSMenuScope({
    super.key,
    required this.style,
    required this.active,
    required this.register,
    required super.child,
  });

  final DSMenuStyle style;

  /// The row the keyboard is on.
  final int? active;

  /// Rows announce their index so the list can move between them without the
  /// list having to know what a caller's own item type is.
  final void Function(int index) register;

  static DSMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DSMenuScope>();

  static DSMenuStyle styleOf(BuildContext context) =>
      maybeOf(context)?.style ?? DSMenuStyle.resolve(context);

  @override
  bool updateShouldNotify(DSMenuScope old) => old.active != active;
}

/// The shared geometry of a menu row: height, padding, glyph, label, and the
/// trailing column a shortcut or a check goes in.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.leading,
    this.trailing,
    this.labelSlot,
    this.shortcut,
    this.reason,
    this.color,
    this.active = false,
    this.flash = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;
  final String? shortcut;
  final String? reason;
  final Color? color;
  final bool active;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    final palette = context.palette;
    final foreground =
        color ?? (enabled ? palette.foreground : palette.mutedForeground);

    // A full-bleed row deliberately does not dip — a row that shrinks away
    // from its neighbours detaches from the column it belongs to, and a row is
    // pressed by lighting up, which is the same call `DSListTile` documents.
    // `enabled: false` switches off the scale and nothing else: the ring is
    // unconditional, and skipping DSPressable entirely to avoid the dip is
    // what left every item in this menu with no focus ring at all.
    return DSPressable(
      enabled: false,
      focusShape: const RoundedRectangleBorder(),
      child: DSInkSurface(
        onTap: enabled ? onTap : null,
        tint: active || flash ? palette.secondary : null,
        minTapTarget: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: style.itemHeight!),
          child: Padding(
            padding: style.itemPadding!,
            child: Row(
              children: [
                if (style.showIcons! && (leading != null || icon != null)) ...[
                  leading ??
                      Icon(icon, size: style.iconSize, color: foreground),
                  SizedBox(width: style.iconGap!),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      labelSlot ??
                          Text(
                            label,
                            style: style.labelStyle?.copyWith(
                              color: foreground,
                            ),
                          ),
                      if (reason != null)
                        Text(reason!, style: style.shortcutStyle),
                    ],
                  ),
                ),
                if (shortcut != null) ...[
                  SizedBox(width: context.design.space.md),
                  Text(shortcut!, style: style.shortcutStyle),
                ],
                if (trailing != null) ...[
                  SizedBox(width: style.iconGap!),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A command. Runs, and closes the menu.
class DSMenuItem extends StatefulWidget {
  const DSMenuItem({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.shortcut,
    this.disabledReason,
    this.tone = DSTone.neutral,
    this.leading,
    this.trailing,
    this.labelSlot,
  });

  final String label;

  /// Null disables the item, which is the convention every control in the kit
  /// shares.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// The keyboard shortcut, right-aligned. A desktop build that shows `⌘⌫`
  /// beside "Delete" teaches the shortcut; the closed item model this
  /// replaces had nowhere to put one.
  final String? shortcut;

  /// Why this item cannot be run. A greyed item with no reason is one the
  /// user taps again.
  final String? disabledReason;

  final DSTone tone;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;

  @override
  State<DSMenuItem> createState() => _DSMenuItemState();
}

class _DSMenuItemState extends State<DSMenuItem> {
  bool _flash = false;

  Future<void> _run() async {
    // The highlight is held for one beat before the menu goes. A menu that
    // vanishes on touch-down leaves the user unsure which item they hit.
    setState(() => _flash = true);
    await Future<void>.delayed(context.design.motion.instant);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = widget.onPressed != null;
    final index = _DSMenuIndex.of(context);
    final active = DSMenuScope.maybeOf(context)?.active == index;

    return Semantics(
      role: SemanticsRole.menuItem,
      enabled: enabled,
      // The reason is part of the name. A disabled control a screen reader
      // cannot discover the reason for is a control it cannot explain.
      label: widget.disabledReason == null || enabled
          ? widget.label
          : '${widget.label}, ${widget.disabledReason}',
      child: ExcludeSemantics(
        child: _MenuRow(
          label: widget.label,
          enabled: enabled,
          onTap: _run,
          icon: widget.icon,
          leading: widget.leading,
          trailing: widget.trailing,
          labelSlot: widget.labelSlot,
          shortcut: widget.shortcut,
          reason: enabled ? null : widget.disabledReason,
          color: widget.tone == DSTone.error && enabled
              ? palette.destructive
              : null,
          active: active,
          flash: _flash,
        ),
      ),
    );
  }
}

/// A toggle. Stays open, which is the whole point of it: turning on three
/// view options should not mean opening the menu three times.
class DSMenuCheckItem extends StatelessWidget {
  const DSMenuCheckItem({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.shortcut,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    final palette = context.palette;
    final index = _DSMenuIndex.of(context);
    final active = DSMenuScope.maybeOf(context)?.active == index;

    return Semantics(
      role: SemanticsRole.menuItemCheckbox,
      checked: value,
      label: label,
      child: ExcludeSemantics(
        child: _MenuRow(
          label: label,
          enabled: true,
          onTap: () => onChanged(!value),
          icon: icon,
          shortcut: shortcut,
          active: active,
          trailing: AnimatedOpacity(
            opacity: value ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : context.design.motion.fast,
            child: Icon(
              Icons.check,
              size: style.iconSize,
              color: palette.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of a group. Picks, and closes.
class DSMenuRadioItem<T> extends StatelessWidget {
  const DSMenuRadioItem({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    final palette = context.palette;
    final selected = value == groupValue;
    final index = _DSMenuIndex.of(context);
    final active = DSMenuScope.maybeOf(context)?.active == index;

    return Semantics(
      role: SemanticsRole.menuItemRadio,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: ExcludeSemantics(
        child: _MenuRow(
          label: label,
          enabled: true,
          icon: icon,
          active: active,
          onTap: () {
            Navigator.of(context).maybePop();
            onChanged(value);
          },
          trailing: selected
              ? Icon(Icons.check, size: style.iconSize, color: palette.primary)
              : null,
        ),
      ),
    );
  }
}

/// A non-selectable label over a group of items.
class DSMenuSection extends StatelessWidget {
  const DSMenuSection({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    return Semantics(
      header: true,
      child: Container(
        height: context.design.space.xxl,
        padding: style.itemPadding!,
        alignment: AlignmentDirectional.centerStart,
        child: Text(label, style: style.sectionStyle),
      ),
    );
  }
}

/// A hairline between groups.
// ds-tier: 1 — atom — A hairline between two groups of menu items.
class DSMenuSeparator extends StatelessWidget {
  const DSMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    return ExcludeSemantics(
      child: DSDivider(style: DSDividerStyle(color: style.separatorColor)),
    );
  }
}

/// The row a menu draws while its items are still arriving — a menu of a
/// document's collaborators is exactly this.
class DSMenuItemSkeleton extends StatelessWidget {
  const DSMenuItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final style = DSMenuScope.styleOf(context);
    return DSSkeleton(
      child: SizedBox(
        height: style.itemHeight!,
        child: Padding(
          padding: style.itemPadding!,
          child: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('An action'),
          ),
        ),
      ),
    );
  }
}

/// A nested menu. Declared so the API does not have to change when it lands,
/// and deferred so that its hover intent, flip logic and nested focus model
/// are designed rather than improvised.
class DSSubmenu extends StatelessWidget {
  const DSSubmenu({super.key, required this.label, required this.items});

  final String label;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    assert(
      false,
      'DSSubmenu is declared and deferred: nested menus need their own hover '
      'intent, flip logic and focus model, and shipping a half-built one is '
      'worse than not having it. Use a DSMenuSection, or a second menu.',
    );
    return const SizedBox.shrink();
  }
}

/// Carries a row's position in the menu down to the row.
class _DSMenuIndex extends InheritedWidget {
  const _DSMenuIndex({required this.index, required super.child});

  final int index;

  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DSMenuIndex>()?.index;

  @override
  bool updateShouldNotify(_DSMenuIndex old) => old.index != index;
}

/// The surface a menu's items are drawn on, with its keyboard model.
class DSMenuSurface extends StatefulWidget {
  const DSMenuSurface({
    super.key,
    required this.items,
    this.header,
    this.footer,
    this.loading = false,
    this.style,
  });

  final List<Widget> items;
  final Widget? header;
  final Widget? footer;
  final bool loading;
  final DSMenuStyle? style;

  @override
  State<DSMenuSurface> createState() => _DSMenuSurfaceState();
}

class _DSMenuSurfaceState extends State<DSMenuSurface> {
  final FocusNode _focus = FocusNode(debugLabel: 'DSMenu');
  int? _active;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The rows arrows move between: everything except a section header and a
  /// separator. A disabled item is included deliberately — focus that skips
  /// it is focus that hides it.
  List<int> get _navigable => [
    for (var i = 0; i < widget.items.length; i++)
      if (widget.items[i] is! DSMenuSection &&
          widget.items[i] is! DSMenuSeparator)
        i,
  ];

  void _move(int delta) {
    final rows = _navigable;
    if (rows.isEmpty) return;
    final current = rows.indexOf(_active ?? -1);
    final next = (current + delta).clamp(0, rows.length - 1);
    setState(() => _active = rows[next < 0 ? 0 : next]);
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
        setState(() => _active = _navigable.firstOrNull);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() => _active = _navigable.lastOrNull);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final style = DSMenuStyle.resolve(context, widget.style);

    // A danger item is placed as well as coloured: last, below a separator.
    // Encoding it as a tone the caller must remember to pair with a separator
    // produces menus that disagree with each other.
    assert(() {
      final lastSeparator = widget.items.lastIndexWhere(
        (item) => item is DSMenuSeparator,
      );
      for (var i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        if (item is DSMenuItem &&
            item.tone == DSTone.error &&
            i < lastSeparator) {
          throw FlutterError(
            'A destructive menu item must be in the final section, below the '
            'last DSMenuSeparator. "${item.label}" is above one, which is '
            'where a user reaches for it by accident.',
          );
        }
      }
      return true;
    }());

    final rows = widget.loading
        ? const <Widget>[
            DSMenuItemSkeleton(),
            DSMenuItemSkeleton(),
            DSMenuItemSkeleton(),
          ]
        : widget.items;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        role: SemanticsRole.menu,
        explicitChildNodes: true,
        child: DSMenuScope(
          style: style,
          active: _active,
          register: (_) {},
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: style.minWidth!,
              maxWidth: style.maxWidth!,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null) widget.header!,
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(
                      vertical: context.design.space.xs,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _DSMenuIndex(index: index, child: rows[index]),
                  ),
                ),
                if (widget.footer != null) widget.footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short list of actions anchored to the control that opened it.
///
/// A select chooses a value and reports it; a menu performs a command and
/// closes. They share a row and a surface and nothing else, which is why they
/// are two components with one geometry rather than one component with a
/// mode.
class DSMenu extends StatefulWidget {
  const DSMenu({
    super.key,
    required this.items,
    required this.semanticLabel,
    this.trigger,
    this.triggerIcon = Icons.more_vert,
    this.tooltip,
    this.header,
    this.footer,
    this.loading = false,
    this.enabled = true,
    this.style,
  });

  final List<Widget> items;

  /// Required, per plan 13: a bare `⋮` is the canonical unlabelled control.
  final String semanticLabel;

  final Widget? trigger;
  final IconData triggerIcon;
  final String? tooltip;
  final Widget? header;
  final Widget? footer;
  final bool loading;
  final bool enabled;
  final DSMenuStyle? style;

  @override
  State<DSMenu> createState() => _DSMenuState();
}

class _DSMenuState extends State<DSMenu> {
  final GlobalKey _anchor = GlobalKey();
  bool _open = false;

  Future<void> _show() async {
    setState(() => _open = true);
    await showDSMenu<void>(
      context: context,
      anchor: _anchor,
      items: widget.items,
      header: widget.header,
      footer: widget.footer,
      loading: widget.loading,
      semanticLabel: widget.semanticLabel,
      style: widget.style,
    );
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.trigger;

    return Semantics(
      // The trigger states whether the menu is open, which is the half of
      // "name, role, value" a bare icon button leaves out.
      expanded: _open,
      child: KeyedSubtree(
        key: _anchor,
        child: trigger == null
            ? DSIconButton(
                icon: widget.triggerIcon,
                semanticLabel: widget.semanticLabel,
                tooltip: widget.tooltip,
                onPressed: widget.enabled ? _show : null,
              )
            : GestureDetector(
                onTap: widget.enabled ? _show : null,
                child: trigger,
              ),
      ),
    );
  }
}

/// Presents a menu anchored to [anchor], for a menu opened from a gesture
/// rather than from [DSMenu]'s own trigger.
Future<T?> showDSMenu<T>({
  required BuildContext context,
  required GlobalKey anchor,
  required List<Widget> items,
  String? semanticLabel,
  Widget? header,
  Widget? footer,
  bool loading = false,
  DSMenuStyle? style,
}) {
  final resolved = DSMenuStyle.resolve(context, style);
  return showDSOverlay<T>(
    context: context,
    anchor: anchor,
    presentation: DSOverlayPresentation.menu,
    semanticLabel: semanticLabel,
    maxHeight: resolved.itemHeight! * resolved.maxVisibleItems!,
    builder: (context) {
      final surface = DSMenuSurface(
        items: items,
        header: header,
        footer: footer,
        loading: loading,
        style: style,
      );
      // Below the responsive breakpoint the same content is a sheet, and a
      // sheet is full width — the menu's own 200..320 constraint would leave
      // it floating in the middle of one.
      final presentation = resolveDSPresentation(
        context,
        DSOverlayPresentation.menu,
      );
      return DSOverlaySurface(
        presentation: presentation,
        showDragHandle: presentation == DSOverlayPresentation.sheet,
        child: surface,
      );
    },
  );
}
