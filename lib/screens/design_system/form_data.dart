import 'package:flutter/foundation.dart';

/// The day the booking demo treats as today.
///
/// Fixed rather than [DateTime.now] because the goldens record this screen:
/// a date strip anchored to the wall clock repaints itself every midnight and
/// every recorded image is stale the next morning.
final DateTime demoBookingToday = DateTime(2026, 3, 2);

/// The account the demo is signed in as.
///
/// The name and the email are *defaults*, not questions: the app already knows
/// who is booking, so the first step opens with both filled in and the user
/// confirms them rather than typing them. Clearing one still fails validation
/// — a default is a starting point, not a bypass.
const String demoBookingName = 'Ada Lovelace';
const String demoBookingEmail = 'ada@example.com';

/// The days a desk can be booked on: the next ten the office is open, which
/// is as far ahead as a desk booking is worth planning.
///
/// A list rather than a range because the control is a select: ten values is
/// inside the band a select is for, and the weekend is absent rather than
/// present and disabled — a closed office is not an option the user failed
/// to qualify for.
final List<DateTime> demoBookingDays = _openDays(demoBookingToday, 10);

List<DateTime> _openDays(DateTime from, int count) {
  final days = <DateTime>[];
  var day = from;
  while (days.length < count) {
    if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
      days.add(day);
    }
    day = day.add(const Duration(days: 1));
  }
  return days;
}

/// When the booking starts. Three options, all visible, so the control is a
/// a DSSegmentedButton rather than a select.
enum ArrivalSlot { morning, afternoon, allDay }

/// The words each slot is offered under, and the hours it means.
extension ArrivalSlotCopy on ArrivalSlot {
  String get label => switch (this) {
    ArrivalSlot.morning => 'Morning',
    ArrivalSlot.afternoon => 'Afternoon',
    ArrivalSlot.allDay => 'All day',
  };

  String get hours => switch (this) {
    ArrivalSlot.morning => '08:00 – 13:00',
    ArrivalSlot.afternoon => '13:00 – 18:00',
    ArrivalSlot.allDay => '08:00 – 18:00',
  };
}

/// Where the desk is. Six of them: past four the options stop fitting a
/// segmented control, and short of twenty a select still scans, which is
/// exactly the band DSSelect is for.
enum DeskZone {
  quietWest,
  focusPods,
  teamNorth,
  standingBench,
  libraryLoft,
  boardroomAnnexe,
}

/// The label, the one line under it, and whether the zone can be picked.
extension DeskZoneCopy on DeskZone {
  String get label => switch (this) {
    DeskZone.quietWest => 'Quiet west',
    DeskZone.focusPods => 'Focus pods',
    DeskZone.teamNorth => 'Team north',
    DeskZone.standingBench => 'Standing bench',
    DeskZone.libraryLoft => 'Library loft',
    DeskZone.boardroomAnnexe => 'Boardroom annexe',
  };

  String get detail => switch (this) {
    DeskZone.quietWest => 'No calls. 14 desks by the window.',
    DeskZone.focusPods => 'One person, door shut. 6 pods.',
    DeskZone.teamNorth => 'Talk freely. 20 desks, two whiteboards.',
    DeskZone.standingBench => 'Height adjustable. 8 places.',
    DeskZone.libraryLoft => 'Silent. 10 places, no screens above 24 inch.',
    DeskZone.boardroomAnnexe => 'Being rewired until April.',
  };

  /// The one unavailable zone. A demo where every option is pickable never
  /// shows the disabled row, and a disabled row that does not say why is
  /// worse than a row that is absent.
  bool get available => this != DeskZone.boardroomAnnexe;
}

/// One of the things that can be added to a booking. A value type, not a
/// model: the demo has no repository and nothing to serialise, the same
/// pattern as `InboxItem` in the file next door.
@immutable
class BookingExtra {
  const BookingExtra({
    required this.id,
    required this.label,
    required this.detail,
  });

  /// Stable key. What the page holds in its selected set, and what the tests
  /// assert on.
  final String id;

  /// The row's own words.
  final String label;

  /// The line under the label — what it costs the user to say yes.
  final String detail;
}

