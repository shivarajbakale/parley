// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:parley_android/theme/app_choice_label.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_text_style.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Which of the two shipped indicators the bar draws.
///
/// Renamed from `DSTabBarVariant` because that is what it selects, and because
/// "variant" was already doing four different jobs across the kit before plans
/// 08, 11 and 14 narrowed it.
enum DSTabIndicatorStyle {
  /// A rule under the label, on the page ground. Reads as navigation, and is
  /// the default for a screen's primary tabs.
  underline,

  /// A raised slot on a well track. Reads as a control, and belongs inside a
  /// card or a sheet.
  pill,
}

/// How the tabs divide the row.
enum DSTabLayout {
  /// Fixed when the tabs fit, scrollable when they do not.
  ///
  /// The default, and the only setting that is correct at every text scale and
  /// in every locale — a boolean made the caller predict at build time whether
  /// five labels fit on the narrowest device in the longest translation, which
  /// they cannot.
  auto,

  /// Equal widths, all visible.
  fixed,

  /// Content widths, the row scrolls, and the selected tab scrolls into view.
  scrollable,
}

/// Whether the underline spans the label or the whole tab.
enum DSTabIndicatorWidth { label, tab }

/// How a tab bar looks, at every layer of the resolution chain.
@immutable
class DSTabBarStyle extends DSComponentStyle<DSTabBarStyle> {
  const DSTabBarStyle({
    this.height,
    this.tabPadding,
    this.minTabWidth,
    this.labelStyle,
    this.selectedLabelStyle,
    this.indicatorHeight,
    this.indicatorColor,
    this.indicatorWidth,
    this.trackFill,
    this.pillFill,
    this.pillShadows,
    this.showBaseline,
    this.baselineColor,
    this.edgeFadeWidth,
    this.iconSize,
    this.countStyle,
    this.travelSpring,
    this.disabledOpacity,
  });

  final double? height;
  final EdgeInsetsGeometry? tabPadding;
  final double? minTabWidth;
  final TextStyle? labelStyle;

  /// Weight as well as colour, per the M-4 rule: three channels carry the
  /// selection — the indicator, the colour and the weight — and the
  /// unselected label is the one that fails on the dark theme when colour is
  /// asked to carry it alone.
  final TextStyle? selectedLabelStyle;

  final double? indicatorHeight;
  final Color? indicatorColor;
  final DSTabIndicatorWidth? indicatorWidth;

  /// The pill variant's track and slot. The *same* two roles
  /// `DSSegmentedButton` reads: two controls that look identical must not have
  /// two sources for their colours.
  final Color? trackFill;
  final Color? pillFill;
  final List<BoxShadow>? pillShadows;

  final bool? showBaseline;
  final Color? baselineColor;

  /// The fade over an overflowing edge. Without it a scrollable row reads as
  /// ending where the screen does.
  final double? edgeFadeWidth;

  final double? iconSize;
  final TextStyle? countStyle;
  final SpringDescription? travelSpring;
  final double? disabledOpacity;

  @override
  DSTabBarStyle merge(DSTabBarStyle? other) {
    if (other == null) return this;
    return DSTabBarStyle(
      height: other.height ?? height,
      tabPadding: other.tabPadding ?? tabPadding,
      minTabWidth: other.minTabWidth ?? minTabWidth,
      labelStyle: other.labelStyle ?? labelStyle,
      selectedLabelStyle: other.selectedLabelStyle ?? selectedLabelStyle,
      indicatorHeight: other.indicatorHeight ?? indicatorHeight,
      indicatorColor: other.indicatorColor ?? indicatorColor,
      indicatorWidth: other.indicatorWidth ?? indicatorWidth,
      trackFill: other.trackFill ?? trackFill,
      pillFill: other.pillFill ?? pillFill,
      pillShadows: other.pillShadows ?? pillShadows,
      showBaseline: other.showBaseline ?? showBaseline,
      baselineColor: other.baselineColor ?? baselineColor,
      edgeFadeWidth: other.edgeFadeWidth ?? edgeFadeWidth,
      iconSize: other.iconSize ?? iconSize,
      countStyle: other.countStyle ?? countStyle,
      travelSpring: other.travelSpring ?? travelSpring,
      disabledOpacity: other.disabledOpacity ?? disabledOpacity,
    );
  }

