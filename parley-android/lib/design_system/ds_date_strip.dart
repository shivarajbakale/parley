// ds-tier: 2 — molecule

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_skeleton.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two designed strip scales.
///
/// `compact` drops the weekday row, which is why it is a size that changes
/// information content rather than a second class.
enum DSDateStripSize { compact, md }

/// Everything a day cell is, as one value.
///
/// A state object rather than five booleans, so a caller's `dayBuilder`
/// signature stays stable as states are added.
///
/// The fields are not `is`-prefixed: the kit names booleans `enabled`,
/// `selected` and `dense`, and `ui_lint` fails the other convention.
@immutable
class DSDateState {
  const DSDateState({
    this.selected = false,
    this.today = false,
    this.disabled = false,
    this.focused = false,
    this.pressed = false,
  });

  final bool selected;
  final bool today;
  final bool disabled;
  final bool focused;
  final bool pressed;
}

/// [DSDateStrip]'s appearance, as data.
@immutable
class DSDateStripStyle extends DSComponentStyle<DSDateStripStyle> {
  const DSDateStripStyle({
    this.cellWidth,
    this.cellHeight,
    this.cellGap,
    this.radius,
    this.selectedColor,
    this.onSelectedColor,
    this.todayMarkerColor,
    this.todayMarkerSize,
    this.pressedColor,
    this.weekdayStyle,
    this.dayStyle,
    this.badgeStyle,
    this.headerStyle,
    this.showWeekday,
    this.edgePeek,
  });

  final double? cellWidth;
  final double? cellHeight;
  final double? cellGap;
  final BorderRadius? radius;
  final Color? selectedColor;
  final Color? onSelectedColor;
  final Color? todayMarkerColor;
  final double? todayMarkerSize;

  final Color? pressedColor;
  final TextStyle? weekdayStyle;
  final TextStyle? dayStyle;

  /// The type a `dayBadge` is drawn in. Its colour is replaced per cell with
  /// the cell's own foreground, so a badge sitting on the selected day is
  /// legible on the accent rather than on the card it is not on.
  final TextStyle? badgeStyle;
  final TextStyle? headerStyle;
  final bool? showWeekday;

  /// How much of the next cell shows at the trailing edge. Users miss content
  /// in a horizontal scroller unless a partial item is visible, so the strip
  /// deliberately does not sit flush.
  final double? edgePeek;

  @override
  DSDateStripStyle merge(DSDateStripStyle? other) {
    if (other == null) return this;
    return DSDateStripStyle(
      cellWidth: other.cellWidth ?? cellWidth,
      cellHeight: other.cellHeight ?? cellHeight,
      cellGap: other.cellGap ?? cellGap,
      radius: other.radius ?? radius,
      selectedColor: other.selectedColor ?? selectedColor,
      onSelectedColor: other.onSelectedColor ?? onSelectedColor,
      todayMarkerColor: other.todayMarkerColor ?? todayMarkerColor,
      todayMarkerSize: other.todayMarkerSize ?? todayMarkerSize,
      pressedColor: other.pressedColor ?? pressedColor,
      weekdayStyle: other.weekdayStyle ?? weekdayStyle,
      dayStyle: other.dayStyle ?? dayStyle,
      badgeStyle: other.badgeStyle ?? badgeStyle,
      headerStyle: other.headerStyle ?? headerStyle,
      showWeekday: other.showWeekday ?? showWeekday,
      edgePeek: other.edgePeek ?? edgePeek,
    );
  }

  @override
  DSDateStripStyle copyWith({
    double? cellWidth,
    double? cellHeight,
    double? cellGap,
    BorderRadius? radius,
    Color? selectedColor,
    Color? onSelectedColor,
    Color? todayMarkerColor,
    double? todayMarkerSize,
    Color? pressedColor,
    TextStyle? weekdayStyle,
    TextStyle? dayStyle,
    TextStyle? badgeStyle,
    TextStyle? headerStyle,
    bool? showWeekday,
    double? edgePeek,
  }) => DSDateStripStyle(
    cellWidth: cellWidth ?? this.cellWidth,
    cellHeight: cellHeight ?? this.cellHeight,
    cellGap: cellGap ?? this.cellGap,
    radius: radius ?? this.radius,
    selectedColor: selectedColor ?? this.selectedColor,
    onSelectedColor: onSelectedColor ?? this.onSelectedColor,
    todayMarkerColor: todayMarkerColor ?? this.todayMarkerColor,
    todayMarkerSize: todayMarkerSize ?? this.todayMarkerSize,
    pressedColor: pressedColor ?? this.pressedColor,
    weekdayStyle: weekdayStyle ?? this.weekdayStyle,
    dayStyle: dayStyle ?? this.dayStyle,
    badgeStyle: badgeStyle ?? this.badgeStyle,
    headerStyle: headerStyle ?? this.headerStyle,
    showWeekday: showWeekday ?? this.showWeekday,
    edgePeek: edgePeek ?? this.edgePeek,
  );

