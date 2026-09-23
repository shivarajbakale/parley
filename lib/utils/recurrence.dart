/// A repeat rule, and the arithmetic that answers "does this happen today?".
///
/// Pure Dart on purpose: no `material`, no `intl`, no clock. Everything here
/// is a function of the values passed in, so the same series expands the same
/// way in a test, in a golden and on a device in another timezone.
///
/// What it is for: an event happens first on a date, and a [Recurrence] says
/// whether it happens again. The event itself — its title, its hours, its
/// room — is the caller's; a rule that carried the event would be a calendar,
/// and this is the part of a calendar that is worth testing.
///
/// The three things that make recurrence a source of bugs, and what this does
/// about each:
///
///   * **A date is not an instant.** Adding 24 hours across a daylight-saving
///     boundary lands at 23:00 the previous day, and an event that quietly
///     stops happening in late March is the defect that reaches production.
///     Every comparison here is made on the calendar date, through
///     [_daysBetween], which counts days in UTC after dropping the time.
///   * **Months are not the same length.** The 31st of a month does not
///     happen in February. A monthly series skips the months that cannot hold
///     its day rather than sliding to the 1st, which is what the user asked
///     for and what every calendar the user has already used does.
///   * **An end is one rule or the other.** A series ends on a date or after
///     a number of occurrences, never both — two ends is two answers to "when
///     does this stop", and the one that fires first is an implementation
///     detail the user cannot see.
library;

/// How often a thing comes back.
enum RecurrenceFrequency {
  /// It does not. The event happens on its own date and nowhere else.
  once,
  daily,
  weekly,
  monthly,
}