  @override
  DSTabBarStyle copyWith({
    double? height,
    EdgeInsetsGeometry? tabPadding,
    double? minTabWidth,
    TextStyle? labelStyle,
    TextStyle? selectedLabelStyle,
    double? indicatorHeight,
    Color? indicatorColor,
    DSTabIndicatorWidth? indicatorWidth,
    Color? trackFill,
    Color? pillFill,
    List<BoxShadow>? pillShadows,
    bool? showBaseline,
    Color? baselineColor,
    double? edgeFadeWidth,
    double? iconSize,
    TextStyle? countStyle,
    SpringDescription? travelSpring,
    double? disabledOpacity,
  }) => DSTabBarStyle(
    height: height ?? this.height,
    tabPadding: tabPadding ?? this.tabPadding,
    minTabWidth: minTabWidth ?? this.minTabWidth,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedLabelStyle: selectedLabelStyle ?? this.selectedLabelStyle,
    indicatorHeight: indicatorHeight ?? this.indicatorHeight,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    indicatorWidth: indicatorWidth ?? this.indicatorWidth,
    trackFill: trackFill ?? this.trackFill,
    pillFill: pillFill ?? this.pillFill,
    pillShadows: pillShadows ?? this.pillShadows,
    showBaseline: showBaseline ?? this.showBaseline,
    baselineColor: baselineColor ?? this.baselineColor,
    edgeFadeWidth: edgeFadeWidth ?? this.edgeFadeWidth,
    iconSize: iconSize ?? this.iconSize,
    countStyle: countStyle ?? this.countStyle,
    travelSpring: travelSpring ?? this.travelSpring,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
  );

  @override
  DSTabBarStyle lerp(DSTabBarStyle? other, double t) {
    if (other == null) return this;
    return DSTabBarStyle(
      // Three fields with no midpoint.
      indicatorWidth: t < 0.5 ? indicatorWidth : other.indicatorWidth,
      showBaseline: t < 0.5 ? showBaseline : other.showBaseline,
      travelSpring: t < 0.5 ? travelSpring : other.travelSpring,
      height: lerpDouble(height, other.height, t),
      tabPadding: EdgeInsetsGeometry.lerp(tabPadding, other.tabPadding, t),
      minTabWidth: lerpDouble(minTabWidth, other.minTabWidth, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      selectedLabelStyle: TextStyle.lerp(
        selectedLabelStyle,
        other.selectedLabelStyle,
        t,
      ),
      indicatorHeight: lerpDouble(indicatorHeight, other.indicatorHeight, t),
      indicatorColor: Color.lerp(indicatorColor, other.indicatorColor, t),
      trackFill: Color.lerp(trackFill, other.trackFill, t),
      pillFill: Color.lerp(pillFill, other.pillFill, t),
      pillShadows: BoxShadow.lerpList(pillShadows, other.pillShadows, t),
      baselineColor: Color.lerp(baselineColor, other.baselineColor, t),
      edgeFadeWidth: lerpDouble(edgeFadeWidth, other.edgeFadeWidth, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      countStyle: TextStyle.lerp(countStyle, other.countStyle, t),
      disabledOpacity: lerpDouble(disabledOpacity, other.disabledOpacity, t),
    );
  }

  static DSTabBarStyle resolve(
    BuildContext context, [
    DSTabIndicatorStyle indicator = DSTabIndicatorStyle.underline,
    DSTabBarStyle? own,
  ]) {
    final design = context.design;
    final component = design.component;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final pill = indicator == DSTabIndicatorStyle.pill;

    return resolveStyle(
      context: context,
      specDefaults: DSTabBarStyle(
        // Both flavours are the floor tall. The pill used to be
        // `controlHeight + trackInset * 2` with the inset spent as padding on
        // the track, which left every tab 42 — six points under the floor the
        // same spec declares. The inset is now spent by the indicator, which
        // paints the same 42-point pill inside a tab that is a target.
        height: pill ? component.minTapTarget : component.tabHeight,
        tabPadding: EdgeInsets.symmetric(horizontal: space.md),
        minTabWidth: component.minTabWidth,
        labelStyle: text.labelLarge?.copyWith(color: palette.mutedForeground),
        selectedLabelStyle: text.labelLarge?.copyWith(
          color: pill ? palette.foreground : palette.primary,
          fontWeight: context.design.type.emphasisWeight,
        ),
        indicatorHeight: component.tabIndicatorHeight,
        indicatorColor: palette.primary,
        indicatorWidth: DSTabIndicatorWidth.label,
        trackFill: palette.muted,
        pillFill: palette.chrome,
        pillShadows: design.elevation.resolve(
          elevation: design.elevation.levelOf(DSElevation.low),
          brightness: palette.brightness,
          shadowColor: palette.overlay,
        ),
        showBaseline: !pill,
        baselineColor: palette.borderSoft,
        edgeFadeWidth: component.edgeFadeWidth,
        iconSize: component.iconSizeInline,
        countStyle: DSTextRole.caption.styleOf(context),
        travelSpring: design.motion.gentle,
        disabledOpacity: 0.38,
      ),
      own: own,
    );
  }
}

/// How the selected tab is marked.
///
/// The strategy the two shipped indicators implement, and the seam a house
/// indicator — a dot, a full-bleed fill, a bracket — plugs into. It exists
/// because `_PillTabBar` and `_UnderlineTabBar` were two 125-line widgets that
/// shared nothing but the item model and had already begun to disagree; as a
/// strategy each is about thirty lines and everything else is written once.
///
/// [labelRects] is passed alongside [tabRects] rather than derived from it,
/// which the plan's sketch of this interface did not anticipate: an underline
/// that spans the *label* rather than the tab cannot be drawn from the tab's
/// rectangle alone.
abstract class DSTabIndicator {
  const DSTabIndicator();

  void paint(
    Canvas canvas,
    Size size,
    List<Rect> tabRects,
    List<Rect> labelRects,
    double fraction,
    DSTabBarStyle style,
  );
}

/// A rounded rule under the selected label.
// ds-tier: 1 — atom — The same, as a line under the label.
class DSUnderlineIndicator extends DSTabIndicator {
  const DSUnderlineIndicator();

  @override
  void paint(
    Canvas canvas,
    Size size,
    List<Rect> tabRects,
    List<Rect> labelRects,
    double fraction,
    DSTabBarStyle style,
  ) {
    final rects = style.indicatorWidth == DSTabIndicatorWidth.label
        ? labelRects
        : tabRects;
    final rect = _lerpRect(rects, fraction);
    if (rect == null) return;
    final height = style.indicatorHeight!;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(rect.left, size.height - height, rect.width, height),
        topLeft: Radius.circular(height),
        topRight: Radius.circular(height),
      ),
      Paint()..color = style.indicatorColor!,
    );
  }
}

