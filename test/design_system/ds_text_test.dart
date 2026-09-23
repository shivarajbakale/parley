import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The claim under test: a role is a decision made once.
///
/// Every group below is one property a call site would otherwise have had to
/// remember — the grey, the weight, the ellipsis that has to travel with a
/// line limit, the casing knob, the tabular figures, the heading a screen
/// reader needs, and the text-scale ceiling that five components had already
/// solved five ways.
void main() {
  late BuildContext ctx;
  late DSTextStyle resolved;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    DesignSpec? spec,
    DSTextStyle? extension,
    TextScaler? scaler,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: spec ?? AppTheme.spec,
        child: MaterialApp(
          theme: extension == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(extensions: [extension]),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return scaler == null
                    ? child
                    : MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: scaler),
                        child: child,
                      );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Resolves one role inside a real app, optionally under a scope.
  Future<void> resolveRole(
    WidgetTester tester,
    DSTextRole role, {
    DSTone? tone,
    bool emphasis = false,
    DSSize? size,
    DSTone? scopeTone,
    bool? enabled,
    DSTextStyle? extension,
    DSTextStyle? own,
  }) async {
    Widget probe = Builder(
      builder: (context) {
        ctx = context;
        resolved = DSTextStyle.resolve(
          context,
          role: role,
          tone: tone,
          emphasis: emphasis,
          own: own,
        );
        return const SizedBox.shrink();
      },
    );
    if (size != null || scopeTone != null || enabled != null) {
      final inner = probe;
      probe = DSScope(
        size: size,
        tone: scopeTone,
        enabled: enabled,
        child: inner,
      );
    }
    await pump(tester, probe, extension: extension);
  }

  group(
    'a role carries the grey and the weight, so no call site names one',
    () {
      testWidgets('the three text weights are roles, not colours', (t) async {
        await resolveRole(t, DSTextRole.body);
        expect(resolved.color, ctx.palette.foreground);

        await resolveRole(t, DSTextRole.bodyDetail);
        expect(resolved.color, ctx.palette.mutedForeground);

        // The third grey is the disabled state's and nothing else's: at the
        // label step it renders 3.95:1 on the light canvas.
        await resolveRole(t, DSTextRole.itemMeta);
        expect(resolved.color, ctx.palette.mutedForeground);
      });

      testWidgets('an error line reads the palette family, not a red', (
        t,
      ) async {
        await resolveRole(t, DSTextRole.fieldError);
        expect(resolved.color, ctx.palette.destructive);
      });

      testWidgets('a control inherits its colour from what it sits on', (
        t,
      ) async {
        await resolveRole(t, DSTextRole.control);
        expect(
          resolved.color,
          isNull,
          reason:
              'a filled button’s label is onAccent and an outlined '
              'one’s is not, so the role cannot name either',
        );
        await resolveRole(t, DSTextRole.count);
        expect(resolved.color, isNull);
      });

      testWidgets('emphasis is a weight step from the spec, not a literal', (
        t,
      ) async {
        await resolveRole(t, DSTextRole.body, emphasis: true);
        expect(resolved.textStyle!.fontWeight, ctx.design.type.emphasisWeight);
      });

      testWidgets('a section title is already at the emphasis step', (t) async {
        await resolveRole(t, DSTextRole.sectionTitle);
        expect(resolved.textStyle!.fontWeight, ctx.design.type.emphasisWeight);
      });

      testWidgets('a tone selects a family and never a colour', (t) async {
        await resolveRole(t, DSTextRole.body, tone: DSTone.warning);
        expect(resolved.color, ctx.palette.warning);
      });
    },
  );

  group('a line limit and its ellipsis are one decision', () {
    testWidgets('a role that points at content truncates', (t) async {
      await resolveRole(t, DSTextRole.itemTitle);
      expect(resolved.maxLines, 1);
      expect(resolved.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a role that is the content wraps without limit', (t) async {
      await resolveRole(t, DSTextRole.body);
      expect(resolved.maxLines, isNull);
      expect(resolved.softWrap, isTrue);
    });

    testWidgets('a limit passed at the call site brings the ellipsis with '
        'it', (t) async {
      await pump(
        t,
        const DSText(
          'a long line of running copy',
          role: DSTextRole.body,
          maxLines: 2,
        ),
      );
      final text = t.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      expect(
        text.overflow,
        TextOverflow.ellipsis,
        reason:
            'the twenty-one places that clipped with no ellipsis are what '
            'this pairing exists to prevent',
      );
    });
  });

  group('the casing is a spec knob, not a toUpperCase at the call site', () {
    testWidgets('an eyebrow is capitalised when the identity says so', (
      t,
    ) async {
      await pump(t, const DSText('Overdue', role: DSTextRole.eyebrow));
      expect(find.text('OVERDUE'), findsOneWidget);
    });

    testWidgets('and is not when it does not', (t) async {
      await pump(
        t,
        const DSText('Overdue', role: DSTextRole.eyebrow),
        spec: AppTheme.spec.copyWith(
          type: const TypeSpec(eyebrowUppercase: false),
        ),
      );
      expect(find.text('Overdue'), findsOneWidget);
    });
  });

  group('the running face', () {
    testWidgets('every role stays on the identity’s family', (t) async {
      await resolveRole(t, DSTextRole.body);
      expect(resolved.textStyle!.fontFamily, ctx.design.type.family);
    });
  });

  group('digits that line up', () {
    testWidgets('a metric is tabular without being asked', (t) async {
      await resolveRole(t, DSTextRole.metric);
      expect(
        resolved.textStyle!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('and any role can be, for a column the role does not know '
        'about', (t) async {
      await pump(
        t,
        const DSText('1,284', role: DSTextRole.body, numeric: true),
      );
      final text = t.widget<Text>(find.byType(Text));
      expect(
        text.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('a container speaks to what it holds', () {
    testWidgets('a small scope steps the role down the spec ratio', (t) async {
      await resolveRole(t, DSTextRole.itemTitle);
      final base = resolved.textStyle!.fontSize!;

      await resolveRole(t, DSTextRole.itemTitle, size: DSSize.sm);
      expect(
        resolved.textStyle!.fontSize,
        closeTo(base / ctx.design.type.ratio, 0.001),
        reason: 'a second hand-picked size is what the ratio exists to avoid',
      );
    });

    testWidgets('a scope lends its tone, and an explicit one still wins', (
      t,
    ) async {
      await resolveRole(t, DSTextRole.body, scopeTone: DSTone.error);
      expect(resolved.color, ctx.palette.destructive);

      await resolveRole(
        t,
        DSTextRole.body,
        scopeTone: DSTone.error,
        tone: DSTone.success,
      );
      expect(resolved.color, ctx.palette.success);
    });

    testWidgets('a disabled container greys what it holds', (t) async {
      await resolveRole(t, DSTextRole.body, enabled: false);
      expect(resolved.color, ctx.palette.mutedForeground);
    });

    testWidgets('but not a role whose colour comes from the surface', (
      t,
    ) async {
      await resolveRole(t, DSTextRole.control, enabled: false);
      expect(
        resolved.color,
        isNull,
        reason:
            'the button is already greying its own label, and two greys is a '
            'third grey',
      );
    });
  });

  group('the four layers stack', () {
    testWidgets('layer 2 is a theme extension and overrides only what it '
        'sets', (t) async {
      await resolveRole(
        t,
        DSTextRole.body,
        extension: const DSTextStyle(maxLines: 3),
      );
      expect(resolved.maxLines, 3);
      expect(resolved.color, ctx.palette.foreground);
    });

    testWidgets('layer 4 is the instance, and it wins', (t) async {
      await resolveRole(
        t,
        DSTextRole.body,
        extension: const DSTextStyle(maxLines: 3),
        own: const DSTextStyle(maxLines: 5),
      );
      expect(resolved.maxLines, 5);
    });

    test('lerp is implemented, not stubbed', () {
      const a = DSTextStyle(color: Color(0xFF000000), maxLines: 1, maxScale: 1);
      const b = DSTextStyle(color: Color(0xFFFFFFFF), maxLines: 4, maxScale: 2);
      final mid = a.lerp(b, 0.5);
      expect(mid.color, Color.lerp(a.color, b.color, 0.5));
      expect(mid.maxLines, 4, reason: 'discrete values cross at the midpoint');
    });
  });

  group('what a screen reader gets', () {
    testWidgets('a page title is announced as a heading', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, const DSText('Library', role: DSTextRole.pageTitle));
      expect(
        t.getSemantics(find.text('Library')),
        matchesSemantics(label: 'Library', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('running copy is not', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, const DSText('Some copy', role: DSTextRole.body));
      expect(
        t.getSemantics(find.text('Some copy')),
        matchesSemantics(label: 'Some copy'),
      );
      handle.dispose();
    });

    testWidgets('a field error is a live region, so it is announced when it '
        'appears', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, const DSText('Taken', role: DSTextRole.fieldError));
      expect(
        t.getSemantics(find.text('Taken')),
        matchesSemantics(label: 'Taken', isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  group('the reader’s text scale', () {
    /// The scale actually in force where the string is painted.
    TextScaler scalerAround(WidgetTester tester, String text) => tester
        .widget<MediaQuery>(
          find
              .ancestor(of: find.text(text), matching: find.byType(MediaQuery))
              .first,
        )
        .data
        .textScaler;

    testWidgets('running copy grows as far as the reader asks', (t) async {
      await pump(
        t,
        const DSText('Copy', role: DSTextRole.body),
        scaler: const TextScaler.linear(3),
      );
      expect(scalerAround(t, 'Copy').scale(10), 30);
    });

    testWidgets('a control label stops at the identity’s ceiling', (t) async {
      await pump(
        t,
        const DSText('Save', role: DSTextRole.control),
        scaler: const TextScaler.linear(3),
      );
      expect(
        scalerAround(t, 'Save').scale(10),
        10 * AppTheme.spec.type.controlScaleCeiling,
        reason:
            'a segmented control that grew to fit its longest label at 300% '
            'would have stopped being a segmented control',
      );
    });
  });

  group('a run inside a line', () {
    testWidgets('an emphasised span takes the weight and the rest does not', (
      t,
    ) async {
      await pump(
        t,
        const DSText.rich([
          DSTextSpan('Signed in as '),
          DSTextSpan('ada@example.com', emphasis: true),
        ], role: DSTextRole.body),
      );
      final span = t.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final runs = span.children!.cast<TextSpan>();
      expect(runs.first.style, isNull);
      expect(runs.last.style!.fontWeight, ctx.design.type.emphasisWeight);
    });

    testWidgets('a toned span reads the palette family', (t) async {
      await pump(
        t,
        const DSText.rich([
          DSTextSpan('2 overdue', tone: DSTone.warning),
        ], role: DSTextRole.bodyDetail),
      );
      final span = t.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final run = span.children!.first as TextSpan;
      expect(run.style!.color, ctx.palette.warning);
    });
  });
}