/// The three extras the demo offers. Checkboxes rather than switches: a
/// switch means the change already happened, and nothing here happens until
/// the booking is confirmed.
const List<BookingExtra> demoBookingExtras = [
  BookingExtra(
    id: 'parking',
    label: 'Parking space',
    detail: 'Level 2, released 30 minutes after your arrival slot starts.',
  ),
  BookingExtra(
    id: 'monitor',
    label: 'Second monitor',
    detail: '27 inch, delivered to the desk before you arrive.',
  ),
  BookingExtra(
    id: 'guest',
    label: 'Guest pass',
    detail: 'One visitor, signed in at reception under your name.',
  ),
];

/// A desk this account already holds, for the panel on the first step.
///
/// The step asks who the desk is for and how many of you; the question it
/// raises and never answered is whether you already have one. Without this
/// the step was three fields and 223pt of white under them, which is what
/// `ui-probe`'s `dead-band` rule measured — `flutter-086`.
@immutable
class BookingHeld {
  const BookingHeld({
    required this.day,
    required this.zone,
    required this.slot,
  });

  final String day;
  final String zone;
  final ArrivalSlot slot;
}

/// The two desks the demo account already holds. Two rather than one: a
/// single row reads as a notice, and the panel is a list.
const List<BookingHeld> demoBookingsHeld = <BookingHeld>[
  BookingHeld(
    day: 'Wed 4 March',
    zone: 'Quiet west',
    slot: ArrivalSlot.morning,
  ),
  BookingHeld(
    day: 'Fri 6 March',
    zone: 'Focus pods',
    slot: ArrivalSlot.allDay,
  ),
];

/// How full a day is, for the panel on the second step.
///
/// A day picker that says only the date makes the reader pick blind. The
/// numbers are the answer to the question the choice is actually about.
@immutable
class BookingDayLoad {
  const BookingDayLoad({
    required this.taken,
    required this.total,
    required this.teammates,
  });

  final int taken;
  final int total;

  /// How many of the reader's own team are already in that day.
  final int teammates;

  double get share => total == 0 ? 0 : taken / total;

  /// The word for how it will feel, which is what the reader is asking.
  String get mood => switch (share) {
    < 0.4 => 'Quiet',
    < 0.75 => 'Filling up',
    _ => 'Nearly full',
  };
}

/// The load per day, by that day's position in [demoBookingDays].
///
/// A fixed list rather than a random draw: the goldens record this screen,
/// and a number that changes per run records a new baseline every run.
const List<BookingDayLoad> demoBookingLoad = <BookingDayLoad>[
  BookingDayLoad(taken: 9, total: 58, teammates: 2),
  BookingDayLoad(taken: 31, total: 58, teammates: 5),
  BookingDayLoad(taken: 44, total: 58, teammates: 7),
  BookingDayLoad(taken: 52, total: 58, teammates: 9),
  BookingDayLoad(taken: 17, total: 58, teammates: 3),
  BookingDayLoad(taken: 24, total: 58, teammates: 4),
  BookingDayLoad(taken: 38, total: 58, teammates: 6),
  BookingDayLoad(taken: 12, total: 58, teammates: 2),
  BookingDayLoad(taken: 47, total: 58, teammates: 8),
  BookingDayLoad(taken: 21, total: 58, teammates: 4),
];

/// What happens after Confirm, for the panel on the review step.
///
/// The review said what was chosen and nothing about what confirming does,
/// and the 311pt under it is where that question was sitting.
@immutable
class BookingNextStep {
  const BookingNextStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

const List<BookingNextStep> demoBookingNextSteps = <BookingNextStep>[
  BookingNextStep(
    title: 'A calendar invite',
    detail: 'Sent to everyone on the booking, with the zone in the location.',
  ),
  BookingNextStep(
    title: 'A door code',
    detail: 'Arrives an hour before your slot and lasts the day.',
  ),
  BookingNextStep(
    title: 'Free to cancel',
    detail: 'Until 09:00 on the day. After that the desk stays held.',
  ),
  // The fourth arrived with `flutter-087`. Giving every row the height
  // `ComponentSpec.listRowMinHeight` declares took eight points off each of
  // the three above, and the step lost the last of its scroll — the void this
  // panel had closed opened again 25 points wide. A reminder is the one thing
  // the reader could still not see from the review.
  BookingNextStep(
    title: 'A reminder',
    detail:
        'At 17:00 the day before, so a change of plan frees the desk for '
        'somebody else.',
  ),
];
