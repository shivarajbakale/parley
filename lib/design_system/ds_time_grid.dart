// ds-tier: 1 — atom

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_text.dart';
import 'package:parley_android/design_system/ds_component_style.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// One thing on a day, between two times.
@immutable
class DSTimeSlot {
  const DSTimeSlot({
    required this.start,
    required this.end,
    required this.title,
    this.subtitle,
    this.tone = DSTone.neutral,
    this.repeats = false,
    this.onTap,
  });

  final TimeOfDay start;
  final TimeOfDay end;

  final String title;

  /// The room, the attendee, the location. Drawn only when the slot is tall
  /// enough to hold a second line without clipping the first.
  final String? subtitle;

  /// What kind of thing it is, in the kit's five words. A held slot is
  /// `neutral`; a clash the app has detected is `error`.
  final DSTone tone;

  /// Whether this is one occurrence of a series.
  ///
  /// Drawn as a glyph on the title's own line rather than left to the
  /// subtitle: a fifteen-minute booking has no room for a second line, and a
  /// recurring standup that looks exactly like a one-off is the one the
  /// reader moves once and finds again next week. The words belong in
  /// [subtitle], which the semantics label carries whether or not there was
  /// room to draw it.
  final bool repeats;

  final VoidCallback? onTap;

  int get startMinutes => start.hour * 60 + start.minute;

  /// Midnight at the end of the day reads as 24:00, not 00:00 — otherwise an
  /// event that runs to the end of the day has a negative length.
  int get endMinutes {
    final raw = end.hour * 60 + end.minute;
    return raw <= startMinutes ? 24 * 60 : raw;
  }

  int get lengthMinutes => endMinutes - startMinutes;
}

/// How a day looks, at every layer of the resolution chain.
@immutable
class DSTimeGridStyle extends DSComponentStyle<DSTimeGridStyle> {
  const DSTimeGridStyle({
    this.hourHeight,
    this.axisWidth,
    this.minSlotHeight,
    this.minLaneWidth,
    this.gap,
    this.radius,
    this.hairlineColor,
    this.hourStyle,
    this.hourColor,
    this.titleStyle,
    this.subtitleStyle,
    this.nowColor,
  });

  /// One hour of the day, in points. Everything else on the grid is derived
  /// from it, which is why it is the only size a caller usually changes.
  final double? hourHeight;

  /// The column the hour labels sit in.
  final double? axisWidth;

  /// A slot is never drawn shorter than this, whatever its length says. A
  /// fifteen-minute event at an honest scale is sixteen points tall — under
  /// the tap-target floor, and unreadable besides.
  final double? minSlotHeight;

  /// A lane is never drawn narrower than this. Two bookings at the same
  /// hour split the width between them, and on a narrow phone at a large
  /// text scale that split is narrower than one word of the title — the
  /// baseline read "Desi" where the booking said "Design review". Past this
  /// floor the day scrolls sideways instead, because the archetype's rule is
  /// that both bookings are readable, not that both are on the screen at once.
  final double? minLaneWidth;

  /// Between two slots that share an hour.
  final double? gap;

  final double? radius;
  final Color? hairlineColor;

  final TextStyle? hourStyle;
  final Color? hourColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// The line across the grid at [DSTimeGrid.now].
  final Color? nowColor;

  @override
  DSTimeGridStyle merge(DSTimeGridStyle? other) {
    if (other == null) return this;
    return DSTimeGridStyle(
      hourHeight: other.hourHeight ?? hourHeight,
      axisWidth: other.axisWidth ?? axisWidth,
      minSlotHeight: other.minSlotHeight ?? minSlotHeight,
      minLaneWidth: other.minLaneWidth ?? minLaneWidth,
      gap: other.gap ?? gap,
      radius: other.radius ?? radius,
      hairlineColor: other.hairlineColor ?? hairlineColor,
      hourStyle: other.hourStyle ?? hourStyle,
      hourColor: other.hourColor ?? hourColor,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      nowColor: other.nowColor ?? nowColor,
    );
  }

