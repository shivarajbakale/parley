import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

void main() {
  group('DSMediaSource', () {
    test('every variant carries a label, and none() is empty', () {
      const network = DSMediaSource.network(
        'https://example.test/a.jpg',
        semanticLabel: 'A cover',
      );
      expect(network.semanticLabel, 'A cover');
      expect(network.isEmpty, isFalse);

      const decorative = DSMediaSource.asset('assets/a.jpg', semanticLabel: '');
      expect(decorative.semanticLabel, isEmpty);
      expect(decorative.isEmpty, isFalse, reason: 'decorative is not absent');

      const none = DSMediaSource.none();
      expect(none.isEmpty, isTrue);
      expect(none.semanticLabel, isEmpty);
    });

    test('dominantColor is carried where one was given', () {
      const source = DSMediaSource.network(
        'https://example.test/a.jpg',
        semanticLabel: 'A cover',
        dominantColor: Color(0xFF112233),
      );
      expect(source.dominantColor, const Color(0xFF112233));
      expect(const DSMediaSource.none().dominantColor, isNull);
    });
  });

  group('DSMediaAspect', () {
    test('the three named ratios are the three the family draws', () {
      expect(DSMediaAspect.square.ratio, 1);
      expect(DSMediaAspect.portrait.ratio, closeTo(2 / 3, 0.001));
      expect(DSMediaAspect.wide.ratio, closeTo(16 / 9, 0.001));
    });
  });

  group('DSMediaStatus', () {
    test('an unset status draws nothing', () {
      expect(const DSMediaStatus().isEmpty, isTrue);
      expect(const DSMediaStatus(unread: true).isEmpty, isFalse);
      expect(const DSMediaStatus(rank: 1).isEmpty, isFalse);
    });

    test('durationLabel is the pill, not the sentence', () {
      expect(
        const DSMediaStatus(
          duration: Duration(minutes: 12, seconds: 4),
        ).durationLabel,
        '12:04',
      );
      expect(
        const DSMediaStatus(
          duration: Duration(hours: 1, minutes: 2, seconds: 3),
        ).durationLabel,
        '1:02:03',
      );
      expect(const DSMediaStatus().durationLabel, isNull);

      // The three edges the two cases above skip. A zero is a real value —
      // a live item that has not started — and a label that renders it as
      // an empty pill is worse than none; the hour boundary is where the
      // padding rule changes, and it is one second either side of the
      // branch above it.
      expect(
        const DSMediaStatus(duration: Duration.zero).durationLabel,
        '0:00',
      );
      expect(
        const DSMediaStatus(duration: Duration(seconds: 45)).durationLabel,
        '0:45',
      );
      expect(
        const DSMediaStatus(duration: Duration(hours: 1)).durationLabel,
        '1:00:00',
      );
      expect(
        const DSMediaStatus(
          duration: Duration(minutes: 59, seconds: 59),
        ).durationLabel,
        '59:59',
      );
    });

    test('the spoken phrases come in the order the spec fixes', () {
      const status = DSMediaStatus(
        duration: Duration(minutes: 12, seconds: 4),
        playback: DSMediaPlayback.playing,
        progress: 0.42,
        offline: DSMediaOffline.downloaded,
        live: true,
        unread: true,
      );
      expect(status.semanticPhrases(), <String>[
        '12 minutes 4 seconds',
        'Playing',
        '42 percent played',
        'Downloaded',
        'Live',
        'Unread',
      ]);
    });

    test('an empty status speaks nothing', () {
      expect(const DSMediaStatus().semanticPhrases(), isEmpty);
    });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: textScaler,
                disableAnimations: disableAnimations,
              ),
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
  }

  group('DSMediaSurface', () {
    testWidgets('a height sizes the width from the aspect', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.wide,
            height: 64,
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(DSMediaSurface));
      expect(size.height, 64);
      expect(size.width, closeTo(64 * 16 / 9, 0.5));
    });

    testWidgets('a width sizes the height from the aspect', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.square,
            width: 144,
          ),
        ),
      );
      expect(tester.getSize(find.byType(DSMediaSurface)), const Size(144, 144));
    });

    testWidgets('the box is at its final size before anything resolves', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.network(
              'https://example.test/a.jpg',
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.square,
            height: 64,
          ),
        ),
      );
      expect(tester.getSize(find.byType(DSMediaSurface)), const Size(64, 64));
    });

    testWidgets('an empty source draws no box', (tester) async {
      await pump(
        tester,
        const DSMediaSurface(
          source: DSMediaSource.none(),
          aspect: DSMediaAspect.square,
          height: 64,
        ),
      );
      expect(tester.getSize(find.byType(DSMediaSurface)), Size.zero);
    });

    testWidgets('duration and progress are both visible at once', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.wide,
            height: 64,
            status: DSMediaStatus(
              duration: Duration(minutes: 12, seconds: 4),
              progress: 0.5,
            ),
          ),
        ),
      );
      expect(find.text('12:04'), findsOneWidget);
      expect(find.byKey(DSMediaSurface.progressKey), findsOneWidget);
    });

    testWidgets('playing replaces the duration pill', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.wide,
            height: 64,
            status: DSMediaStatus(
              duration: Duration(minutes: 12, seconds: 4),
              playback: DSMediaPlayback.playing,
            ),
          ),
        ),
      );
      expect(find.text('12:04'), findsNothing);
      expect(find.byKey(DSMediaSurface.equalizerKey), findsOneWidget);
    });

    testWidgets('the equalizer stops when animations are disabled', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.wide,
            height: 64,
            status: DSMediaStatus(playback: DSMediaPlayback.playing),
          ),
        ),
        disableAnimations: true,
      );
      // The failure this guards is a hang, not a wrong pixel: a looping
      // controller that ignores the flag makes pumpAndSettle time out in
      // every test that mounts a playing item.
      await tester.pumpAndSettle();
      expect(find.byKey(DSMediaSurface.equalizerKey), findsOneWidget);
    });

    testWidgets('rank overlays only when the shape asks for it', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.portrait,
            height: 64,
            status: DSMediaStatus(rank: 3),
            showRank: true,
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a live item that is also ranked shows both badges', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'A cover',
            ),
            aspect: DSMediaAspect.portrait,
            // Tall enough that the stacked LIVE badge and rank numeral both
            // fit without a RenderFlex overflow — this is a layout test, not
            // a sizing one; the sizing contract has its own tests above.
            height: 200,
            status: DSMediaStatus(live: true, rank: 3),
            showRank: true,
          ),
        ),
      );
      final Rect live = tester.getRect(find.text('LIVE'));
      final Rect rank = tester.getRect(find.text('3'));
      expect(live.overlaps(rank), isFalse);
      final Rect surface = tester.getRect(find.byType(DSMediaSurface));
      expect(surface.contains(live.center), isTrue);
      expect(surface.contains(rank.center), isTrue);
    });

    testWidgets('the picture keeps its own label', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaSurface(
            source: DSMediaSource.widget(
              ColoredBox(color: Color(0xFF112233)),
              semanticLabel: 'Cover of the quarterly report',
            ),
            aspect: DSMediaAspect.square,
            height: 64,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Cover of the quarterly report'),
        findsOneWidget,
      );
    });

    testWidgets('the four layers stack on the surface style too', (
      tester,
    ) async {
      late DSMediaSurfaceStyle resolved;
      await pump(
        tester,
        Builder(
          builder: (context) {
            resolved = DSMediaSurfaceStyle.resolve(
              context,
              const DSMediaSurfaceStyle(fit: BoxFit.contain),
            );
            return const SizedBox.shrink();
          },
        ),
      );
      expect(resolved.fit, BoxFit.contain, reason: 'the instance won');
      expect(
        resolved.progressColor,
        isNotNull,
        reason: 'and the spec defaults filled the rest',
      );
    });
  });
}