  @override
  DSDateStripStyle lerp(DSDateStripStyle? other, double t) {
    if (other == null) return this;
    return DSDateStripStyle(
      cellWidth: lerpDouble(cellWidth, other.cellWidth, t),
      cellHeight: lerpDouble(cellHeight, other.cellHeight, t),
      cellGap: lerpDouble(cellGap, other.cellGap, t),
      radius: BorderRadius.lerp(radius, other.radius, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      onSelectedColor: Color.lerp(onSelectedColor, other.onSelectedColor, t),
      todayMarkerColor: Color.lerp(todayMarkerColor, other.todayMarkerColor, t),
      todayMarkerSize: lerpDouble(todayMarkerSize, other.todayMarkerSize, t),
      pressedColor: Color.lerp(pressedColor, other.pressedColor, t),
      weekdayStyle: TextStyle.lerp(weekdayStyle, other.weekdayStyle, t),
      dayStyle: TextStyle.lerp(dayStyle, other.dayStyle, t),
      badgeStyle: TextStyle.lerp(badgeStyle, other.badgeStyle, t),
      headerStyle: TextStyle.lerp(headerStyle, other.headerStyle, t),
      showWeekday: t < 0.5 ? showWeekday : other.showWeekday,
      edgePeek: lerpDouble(edgePeek, other.edgePeek, t),
    );
  }

  static DSDateStripSize sizeOf(BuildContext context, DSDateStripSize? size) {
    // Past this the weekday row cannot survive at any cell width, so the
    // compact form is used whatever the caller asked for.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.6) {
      return DSDateStripSize.compact;
    }
    return size ??
        (DSScope.densityOf(context) == DSDensity.compact
            ? DSDateStripSize.compact
            : DSDateStripSize.md);
  }

  static DSDateStripStyle resolve(
    BuildContext context,
    DSDateStripSize? size, [
    DSDateStripStyle? own,
  ]) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final text = Theme.of(context).textTheme;
    final compact = sizeOf(context, size) == DSDateStripSize.compact;
    // The cell grows with the type and the day number stays whole; the
    // alternative is a clipped date, and a clipped date is a wrong date.
    final scaler = MediaQuery.textScalerOf(context);
    final width = scaler.scale(
      compact ? design.component.wellSize : design.component.minTapTarget,
    );
    // Room for the design rather than the minimum the glyphs survive in. The
    // old 64 fitted a weekday, a number and a dot only because the padding
    // between them had been squeezed to a hairline, and a cell that tight is
    // the difference a person reads as cheap before they can say why.
    final height = scaler.scale(
      compact
          ? design.component.wellSize + space.sm
          : design.component.listRowMinHeight + space.lg,
    );

    return resolveStyle(
      context: context,
      specDefaults: DSDateStripStyle(
        cellWidth: width,
        cellHeight: height,
        cellGap: space.sm,
        radius: BorderRadius.all(
          // A day cell is a tile: it is a container that holds two lines of
          // content, not a control the size of a button. The control radius
          // on a 48x64 box is what turned the selected day into a lozenge.
          Radius.circular(context.radiusOf(AppShape.tile)),
        ),
        selectedColor: palette.primary,
        onSelectedColor: palette.primaryForeground,
        todayMarkerColor: palette.primary,
        todayMarkerSize: space.xs,
        pressedColor: palette.muted,
        weekdayStyle: text.labelSmall?.copyWith(
          color: palette.mutedForeground,
          letterSpacing: 0.4,
        ),
        badgeStyle: text.labelSmall,
        // Tabular matters more here than anywhere else in the kit: without
        // it the strip visibly reflows as it scrolls from single- to
        // double-digit days.
        dayStyle: (compact ? text.titleSmall : text.titleMedium)
            ?.copyWith(
              color: palette.foreground,
              // The rest weight, deliberately not the emphasis one. A row where
              // all seven numbers are already bold has nothing left to say when
              // one of them is chosen, and the strip's whole job is saying that.
              fontWeight: context.design.type.titleWeight,
            )
            .tabular,
        headerStyle: text.titleSmall?.copyWith(
          color: palette.foreground,
          fontWeight: context.design.type.emphasisWeight,
        ),
        showWeekday: !compact,
        edgePeek: width / 2,
      ),
      own: own,
    );
  }
}