  @override
  DSTimeGridStyle copyWith({
    double? hourHeight,
    double? axisWidth,
    double? minSlotHeight,
    double? minLaneWidth,
    double? gap,
    double? radius,
    Color? hairlineColor,
    TextStyle? hourStyle,
    Color? hourColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    Color? nowColor,
  }) => DSTimeGridStyle(
    hourHeight: hourHeight ?? this.hourHeight,
    axisWidth: axisWidth ?? this.axisWidth,
    minSlotHeight: minSlotHeight ?? this.minSlotHeight,
    minLaneWidth: minLaneWidth ?? this.minLaneWidth,
    gap: gap ?? this.gap,
    radius: radius ?? this.radius,
    hairlineColor: hairlineColor ?? this.hairlineColor,
    hourStyle: hourStyle ?? this.hourStyle,
    hourColor: hourColor ?? this.hourColor,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    nowColor: nowColor ?? this.nowColor,
  );

  @override
  DSTimeGridStyle lerp(DSTimeGridStyle? other, double t) {
    if (other == null) return this;
    return DSTimeGridStyle(
      hourHeight: lerpDouble(hourHeight, other.hourHeight, t),
      axisWidth: lerpDouble(axisWidth, other.axisWidth, t),
      minSlotHeight: lerpDouble(minSlotHeight, other.minSlotHeight, t),
      minLaneWidth: lerpDouble(minLaneWidth, other.minLaneWidth, t),
      gap: lerpDouble(gap, other.gap, t),
      radius: lerpDouble(radius, other.radius, t),
      hairlineColor: Color.lerp(hairlineColor, other.hairlineColor, t),
      hourStyle: TextStyle.lerp(hourStyle, other.hourStyle, t),
      hourColor: Color.lerp(hourColor, other.hourColor, t),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      nowColor: Color.lerp(nowColor, other.nowColor, t),
    );
  }

  static DSTimeGridStyle resolve(BuildContext context, [DSTimeGridStyle? own]) {
    final design = context.design;
    final space = design.space;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return resolveStyle(
      context: context,
      specDefaults: DSTimeGridStyle(
        // Two of the largest step: a half-hour then clears the tap-target
        // floor on its own, which is the shortest slot most calendars have.
        hourHeight: space.xxxl * 2,
        // Wider than the chart axis it was borrowed from: `10:00 AM` wrapped
        // there, and it wrapped mid-number — `10:0` over `0 AM`.
        axisWidth: space.xxxl + space.xl,
        minSlotHeight: design.component.minTapTarget,
        // Wide enough for the longest word a slot title usually holds. Below
        // it the lanes stop splitting and the grid scrolls.
        minLaneWidth: space.xxxl * 2,
        gap: space.hairline,
        radius: context.radiusOf(AppShape.control),
        hairlineColor: palette.borderSoft,
        hourStyle: text.labelSmall,
        hourColor: palette.mutedForeground,
        titleStyle: DSTextRole.control.styleOf(context),
        subtitleStyle: text.labelSmall,
        nowColor: palette.destructive,
      ),
      own: own,
    );
  }
}

/// A day as a column of hours, with what is booked drawn on it.
///
/// **Use when** the question is *when*, and the answer is read from the shape
/// of the day: where the gaps are, what runs long, what collides.
/// **Instead:** `DSListTile` rows under a `DSSectionHeader` when the question
/// is *what* — an agenda of five things spread over ten hours is nine hours of
/// empty grid, and the list says the same thing in a fifth of the height.
/// `DSDateStrip` is what picks the day this draws.
///
/// Two things it does that a hand-rolled grid usually does not. Slots that
/// overlap are laid **side by side** rather than stacked, because a booking
/// hidden under another booking is the one the user double-books. And the
/// window grows to fit: a slot outside [startHour]–[endHour] moves the edge
/// rather than being clipped, because an event drawn nowhere is worse than a
/// grid that scrolls further than it meant to.
class DSTimeGrid extends StatelessWidget {
  const DSTimeGrid({
    super.key,
    required this.slots,
    this.startHour = 8,
    this.endHour = 20,
    this.now,
    this.nowLabel = 'Now',
    this.style,
  }) : assert(
         startHour >= 0 && endHour <= 24 && startHour < endHour,
         'the window runs from startHour to endHour inside one day',
       );

  final List<DSTimeSlot> slots;

  /// The window the day opens on. Both are hints: a slot outside them widens
  /// the window rather than being cut.
  final int startHour;
  final int endHour;

