import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
    DSDensity? density,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    final Widget body = Builder(builder: (_) => child);
                    return density == null
                        ? body
                        : DSScope.merge(context, density: density, child: body);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  const source = DSMediaSource.widget(
    ColoredBox(color: Color(0xFF112233)),
    semanticLabel: 'Cover of the quarterly report',
  );

  group('DSMediaTile', () {
    testWidgets('a null width fills the column', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: DSMediaTile(source: source, title: 'Fills'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DSMediaSurface)).width, 200);
    });

    testWidgets('a given width makes it a carousel item', (tester) async {
      late double carousel;
      await pump(
        tester,
        Builder(
          builder: (context) {
            carousel = context.design.space.xxxl * 3;
            return Align(
              alignment: Alignment.topLeft,
              child: DSMediaTile(
                source: source,
                title: 'Carousel',
                width: carousel,
              ),
            );
          },
        ),
      );
      expect(tester.getSize(find.byType(DSMediaSurface)).width, carousel);
    });

    testWidgets('height follows the aspect', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: DSMediaTile(
            source: source,
            title: 'Poster',
            aspect: DSMediaAspect.portrait,
            width: 120,
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(DSMediaSurface));
      expect(size.height, closeTo(120 / (2 / 3), 0.5));
    });

    testWidgets('the text budget is the row\'s', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: DSMediaTile(
              source: source,
              title: 'Title',
              subtitle: 'Supporting',
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('Title')).maxLines, 2);
      expect(tester.widget<Text>(find.text('Supporting')).maxLines, 1);
    });

    testWidgets('rank stamps the poster rather than leading it', (
      tester,
    ) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: DSMediaTile(
              source: source,
              title: 'Number one',
              status: DSMediaStatus(rank: 1),
            ),
          ),
        ),
      );
      final Rect media = tester.getRect(find.byType(DSMediaSurface));
      final Rect rank = tester.getRect(find.text('1'));
      expect(media.contains(rank.center), isTrue);
    });

    testWidgets('a tile dips on press', (tester) async {
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: DSMediaTile(source: source, title: 'Press', onTap: () {}),
          ),
        ),
      );
      expect(find.byType(DSPressable), findsOneWidget);
    });
  });
}