/// The words a rule is written in.
///
/// Indexed the way `DateTime.weekday` and `DateTime.month` are — 1 is Monday
/// and 1 is January — so a caller never has to remember to subtract one in
/// two places. Public because the screens that write a date in words read the
/// same table: two tables drift, and a Thursday drawn as a Wednesday is the
/// kind of drift nobody reads in a diff.
const List<String> weekdayNames = <String>[
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> monthNames = <String>[
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A repeat rule: how often, on which days, and when it stops.
class Recurrence {
  const Recurrence({
    this.frequency = RecurrenceFrequency.once,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.until,
    this.count,
  }) : assert(interval >= 1, 'every zero weeks is a series with no members'),
       assert(count == null || count >= 1),
       assert(
         until == null || count == null,
         'a series ends on a date or after a number of times, never both',
       );

  /// The rule for a thing that happens once. The default, and the value a
  /// form starts on: repeating is the choice the user makes, not the one they
  /// have to undo.
  static const Recurrence once = Recurrence();

  final RecurrenceFrequency frequency;

  /// Every *n*th day, week or month. One unless the user says otherwise.
  final int interval;

  /// Which days of the week a weekly series lands on, as `DateTime.weekday`
  /// values. Empty means "the day the series starts on", which is what a
  /// weekly rule means before the user touches the day picker.
  ///
  /// Ignored by every other frequency: a daily rule that also carried
  /// weekdays would be two rules, and the second one would be invisible.
  final Set<int> weekdays;

  /// The last date the series may land on, inclusive. Null if it never ends.
  final DateTime? until;

  /// How many times it happens in total, counting the first. Null if it never
  /// ends.
  final int? count;

  bool get repeats => frequency != RecurrenceFrequency.once;

  Recurrence copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    int? count,
    bool clearUntil = false,
    bool clearCount = false,
  }) => Recurrence(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    until: clearUntil ? null : (until ?? this.until),
    count: clearCount ? null : (count ?? this.count),
  );

  /// Whether a series that first happens on [start] also happens on [day].
  ///
  /// Both are read as calendar dates; the time of day on either is ignored,
  /// because a rule is about which days a thing lands on and the hours belong
  /// to the event.
  bool occursOn(DateTime start, DateTime day) {
    final DateTime from = dateOnly(start);
    final DateTime on = dateOnly(day);
    if (on.isBefore(from)) return false;
    if (!repeats) return on == from;
    if (!_matchesPattern(from, on)) return false;

    final DateTime? last = until;
    if (last != null && on.isAfter(dateOnly(last))) return false;

    final int? limit = count;
    if (limit != null && _ordinal(from, on) >= limit) return false;

    return true;
  }

  /// Every date the series lands on between [from] and [to], inclusive.
  ///
  /// Walks the pattern rather than every day in the range, so asking a yearly
  /// question of a monthly series costs twelve steps rather than 365.
  List<DateTime> occurrencesBetween(
    DateTime start,
    DateTime from,
    DateTime to,
  ) {
    final DateTime first = dateOnly(start);
    final DateTime lower = dateOnly(from);
    final DateTime upper = dateOnly(to);
    if (upper.isBefore(first) || upper.isBefore(lower)) {
      return const <DateTime>[];
    }

    final List<DateTime> found = <DateTime>[];
    for (final DateTime candidate in _candidates(first, upper)) {
      // Both ends are the caller's, and a pattern walked by month can step
      // past the far one — a monthly series on the 31st offers May's while
      // the window closes on the 1st.
      if (candidate.isBefore(lower) || candidate.isAfter(upper)) continue;
      if (occursOn(first, candidate)) found.add(candidate);
    }
    return found;
  }

  /// The rule in words: "Every 2 weeks on Tuesday and Thursday, 6 times".
  ///
  /// A repeat rule the user cannot read is a repeat rule they find out about
  /// next Tuesday. The sentence is the screen's only honest statement of what
  /// is about to be created, so it is built here — beside the arithmetic it
  /// describes — rather than assembled at each call site.
  String describe(DateTime start) {
    if (!repeats) {
      final DateTime on = dateOnly(start);
      return 'Once, on ${weekdayNames[on.weekday]} ${on.day} '
          '${monthNames[on.month]}';
    }

    final String every = switch (frequency) {
      RecurrenceFrequency.once => '',
      RecurrenceFrequency.daily =>
        interval == 1 ? 'Every day' : 'Every $interval days',
      RecurrenceFrequency.weekly =>
        interval == 1 ? 'Every week' : 'Every $interval weeks',
      RecurrenceFrequency.monthly =>
        interval == 1 ? 'Every month' : 'Every $interval months',
    };

    final StringBuffer out = StringBuffer(every);
    if (frequency == RecurrenceFrequency.weekly) {
      out.write(' on ${_weekdayWords(start)}');
    } else if (frequency == RecurrenceFrequency.monthly) {
      out.write(' on the ${_ordinalWord(dateOnly(start).day)}');
    }

    final DateTime? last = until;
    final int? limit = count;
    if (last != null) {
      final DateTime end = dateOnly(last);
      out.write(', until ${end.day} ${monthNames[end.month]}');
    } else if (limit != null) {
      out.write(limit == 1 ? ', once' : ', $limit times');
    }
    return out.toString();
  }

  /// The same rule in the two or three words a booking can carry beside its
  /// title: "every Thursday", "every 2 weeks".
  String get shortLabel => switch (frequency) {
    RecurrenceFrequency.once => '',
    RecurrenceFrequency.daily =>
      interval == 1 ? 'daily' : 'every $interval days',
    RecurrenceFrequency.weekly =>
      interval == 1 ? 'weekly' : 'every $interval weeks',
    RecurrenceFrequency.monthly =>
      interval == 1 ? 'monthly' : 'every $interval months',
  };

  /// The days this weekly rule lands on, in week order, with the start day
  /// standing in when the user has not chosen any.
  Set<int> effectiveWeekdays(DateTime start) =>
      weekdays.isEmpty ? <int>{dateOnly(start).weekday} : weekdays;

  /// "Tuesday", "Tuesday and Thursday", "Monday, Wednesday and Friday".
  ///
  /// The list is spoken rather than abbreviated: a rule read out by a screen
  /// reader as "Mo, We, Fr" is a rule nobody heard.
  String _weekdayWords(DateTime start) {
    final List<String> names = (effectiveWeekdays(
      start,
    ).toList()..sort()).map((int day) => weekdayNames[day]).toList();
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  bool _matchesPattern(DateTime from, DateTime on) => switch (frequency) {
    RecurrenceFrequency.once => on == from,
    RecurrenceFrequency.daily => _daysBetween(from, on) % interval == 0,
    RecurrenceFrequency.weekly =>
      effectiveWeekdays(from).contains(on.weekday) &&
          _weeksBetween(from, on) % interval == 0,
    // The day of the month has to match, which is also why February has no
    // 31st: `DateTime(2026, 2, 31)` would roll into March, so the month is
    // walked rather than constructed.
    RecurrenceFrequency.monthly =>
      on.day == from.day && _monthsBetween(from, on) % interval == 0,
  };

  /// How many occurrences precede [on], counting from zero. Only asked when
  /// the series ends after a count.
  int _ordinal(DateTime from, DateTime on) => switch (frequency) {
    RecurrenceFrequency.once => 0,
    RecurrenceFrequency.daily => _daysBetween(from, on) ~/ interval,
    RecurrenceFrequency.weekly => _weeklyOrdinal(from, on),
    RecurrenceFrequency.monthly => _monthsBetween(from, on) ~/ interval,
  };

  /// A weekly series with three days a week has three occurrences per active
  /// week, and the first week is short: the days before the start are days
  /// the series had not begun on.
  int _weeklyOrdinal(DateTime from, DateTime on) {
    final List<int> days = effectiveWeekdays(from).toList()..sort();
    final int weeks = _weeksBetween(from, on) ~/ interval;
    final int before = days.where((int d) => d < from.weekday).length;
    final int index = days.indexOf(on.weekday);
    return weeks * days.length + index - before;
  }

  /// Candidate dates in pattern order, from the first occurrence to [upper].
  Iterable<DateTime> _candidates(DateTime first, DateTime upper) sync* {
    switch (frequency) {
      case RecurrenceFrequency.once:
        yield first;
      case RecurrenceFrequency.daily:
        for (DateTime d = first; !d.isAfter(upper); d = _addDays(d, interval)) {
          yield d;
        }
      case RecurrenceFrequency.weekly:
        final List<int> days = effectiveWeekdays(first).toList()..sort();
        // From the Monday of the first week, so every active day in that week
        // is offered — `occursOn` drops the ones before the series started.
        DateTime weekStart = _startOfWeek(first);
        while (!weekStart.isAfter(upper)) {
          for (final int weekday in days) {
            final DateTime day = _addDays(weekStart, weekday - 1);
            if (!day.isAfter(upper)) yield day;
          }
          weekStart = _addDays(weekStart, 7 * interval);
        }
      case RecurrenceFrequency.monthly:
        DateTime month = DateTime(first.year, first.month);
        while (!month.isAfter(upper)) {
          if (first.day <= _daysInMonth(month.year, month.month)) {
            yield DateTime(month.year, month.month, first.day);
          }
          month = DateTime(month.year, month.month + interval);
        }
    }
  }
}

/// The date, with the time dropped. The one conversion every comparison here
/// starts from.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whole days between two dates, counted in UTC.
///
/// `DateTime.difference` on local dates is 23 or 25 hours across a
/// daylight-saving boundary, and `inDays` truncates — so a daily series in
/// London stopped landing on the right day every spring. Dropping to UTC
/// makes every day 24 hours long, which is what a calendar means by "day".
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int _weeksBetween(DateTime a, DateTime b) =>
    _daysBetween(_startOfWeek(a), _startOfWeek(b)) ~/ 7;

int _monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + (b.month - a.month);

DateTime _startOfWeek(DateTime value) => _addDays(value, 1 - value.weekday);

/// Adds days by construction rather than by [Duration], for the same reason
/// [_daysBetween] counts in UTC.
DateTime _addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String _ordinalWord(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