/// A raised slot behind the selected tab.
// ds-tier: 1 — atom — The shape that follows the selected tab. It paints one rounded rectangle.
class DSPillIndicator extends DSTabIndicator {
  const DSPillIndicator({required this.shape, required this.inset});

  final OutlinedBorder shape;

  /// How far the pill sits inside the tab it marks.
  ///
  /// Vertical only: horizontally the pill is the tab, and a slot narrower than
  /// the label it holds reads as a misplaced pill rather than as an inset one.
  /// This used to be padding on the track, which inset the *tab* — and a tab
  /// is a target, so the inset came out of the one dimension that has a floor.
  final double inset;

  @override
  void paint(
    Canvas canvas,
    Size size,
    List<Rect> tabRects,
    List<Rect> labelRects,
    double fraction,
    DSTabBarStyle style,
  ) {
    final lerped = _lerpRect(tabRects, fraction);
    if (lerped == null) return;
    final rect = Rect.fromLTRB(
      lerped.left,
      lerped.top + inset,
      lerped.right,
      lerped.bottom - inset,
    );
    final path = shape.getOuterPath(rect, textDirection: TextDirection.ltr);
    for (final shadow in style.pillShadows ?? const <BoxShadow>[]) {
      canvas.drawPath(
        path.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas.drawPath(path, Paint()..color = style.pillFill!);
  }
}

/// Where the indicator is when the travel is [fraction] of the way along.
Rect? _lerpRect(List<Rect> rects, double fraction) {
  if (rects.isEmpty) return null;
  final lower = fraction.floor().clamp(0, rects.length - 1);
  final upper = fraction.ceil().clamp(0, rects.length - 1);
  return Rect.lerp(rects[lower], rects[upper], (fraction - lower).clamp(0, 1));
}

/// What the bar tells the tabs inside it.
@immutable
class _DSTabScope extends InheritedWidget {
  const _DSTabScope({
    required this.style,
    required this.indicator,
    required this.selectedness,
    required this.selectedIndex,
    required this.count,
    required this.onSelect,
    required this.enabled,
    required this.report,
    required this.reportWanted,
    required super.child,
  });

  final DSTabBarStyle style;
  final DSTabIndicatorStyle indicator;
  final List<double> selectedness;
  final int selectedIndex;
  final int count;
  final ValueChanged<int> onSelect;
  final bool enabled;

  /// A tab hands back its own width and its label's width, which is what the
  /// indicator strategy is positioned from. It replaces the constructor
  /// threading both private implementations used to do by hand.
  final void Function(int index, double width, double labelWidth) report;

  /// What a tab would take if nothing squeezed it — the number the `auto`
  /// layout decision is made from.
  final void Function(int index, double wanted) reportWanted;

  static _DSTabScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DSTabScope>();
    assert(
      scope != null,
      'a DSTab outside a DSTabBar — a tab is a slot in a strip, and alone it '
      'has no indicator to move, no siblings to be exclusive with, and '
      'nothing to tell it what selecting it means',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_DSTabScope old) => true;
}

/// A row of labels that switches between sibling panels, keeping the user in
/// place.
///
/// See `docs/plans/25-ds-tab-bar.plan.md`. One implementation with an
/// indicator strategy, where there were two whole widgets sharing nothing but
/// an item model.
///
/// **Use when** the row changes *which panel is shown*. **Instead:**
/// `DSSegmentedButton` to switch a value in place, `DSBottomNavBar` for
/// top-level destinations, `DSChipGroup` for filters. A tab bar and a
/// segmented control are the two most confused components in any kit, and the
/// distinction is what they change, not what they look like.
///
/// **The controller is optional.** Paired with a `TabBarView` it syncs with a
/// `TabController` exactly as before, and the indicator follows a swipe
/// continuously rather than jumping on release. Driving your own `PageView` or
/// your own state, pass [index] and [onIndexChanged] and no controller —
/// which used to force a `StatefulWidget` with a `TickerProvider` for a row of
/// three labels.
class DSTabBar extends StatefulWidget {
  const DSTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.index,
    this.onIndexChanged,
    this.indicator = DSTabIndicatorStyle.underline,
    this.layout = DSTabLayout.auto,
    this.loading = false,
    this.indicatorDelegate,
    this.enabled = true,
    this.style,
  }) : assert(
         controller != null || index != null,
         'a DSTabBar needs either a TabController or an index — without one '
         'it has no way to know which tab is selected',
       );

