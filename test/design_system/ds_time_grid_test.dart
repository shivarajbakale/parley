import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The two claims that make this a grid rather than a stack of boxes: two
/// bookings at the same hour are both visible, and a booking outside the
/// window is still drawn. Both are the kind of defect that ships silently —
/// nothing crashes, an event is simply not there.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, home) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: home!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  ctx = context;
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  const morning = DSTimeSlot(
    start: TimeOfDay(hour: 10, minute: 0),
    end: TimeOfDay(hour: 11, minute: 0),
    title: 'Design review',
  );
  const clash = DSTimeSlot(
    start: TimeOfDay(hour: 10, minute: 30),
    end: TimeOfDay(hour: 11, minute: 30),
    title: 'Dentist',
  );

  group('two things at once', () {
    testWidgets('bookings that overlap are side by side, not stacked', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTimeGrid(slots: [morning, clash], startHour: 9, endHour: 13),
      );

      final a = tester.getRect(find.text('Design review'));
      final b = tester.getRect(find.text('Dentist'));
      expect(a.overlaps(b), isFalse, reason: 'one is hidden under the other');
      expect(a.left, lessThan(b.left));
    });

    testWidgets('a day with no clash gives the whole width to the slot', (
      tester,
    ) async {
      await pump(
        tester,
        const DSTimeGrid(slots: [morning], startHour: 9, endHour: 13),
      );

      final width = tester.getSize(find.byType(DSTimeGrid)).width;
      final axis = DSTimeGridStyle.resolve(ctx).axisWidth!;
      final slot = tester.getSize(
        find.ancestor(
          of: find.text('Design review'),
          matching: find.byType(DSPressable),
        ),
      );
      expect(slot.width, closeTo(width - axis, 1));
    });
  });

  group('the window is a hint', () {
    testWidgets('a slot past the end widens the grid rather than being cut', (
      tester,
    ) async {
      const evening = DSTimeSlot(
        start: TimeOfDay(hour: 20, minute: 0),
        end: TimeOfDay(hour: 21, minute: 0),
        title: 'Dinner',
      );
      await pump(
        tester,
        const DSTimeGrid(slots: [evening], startHour: 16, endHour: 18),
      );

      expect(find.text('Dinner'), findsOneWidget);
      final hourHeight = DSTimeGridStyle.resolve(ctx).hourHeight!;
      // 16:00 to 21:00, not 16:00 to 18:00.
      expect(tester.getSize(find.byType(DSTimeGrid)).height, hourHeight * 5);
    });
  });

  group('the height a slot is given', () {
    testWidgets('an hour is an hour', (tester) async {
      await pump(
        tester,
        const DSTimeGrid(slots: [morning], startHour: 9, endHour: 13),
      );

      final hourHeight = DSTimeGridStyle.resolve(ctx).hourHeight!;
      final slot = tester.getSize(
        find.ancestor(
          of: find.text('Design review'),
          matching: find.byType(DSPressable),
        ),
      );
      expect(slot.height, closeTo(hourHeight, 2));
    });

    testWidgets('a short booking still clears the tap-target floor', (
      tester,
    ) async {
      const quick = DSTimeSlot(
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 10, minute: 10),
        title: 'Call',
      );
      await pump(
        tester,
        const DSTimeGrid(slots: [quick], startHour: 9, endHour: 13),
      );

      final floor = DSTimeGridStyle.resolve(ctx).minSlotHeight!;
      final slot = tester.getSize(
        find.ancestor(
          of: find.text('Call'),
          matching: find.byType(DSPressable),
        ),
      );
      expect(slot.height, greaterThanOrEqualTo(floor - 1));
    });
  });

  group('now', () {
    testWidgets('is drawn only when the caller passes it', (tester) async {
      await pump(
        tester,
        const DSTimeGrid(slots: [morning], startHour: 9, endHour: 13),
      );
      expect(find.text('Now'), findsNothing);

      await pump(
        tester,
        const DSTimeGrid(
          slots: [morning],
          startHour: 9,
          endHour: 13,
          now: TimeOfDay(hour: 11, minute: 20),
        ),
      );
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('the hour it lands on gives up its label', (tester) async {
      // Both sit on the axis, and at a large text scale they are painted
      // through each other — `ui-probe` measured "Now" over "10:00 AM" by
      // seven points. The line wins: it is the one thing on the axis that is
      // only true for a moment.
      await pump(
        tester,
        const DSTimeGrid(
          slots: [morning],
          startHour: 9,
          endHour: 13,
          now: TimeOfDay(hour: 11, minute: 2),
        ),
      );
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('11:00 AM'), findsNothing);
      // And the hours it is nowhere near keep theirs.
      expect(find.text('9:00 AM'), findsOneWidget);
    });
  });

  group('a lane narrower than a word', () {
    testWidgets('stops splitting and scrolls the day sideways', (tester) async {
      // Two bookings at one hour split the width. On a narrow phone at a
      // large text scale that split was narrower than the first word of the
      // title, and the baseline read "Desi" where the booking said "Design
      // review". Both readable beats both on the screen at once.
      await tester.pumpWidget(
        Design(
          spec: AppTheme.spec,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SizedBox(
                width: 200,
                child: SingleChildScrollView(
                  child: DSTimeGrid(
                    slots: [morning, clash],
                    startHour: 9,
                    endHour: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
      // Still side by side, and still both there.
      expect(find.text('Design review'), findsOneWidget);
      expect(find.text('Dentist'), findsOneWidget);
    });
  });

  group('a booking that comes back', () {
    testWidgets('says so on the title row, whatever height it was given', (
      tester,
    ) async {
      // The words "repeats weekly" live in the subtitle, and the subtitle is
      // dropped whenever the block cannot hold a second line — so a recurring
      // booking drawn only in words is a recurring booking nobody sees is
      // recurring. The glyph is the part that cannot be dropped.
      //
      // This used to pin the drop to a fifteen-minute block, which held only
      // while body copy was 16pt: at 12.8 the same block fits both lines and
      // the assertion inverted. The height that cannot hold two lines is a
      // function of the type scale, not a constant, so the test drives the
      // scale instead of guessing a duration — and checks the glyph on both
      // sides of the drop, which is the claim that has to survive either way.
      const quick = DSTimeSlot(
        start: TimeOfDay(hour: 8, minute: 30),
        end: TimeOfDay(hour: 8, minute: 45),
        title: 'Standup',
        subtitle: 'Studio 2 · repeats weekly',
        repeats: true,
      );
      const grid = DSTimeGrid(slots: [quick], startHour: 8, endHour: 12);

      await pump(tester, grid);
      expect(
        find.byIcon(Icons.repeat),
        findsOneWidget,
        reason: 'the glyph is on the title row whether or not the words fit',
      );

      // 2.0 is the scale the component's own comment names as the one a short
      // booking cannot survive, and the drop is what stops it overflowing its
      // slot.
      await pump(tester, grid, textScale: 2.0);
      expect(
        find.text('Studio 2 · repeats weekly'),
        findsNothing,
        reason: 'the second line is dropped rather than clipped',
      );
      expect(
        find.byIcon(Icons.repeat),
        findsOneWidget,
        reason: 'dropping the words is exactly why the glyph exists',
      );
    });

    testWidgets('and a one-off carries no glyph', (tester) async {
      await pump(
        tester,
        const DSTimeGrid(slots: [morning], startHour: 9, endHour: 13),
      );
      expect(find.byIcon(Icons.repeat), findsNothing);
    });

    testWidgets('the words survive in what a screen reader hears', (
      tester,
    ) async {
      // The glyph is for the eye and cannot be read aloud. The subtitle is in
      // the label whether or not there was room to draw it, which is the only
      // reason dropping it is safe.
      const quick = DSTimeSlot(
        start: TimeOfDay(hour: 8, minute: 30),
        end: TimeOfDay(hour: 8, minute: 45),
        title: 'Standup',
        subtitle: 'Studio 2 · repeats weekly',
        repeats: true,
      );
      await pump(
        tester,
        const DSTimeGrid(slots: [quick], startHour: 8, endHour: 12),
      );

      expect(
        find.bySemanticsLabel(RegExp('Standup, .*repeats weekly')),
        findsOneWidget,
      );
    });
  });

  group('what a screen reader hears', () {
    testWidgets('a slot names itself and its times, once', (tester) async {
      await pump(
        tester,
        DSTimeGrid(
          startHour: 9,
          endHour: 13,
          slots: [
            DSTimeSlot(
              start: const TimeOfDay(hour: 10, minute: 0),
              end: const TimeOfDay(hour: 11, minute: 0),
              title: 'Design review',
              subtitle: 'With Ada',
              onTap: () {},
            ),
          ],
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Design review, .* to .*, With Ada')),
        findsOneWidget,
      );
    });
  });
}
