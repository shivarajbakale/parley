import 'package:flutter/material.dart';

/// The span the recap covers. The control at the top of [InsightPage] switches
/// between them, and every figure on the screen is derived from the one that
/// is selected — the headline, the plot, the sentence and the breakdown all
/// move together, because a recap whose chart changes while its headline does
/// not is a recap nobody trusts twice.
enum InsightPeriod { week, month }

/// One row of the breakdown: a named part of the same total the headline is.
@immutable
class InsightSlice {
  const InsightSlice({required this.label, required this.minutes});

  final String label;

  /// Minutes, so the screen owns the formatting rather than the fixture. A
  /// fixture that ships "2h 40m" as a string cannot be summed, and the total
  /// under the breakdown would then be a fourth number typed by hand.
  final int minutes;
}

/// Everything one period of the recap is.
///
/// Assembled here rather than in the widget for the reason every demo fixture
/// in this directory is: the screen is the thing being demonstrated, and a
/// screen holding its own numbers reads as a screen that could not exist
/// without them.
@immutable
class InsightRecap {
  const InsightRecap({
    required this.period,
    required this.span,
    required this.minutes,
    required this.previousMinutes,
    required this.labels,
    required this.values,
    required this.reading,
    required this.slices,
  });

  final InsightPeriod period;

  /// The dates the figure covers, written out. The archetype's third rule: a
  /// figure whose denominator is a guess is one the reader quietly distrusts.
  final String span;

  final int minutes;
  final int previousMinutes;

  /// One label per plotted point, along the bottom axis.
  final List<String> labels;

  /// One value per label, in minutes.
  final List<double> values;

  /// The single sentence of interpretation. Not generated: the whole point of
  /// the archetype is that somebody decided what the numbers mean, and a
  /// template sentence with a number substituted into it is the chart read
  /// aloud rather than a reading of it.
  final String reading;

  final List<InsightSlice> slices;

  /// The change against the period before, as a whole percentage. Signed, so
  /// the screen can pick the trend without comparing the two totals a second
  /// time.
  int get deltaPercent => previousMinutes == 0
      ? 0
      : (((minutes - previousMinutes) / previousMinutes) * 100).round();

  /// The delta as the chip beside the figure reads it: `+18%`, `−14%`.
  ///
  /// Short on purpose. `DSStatTile`'s delta sits on one line with the value,
  /// and a sentence there is a sentence that ellipsises at the first reader
  /// who enlarges their type — which is why the *words* of the comparison are
  /// a line of their own underneath rather than a longer label here.
  String get deltaBadge =>
      '${deltaPercent >= 0 ? '+' : '\u2212'}${deltaPercent.abs()}%';

  /// The busiest slice, which is what the section header's supporting line
  /// names. Derived rather than stored so it cannot disagree with the rows
  /// underneath it.
  InsightSlice get leadingSlice =>
      slices.reduce((a, b) => b.minutes > a.minutes ? b : a);
}

/// `252` becomes `4h 12m`, and `40` stays `40m`.
///
/// The archetype's first rule is that the headline is in the user's units, and
/// units are a formatting decision rather than a data one — the fixture holds
/// minutes so every figure on the screen is summable, and this is the single
/// place they become something a person reads.
String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}

const _weekRecap = InsightRecap(
  period: InsightPeriod.week,
  span: 'Mon 25 – Sun 31 August',
  minutes: 252,
  previousMinutes: 214,
  labels: <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  values: <double>[24, 71, 38, 12, 46, 33, 28],
  reading:
      'Tuesday carried the week — one long evening was more than Thursday, '
      'Friday and Saturday together.',
  slices: <InsightSlice>[
    InsightSlice(label: 'Guides', minutes: 118),
    InsightSlice(label: 'Design', minutes: 79),
    InsightSlice(label: 'Modules', minutes: 55),
  ],
);

const _monthRecap = InsightRecap(
  period: InsightPeriod.month,
  span: '1 – 31 August',
  minutes: 946,
  previousMinutes: 1102,
  labels: <String>['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5'],
  values: <double>[188, 264, 141, 201, 152],
  reading:
      'August fell behind July, and all of the gap is week three — the week '
      'nothing new was started.',
  slices: <InsightSlice>[
    InsightSlice(label: 'Guides', minutes: 402),
    InsightSlice(label: 'Design', minutes: 311),
    InsightSlice(label: 'Modules', minutes: 233),
  ],
);

/// The recap for [period].
InsightRecap recapFor(InsightPeriod period) => switch (period) {
  InsightPeriod.week => _weekRecap,
  InsightPeriod.month => _monthRecap,
};

/// What the period control's segments are called.
String periodLabel(InsightPeriod period) => switch (period) {
  InsightPeriod.week => 'This week',
  InsightPeriod.month => 'This month',
};

/// What the delta is measured against, in words. Part of the headline block
/// rather than a caption under the chart: the archetype's rule is that the
/// comparison stays beside the figure, and a delta with no named baseline is
/// a percentage nobody can check.
String comparisonLabel(InsightRecap recap) {
  final delta = recap.deltaPercent;
  final direction = delta >= 0 ? 'more' : 'less';
  final against = switch (recap.period) {
    InsightPeriod.week => 'last week',
    InsightPeriod.month => 'July',
  };
  return '${delta.abs()}% $direction than $against';
}

/// The comparison and the span on one line, under the figure.
///
/// Both of the archetype's supporting facts in one wrapping paragraph rather
/// than two ellipsising chips: the baseline the percentage is measured against
/// and the dates it covers are the two things a reader checks before they
/// believe the number, and neither may be the casualty of a larger type size.
String supportingLine(InsightRecap recap) =>
    '${comparisonLabel(recap)}  \u00b7  ${recap.span}';