  /// `List<Widget>`, not `List<DSTabItem>`: the same move plan 24 made for the
  /// segment, and for the same reason.
  final List<Widget> tabs;

  final TabController? controller;
  final int? index;
  final ValueChanged<int>? onIndexChanged;
  final DSTabIndicatorStyle indicator;
  final DSTabLayout layout;
  final bool loading;

  /// A house indicator. `underline` and `pill` are the two shipped
  /// implementations of the same interface.
  final DSTabIndicator? indicatorDelegate;

  final bool enabled;
  final DSTabBarStyle? style;

  @override
  State<DSTabBar> createState() => _DSTabBarState();
}

class _DSTabBarState extends State<DSTabBar>
    with SingleTickerProviderStateMixin {
  /// Drives the indicator when there is no controller to read a swipe from.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    value: 1,
  );

  final ScrollController _scroll = ScrollController();
  final List<double> _widths = [];
  final List<double> _labelWidths = [];

  /// What each tab would take if nothing squeezed it.
  ///
  /// Separate from [_widths] because they answer different questions and only
  /// one of them can answer the layout one. In the fixed row every tab is
  /// `Expanded`, so the width it reports is the width it was *given* — the
  /// slice sums to the row exactly, `fits` is true by construction, and `auto`
  /// could never decide to scroll however long the labels were. This is the
  /// width the tab asked for, which is the only number the decision can be
  /// made from.
  final List<double> _wanted = [];

  late double _from = _index.toDouble();
  late double _to = _from;
  bool _reducedMotion = false;

  int get _index => widget.controller?.index ?? widget.index ?? 0;

  double get _fraction {
    final animation = widget.controller?.animation;
    if (animation != null) return animation.value;
    return lerpDouble(_from, _to, _travel.value)!;
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.animation?.addListener(_onControllerTick);
    // Without a controller the indicator's whole position comes from
    // `_travel`, and an AnimationController nothing listens to ticks without
    // ever marking the bar dirty: the strip repainted only when some other
    // setState happened to land, which left the underline under the
    // previously selected tab.
    _travel.addListener(_onControllerTick);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final motion = context.design.motion;
    _travel.duration = motion.scaled(motion.fast);
  }

  @override
  void didUpdateWidget(covariant DSTabBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.animation?.removeListener(_onControllerTick);
      widget.controller?.animation?.addListener(_onControllerTick);
    }
    if (widget.controller != null) return;
    final target = _index.toDouble();
    if (target == _to) return;
    _from = _fraction;
    _to = target;
    _travel.value = 0;
    if (_reducedMotion) {
      _travel.value = 1;
    } else if (context.springsAvailable) {
      _travel.animateWith(context.design.motion.simulation(from: 0, to: 1));
    } else {
      _travel.animateTo(1, curve: context.design.motion.emphasize);
    }
    _ensureVisible(target.round());
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?.animation?.removeListener(_onControllerTick);
    _travel.removeListener(_onControllerTick);
    _scroll.dispose();
    _travel.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    AppHaptics.selection();
    widget.controller?.animateTo(index);
    widget.onIndexChanged?.call(index);
    _ensureVisible(index);
  }

  /// Scrolls the tab into view, with its neighbour beside it — and no
  /// further.
  ///
  /// Every tap used to be sent to `start - oneTabWidth`, which moved the
  /// strip whether or not the tab needed moving: on a 320pt screen the third
  /// of four tabs slid the row 55 points while the finger was still down, so
  /// the tab under the finger at release was not the tab that had been
  /// tapped. Tabs one and two, meanwhile, never moved at all, because that
  /// target clamped to zero. A tab already on screen with its neighbour
  /// beside it now stays where the reader put their finger.
  void _ensureVisible(int index) {
    if (!_scroll.hasClients || index >= _widths.length) return;
    final position = _scroll.position;
    var start = 0.0;
    for (var i = 0; i < index; i++) {
      start += _widths[i];
    }
    final end = start + _widths[index];
    final viewport = position.viewportDimension;

    // The peek is the neighbour on the side the strip would travel, so the
    // row never looks like it ends at the selected tab. Capped at a third of
    // the viewport, because revealing a neighbour wider than that would push
    // the tab that was tapped off the opposite edge.
    double peek(int neighbour) {
      final width = neighbour >= 0 && neighbour < _widths.length
          ? _widths[neighbour]
          : 0.0;
      return width.clamp(0.0, viewport / 3);
    }

    // A tab that is already whole on screen does not move, peek or no peek:
    // the peek buys a neighbour, and it is not worth moving the row the
    // reader is currently touching to buy one.
    final double wanted;
    if (start < _scroll.offset) {
      wanted = start - peek(index - 1);
    } else if (end > _scroll.offset + viewport) {
      wanted = end + peek(index + 1) - viewport;
    } else {
      return;
    }

    final target = wanted.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - _scroll.offset).abs() < precisionErrorTolerance) return;
    if (_reducedMotion) {
      _scroll.jumpTo(target);
    } else {
      final motion = context.design.motion;
      _scroll.animateTo(
        target,
        duration: motion.scaled(motion.normal),
        curve: motion.emphasize,
      );
    }
  }

  void _grow(int index) {
    while (_widths.length <= index) {
      _widths.add(0);
      _labelWidths.add(0);
      _wanted.add(0);
    }
  }

  void _reportWanted(int index, double wanted) {
    _grow(index);
    if (_wanted[index] == wanted) return;
    _wanted[index] = wanted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _report(int index, double width, double labelWidth) {
    _grow(index);
    if (_widths[index] == width && _labelWidths[index] == labelWidth) return;
    _widths[index] = width;
    _labelWidths[index] = labelWidth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _step(int by) {
    var next = _index + by;
    // A disabled tab is skipped by the arrows and still reachable by Tab —
    // the same rule plan 21 gives a disabled menu item.
    while (next >= 0 && next < widget.tabs.length && !_isEnabled(next)) {
      next += by;
    }
    if (next < 0 || next >= widget.tabs.length) return;
    _select(next);
  }

  bool _isEnabled(int index) {
    final tab = widget.tabs[index];
    return tab is! DSTab || tab.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = DSTabBarStyle.resolve(
      context,
      widget.indicator,
      widget.style,
    );
    final count = widget.tabs.length;
    if (widget.loading) {
      return DSTabBarSkeleton(tabs: count, indicator: widget.indicator);
    }

    final enabled = widget.enabled && (DSScope.enabledOf(context) ?? true);
    final fraction = _fraction;
    final selectedness = <double>[
      for (var i = 0; i < count; i++)
        (1 - (fraction - i).abs()).clamp(0.0, 1.0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = _wanted.fold<double>(0, (sum, w) => sum + w);
        final fits = total > 0 && total <= constraints.maxWidth;
        final scrollable = switch (widget.layout) {
          DSTabLayout.fixed => false,
          DSTabLayout.scrollable => true,
          // Measured, not predicted: whether five labels fit on the narrowest
          // device in the longest translation is not something a caller can
          // answer at build time, and a boolean asked them to.
          //
          // What is measured is what each tab *wants*. Measuring what it got
          // is measuring the constraint back: `Expanded` hands every tab an
          // equal slice, the slices sum to the row, and a row that fits by
          // construction is a row that scrolls never — six labels squeezed to
          // 53pt each and ellipsised, which is what the probe found.
          DSTabLayout.auto => _wanted.length == count && !fits,
        };

        final tabs = <Widget>[
          for (var i = 0; i < count; i++)
            _sized(i, scrollable, resolved, widget.tabs[i]),
        ];

        // The role sits on the row of tabs, not on the widget as a whole: a
        // scrollable strip puts a scroll node between the two, and Flutter
        // asserts that every direct child of a `tabBar` node is a `tab`.
        Widget row = Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          child: Row(
            mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
            children: tabs,
          ),
        );

        row = CustomPaint(
          painter: _IndicatorPainter(
            delegate:
                widget.indicatorDelegate ??
                (widget.indicator == DSTabIndicatorStyle.pill
                    ? DSPillIndicator(
                        shape: context.shapeOf(AppShape.control),
                        inset: context.design.component.trackInset,
                      )
                    : const DSUnderlineIndicator()),
            widths: List<double>.of(_widths),
            labelWidths: List<double>.of(_labelWidths),
            count: count,
            fraction: fraction,
            style: resolved,
          ),
          child: row,
        );

        Widget bar = SizedBox(height: resolved.height, child: row);

        if (scrollable) {
          bar = SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: bar,
          );
          bar = _EdgeFade(
            width: resolved.edgeFadeWidth!,
            atStart: !_scroll.hasClients || _scroll.offset <= 0,
            atEnd:
                !_scroll.hasClients ||
                _scroll.offset >= _scroll.position.maxScrollExtent,
            child: bar,
          );
        }

        if (widget.indicator == DSTabIndicatorStyle.pill) {
          bar = Container(
            // Horizontal only. Vertically the tabs fill the track, because
            // they are the targets and the track is what is painted behind
            // them.
            padding: EdgeInsets.symmetric(
              horizontal: context.design.component.trackInset,
            ),
            decoration: ShapeDecoration(
              color: resolved.trackFill,
              shape: context.shapeOf(AppShape.control),
            ),
            child: bar,
          );
        } else if (resolved.showBaseline ?? false) {
          bar = DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: resolved.baselineColor!,
                  width: context.design.component.hairlineWidth,
                ),
              ),
            ),
            child: bar,
          );
        }

        return _DSTabScope(
          style: resolved,
          indicator: widget.indicator,
          selectedness: selectedness,
          selectedIndex: _index,
          count: count,
          onSelect: _select,
          enabled: enabled,
          report: _report,
          reportWanted: _reportWanted,
          child: FocusableActionDetector(
            enabled: enabled,
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.arrowLeft): _TabStep(-1),
              SingleActivator(LogicalKeyboardKey.arrowRight): _TabStep(1),
              SingleActivator(LogicalKeyboardKey.home): _TabStep(-9999),
              SingleActivator(LogicalKeyboardKey.end): _TabStep(9999),
            },
            actions: <Type, Action<Intent>>{
              _TabStep: CallbackAction<_TabStep>(
                onInvoke: (intent) {
                  _step(intent.by);
                  return null;
                },
              ),
            },
            child: bar,
          ),
        );
      },
    );
  }

  Widget _sized(int index, bool scrollable, DSTabBarStyle style, Widget child) {
    final measured = _DSTabIndex(
      index: index,
      child: _MeasuredTab(index: index, child: child),
    );
    if (scrollable) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: style.minTabWidth!),
        child: measured,
      );
    }
    return Expanded(child: measured);
  }
}

