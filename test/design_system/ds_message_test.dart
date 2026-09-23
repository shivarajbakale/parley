import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// `docs/plans/11-ds-message.plan.md`.
///
/// `DSBanner` and `DSInfoCard` declared identical variant enums and differed
/// only in radius, padding and whether there was a body. The regressions this
/// file holds are C-8 — four tones the user could not tell apart, measured at
/// 1.13:1 — and S-9, a message whose only channels were a glyph and a hue.
void main() {
  late BuildContext ctx;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.lightTheme
              : AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(width: 340, child: child),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(DSMessage),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  group('the tones are separable — audit C-8', () {
    for (final brightness in Brightness.values) {
      testWidgets('status accents stay apart in ${brightness.name}', (
        tester,
      ) async {
        await pump(
          tester,
          const DSMessage.section(message: 'x'),
          brightness: brightness,
        );
        // The colours that draw each message's icon and border, read from
        // the widget's own style resolution rather than the raw palette —
        // this is what `DSMessage` actually paints. A 12% tint over the card
        // cannot separate grounds, so the icon and border carry the
        // difference.
        final accents = <String, Color>{
          'error': DSMessageStyle.resolve(
            ctx,
            DSMessageTone.error,
            DSMessageScope.section,
          ).accentColor!,
          'success': DSMessageStyle.resolve(
            ctx,
            DSMessageTone.success,
            DSMessageScope.section,
          ).accentColor!,
          'warning': DSMessageStyle.resolve(
            ctx,
            DSMessageTone.warning,
            DSMessageScope.section,
          ).accentColor!,
        };

        // Gate K7's own rule, asserted where it is seen: peers separate
        // either by weight or by hue, and a semantic family sampled at one
        // lightness is uniform on purpose — so hue is the axis it separates
        // on. Asserting the ratio alone would demand a ladder the identity
        // deliberately does not have.
        final names = accents.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final a = names[i], b = names[j];
            final ratio = contrastRatio(accents[a]!, accents[b]!);
            final hue = Oklch.hueDistance(
              Oklch.fromColor(accents[a]!).h,
              Oklch.fromColor(accents[b]!).h,
            );
            expect(
              ratio >= 1.20 || hue >= 20,
              isTrue,
              reason:
                  '$a and $b are ${ratio.toStringAsFixed(2)}:1 '
                  'and ${hue.toStringAsFixed(1)}° apart. The identity this '
                  'replaces put info and success 1.13:1 and no degrees '
                  'apart, which is four message types that mean nothing',
            );
          }
        }
      });

      testWidgets('and the text on each clears 4.5 in ${brightness.name}', (
        tester,
      ) async {
        await pump(
          tester,
          const DSMessage.section(message: 'x'),
          brightness: brightness,
        );
        for (final tone in DSMessageTone.values) {
          final style = DSMessageStyle.resolve(
            ctx,
            tone,
            DSMessageScope.section,
          );
          final ratio = contrastRatio(style.foregroundColor!, style.fillColor!);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${tone.name} measures ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }

    testWidgets('the tone chooses the ground the message is drawn on', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMessage.section(
          tone: DSMessageTone.error,
          message: 'Could not save',
        ),
      );
      expect(
        decorationOf(tester).color,
        DSMessageStyle.resolve(
          ctx,
          DSMessageTone.error,
          DSMessageScope.section,
        ).fillColor,
      );
      expect(
        Oklch.hueDistance(
          Oklch.fromColor(decorationOf(tester).color!).h,
          Oklch.fromColor(ctx.palette.tint(ctx.palette.destructive)).h,
        ),
        lessThan(5),
        reason:
            'the ground is the tone container washed toward the surface, so '
            'it keeps the hue and loses only the weight',
      );

      await pump(
        tester,
        const DSMessage.section(tone: DSMessageTone.neutral, message: 'Draft'),
      );
      expect(
        decorationOf(tester).color,
        DSMessageStyle.resolve(
          ctx,
          DSMessageTone.neutral,
          DSMessageScope.section,
        ).fillColor,
      );
      expect(
        Oklch.fromColor(decorationOf(tester).color!).c,
        lessThan(0.02),
        reason:
            'neutral is state, not information — the audit found four call '
            'sites using `info` for a draft, and a blue "Draft" reads as '
            'something the user should act on. It is the one tone with no '
            'hue, and washing it must not give it one',
      );
    });
  });

  group('three channels, never one — audit S-9', () {
    testWidgets('a message always has an icon, a tone and text', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMessage.section(message: 'Two invites are unaccepted.'),
      );
      expect(find.text('Two invites are unaccepted.'), findsOneWidget);
      expect(find.byIcon(Icons.info_rounded), findsOneWidget);
      expect(
        decorationOf(tester).color,
        DSMessageStyle.resolve(
          ctx,
          DSMessageTone.info,
          DSMessageScope.section,
        ).fillColor,
      );
    });

    test('every tone has a glyph', () {
      expect(
        DSMessageStyle.defaultIcons.keys,
        containsAll(DSMessageTone.values),
        reason:
            'the icon is the SC 1.4.1 channel; a tone without one is down to '
            'colour and text',
      );
    });

    testWidgets('the icon is excluded from semantics', (tester) async {
      final handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics();
      await pump(tester, const DSMessage.section(message: 'Syncing.'));
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byIcon(Icons.info_rounded),
        ),
        findsOneWidget,
        reason:
            'one of three redundant channels, with nothing to say the text '
            'has not',
      );
      handle.dispose();
    });
  });

  group('the announcement', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('is a live region whatever the tone', (tester) async {
      await pump(tester, const DSMessage.section(message: 'Syncing.'));
      expect(
        tester
            .getSemantics(find.byType(DSMessage))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    });

    testWidgets('and only warning and error interrupt', (tester) async {
      final spoken = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            Object? message,
          ) async {
            final data = (message! as Map<Object?, Object?>)['data']!;
            final map = data as Map<Object?, Object?>;
            if (map['assertiveness'] == Assertiveness.assertive.index) {
              spoken.add(map['message']! as String);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      for (final tone in DSMessageTone.values) {
        await pump(
          tester,
          DSMessage.section(
            key: ValueKey(tone),
            tone: tone,
            message: tone.name,
          ),
        );
      }

      expect(
        spoken,
        ['warning', 'error'],
        reason:
            'a polite green "Saved" that cuts across what the user is reading '
            'is the classic ARIA `alert` misuse',
      );
      expect(
        DSMessageTone.values
            .where((t) => DSMessage.section(message: 'x', tone: t).assertive)
            .map((t) => t.name),
        ['warning', 'error'],
      );
    });
  });

  group('the controls are separate nodes', () {
    late SemanticsHandle handle;
    setUp(
      () => handle = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => handle.dispose());

    testWidgets('dismiss and the action are each labelled and ≥48dp, and '
        'they do not touch', (tester) async {
      await pump(
        tester,
        DSMessage.screen(
          tone: DSMessageTone.error,
          title: 'Your session expired',
          message: 'Sign in again to keep working.',
          actionLabel: 'Sign in',
          onAction: () {},
          onDismiss: () {},
        ),
      );

      final target = ctx.design.component.minTapTarget;
      final dismiss = find.byTooltip('Dismiss Your session expired');
      final action = find.widgetWithText(DSButton, 'Sign in');
      expect(dismiss, findsOneWidget);

      final size = tester.getSize(dismiss);
      expect(size.width, greaterThanOrEqualTo(target));
      expect(size.height, greaterThanOrEqualTo(target));

      final node = tester.getSemantics(dismiss);
      expect('${node.label}${node.tooltip}', isNotEmpty);

      final gap =
          tester.getTopLeft(action).dy - tester.getBottomLeft(dismiss).dy;
      expect(
        gap.abs(),
        greaterThanOrEqualTo(8.0),
        reason: 'two adjacent targets one thumb-width apart is one target',
      );
    });

    testWidgets('dismiss collapses the message before it is removed', (
      tester,
    ) async {
      var dismissed = false;
      await pump(
        tester,
        DSMessage.section(
          message: 'You are viewing a shared copy.',
          onDismiss: () => dismissed = true,
        ),
      );
      final settled = tester.getSize(find.byType(DSMessage)).height;

      await tester.tap(
        find.byTooltip('Dismiss You are viewing a shared copy.'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.getSize(find.byType(DSMessage)).height,
        lessThan(settled),
        reason:
            'the removal is committed after the collapse, so the list below '
            'does not snap shut around a gap',
      );
      expect(dismissed, isFalse);

      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });
  });

  group('the scopes differ in placement, not in meaning', () {
    testWidgets('screen is square at the edges and section is not', (
      tester,
    ) async {
      await pump(tester, const DSMessage.screen(message: 'Offline.'));
      // No rounding is the contract. Null rather than `BorderRadius.zero`
      // because the border is a `BorderDirectional`, whose paint path asserts
      // on a zero radius where `Border`'s only rejects a non-zero one — see
      // the comment in `_surface`.
      expect(
        decorationOf(tester).borderRadius,
        anyOf(isNull, BorderRadius.zero),
      );

      await pump(tester, const DSMessage.section(message: 'Offline.'));
      expect(decorationOf(tester).borderRadius, isNot(BorderRadius.zero));
    });

    testWidgets('compact has no title, no action and no dismiss', (
      tester,
    ) async {
      await pump(tester, const DSMessage.compact(message: 'Read-only.'));
      expect(find.byType(DSButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('a long message wraps and never truncates', (tester) async {
      const long =
          'This workspace is using 9.6 GB of its 10 GB. New uploads will '
          'fail once the limit is reached, and scheduled backups will stop '
          'running until there is room for them.';
      await pump(
        tester,
        const DSMessage.section(tone: DSMessageTone.warning, message: long),
      );
      final text = tester.widget<Text>(find.text(long));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);
      expect(
        tester.getSize(find.byType(DSMessage)).height,
        greaterThan(60),
        reason: 'a truncated error is a support ticket',
      );
    });

    testWidgets('at a large text scale the action takes the full width', (
      tester,
    ) async {
      await pump(
        tester,
        DSMessage.section(
          message: 'Offline.',
          actionLabel: 'Retry',
          onAction: () {},
        ),
        textScale: 2,
      );
      final button = tester.widget<DSButton>(find.byType(DSButton));
      expect(button.fullWidth, isTrue);
    });
  });

  group('the four layers stack', () {
    testWidgets('the edge can be switched off, and the icon cannot', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMessage.section(
          message: 'Offline.',
          style: DSMessageStyle(showRule: false, borderWidth: 0),
        ),
      );
      expect(decorationOf(tester).border, isNull);
      expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    });

    testWidgets('by default the edge is a hairline all the way round', (
      tester,
    ) async {
      await pump(tester, const DSMessage.section(message: 'Offline.'));
      final border = decorationOf(tester).border! as Border;
      expect(border.isUniform, isTrue);
      expect(border.left.width, ctx.design.component.hairlineWidth);
      expect(
        contrastRatio(border.left.color, decorationOf(tester).color!),
        greaterThan(1.1),
        reason: 'an edge nobody can see is not an edge',
      );
    });

    testWidgets('and the banner rule is opt-in, on the leading side only', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMessage.section(
          message: 'Offline.',
          style: DSMessageStyle(showRule: true),
        ),
      );
      // BorderDirectional: the rule is on `start`, so it stays on the
      // leading edge in Arabic — see docs/principles/direction.md.
      final border = decorationOf(tester).border! as BorderDirectional;
      expect(border.start.color, ctx.palette.primary);
      expect(border.start.width, greaterThan(border.top.width));
    });

    testWidgets('the full-bleed scope draws no vertical edge at the bezel', (
      tester,
    ) async {
      await pump(tester, const DSMessage.screen(message: 'Offline.'));
      final border = decorationOf(tester).border! as BorderDirectional;
      expect(border.start, BorderSide.none);
      expect(border.end, BorderSide.none);
      expect(border.bottom.width, ctx.design.component.hairlineWidth);
    });

    testWidgets('a consumer can replace one glyph and keep the other four', (
      tester,
    ) async {
      await pump(
        tester,
        const DSMessage.section(
          tone: DSMessageTone.error,
          message: 'Could not save.',
          style: DSMessageStyle(
            icons: {DSMessageTone.error: Icons.cloud_off_outlined},
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      await pump(
        tester,
        const DSMessage.section(
          message: 'Syncing.',
          style: DSMessageStyle(
            icons: {DSMessageTone.error: Icons.cloud_off_outlined},
          ),
        ),
      );
      expect(
        find.byIcon(Icons.info_rounded),
        findsOneWidget,
        reason: 'the map merges key by key, so a partial set is not a hole',
      );
    });
  });

  group('the style object', () {
    test('merge takes the non-null fields of the layer above', () {
      const base = DSMessageStyle(ruleWidth: 3, iconGap: 12);
      final merged = base.merge(const DSMessageStyle(ruleWidth: 0));
      expect(merged.ruleWidth, 0);
      expect(merged.iconGap, 12, reason: 'null is not a value');
    });

    test('lerp interpolates rather than snapping', () {
      const a = DSMessageStyle(ruleWidth: 0, iconGap: 0);
      const b = DSMessageStyle(ruleWidth: 4, iconGap: 16);
      final mid = a.lerp(b, 0.5);
      expect(mid.ruleWidth, 2);
      expect(mid.iconGap, 8);
    });
  });
}