  /// Drawn as a line across the grid, and only when it is given. The widget
  /// never reads the clock itself — a component that did could not be
  /// photographed twice and compared.
  final TimeOfDay? now;

  final String nowLabel;

  final DSTimeGridStyle? style;

  /// What a text style's line box is when it does not say. Material's own
  /// default for a paragraph of one line, and only ever a fallback here.
  static const _defaultLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final resolved = DSTimeGridStyle.resolve(context, style);
    // The hour's height and the axis' width are type, not chrome: at a
    // doubled text scale a fixed 96-point hour holds half a title and a fixed
    // 72-point axis cuts "10:00 AM" to "10:00". Scaled, the day is twice as
    // tall and scrolls twice as far, which is what every platform's contract
    // at that setting says should happen. `DSDateStrip` scales its cells the
    // same way and for the same reason.
    final scaler = MediaQuery.textScalerOf(context);
    final hourHeight = scaler.scale(resolved.hourHeight!);
    final axisWidth = scaler.scale(resolved.axisWidth!);
    final localizations = MaterialLocalizations.of(context);

    final first = slots.isEmpty
        ? startHour
        : math.min(
            startHour,
            slots.map((s) => s.startMinutes ~/ 60).reduce(math.min),
          );
    final last = slots.isEmpty
        ? endHour
        : math.max(
            endHour,
            slots.map((s) => (s.endMinutes / 60).ceil()).reduce(math.max),
          );
    final windowStart = first * 60;
    final height = (last - first) * hourHeight;

    double yOf(int minutes) => (minutes - windowStart) / 60 * hourHeight;

    final columns = _columns(slots);

    // The now line and an hour label can land on the same few points, and at
    // a doubled text scale they overlap outright — `ui-probe` measured "Now"
    // drawn through "10:00 AM" by seven points on the schedule demo. The line
    // wins: it is the one thing on the axis that is only true for a moment,
    // and the hour it lands on gives up its label.
    final int? nowMinutes = now == null ? null : now!.hour * 60 + now!.minute;
    // The label's line box, not its point size: both labels are centred on
    // their line, so they touch as soon as the gap is smaller than one line
    // — plus a hair's breadth, so they do not merely abut.
    final double labelHeight =
        MediaQuery.textScalerOf(context).scale(
              resolved.hourStyle?.fontSize ??
                  context.design.component.iconSizeMicro,
            ) *
            (resolved.hourStyle?.height ?? _defaultLineHeight) +
        context.design.space.xs;
    bool hourIsUnderNow(int hour) {
      if (nowMinutes == null) return false;
      return (yOf(hour * 60) - yOf(nowMinutes)).abs() < labelHeight;
    }