/// Moving between tabs with the keyboard.
class _TabStep extends Intent {
  const _TabStep(this.by);

  final int by;
}

/// Paints whichever indicator the bar was given, behind the labels.
class _IndicatorPainter extends CustomPainter {
  const _IndicatorPainter({
    required this.delegate,
    required this.widths,
    required this.labelWidths,
    required this.count,
    required this.fraction,
    required this.style,
  });

  final DSTabIndicator delegate;
  final List<double> widths;
  final List<double> labelWidths;
  final int count;
  final double fraction;
  final DSTabBarStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (widths.length < count || widths.any((w) => w <= 0)) return;
    final tabs = <Rect>[];
    final labels = <Rect>[];
    var x = 0.0;
    for (var i = 0; i < count; i++) {
      tabs.add(Rect.fromLTWH(x, 0, widths[i], size.height));
      final labelWidth = labelWidths[i] > 0 ? labelWidths[i] : widths[i];
      labels.add(
        Rect.fromLTWH(
          x + (widths[i] - labelWidth) / 2,
          0,
          labelWidth,
          size.height,
        ),
      );
      x += widths[i];
    }
    delegate.paint(canvas, size, tabs, labels, fraction, style);
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) =>
      old.fraction != fraction ||
      old.widths.length != widths.length ||
      !_sameWidths(old.widths, widths) ||
      old.delegate != delegate ||
      old.style != style;

  static bool _sameWidths(List<double> a, List<double> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A 24-point fade over each overflowing edge, and none over an edge that is
/// already at its end.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.width,
    required this.atStart,
    required this.atEnd,
    required this.child,
  });

  final double width;
  final bool atStart;
  final bool atEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (atStart && atEnd) return child;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [
          atStart ? Palette.sheenInk : Palette.sheenInk.withValues(alpha: 0),
          Palette.sheenInk,
          Palette.sheenInk,
          atEnd ? Palette.sheenInk : Palette.sheenInk.withValues(alpha: 0),
        ],
        stops: [
          0,
          rect.width == 0 ? 0 : width / rect.width,
          rect.width == 0 ? 1 : 1 - width / rect.width,
          1,
        ],
        // The fade marks the end of a *scrollable*, and the end of a
        // scrollable moves with the reading direction — so the gradient is
        // directional, and a directional alignment needs the direction handed
        // to it here: `createShader` is outside the build's inherited scope.
      ).createShader(rect, textDirection: Directionality.of(context)),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// Reports a tab's own width and its label's width.
