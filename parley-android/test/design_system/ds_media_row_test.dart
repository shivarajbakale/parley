import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

void main() {
  late BuildContext ctx;

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
                    ctx = context;
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

  group('geometry', () {
    testWidgets('aspect changes the width and never the height', (
      tester,
    ) async {
      await pump(tester, const DSMediaRow(source: source, title: 'Square'));
      final Size square = tester.getSize(find.byType(DSMediaSurface));

      await pump(
        tester,
        const DSMediaRow(
          source: source,
          aspect: DSMediaAspect.wide,
          title: 'Wide',
        ),
      );
      final Size wide = tester.getSize(find.byType(DSMediaSurface));

      expect(wide.height, square.height, reason: 'one row height');
      expect(wide.width, greaterThan(square.width));
    });

    testWidgets('compact spends its density on the picture and the padding', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMediaRow(source: source, title: 'Compact', subtitle: 'Hidden'),
        density: DSDensity.compact,
      );
      expect(
        tester.getSize(find.byType(DSMediaSurface)).height,
        ctx.design.space.xxxl,
      );
      expect(
        find.text('Hidden'),
        findsNothing,
        reason: 'a compact row has no supporting line',
      );
    });

    testWidgets('the supporting line is one line, not two', (tester) async {
      await pump(
        tester,
        const DSMediaRow(
          source: source,
          title: 'Title',
          subtitle: 'Supporting',
        ),
      );
      final Text subtitle = tester.widget<Text>(find.text('Supporting'));
      expect(subtitle.maxLines, 1);
    });
  });

  group('the four layers stack', () {
    testWidgets('the instance beats the spec default', (tester) async {
      late DSMediaRowStyle resolved;
      await pump(
        tester,
        Builder(
          builder: (context) {
            resolved = DSMediaRowStyle.resolve(
              context,
              null,
              const DSMediaRowStyle(titleMaxLines: 1),
            );
            return const SizedBox.shrink();
          },
        ),
      );
      expect(resolved.titleMaxLines, 1);
      expect(resolved.mediaExtent, isNotNull, reason: 'the rest still filled');
    });

    test('titleMaxLines is bounded at four', () {
      expect(() => DSMediaRowStyle(titleMaxLines: 5), throwsAssertionError);
      expect(const DSMediaRowStyle(titleMaxLines: 4).titleMaxLines, 4);
    });
  });

  group('selection', () {
    testWidgets('leaves the trailing control alone', (tester) async {
      await pump(
        tester,
        DSMediaRow(
          source: source,
          title: 'Selected',
          selected: true,
          trailing: const Icon(Icons.more_vert),
          onTap: () {},
        ),
      );
      expect(
        find.byIcon(Icons.more_vert),
        findsOneWidget,
        reason: 'selecting an item must not remove the command it offers',
      );
      expect(find.byKey(DSMediaSurface.selectionKey), findsOneWidget);
    });
  });

  group('the long-press menu', () {
    testWidgets('opens, and registers a custom action for a reader', (
      tester,
    ) async {
      var opened = false;
      await pump(
        tester,
        DSMediaRow(
          source: source,
          title: 'With a menu',
          menuItems: [
            DSMenuItem(label: 'Download', onPressed: () => opened = true),
          ],
          onTap: () {},
        ),
      );
      await tester.longPress(find.byType(DSMediaRow));
      await tester.pumpAndSettle();
      expect(find.text('Download'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('a menu and a long-press callback are mutually exclusive', (
      tester,
    ) async {
      await pump(
        tester,
        DSMediaRow(
          source: source,
          title: 'Both',
          menuItems: [DSMenuItem(label: 'Download', onPressed: () {})],
          onLongPress: () {},
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('what the row says', () {
    testWidgets('the image label and the status reach the reader', (
      tester,
    ) async {
      await pump(
        tester,
        DSMediaRow(
          source: source,
          title: 'Quarterly report',
          subtitle: 'Finance',
          status: const DSMediaStatus(
            duration: Duration(minutes: 12, seconds: 4),
            unread: true,
          ),
          onTap: () {},
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.byType(DSMediaRow));
      expect(node.label, contains('Quarterly report'));
      expect(node.label, contains('Finance'));
      expect(node.label, contains('Cover of the quarterly report'));
      expect(node.label, contains('12 minutes 4 seconds'));
      expect(node.label, contains('Unread'));
    });
  });

  group('the meta row', () {
    testWidgets('drops below the row past 1.6x text scale', (tester) async {
      await pump(
        tester,
        const DSMediaRow(
          source: source,
          title: 'Reflow',
          meta: [DSMediaMeta(label: 'Draft')],
        ),
        textScaler: const TextScaler.linear(2),
      );
      final double metaLeft = tester.getTopLeft(find.text('Draft')).dx;
      final double mediaLeft = tester
          .getTopLeft(find.byType(DSMediaSurface))
          .dx;
      expect(metaLeft, closeTo(mediaLeft, 1));
    });
  });
}
