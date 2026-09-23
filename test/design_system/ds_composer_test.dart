import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Three things have to agree in a composer and each is separately easy to
/// get wrong: the send affordance is dead until there is something to send,
/// the field grows without the bar leaving the bottom edge, and whoever owns
/// the text is the one who gets to clear it.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    );
  }

  group('the send affordance', () {
    testWidgets('is dead until there is something to send', (tester) async {
      var sent = <String>[];
      await pump(tester, DSComposer(onSend: sent.add));

      DSIconButton button() =>
          tester.widget<DSIconButton>(find.byType(DSIconButton));
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      await tester.tap(find.byType(DSIconButton));
      expect(sent, ['Hello']);
    });

    testWidgets('whitespace alone is not something to send', (tester) async {
      await pump(tester, DSComposer(onSend: (_) {}));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(
        tester.widget<DSIconButton>(find.byType(DSIconButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a send in flight waits, the field does not', (tester) async {
      await pump(tester, DSComposer(onSend: (_) {}, sending: true));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(
        tester.widget<DSIconButton>(find.byType(DSIconButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('a closed conversation disables the whole bar', (tester) async {
      await pump(tester, DSComposer(onSend: (_) {}, enabled: false));

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester.widget<DSIconButton>(find.byType(DSIconButton)).onPressed,
        isNull,
      );
    });
  });

  group('who owns the text', () {
    testWidgets('its own controller is cleared on send', (tester) async {
      await pump(tester, DSComposer(onSend: (_) {}));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byType(DSIconButton));
      await tester.pump();

      expect(find.text('Hello'), findsNothing);
    });

    testWidgets("the caller's controller is left alone", (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pump(tester, DSComposer(controller: controller, onSend: (_) {}));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byType(DSIconButton));
      await tester.pump();

      // The send failing is the case this protects: a composer that cleared
      // the caller's field would have swallowed what the user typed.
      expect(controller.text, 'Hello');
    });
  });

  group('the bar', () {
    testWidgets('grows with the text and keeps its bottom edge', (
      tester,
    ) async {
      await pump(tester, DSComposer(onSend: (_) {}));

      final before = tester.getRect(find.byType(DSComposer));
      await tester.enterText(
        find.byType(TextField),
        'One\nTwo\nThree\nFour going down the page',
      );
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(DSComposer));

      expect(after.height, greaterThan(before.height));
      expect(after.bottom, before.bottom);
    });

    testWidgets('the field stops growing at the resolved ceiling', (
      tester,
    ) async {
      late BuildContext ctx;
      await pump(
        tester,
        Builder(
          builder: (context) {
            ctx = context;
            return DSComposer(onSend: (_) {});
          },
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, DSComposerStyle.resolve(ctx).maxLines);
    });
  });
}