class _MeasuredTab extends StatelessWidget {
  const _MeasuredTab({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = _DSTabScope.of(context);
    // The label's width is the tab minus its own padding. Measuring the text
    // separately would add a render object per tab for a number that is
    // already known, and the padding is the only thing between the two.
    final padding = scope.style.tabPadding!.horizontal;
    // Floored at the same minimum a scrollable tab is given, so the two
    // layouts agree about how much room the row needs. Without the floor a
    // narrow label measures below the minimum it would actually be laid out
    // at, and the bar can decide it fits, switch back to fixed, and measure
    // itself into scrolling again on the next frame.
    final floor = scope.style.minTabWidth ?? 0;
    return _Measured(
      onSize: (size) => scope.report(
        index,
        size.width,
        (size.width - padding).clamp(0, size.width),
      ),
      onIntrinsicWidth: (width) =>
          scope.reportWanted(index, width < floor ? floor : width),
      child: AppChoiceLabel(child: child),
    );
  }
}

class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({
    required this.onSize,
    required this.onIntrinsicWidth,
    required super.child,
  });

  final ValueChanged<Size> onSize;

  /// The width the child would take if it were asked for its preference
  /// rather than handed a slice.
  final ValueChanged<double> onIntrinsicWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize, onIntrinsicWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) {
    renderObject
      ..onSize = onSize
      ..onIntrinsicWidth = onIntrinsicWidth;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize, this.onIntrinsicWidth);

  ValueChanged<Size> onSize;
  ValueChanged<double> onIntrinsicWidth;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
    final RenderBox? child = this.child;
    if (child != null) {
      onIntrinsicWidth(child.getMaxIntrinsicWidth(size.height));
    }
  }
}