    // How wide the day wants to be: the axis, plus a lane per clash at the
    // floor below which a lane is narrower than a word.
    final int maxLanes = columns.values.isEmpty
        ? 1
        : columns.values.map((_Lane l) => l.lanes).reduce(math.max);
    final double wanted =
        axisWidth +
        maxLanes * scaler.scale(resolved.minLaneWidth!) +
        resolved.gap! * (maxLanes - 1);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.max(constraints.maxWidth, wanted);
        final Widget grid = SizedBox(
          width: width,
          height: height,
          child: _stack(
            context,
            resolved,
            first: first,
            last: last,
            axisWidth: axisWidth,
            yOf: yOf,
            columns: columns,
            windowStart: windowStart,
            hourIsUnderNow: hourIsUnderNow,
            localizations: localizations,
          ),
        );
        if (width <= constraints.maxWidth) return grid;
        // Sideways rather than squeezed. A `ListView` because `ui-probe`'s
        // `overlap` rule reads a clip from the render object and only a real
        // viewport has one.
        return SizedBox(
          height: height,
          child: ListView(scrollDirection: Axis.horizontal, children: [grid]),
        );
      },
    );
  }

  Widget _stack(
    BuildContext context,
    DSTimeGridStyle resolved, {
    required int first,
    required int last,
    required double axisWidth,
    required double Function(int) yOf,
    required Map<DSTimeSlot, _Lane> columns,
    required int windowStart,
    required bool Function(int) hourIsUnderNow,
    required MaterialLocalizations localizations,
  }) {
    return Stack(
      children: [
        for (var h = first; h <= last; h++)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: yOf(h * 60),
            child: _HourLine(
              label: h == last || hourIsUnderNow(h)
                  ? ''
                  : localizations.formatTimeOfDay(
                      TimeOfDay(hour: h % 24, minute: 0),
                    ),
              axisWidth: axisWidth,
              style: resolved,
            ),
          ),
        for (final slot in slots)
          _positioned(context, slot, columns[slot]!, resolved, yOf, axisWidth),
        if (now != null &&
            now!.hour * 60 + now!.minute >= windowStart &&
            now!.hour * 60 + now!.minute <= last * 60)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: yOf(now!.hour * 60 + now!.minute),
            child: _NowLine(
              axisWidth: axisWidth,
              label: nowLabel,
              style: resolved,
            ),
          ),
      ],
    );
  }

  Widget _positioned(
    BuildContext context,
    DSTimeSlot slot,
    _Lane lane,
    DSTimeGridStyle resolved,
    double Function(int) yOf,
    // The scaled width, not the style's: the slots start where the axis ends,
    // and reading the unscaled number here drew "10:00 AM" through a booking
    // at a 1.3x text scale.
    double axisWidth,
  ) {
    // Its own cluster's lane count, never the day's maximum: one clash at ten
    // o'clock does not make the two o'clock booking half a screen wide.
    final lanes = lane.lanes;
    final gap = resolved.gap!;
    final top = yOf(slot.startMinutes);
    final rawHeight = yOf(slot.endMinutes) - top;
    // The floor is on the drawn box, not on the row: the gap below the slot
    // comes out of this height, and a floor applied before it left the box a
    // gap short of the tap target.
    final height = math.max(rawHeight, resolved.minSlotHeight! + gap);

    return Positioned(
      top: top,
      height: height,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: axisWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final laneWidth =
                (constraints.maxWidth - gap * (lanes - 1)) / lanes;
            return Stack(
              children: [
                PositionedDirectional(
                  start: lane.index * (laneWidth + gap),
                  width: laneWidth,
                  top: 0,
                  bottom: gap,
                  child: _Slot(slot: slot, style: resolved),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Which lane each slot takes, and how many lanes its cluster needs.
  ///
  /// Greedy by start time: a slot takes the first lane whose last occupant has
  /// already finished. Every slot in one overlapping run reports the run's
  /// lane count, so two clashing bookings are each half the width and both
  /// are visible.
  static Map<DSTimeSlot, _Lane> _columns(List<DSTimeSlot> slots) {
    if (slots.isEmpty) return const {};
    final sorted = [...slots]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final out = <DSTimeSlot, _Lane>{};
    var cluster = <DSTimeSlot>[];
    var clusterEnd = -1;
    final laneEnds = <int>[];

    void closeCluster() {
      for (final s in cluster) {
        out[s] = _Lane(out[s]!.index, laneEnds.length);
      }
      cluster = [];
      laneEnds.clear();
      clusterEnd = -1;
    }

    for (final s in sorted) {
      if (cluster.isNotEmpty && s.startMinutes >= clusterEnd) closeCluster();
      var index = laneEnds.indexWhere((end) => end <= s.startMinutes);
      if (index == -1) {
        laneEnds.add(s.endMinutes);
        index = laneEnds.length - 1;
      } else {
        laneEnds[index] = s.endMinutes;
      }
      out[s] = _Lane(index, 1);
      cluster.add(s);
      clusterEnd = math.max(clusterEnd, s.endMinutes);
    }
    if (cluster.isNotEmpty) closeCluster();
    return out;
  }
}

@immutable
class _Lane {
  const _Lane(this.index, this.lanes);
  final int index;
  final int lanes;
}

class _HourLine extends StatelessWidget {
  const _HourLine({
    required this.label,
    required this.axisWidth,
    required this.style,
  });

  final String label;
  final double axisWidth;
  final DSTimeGridStyle style;

  @override
  Widget build(BuildContext context) {
    // The hour rule is furniture. A screen reader that stops on twelve of
    // them before reaching the first booking is reading the graph paper.
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: axisWidth,
            child: Text(
              label,
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: style.hourStyle?.copyWith(color: style.hourColor),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: context.design.component.hairlineWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(color: style.hairlineColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.axisWidth,
    required this.label,
    required this.style,
  });

  final double axisWidth;
  final String label;
  final DSTimeGridStyle style;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    return Semantics(
      label: label,
      child: Row(
        children: [
          SizedBox(
            width: axisWidth,
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: style.hourStyle?.copyWith(color: style.nowColor),
            ),
          ),
          SizedBox(width: space.xs),
          Expanded(
            child: SizedBox(
              height: context.design.component.controlStroke,
              child: DecoratedBox(
                decoration: BoxDecoration(color: style.nowColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot, required this.style});

  /// Only reached when a text style arrives with no size on it, which the
  /// theme never does — the fallbacks exist so the measurement below cannot
  /// throw on an app that overrode the style with a bare `TextStyle()`.
  static const double _fallbackFontSize = 14;
  static const double _fallbackLineHeight = 1.3;

  final DSTimeSlot slot;
  final DSTimeGridStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final space = context.design.space;
    final localizations = MaterialLocalizations.of(context);

    final (ground, accent) = switch (slot.tone) {
      DSTone.neutral => (palette.secondary, palette.primary),
      DSTone.info => (palette.tint(palette.primary), palette.primary),
      DSTone.success => (palette.tint(palette.success), palette.success),
      DSTone.warning => (palette.tint(palette.warning), palette.warning),
      DSTone.error => (palette.tint(palette.destructive), palette.destructive),
    };
    final neutral = slot.tone == DSTone.neutral;
    final fill = DSToneWash.fill(
      container: ground,
      surface: palette.card,
      neutral: neutral,
    );

    final label =
        '${slot.title}, '
        '${localizations.formatTimeOfDay(slot.start)} to '
        '${localizations.formatTimeOfDay(slot.end)}'
        '${slot.subtitle == null ? '' : ', ${slot.subtitle}'}';

    return Semantics(
      button: slot.onTap != null,
      label: label,
      excludeSemantics: true,
      // Press feedback, the focus ring and the haptic come from the kit's one
      // pressable rather than from a bare gesture detector: a booking that
      // does not move under a finger is one the user taps twice.
      child: DSPressable(
        enabled: slot.onTap != null,
        focusShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(style.radius!)),
        ),
        child: GestureDetector(
          onTap: slot.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.all(Radius.circular(style.radius!)),
              border: BorderDirectional(
                // The tone is on the leading edge rather than around the whole
                // slot: a run of outlined blocks reads as a table, and the edge
                // is what the eye scans down.
                start: BorderSide(
                  color: accent,
                  width: context.design.component.controlStroke,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: space.sm,
                vertical: space.xs,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The subtitle is drawn only when the box can hold a second
                  // line. A half-hour booking at a 2.0 text scale cannot, and
                  // the version that drew it anyway overflowed its own slot
                  // by six points — which the golden caught and the eye would
                  // not have, because the striped bar is a debug-build thing.
                  final scaler = MediaQuery.textScalerOf(context);
                  double lineOf(TextStyle? s) =>
                      scaler.scale(s?.fontSize ?? _fallbackFontSize) *
                      (s?.height ?? _fallbackLineHeight);

                  final titleLine = lineOf(style.titleStyle);
                  final subtitleLine = slot.subtitle == null
                      ? 0.0
                      : lineOf(style.subtitleStyle);
                  final room = constraints.maxHeight;

                  // The title gets a second line before the subtitle gets
                  // its first. At 320pt a clashing booking is 87 points
                  // wide, and `ui-probe` reads an ellipsis through the
                  // middle of "Design review" as content the reader came for
                  // being cut — which it is.
                  final titleMaxLines = room >= titleLine * 2 + subtitleLine
                      ? 2
                      : 1;
                  final showSubtitle =
                      slot.subtitle != null &&
                      room >= titleLine * titleMaxLines + subtitleLine;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                slot.title,
                                maxLines: titleMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: style.titleStyle?.copyWith(
                                  color: palette.foreground,
                                ),
                              ),
                            ),
                            if (slot.repeats) ...[
                              SizedBox(width: space.xs),
                              Icon(
                                Icons.repeat,
                                size: context.design.component.iconSizeMicro,
                                color: palette.mutedForeground,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showSubtitle)
                        Flexible(
                          child: Text(
                            slot.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.subtitleStyle?.copyWith(
                              color: palette.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