/// A horizontal, scrollable run of dates with one selected.
///
/// See `docs/plans/07-ds-date-strip.plan.md`. The control for picking a day
/// that is *near* today, where seeing the neighbouring days is part of the
/// decision — booking, scheduling, a log, an agenda. For a distant or exact
/// date, `showDatePicker`.
///
/// It contains no English and no hardcoded date format: every label goes
/// through a formatter that defaults to [MaterialLocalizations], and the first
/// day of the week is locale data rather than a constant.
///
/// [today] is a parameter with a `DateTime.now()` default. A widget that reads
/// the clock internally cannot be golden-tested.
class DSDateStrip extends StatefulWidget {
  const DSDateStrip({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    this.selectedDate,
    this.today,
    this.showHeader = true,
    this.size,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.header,
    this.empty,
    this.dayBuilder,
    this.dayBadge,
    this.isDayEnabled,
    this.weekdayFormatter,
    this.dayFormatter,
    this.headerFormatter,
    this.semanticFormatter,
    this.controller,
  });

  /// The compact strip: no weekday row, for a strip docked in an app bar.
  const DSDateStrip.compact({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    this.selectedDate,
    this.today,
    this.showHeader = false,
    this.enabled = true,
    this.loading = false,
    this.style,
    this.header,
    this.empty,
    this.dayBuilder,
    this.dayBadge,
    this.isDayEnabled,
    this.weekdayFormatter,
    this.dayFormatter,
    this.headerFormatter,
    this.semanticFormatter,
    this.controller,
  }) : size = DSDateStripSize.compact;

  /// A strip spanning one whole calendar month, first to last.
  ///
  /// The header already names a month; without this the component knew about
  /// days and nothing about the unit it was printing, and every caller
  /// computed February for itself.
  ///
  /// [month] is any instant inside the wanted month — its day is ignored.
  /// Omitted, it is the month the clock is in, read once here rather than
  /// twice in an initializer list that could straddle a month boundary.
  factory DSDateStrip.month({
    Key? key,
    DateTime? month,
    required ValueChanged<DateTime> onDateSelected,
    DateTime? selectedDate,
    DateTime? today,
    bool showHeader = true,
    DSDateStripSize? size,
    bool enabled = true,
    bool loading = false,
    DSDateStripStyle? style,
    Widget? header,
    Widget? empty,
    Widget Function(BuildContext context, DSDateState state, DateTime date)?
    dayBuilder,
    Widget Function(BuildContext context, DateTime date)? dayBadge,
    bool Function(DateTime date)? isDayEnabled,
    String Function(DateTime date)? weekdayFormatter,
    String Function(DateTime date)? dayFormatter,
    String Function(DateTime date)? headerFormatter,
    String Function(DateTime date)? semanticFormatter,
    ScrollController? controller,
  }) {
    final anchor = month ?? DateTime.now();
    return DSDateStrip(
      key: key,
      firstDate: DateTime(anchor.year, anchor.month, 1),
      // Day zero of the next month is the last day of this one. February is
      // 28 or 29 because the calendar says so, not because a table here does.
      lastDate: DateTime(anchor.year, anchor.month + 1, 0),
      onDateSelected: onDateSelected,
      selectedDate: selectedDate,
      today: today,
      showHeader: showHeader,
      size: size,
      enabled: enabled,
      loading: loading,
      style: style,
      header: header,
      empty: empty,
      dayBuilder: dayBuilder,
      dayBadge: dayBadge,
      isDayEnabled: isDayEnabled,
      weekdayFormatter: weekdayFormatter,
      dayFormatter: dayFormatter,
      headerFormatter: headerFormatter,
      semanticFormatter: semanticFormatter,
      controller: controller,
    );
  }

  final DateTime firstDate;
  final DateTime lastDate;

  /// Nullable: no selection is a valid state, and today still shows its mark.
  final DateTime? selectedDate;

  final ValueChanged<DateTime> onDateSelected;

  /// Injectable so a test and a golden are stable.
  final DateTime? today;

  final bool showHeader;
  final DSDateStripSize? size;
  final bool enabled;
  final bool loading;
  final DSDateStripStyle? style;

  /// Replaces the generated month-and-chevrons row entirely — for a month
  /// picker, a "Today" button or a range summary.
  final Widget? header;

  /// Shown when the range holds no days. The strip does not render zero cells
  /// with no explanation.
  final Widget? empty;

  /// Total replacement of one cell's paint, with its state handed in. The
  /// component keeps the layout, the scrolling, the targets, the keyboard and
  /// the semantics; the caller owns the pixels.
  final Widget Function(BuildContext context, DSDateState state, DateTime date)?
  dayBuilder;

  /// The cheap version of [dayBuilder] for the common case: something small
  /// under the day number.
  final Widget Function(BuildContext context, DateTime date)? dayBadge;

  /// How a booking app greys out sold-out days without this component ever
  /// learning what a booking is.
  final bool Function(DateTime date)? isDayEnabled;