/// One tab in a [DSTabBar].
class DSTab extends StatelessWidget {
  const DSTab({
    super.key,
    required this.label,
    this.icon,
    this.selectedIcon,
    this.count,
    this.enabled = true,
    this.leading,
    this.trailing,
    this.labelSlot,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;

  /// The number beside the label — "Unread 3". Part of the accessible name,
  /// not a separate node: a screen reader says "Unread, 3 items" in one go.
  final int? count;

  final bool enabled;
  final Widget? leading;
  final Widget? trailing;
  final Widget? labelSlot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scope = _DSTabScope.of(context);
    final style = scope.style;
    final index = _index(context);
    final selectedness = index == null ? 0.0 : scope.selectedness[index];
    final selected = index == scope.selectedIndex;
    final on = enabled && scope.enabled;

    final color = Color.lerp(
      style.labelStyle?.color,
      style.selectedLabelStyle?.color,
      selectedness,
    );
    final labelStyle =
        (selectedness > 0.5 ? style.selectedLabelStyle : style.labelStyle)
            ?.copyWith(color: color);

    final glyph = selected ? (selectedIcon ?? icon) : icon;

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null)
          leading!
        else if (glyph != null)
          Icon(glyph, size: style.iconSize, color: color),
        if ((leading != null || glyph != null))
          SizedBox(width: context.design.space.xs),
        Flexible(
          child:
              labelSlot ??
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
        ),
        if (trailing != null)
          trailing!
        else if (count != null) ...[
          SizedBox(width: context.design.space.xs),
          DSTabCount(count: count!),
        ],
      ],
    );

    content = Padding(padding: style.tabPadding!, child: content);
    if (!on) {
      content = Opacity(opacity: style.disabledOpacity!, child: content);
    }

    return Semantics(
      role: SemanticsRole.tab,
      container: true,
      selected: selected,
      enabled: on,
      label: count == null
          ? (semanticLabel ?? label)
          : '${semanticLabel ?? label}, $count items',
      // A scrollable strip owes the reader the shape of the set: without it a
      // screen reader user has no way to know there are tabs past the edge.
      hint: scope.count > 1 ? '${(index ?? 0) + 1} of ${scope.count}' : null,
      onTap: on && index != null ? () => scope.onSelect(index) : null,
      excludeSemantics: true,
      child: DSPressable(
        // A tab does not dip: it belongs to the strip it sits in, and a strip
        // whose members shrink one at a time reads as coming apart.
        enabled: false,
        focusShape: context.shapeOf(AppShape.control),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on && index != null ? () => scope.onSelect(index) : null,
          child: Center(child: content),
        ),
      ),
    );
  }

  int? _index(BuildContext context) {
    final scope = _DSTabScope.of(context);
    final index = _DSTabIndex.of(context);
    return index != null && index < scope.selectedness.length ? index : null;
  }
}

