import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/utils/recurrence.dart';

/// The arithmetic behind "does this happen today?".
///
/// A recurring event is drawn by a rule nobody looks at again, so its defects
/// are silent: a series that quietly stops, a monthly booking that lands on
/// the 1st because February has no 31st, a weekly rule that counts the days
/// before it started. Each of those is a test here.
void main() {
  // A Thursday, which is what the weekly cases are written against.
  final DateTime start = DateTime(2026, 3, 12);

  DateTime march(int day) => DateTime(2026, 3, day);

  group('once', () {
    test('happens on its own date and on no other', () {
      expect(Recurrence.once.occursOn(start, march(12)), isTrue);
      expect(Recurrence.once.occursOn(start, march(13)), isFalse);
      expect(Recurrence.once.occursOn(start, march(19)), isFalse);
    });

    test('ignores the time of day on either side', () {
      final DateTime startedAt = DateTime(2026, 3, 12, 9, 30);
      expect(
        Recurrence.once.occursOn(startedAt, DateTime(2026, 3, 12, 23, 59)),
        isTrue,
      );
    });
  });

  group('daily', () {
    const daily = Recurrence(frequency: RecurrenceFrequency.daily);
    const everyThird = Recurrence(
      frequency: RecurrenceFrequency.daily,
      interval: 3,
    );

    test('every day means every day, including across a month boundary', () {
      expect(daily.occursOn(start, march(13)), isTrue);
      expect(daily.occursOn(start, DateTime(2026, 4, 1)), isTrue);
      expect(daily.occursOn(start, DateTime(2027, 1, 1)), isTrue);
    });

    test('never before the day it starts', () {
      expect(daily.occursOn(start, march(11)), isFalse);
    });

    test('an interval skips the days between', () {
      expect(everyThird.occursOn(start, march(15)), isTrue);
      expect(everyThird.occursOn(start, march(13)), isFalse);
      expect(everyThird.occursOn(start, march(14)), isFalse);
      // And it stays in step over a long run, which is the property a
      // duration-based implementation loses at a clock change.
      expect(everyThird.occursOn(start, DateTime(2026, 6, 10)), isTrue);
    });
  });

  group('weekly', () {
    const weekly = Recurrence(frequency: RecurrenceFrequency.weekly);

    test('with no days chosen, it lands on the day it started on', () {
      expect(weekly.occursOn(start, march(19)), isTrue);
      expect(weekly.occursOn(start, march(26)), isTrue);
      // The day after is a Friday, and this is a Thursday series.
      expect(weekly.occursOn(start, march(13)), isFalse);
    });

    test('every other week skips the week between', () {
      const fortnightly = Recurrence(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );
      expect(fortnightly.occursOn(start, march(26)), isTrue);
      expect(fortnightly.occursOn(start, march(19)), isFalse);
    });

    test('the days before the start in its own week are not occurrences', () {
      // Tuesdays and Thursdays, starting on a Thursday: the Tuesday two days
      // earlier is in the same week and is not part of the series.
      const twiceAWeek = Recurrence(
        frequency: RecurrenceFrequency.weekly,
        weekdays: <int>{DateTime.tuesday, DateTime.thursday},
      );
      expect(twiceAWeek.occursOn(start, march(10)), isFalse);
      expect(twiceAWeek.occursOn(start, march(17)), isTrue);
      expect(twiceAWeek.occursOn(start, march(19)), isTrue);
      expect(twiceAWeek.occursOn(start, march(18)), isFalse);
    });
  });

  group('monthly', () {
    test('the same day of the month, every month', () {
      const monthly = Recurrence(frequency: RecurrenceFrequency.monthly);
      expect(monthly.occursOn(start, DateTime(2026, 4, 12)), isTrue);
      expect(monthly.occursOn(start, DateTime(2027, 3, 12)), isTrue);
      expect(monthly.occursOn(start, DateTime(2026, 4, 13)), isFalse);
    });

    test('a month too short for the day is skipped, not slid', () {
      // The 31st of January. February has no 31st and neither has April, and
      // an event that appears on the 1st of March is an event the user never
      // asked for.
      final DateTime last = DateTime(2026, 1, 31);
      const monthly = Recurrence(frequency: RecurrenceFrequency.monthly);
      expect(monthly.occursOn(last, DateTime(2026, 3, 1)), isFalse);
      expect(monthly.occursOn(last, DateTime(2026, 3, 31)), isTrue);
      expect(monthly.occursOn(last, DateTime(2026, 5, 31)), isTrue);

      final List<DateTime> spring = monthly.occurrencesBetween(
        last,
        DateTime(2026, 2, 1),
        DateTime(2026, 5, 1),
      );
      expect(spring, <DateTime>[DateTime(2026, 3, 31)]);
    });
  });

  group('an end', () {
    test('until includes the day it names and excludes the next', () {
      final Recurrence weekly = Recurrence(
        frequency: RecurrenceFrequency.weekly,
        until: march(26),
      );
      expect(weekly.occursOn(start, march(26)), isTrue);
      expect(weekly.occursOn(start, DateTime(2026, 4, 2)), isFalse);
    });

    test('a count includes the first occurrence', () {
      const three = Recurrence(frequency: RecurrenceFrequency.weekly, count: 3);
      expect(three.occursOn(start, march(12)), isTrue);
      expect(three.occursOn(start, march(19)), isTrue);
      expect(three.occursOn(start, march(26)), isTrue);
      expect(three.occursOn(start, DateTime(2026, 4, 2)), isFalse);
    });

    test('a count over two days a week counts occurrences, not weeks', () {
      // Tuesdays and Thursdays, four times, from a Thursday: Thu 12, Tue 17,
      // Thu 19, Tue 24 — and then it stops, mid-week.
      const four = Recurrence(
        frequency: RecurrenceFrequency.weekly,
        weekdays: <int>{DateTime.tuesday, DateTime.thursday},
        count: 4,
      );
      expect(
        four.occurrencesBetween(start, march(1), DateTime(2026, 4, 30)),
        <DateTime>[march(12), march(17), march(19), march(24)],
      );
    });
  });

  group('the dates a series lands on', () {
    test('are the ones in the window, and none before it', () {
      const weekly = Recurrence(frequency: RecurrenceFrequency.weekly);
      expect(weekly.occurrencesBetween(start, march(18), march(31)), <DateTime>[
        march(19),
        march(26),
      ]);
    });

    test('a window that ends before the series starts is empty', () {
      const daily = Recurrence(frequency: RecurrenceFrequency.daily);
      expect(daily.occurrencesBetween(start, march(1), march(11)), isEmpty);
    });
  });

  group('the rule in words', () {
    test('says what it will do, and when it stops', () {
      expect(Recurrence.once.describe(start), 'Once, on Thursday 12 March');
      expect(
        const Recurrence(frequency: RecurrenceFrequency.daily).describe(start),
        'Every day',
      );
      expect(
        const Recurrence(
          frequency: RecurrenceFrequency.daily,
          interval: 3,
        ).describe(start),
        'Every 3 days',
      );
      expect(
        const Recurrence(frequency: RecurrenceFrequency.weekly).describe(start),
        'Every week on Thursday',
      );
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          weekdays: const <int>{DateTime.tuesday, DateTime.thursday},
          until: march(26),
        ).describe(start),
        'Every 2 weeks on Tuesday and Thursday, until 26 March',
      );
      expect(
        const Recurrence(
          frequency: RecurrenceFrequency.monthly,
          count: 6,
        ).describe(start),
        'Every month on the 12th, 6 times',
      );
      expect(
        const Recurrence(
          frequency: RecurrenceFrequency.monthly,
        ).describe(DateTime(2026, 3, 3)),
        'Every month on the 3rd',
      );
    });
  });
}