  final String Function(DateTime date)? weekdayFormatter;
  final String Function(DateTime date)? dayFormatter;
  final String Function(DateTime date)? headerFormatter;
  final String Function(DateTime date)? semanticFormatter;

  final ScrollController? controller;

  /// The travelling selection pill, for a test that needs to find it.
  ///
  /// A key rather than a public widget class: the pill is one rectangle this
  /// component paints for itself, not a part anybody composes with, and a
  /// class would have to earn a catalog entry it has no use for.
  static const Key indicatorKey = ValueKey('DSDateStrip.indicator');

  /// Whether two instants fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  State<DSDateStrip> createState() => _DSDateStripState();
}

class _DSDateStripState extends State<DSDateStrip>
    with TickerProviderStateMixin {
  late ScrollController _controller = widget.controller ?? ScrollController();
  late DateTime _focused = widget.selectedDate ?? _firstDay;

  /// The width one cell occupies, gap included, as the last build measured
  /// it.
  ///
  /// Cached rather than re-resolved per scroll: `DSDateStripStyle.resolve`
  /// reads the palette, the design spec, the text theme and the text scaler,
  /// and every arrow keypress was paying for all of it to learn one number.
  /// It also registered inherited dependencies from a post-frame callback,
  /// which is not where a widget is supposed to acquire them.
  double? _cellExtent;

  /// Drives the pill from [_from] to [_to]. One pill sliding is the whole
  /// point: two cells cross-fading their own fills says a box appeared over
  /// there, where a pill that travels says *this* is the thing you moved.
  late final AnimationController _travel = AnimationController(vsync: this);

  /// The pill's own size as it goes. It gathers slightly on the way and
  /// settles at full size, which is what makes the arrival read as a landing.
  late final AnimationController _pop = AnimationController(vsync: this);

  /// Drives the scroll offset, so the strip settles on a spring rather than a
  /// stopwatch. A fixed duration gives a one-day move and a twenty-day move
  /// the same length, and only one of those is a small movement.
  late final AnimationController _scrollDrive = AnimationController(
    vsync: this,
  );

  double _from = 0;
  double _to = 0;
  double _scrollFrom = 0;
  double _scrollTarget = 0;
  bool _reducedMotion = false;

  /// Where the pill is, in cell indices.
  double get _fraction => lerpDouble(_from, _to, _travel.value) ?? _to;

  /// Whether this strip owns the selected day's paint at all. A caller with a
  /// `dayBuilder` owns the pixels, and a pill sliding behind their cell is a
  /// second selection marker they did not ask for.
  bool get _travels => widget.dayBuilder == null;

  DateTime get _firstDay => _dayOf(widget.firstDate);
  DateTime get _lastDay => _dayOf(widget.lastDate);

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _dayCount => _lastDay.difference(_firstDay).inDays + 1;

  DateTime _dateAt(int index) =>
      DateTime(_firstDay.year, _firstDay.month, _firstDay.day + index);

  int _indexOf(DateTime date) => _dayOf(date).difference(_firstDay).inDays;

  @override
  void initState() {
    super.initState();
    final selected = widget.selectedDate;
    if (selected != null) {
      _from = _to = _indexOf(selected).toDouble();
    }
    _travel.value = 1;
    _pop.value = 1;
    _scrollDrive.addListener(_onScrollDriveTick);
    _scrollDrive.addStatusListener(_onScrollDriveDone);
    _travel.addStatusListener(_snapToRest);
    _pop.addStatusListener(_snapToRest);
    // The strip opens on the day it is about, not on the first day of its
    // range. At seven cells the two were the same view; at a month apart they
    // are a selection nobody can see. Post-frame because the viewport has no
    // dimensions to centre against until it has been laid out once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = widget.selectedDate ?? widget.today ?? DateTime.now();
      final index = _indexOf(anchor);
      if (index < 0 || index >= _dayCount) return;
      _scrollTo(index, animate: false, centre: true);
    });
  }

  @override
  void didUpdateWidget(DSDateStrip old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      if (old.controller == null) _controller.dispose();
      _controller = widget.controller ?? ScrollController();
    }
    final selected = widget.selectedDate;
    if (selected != null && selected != old.selectedDate) {
      _focused = selected;
      // From wherever the pill actually is, not from the day it was last told
      // about: a second tap mid-travel should carry on from the middle rather
      // than snap back and start again.
      _from = _fraction;
      _to = _indexOf(selected).toDouble();
      _spring(_travel);
      _spring(_pop);
      // Post-frame, like the opening scroll: `didUpdateWidget` runs before the
      // build that would measure the new cells, so scrolling here reads the
      // extent the *previous* layout had.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollTo(_indexOf(selected), centre: true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final motion = context.design.motion;
    // Only the fallback path reads these: a spring runs to its own physics
    // and ignores the controller's duration.
    _travel.duration = motion.scaled(motion.normal);
    _pop.duration = motion.scaled(motion.fast);
    _scrollDrive.duration = motion.scaled(motion.normal);
  }

  @override
  void dispose() {
    _scrollDrive.removeListener(_onScrollDriveTick);
    _scrollDrive.removeStatusListener(_onScrollDriveDone);
    _travel.removeStatusListener(_snapToRest);
    _pop.removeStatusListener(_snapToRest);
    _travel.dispose();
    _pop.dispose();
    _scrollDrive.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// Runs [controller] from 0 to 1 on the kit's travel spring.
  ///
  /// `gentle` is what `DSTabBar` and `DSSegmentedButton` move their indicators
  /// on, and a strip whose pill travelled to different physics than the tab
  /// bar's would be two answers to one question. It is critically damped, so
  /// the pill glides in and stops rather than wobbling on arrival.
  void _spring(AnimationController controller) {
    controller.value = 0;
    if (_reducedMotion) {
      controller.value = 1;
      return;
    }
    final motion = context.design.motion;
    if (context.springsAvailable) {
      controller.animateWith(motion.simulation(spring: motion.gentle));
    } else {
      controller.animateTo(1, curve: motion.emphasize);
    }
  }

  /// Finishes a spring on its rest value rather than inside its tolerance.
  ///
  /// A `SpringSimulation` stops when it calls itself done, which is close to
  /// 1 and not 1 — so the pill came to rest at 99.999% of a cell, a fraction
  /// of a pixel narrower than the day underneath it. Invisible, and still
  /// wrong: the component's resting state should be a number, not a
  /// neighbourhood.
  void _snapToRest(AnimationStatus status) {
    if (!status.isCompleted) return;
    if (_travel.value != 1 && _travel.status.isCompleted) _travel.value = 1;
    if (_pop.value != 1 && _pop.status.isCompleted) _pop.value = 1;
  }

  /// Lands the scroll on the number rather than near it.
  ///
  /// A spring finishes when its simulation calls itself done, which is inside
  /// a tolerance and not at the rest value — so the strip came to rest a
  /// hundredth of a point short and `Home` no longer meant zero.
  void _onScrollDriveDone(AnimationStatus status) {
    if (!status.isCompleted || !_controller.hasClients) return;
    final position = _controller.position;
    _controller.jumpTo(
      _scrollTarget.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  void _onScrollDriveTick() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    _controller.jumpTo(
      (lerpDouble(_scrollFrom, _scrollTarget, _scrollDrive.value) ??
              _scrollTarget)
          // A spring can pass its rest value on the way; the scroll position
          // must not be driven into overscroll by an animation nobody
          // gestured.
          .clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  /// Brings the day at [index] into view.
  ///
  /// [centre] is the difference between choosing a day and stepping onto one.
  /// A day the user picked is put in the middle, because the days either side
  /// of it are the reason a strip exists. A day the focus stepped onto is
  /// revealed and no more: centring on an arrow key throws the strip half a
  /// viewport sideways for a one-day move, and the row the user was reading
  /// disappears under them.
  void _scrollTo(int index, {bool animate = true, bool centre = false}) {
    if (!_controller.hasClients || index < 0) return;
    final extent = _cellExtent ?? 56;
    final position = _controller.position;
    final viewport = position.viewportDimension;
    final start = index * extent;
    final end = start + extent;
    final offset = _controller.offset;
    // A day already on screen is left where it is, whichever way it was
    // reached. Scrolling one that was visible anyway pushes the strip off its
    // leading edge, and that edge is the page gutter — a clipped half cell
    // there is not the trailing peek that says the strip scrolls, it is a
    // strip that looks broken.
    if (start >= offset && end <= offset + viewport) return;
    // The clamp is what keeps the first and last days of a month reachable.
    final target =
        (centre
                ? start - (viewport - extent) / 2
                // Minimal: to the leading edge if it fell off the start, to the
                // trailing edge if it fell off the end.
                : (start < offset ? start : end - viewport))
            .clamp(0.0, position.maxScrollExtent);
    if (!animate || _reducedMotion) {
      _controller.jumpTo(target);
      return;
    }
    _scrollFrom = _controller.offset;
    _scrollTarget = target;
    _spring(_scrollDrive);
  }

  bool _enabledOn(DateTime date) =>
      widget.enabled &&
      !widget.loading &&
      (widget.isDayEnabled?.call(date) ?? true);

  void _select(DateTime date) {
    if (!_enabledOn(date)) return;
    AppHaptics.selection();
    setState(() => _focused = date);
    widget.onDateSelected(date);
  }

  void _moveFocus(int days) {
    final next = DateTime(_focused.year, _focused.month, _focused.day + days);
    if (next.isBefore(_firstDay) || next.isAfter(_lastDay)) return;
    setState(() => _focused = next);
    // SC 2.4.3: the focused cell is always scrolled into view.
    _scrollTo(_indexOf(next));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        _moveFocus(rtl ? -1 : 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _moveFocus(rtl ? 1 : -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveFocus(7);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveFocus(-7);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() => _focused = _firstDay);
        _scrollTo(0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() => _focused = _lastDay);
        _scrollTo(_dayCount - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _select(_focused);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final resolved = DSDateStripStyle.resolve(
      context,
      widget.size,
      widget.style,
    );
    final space = context.design.space;
    final today = widget.today ?? DateTime.now();
    final cellWidth = resolved.cellWidth ?? 48;
    final cellHeight = resolved.cellHeight ?? 64;
    final gap = resolved.cellGap ?? space.sm;
    _cellExtent = cellWidth + gap;

    final headerWidget = !widget.showHeader
        ? null
        : widget.header ??
              DSDateStripHeader(
                title:
                    (widget.headerFormatter ?? localizations.formatMonthYear)(
                      widget.selectedDate ?? _focused,
                    ),
                style: resolved,
              );

    if (_dayCount <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (headerWidget != null) headerWidget,
          widget.empty ?? Text('—', style: resolved.dayStyle),
        ],
      );
    }

    // A badge is content, and content needs room: a cell holding a count under
    // the day is taller than one holding the today dot, and squeezing it is
    // how a strip clips its own numbers.
    final badgeRoom = widget.dayBadge == null ? 0.0 : space.lg;
    Widget buildList() => ListView.separated(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      // The trailing peek: a half cell showing is what tells the user the
      // strip scrolls at all.
      padding: EdgeInsetsDirectional.only(end: resolved.edgePeek ?? 0),
      itemCount: _dayCount,
      separatorBuilder: (context, _) => SizedBox(width: gap),
      itemBuilder: (context, index) {
        final date = _dateAt(index);
        final state = DSDateState(
          selected:
              widget.selectedDate != null &&
              DSDateStrip.isSameDay(date, widget.selectedDate!),
          today: DSDateStrip.isSameDay(date, today),
          disabled: !_enabledOn(date),
          focused: DSDateStrip.isSameDay(date, _focused),
        );

        final cell =
            widget.dayBuilder?.call(context, state, date) ??
            DSDateStripDay(
              date: date,
              state: state,
              style: resolved,
              fill: !_travels,
              // How much of the pill is over this cell. The numeral has to
              // turn to the on-accent colour as the fill arrives and back as
              // it leaves; a cell that flipped its colour on selection alone
              // would go white while the pill was still two cells away.
              coverage: _travels
                  ? (1 - (index - _fraction).abs()).clamp(0.0, 1.0)
                  : null,
              weekday: (resolved.showWeekday ?? true)
                  ? (widget.weekdayFormatter ??
                        (d) =>
                            localizations.narrowWeekdays[d.weekday % 7])(date)
                  : null,
              day:
                  (widget.dayFormatter ??
                  (d) => localizations.formatDecimal(d.day))(date),
              badgeSlot: widget.dayBadge?.call(context, date),
            );

        return Semantics(
          // "3 of 14" comes from the mutually-exclusive group, and it is
          // what a set of plain buttons would lose.
          inMutuallyExclusiveGroup: true,
          selected: state.selected,
          enabled: !state.disabled,
          button: true,
          // The full formatted date, never the bare number: a screen reader
          // user has no weekday row to look at.
          label: _semanticLabel(localizations, date, state),
          // Declared here because `excludeSemantics` removes the one the control
          // publishes for itself. Without it the node says "button", says what the
          // button is for, and offers nothing to activate — VoiceOver's double-tap
          // and TalkBack's click both arrive as this action.
          onTap: state.disabled ? null : () => _select(date),
          excludeSemantics: true,
          child: DSPressable(
            // The kit's floor, not an exception to it: a day dips under the
            // finger, takes the focus ring and reports disabled, the same as
            // every other target. The Listener cancels past the touch slop,
            // so dragging the strip scrolls it rather than pressing a day.
            enabled: !state.disabled,
            focusShape: RoundedRectangleBorder(borderRadius: resolved.radius!),
            child: DSInkSurface(
              onTap: state.disabled ? null : () => _select(date),
              shape: RoundedRectangleBorder(borderRadius: resolved.radius!),
              highlightColor: resolved.pressedColor ?? context.palette.muted,
              child: SizedBox(
                width: cellWidth < context.design.component.minTapTarget
                    ? context.design.component.minTapTarget
                    : cellWidth,
                child: Center(child: cell),
              ),
            ),
          ),
        );
      },
    );

    // The cells rebuild on every travel tick, not only when the pill does.
    // Their numerals cross-fade to the on-accent colour by `coverage`, and a
    // list that only rebuilt when something else called `setState` left a dark
    // number sitting under an arriving fill for the length of the animation.
    // `_travel` only, deliberately: scrolling moves the pill but changes no
    // cell's coverage, and rebuilding fourteen cells per scroll frame to
    // discover that would be a cost for nothing.
    final strip = SizedBox(
      height:
          cellHeight + badgeRoom + context.design.component.hairlineWidth * 2,
      child: _travels
          ? Stack(
              children: [
                // Behind the list, and deaf to pointers: the pill is paint,
                // and a rectangle that swallowed taps would eat the day it is
                // sitting on.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: AnimatedBuilder(
                        // The scroll controller is in here because the pill is
                        // positioned in the list's coordinates: when the strip
                        // scrolls under it, the pill has to move with the cell
                        // rather than stay where it was on screen.
                        animation: Listenable.merge([
                          _travel,
                          _pop,
                          _controller,
                        ]),
                        builder: (context, _) => _pill(
                          resolved,
                          cellWidth,
                          cellHeight,
                          gap,
                          // The cells are centred in a row that is taller than
                          // they are, by the badge room and the hairlines. A
                          // pill pinned to the top of the row misses them by
                          // exactly half of that.
                          (badgeRoom +
                                  context.design.component.hairlineWidth * 2) /
                              2,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _travel,
                  // Built inside the callback, not captured outside it:
                  // handing back the identical widget instance every tick is
                  // how the list stopped rebuilding at all.
                  builder: (context, _) => buildList(),
                ),
              ],
            )
          : buildList(),
    );

    return Semantics(
      container: true,
      // One tab stop, not fourteen: landing in a scroller and pressing tab
      // fourteen times to leave it is the failure this avoids.
      child: Focus(
        onKeyEvent: _onKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (headerWidget != null) ...[
              headerWidget,
              SizedBox(height: space.md),
            ],
            DSSkeleton(enabled: widget.loading, child: strip),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    DSDateStripStyle style,
    double cellWidth,
    double cellHeight,
    double gap,
    double top,
  ) {
    if (widget.selectedDate == null) return const SizedBox.shrink();
    final offset = _controller.hasClients ? _controller.offset : 0.0;
    return Stack(
      children: [
        PositionedDirectional(
          // `start`, not `left`: in a right-to-left strip the first day is at
          // the right edge, and a pill measured from the left would travel the
          // wrong way down a row it is supposed to be following.
          start: _fraction * (cellWidth + gap) - offset,
          top: top,
          width: cellWidth,
          height: cellHeight,
          child: Transform.scale(
            scale: lerpDouble(0.92, 1, _pop.value) ?? 1,
            child: DecoratedBox(
              key: DSDateStrip.indicatorKey,
              decoration: BoxDecoration(
                color: style.selectedColor ?? context.palette.primary,
                borderRadius: style.radius,
                // The chosen day lifts off the row. It is the one thing in the
                // strip allowed any depth, which is what keeps the depth
                // meaningful.
                boxShadow: context.design.elevation.resolve(
                  elevation: context.design.elevation.low,
                  brightness: Theme.of(context).brightness,
                  shadowColor: context.palette.overlay,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _semanticLabel(
    MaterialLocalizations localizations,
    DateTime date,
    DSDateState state,
  ) {
    final base = (widget.semanticFormatter ?? localizations.formatFullDate)(
      date,
    );
    return state.today ? '$base, today' : base;
  }
}

/// The month-and-chevrons row above the strip — the intended occupant of
/// [DSDateStrip.header].
class DSDateStripHeader extends StatelessWidget {
  const DSDateStripHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.titleSlot,
    this.style,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleSlot;
  final DSDateStripStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? DSDateStripStyle.resolve(context, null);
    return Row(
      children: [
        if (leading != null) leading!,
        Expanded(child: titleSlot ?? Text(title, style: resolved.headerStyle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// One day cell, as the strip draws it by default — and what a `dayBuilder`
/// can return unchanged if it only wants to wrap it.
class DSDateStripDay extends StatelessWidget {
  const DSDateStripDay({
    super.key,
    required this.date,
    required this.state,
    required this.day,
    this.weekday,
    this.badgeSlot,
    this.style,
    this.fill = true,
    this.coverage,
  });

  final DateTime date;
  final DSDateState state;

  /// Already formatted — the cell never formats a date itself.
  final String day;
  final String? weekday;

  final Widget? badgeSlot;
  final DSDateStripStyle? style;

  /// Whether the cell paints the selected fill itself.
  ///
  /// False when the strip is drawing one travelling pill instead. The cell
  /// still owns its type and its colours; it has simply stopped owning the
  /// box behind them.
  final bool fill;

  /// How much of that pill is over this cell, 0 to 1.
  ///
  /// Null outside a travelling strip, where selection is the only thing the
  /// colours have to answer to.
  final double? coverage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final design = context.design;
    final space = design.space;
    final motion = design.motion;
    final resolved = style ?? DSDateStripStyle.resolve(context, null);
    final marker = resolved.todayMarkerSize ?? space.xs;

    // One fact, one mark. Today used to be an outline *and* a dot: two marks
    // for the same fact, and because the outline was the only container in the
    // row it read as a stray artifact rather than as a state. Today is now the
    // accent numeral and its dot; the filled container belongs to the
    // selection alone, so a glance answers "which day did I pick" first and
    // "where is today" second, which is the order the questions are asked in.
    // How far this cell is into the selected state. A travelling pill hands
    // it in as a fraction, because the numeral has to change colour as the
    // fill crosses it rather than at the instant the tap landed.
    final double covered = coverage ?? (state.selected ? 1 : 0);
    final Color onFill = resolved.onSelectedColor ?? palette.primaryForeground;
    final Color resting = state.disabled
        ? palette.mutedForeground
        : state.today
        ? (resolved.todayMarkerColor ?? palette.primary)
        : palette.foreground;
    final Color foreground = Color.lerp(resting, onFill, covered) ?? resting;

    // Today's letter takes today's colour: the cell is one mark, and a grey
    // W over an accent 11 reads as two half-states stacked.
    final Color restingWeekday = state.disabled
        ? palette.mutedForeground
        : state.today
        ? (resolved.todayMarkerColor ?? palette.primary)
        : palette.mutedForeground;
    final Color weekdayColor =
        Color.lerp(restingWeekday, onFill, covered) ?? restingWeekday;

    final FontWeight weight = covered > 0.5 || state.today
        ? design.type.emphasisWeight
        : design.type.titleWeight;

    // A selection that appears instantly is a repaint; one that arrives over
    // 200ms is a control answering. Zero under reduced motion, not merely
    // faster.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : motion.scaled(motion.fast);

    return SizedBox(
      // The cell paints at the cell's size. Sizing the container to its own
      // text is what produced a fill narrower than the number above it — a
      // capsule pinched around two glyphs, in a row of otherwise unbounded
      // cells.
      width: resolved.cellWidth,
      child: AnimatedContainer(
        duration: duration,
        curve: motion.standard,
        constraints: BoxConstraints(minHeight: resolved.cellHeight ?? 0),
        decoration: BoxDecoration(
          color: fill && state.selected
              ? (resolved.selectedColor ?? palette.primary)
              : null,
          borderRadius: resolved.radius,
          // The chosen day lifts off the row. It is the one cell in the strip
          // allowed any depth, which is what keeps the depth meaningful.
          boxShadow: fill && state.selected
              ? design.elevation.resolve(
                  elevation: design.elevation.low,
                  brightness: Theme.of(context).brightness,
                  shadowColor: palette.overlay,
                )
              : const [],
        ),
        padding: EdgeInsets.symmetric(
          vertical: weekday == null ? space.xs : space.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (weekday != null) ...[
              Text(
                weekday!.toUpperCase(),
                style: resolved.weekdayStyle?.copyWith(color: weekdayColor),
                maxLines: 1,
              ),
              // A step, not a hairline: the weekday and the number were close
              // enough to read as one clipped word.
              SizedBox(height: space.xs),
            ],
            AnimatedDefaultTextStyle(
              duration: duration,
              curve: motion.standard,
              style: (resolved.dayStyle ?? const TextStyle()).copyWith(
                color: foreground,
                fontWeight: weight,
              ),
              child: Text(day, maxLines: 1),
            ),
            if (badgeSlot != null)
              // The badge takes the cell's own foreground. The slot is
              // caller-supplied content and the caller cannot know which cell
              // it lands in, so a badge styled for the card was drawn on the
              // accent fill of the selected day at 1.40:1 — the lowest ratio
              // anywhere in the kit.
              DefaultTextStyle.merge(
                style: (resolved.badgeStyle ?? const TextStyle()).copyWith(
                  color: foreground,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: badgeSlot!,
                ),
              ),
            if (badgeSlot == null)
              // Decorative: 'today' is already in the cell's spoken label.
              //
              // The slot is reserved in every cell, not only today's. A dot
              // added to one cell of a centred column lifts that cell's number
              // a few pixels above the six beside it, and a row of numbers off
              // its own baseline is the kind of wrongness a person feels
              // without locating.
              ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(top: space.hairline),
                  child: SizedBox(
                    width: marker,
                    height: marker,
                    child: state.today
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  Color.lerp(
                                    resolved.todayMarkerColor ??
                                        palette.primary,
                                    onFill,
                                    covered,
                                  ) ??
                                  palette.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