/// Which slot a tab occupies, supplied by the measurement wrapper the bar
/// puts around each child.
@immutable
class _DSTabIndex extends InheritedWidget {
  const _DSTabIndex({required this.index, required super.child});

  final int index;

  static int? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DSTabIndex>()?.index;

  @override
  bool updateShouldNotify(_DSTabIndex old) => old.index != index;
}

/// The count beside a tab's label.
// ds-tier: 1 — atom — A number beside a tab label.
class DSTabCount extends StatelessWidget {
  const DSTabCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) =>
      Text('$count', style: _DSTabScope.of(context).style.countStyle);
}

/// The bar's shape while its labels are still arriving.
class DSTabBarSkeleton extends StatelessWidget {
  const DSTabBarSkeleton({
    super.key,
    this.tabs = 3,
    this.indicator = DSTabIndicatorStyle.underline,
  });

  final int tabs;
  final DSTabIndicatorStyle indicator;

  @override
  Widget build(BuildContext context) {
    final style = DSTabBarStyle.resolve(context, indicator);
    return SizedBox(
      height: style.height,
      child: Row(
        children: [
          for (var i = 0; i < tabs; i++)
            Expanded(
              child: Padding(
                padding: style.tabPadding!,
                child: const Center(child: DSSkeleton(child: Text('      '))),
              ),
            ),
        ],
      ),
    );
  }
}
