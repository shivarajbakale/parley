import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// A bubble's job is to say three things without being read: who spoke, how
/// wide the thread is, and whether the message actually left. These test the
/// third, because it is the one a thread that draws every bubble identically
/// has to report somewhere the user has already stopped looking.
void main() {
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return child;
              },
            ),
          ),
        ),
      ),
    );
  }

  group('which side the speaker takes', () {
    testWidgets('mine sits against the trailing edge, theirs the leading', (
      tester,
    ) async {
      await pump(
        tester,
        const Column(
          children: [
            DSChatBubble(author: DSChatAuthor.them, text: 'Theirs'),
            DSChatBubble(author: DSChatAuthor.me, text: 'Mine'),
          ],
        ),
      );

      final screen = tester.getSize(find.byType(Scaffold)).width;
      final theirs = tester.getRect(find.text('Theirs'));
      final mine = tester.getRect(find.text('Mine'));

      expect(theirs.left, lessThan(screen - theirs.right));
      expect(screen - mine.right, lessThan(mine.left));
    });

    testWidgets('a bubble never takes the whole line', (tester) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.them,
          text:
              'A message long enough that it would happily fill the line if '
              'nothing stopped it, which is exactly what the width cap is for.',
        ),
      );

      final screen = tester.getSize(find.byType(Scaffold)).width;
      final bubble = tester.getSize(find.byType(Container).first).width;
      final factor = DSChatBubbleStyle.resolve(ctx).maxWidthFactor!;

      expect(bubble, lessThanOrEqualTo(screen * factor));
    });
  });

  group('whether the message left', () {
    testWidgets('a failed bubble says so and offers the way back', (
      tester,
    ) async {
      var retried = 0;
      await pump(
        tester,
        DSChatBubble(
          author: DSChatAuthor.me,
          text: 'Send it',
          status: DSChatStatus.failed,
          onRetry: () => retried++,
        ),
      );

      expect(find.text('Not sent'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('a failed bubble with no callback still says it failed', (
      tester,
    ) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.me,
          text: 'Send it',
          status: DSChatStatus.failed,
        ),
      );

      expect(find.text('Not sent'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('sending is dimmed, sent is not', (tester) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.me,
          text: 'On my way',
          status: DSChatStatus.sending,
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, DSChatBubbleStyle.resolve(ctx).sendingOpacity);

      // The dim fades out rather than switching off, so it is still on the
      // frame the status changes and gone once the transition has run.
      await pump(
        tester,
        const DSChatBubble(author: DSChatAuthor.me, text: 'On my way'),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('a run of turns from one speaker', () {
    BorderRadius cornersOf(WidgetTester tester, int index) {
      final container = tester.widgetList<Container>(find.byType(Container));
      final decoration =
          container.elementAt(index).decoration! as ShapeDecoration;
      final shape = decoration.shape;
      final radius = switch (shape) {
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        BeveledRectangleBorder(:final borderRadius) => borderRadius,
        _ => BorderRadius.zero,
      };
      return radius.resolve(TextDirection.ltr);
    }

    testWidgets('the corner nearest the speaker stays tight inside the run', (
      tester,
    ) async {
      await pump(
        tester,
        const Column(
          children: [
            DSChatBubble(
              author: DSChatAuthor.me,
              text: 'First',
              group: DSChatGroup.first,
            ),
            DSChatBubble(
              author: DSChatAuthor.me,
              text: 'Last',
              group: DSChatGroup.last,
            ),
          ],
        ),
      );

      final style = DSChatBubbleStyle.resolve(ctx);
      final tail = Radius.circular(style.tailRadius!);
      final full = Radius.circular(style.radius!);

      // Mine, so the speaker's side is the trailing one. The turn that opens
      // the run keeps its top corner; the turn continuing it gives that up,
      // which is what stacks the two into one block.
      expect(cornersOf(tester, 0).topRight, full);
      expect(cornersOf(tester, 0).bottomRight, tail);
      expect(cornersOf(tester, 1).topRight, tail);
      // The far side is never tightened, whatever the run is doing.
      expect(cornersOf(tester, 1).topLeft, full);
    });

    testWidgets('a continuing turn sits a hairline under the one before it', (
      tester,
    ) async {
      await pump(tester, const SizedBox.shrink());
      final space = ctx.design.space;

      expect(DSChatBubble.gapBefore(ctx, DSChatGroup.alone), space.sm);
      expect(DSChatBubble.gapBefore(ctx, DSChatGroup.first), space.sm);
      expect(DSChatBubble.gapBefore(ctx, DSChatGroup.middle), space.hairline);
      expect(DSChatBubble.gapBefore(ctx, DSChatGroup.last), space.hairline);
    });
  });

  group('the entrance', () {
    testWidgets('a bubble that animates in starts small and settles at full '
        'size', (tester) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.me,
          text: 'Just sent',
          animateIn: true,
        ),
      );

      // `getRect` walks the ancestor transforms; `getSize` is the layout box
      // and a scale never touches it. The entrance is paint, so it is the
      // painted rectangle that has to be smaller.
      final start = tester.getRect(find.text('Just sent'));
      final laidOut = tester.getSize(find.text('Just sent'));
      expect(start.width, lessThan(laidOut.width));
      expect(
        start.width / laidOut.width,
        closeTo(DSChatBubbleStyle.resolve(ctx).entranceScale!, 0.02),
      );

      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.getRect(find.text('Just sent')).width,
        closeTo(laidOut.width, 0.01),
      );
    });

    testWidgets('a bubble that does not animate in is at full size on its '
        'first frame', (tester) async {
      await pump(
        tester,
        const DSChatBubble(author: DSChatAuthor.me, text: 'Already here'),
      );

      // The default, and the one that matters: a transcript builds its rows
      // as they are scrolled to, so a bubble that animated on every build
      // would pop its way through the history.
      expect(
        tester.getRect(find.text('Already here')).width,
        closeTo(tester.getSize(find.text('Already here')).width, 0.01),
      );
    });
  });

  group('what a screen reader hears', () {
    testWidgets('the speaker and the state are in the label', (tester) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.them,
          text: 'Still working on it',
          status: DSChatStatus.streaming,
        ),
      );

      expect(
        tester.getSemantics(find.byType(DSChatBubble)).label,
        'They said Still working on it, still arriving',
      );
    });
  });

  group('the style chain', () {
    testWidgets('an instance style wins over the spec default', (tester) async {
      await pump(
        tester,
        const DSChatBubble(
          author: DSChatAuthor.me,
          text: 'Narrow',
          style: DSChatBubbleStyle(maxWidthFactor: 0.4),
        ),
      );

      final screen = tester.getSize(find.byType(Scaffold)).width;
      expect(
        tester.getSize(find.byType(Container).first).width,
        lessThanOrEqualTo(screen * 0.4),
      );
    });
  });
}
