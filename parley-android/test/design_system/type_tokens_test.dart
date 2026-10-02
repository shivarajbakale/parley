import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/app_typography.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The type decisions that repeat, and the proof they are made once.
///
/// A weight and a set of font features are the two things every component's
/// style needs and neither is worth re-deciding. `TypeSpec` carries five
/// weights and `AppTypography` carries the one font feature, and the kit was
/// split: twenty-one call sites typed a `FontWeight.wNNN` literal and twelve
/// wrote `fontFeatures: const [FontFeature.tabularFigures()]` out by hand,
/// while their neighbours named the token for the same decision.
///
/// The literals were copied from the `TypeSpec` defaults, which is why nobody
/// saw it: under `halo` and `fallback` they are exactly right. These tests are
/// written under `signal` and `ledger` — the two brands whose weights differ —
/// because that is where a copy and a token stop agreeing, and a test written
/// under the default brand would pass on the broken code.
void main() {
  _rolesAreReachableAsAValue();

  /// A context under one brand, with the theme built from the same brand.
  ///
  /// Both halves matter: `context.design.type` reads the spec and
  /// `Theme.of(context).textTheme` reads the theme, and a test that mixed a
  /// `signal` spec with the default theme would be measuring two brands.
  Future<BuildContext> contextFor(WidgetTester tester, DesignSpec spec) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Design(
        spec: spec,
        child: MaterialApp(
          theme: spec.themeFor(Brightness.light),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  group('a brand that moves its emphasis weight moves all of it', () {
    testWidgets('signal sets w900, and every emphasised style takes it', (
      tester,
    ) async {
      final spec = DesignSpec.signal();
      final ctx = await contextFor(tester, spec);
      final emphasis = spec.type.emphasisWeight;
      // Not a repeat of the spec: this is the value the literals were copied
      // from, and the whole point is that it is not w700 here.
      expect(emphasis, FontWeight.w900);

      // Each of these hardcoded `FontWeight.w700` before this feature, so each
      // drew w700 under this brand while the card beside it drew w900.
      final weights = <String, FontWeight?>{
        'badge': DSBadgeStyle.resolve(ctx).labelStyle?.fontWeight,
        'stat tile value': DSStatTileStyle.resolve(
          ctx,
          DSStatTileSize.md,
        ).valueStyle?.fontWeight,
        'status state title': DSStatusStyle.resolve(ctx).titleStyle?.fontWeight,
        'hero title': DSHeroStyle.resolve(ctx).titleStyle?.fontWeight,
        'page header title': DSPageHeaderStyle.resolve(
          ctx,
        ).titleStyle?.fontWeight,
        'selected tab': DSTabBarStyle.resolve(
          ctx,
        ).selectedLabelStyle?.fontWeight,
        'selected nav destination': DSBottomNavBarStyle.resolve(
          ctx,
        ).selectedLabelStyle?.fontWeight,
      };
      for (final entry in weights.entries) {
        expect(
          entry.value,
          emphasis,
          reason:
              'the ${entry.key} draws ${entry.value} where the brand asks for '
              '$emphasis — a literal weight that does not move with the spec',
        );
      }
    });

    testWidgets('ledger raises the label weight, and the rest weight follows', (
      tester,
    ) async {
      final spec = DesignSpec.ledger();
      final ctx = await contextFor(tester, spec);
      expect(spec.type.labelWeight, FontWeight.w700);

      // `DSBottomNavBar` is the exhibit: the unselected label typed the
      // literal and the selected one named the token, two lines apart in one
      // style block, so under this brand the rest weight sat below the label
      // weight the brand asked for.
      expect(
        DSBottomNavBarStyle.resolve(ctx).labelStyle?.fontWeight,
        spec.type.labelWeight,
      );
      expect(
        DSSectionHeaderStyle.resolve(ctx).labelStyle?.fontWeight,
        spec.type.labelWeight,
      );
      expect(
        DSAvatarStyle.resolve(ctx).initialsStyle?.fontWeight,
        spec.type.labelWeight,
      );
    });

    testWidgets('and the default brand is unchanged, which is why nobody saw '
        'it', (tester) async {
      // The goldens render this brand. If a swap had picked the wrong token,
      // this is the assertion that would have caught it before the images did.
      final spec = DesignSpec.halo();
      final ctx = await contextFor(tester, spec);
      expect(spec.type.emphasisWeight, FontWeight.w700);
      expect(spec.type.labelWeight, FontWeight.w500);
      expect(DSBadgeStyle.resolve(ctx).labelStyle?.fontWeight, FontWeight.w700);
      expect(
        DSBottomNavBarStyle.resolve(ctx).labelStyle?.fontWeight,
        FontWeight.w500,
      );
    });
  });

  group('tabular figures are one decision', () {
    test('the getter puts the feature on the style', () {
      const base = TextStyle(fontSize: 12);
      expect(base.tabular.fontFeatures, const [FontFeature.tabularFigures()]);
      // It adds; it does not replace the style it is called on.
      expect(base.tabular.fontSize, 12);
    });

    test('it null-shorts through the chain', () {
      // The reason this is a getter rather than the static function it
      // replaced: the styles that need it are nullable steps off a TextTheme,
      // and the static's non-null parameter is why twelve call sites wrote the
      // font feature out by hand instead.
      const TextStyle? absent = null;
      expect(absent?.copyWith(fontSize: 12).tabular, isNull);
    });

    testWidgets('and every numeric style in the kit carries it', (
      tester,
    ) async {
      final ctx = await contextFor(tester, DesignSpec.halo());
      const tabular = [FontFeature.tabularFigures()];
      expect(
        DSStatTileStyle.resolve(
          ctx,
          DSStatTileSize.md,
        ).valueStyle?.fontFeatures,
        tabular,
      );
      expect(DSTabBarStyle.resolve(ctx).countStyle?.fontFeatures, tabular);
      expect(DSSliderStyle.resolve(ctx).valueTextStyle?.fontFeatures, tabular);
      expect(
        DSMetricBarStyle.resolve(
          ctx,
          DSMetricBarSize.md,
        ).valueStyle?.fontFeatures,
        tabular,
      );
    });
  });
}

/// The roles, reachable as a value.
///
/// `DSText` draws a string; a component's style class holds a `TextStyle?`
/// because that is what it hands to a `DefaultTextStyle`, a `TextPainter` or a
/// Material widget's own style slot. Until `DSTextRole.styleOf` existed there
/// was no way to fill one from a role, which is why 118 call sites read
/// `Theme.of(context).textTheme` and re-decided the weight, the grey and the
/// tracking each time.
void _rolesAreReachableAsAValue() {
  Future<BuildContext> ctxOf(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return ctx;
  }

  group('a role is a value, not only a widget', () {
    testWidgets('styleOf bakes the colour in, because a style field has '
        'nowhere to put a second one', (tester) async {
      final ctx = await ctxOf(tester);
      final style = DSTextRole.fieldLabel.styleOf(ctx);
      expect(
        style.fontSize,
        AppTheme.lightTheme.textTheme.labelMedium!.fontSize,
      );
      expect(style.color, ctx.palette.mutedForeground);
    });

    testWidgets('timestamp is the one role under the label steps', (
      tester,
    ) async {
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      final micro = DSTextRole.timestamp.styleOf(ctx).fontSize!;

      // Smaller than the smallest step Material names, which is the whole
      // reason the role exists: a timestamp set at `caption`'s size competes
      // with the message it dates.
      expect(micro, lessThan(text.labelSmall!.fontSize!));
      // And never below the floor, however tightly an identity winds its own
      // ratio — `signal` grows its scale at 1.20, where a fixed step off
      // `labelSmall` lands at 7.5pt.
      for (final spec in <DesignSpec>[
        DesignSpec.halo(),
        DesignSpec.ledger(),
        DesignSpec.signal(),
      ]) {
        expect(
          spec.type.micro.fontSize,
          greaterThanOrEqualTo(spec.type.microFloor),
        );
      }
    });

    testWidgets('a role that declares no colour adds none of its own', (
      tester,
    ) async {
      // `control` and `count` leave the colour null so a filled button and an
      // outlined one can share the role, and `styleOf` must not fill that in.
      //
      // The colour is still not null, and that is not a contradiction: a step
      // off `TextTheme` is built with `apply(bodyColor:)`, so it arrives
      // already painted. What this asserts is that the *role* adds nothing on
      // top — which is exactly what the call sites being replaced handed to
      // their style fields, and why twenty-one of them moved with no golden
      // changing.
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      expect(DSTextRole.control.styleOf(ctx).color, text.labelLarge?.color);
      expect(DSTextRole.count.styleOf(ctx).color, text.labelSmall?.color);
      // And a role that *does* declare one overrides the step's.
      expect(
        DSTextRole.fieldLabel.styleOf(ctx).color,
        isNot(text.labelMedium?.color),
      );
    });

    testWidgets('and `toned` swaps the meaning without a second role', (
      tester,
    ) async {
      final ctx = await ctxOf(tester);
      expect(
        DSTextRole.bodyDetail.toned(ctx, DSTone.error).color,
        ctx.palette.destructive,
      );
    });

    testWidgets('the components that moved onto roles kept their pixels', (
      tester,
    ) async {
      // The argument for the whole migration: these are the values the
      // components used to build by hand, so converting them changed nothing.
      // Twenty-one call sites moved and not one golden did.
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      final palette = ctx.palette;

      expect(
        DSControlTileStyle.resolve(ctx).helperStyle,
        text.bodySmall?.copyWith(color: palette.mutedForeground),
      );
      expect(
        DSControlTileStyle.resolve(ctx).errorStyle,
        text.bodySmall?.copyWith(color: palette.destructive),
      );
      expect(
        DSListTileStyle.resolve(ctx, DSTone.neutral).subtitleStyle,
        text.bodySmall?.copyWith(color: palette.mutedForeground),
      );
      expect(
        DSTextFieldStyle.resolve(ctx, DSTextFieldSize.md).labelStyle,
        text.labelMedium?.copyWith(color: palette.mutedForeground),
      );
    });
  });

  group('a role carries the facts that do not depend on a theme', () {
    test('exactly the three title roles are announced as headings', () {
      expect(DSTextRole.values.where((r) => r.heading), [
        DSTextRole.pageTitle,
        DSTextRole.screenTitle,
        DSTextRole.sectionTitle,
      ]);
    });

    test('exactly the error line is a live region', () {
      expect(DSTextRole.values.where((r) => r.live), [DSTextRole.fieldError]);
    });

    test('exactly the eyebrow asks the brand how it is cased', () {
      expect(DSTextRole.values.where((r) => r.uppercases), [
        DSTextRole.eyebrow,
      ]);
    });

    testWidgets('and the widget reads them off the role', (tester) async {
      // The three used to be fields on the private recipe, which meant a
      // theme lookup to answer a question no theme can change.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                DSText('Today', role: DSTextRole.sectionTitle),
                DSText('Not a number', role: DSTextRole.fieldError),
                DSText('Overdue', role: DSTextRole.eyebrow),
                DSText('Running copy', role: DSTextRole.body),
              ],
            ),
          ),
        ),
      );
      final headings = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.header ?? false);
      expect(headings, hasLength(1));
      final live = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.liveRegion ?? false);
      expect(live, hasLength(1));
      // The brand cases the eyebrow; the role only asks.
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('Running copy'), findsOneWidget);
    });
  });

  group('the two roles the counts demanded', () {
    testWidgets('bodySupport is body size in the quieter grey', (tester) async {
      // The axis bodyDetail does not offer: it drops the size as well as the
      // colour, and five components wanted only the colour.
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      final support = DSTextRole.bodySupport.styleOf(ctx);
      expect(support.fontSize, DSTextRole.body.styleOf(ctx).fontSize);
      expect(support.fontSize, text.bodyMedium?.fontSize);
      expect(support.color, ctx.palette.mutedForeground);
      expect(support.color, isNot(DSTextRole.body.styleOf(ctx).color));
      // And it is a step above the role that drops both.
      expect(
        support.fontSize,
        greaterThan(DSTextRole.bodyDetail.styleOf(ctx).fontSize!),
      );
    });

    testWidgets('caption is itemMeta without the row', (tester) async {
      // Deliberately the same three values. A role names a meaning, and two
      // meanings may resolve to one style — the kit already has three roles
      // on bodySmall in the secondary grey.
      final ctx = await ctxOf(tester);
      expect(DSTextRole.caption.styleOf(ctx), DSTextRole.itemMeta.styleOf(ctx));
      expect(
        DSTextRole.caption.styleOf(ctx).fontSize,
        Theme.of(ctx).textTheme.labelSmall?.fontSize,
      );
    });

    testWidgets('and the components that moved kept their pixels', (
      tester,
    ) async {
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      final palette = ctx.palette;
      expect(
        DSStatusStyle.resolve(ctx).messageStyle,
        text.bodyMedium?.copyWith(color: palette.mutedForeground),
      );
      expect(
        DSHeroStyle.resolve(ctx).subtitleStyle,
        text.bodyMedium?.copyWith(color: palette.mutedForeground),
      );
      expect(
        DSSearchBarStyle.resolve(ctx).countStyle?.fontSize,
        text.labelSmall?.fontSize,
      );
    });
  });

  group('the style chain reaches a style class', () {
    testWidgets('a page header builds its three text styles from roles', (
      tester,
    ) async {
      // The reason the chain moved down a tier. Before this, the header's
      // style class was tier 0 and the roles were in the tier-1 atom, so it
      // assembled all three by hand from Material steps.
      final ctx = await ctxOf(tester);
      final resolved = DSPageHeaderStyle.resolve(ctx);
      expect(resolved.eyebrowStyle, DSTextRole.eyebrow.styleOf(ctx));
      expect(resolved.subtitleStyle, DSTextRole.bodyDetail.styleOf(ctx));
      expect(
        resolved.titleStyle,
        DSTextRole.pageTitle.styleOf(ctx, emphasis: true),
      );
    });

    testWidgets('and emphasis is the role, one weight up — not a second role', (
      tester,
    ) async {
      // Under the default brand this asserts nothing: `halo` draws its
      // headline steps at the same w700 it emphasises with, so a call site
      // that hardcoded the weight and one that names the token agree. Signal
      // is where they part, and it is the brand the header's old
      // `copyWith(fontWeight: emphasisWeight)` was written for.
      final spec = DesignSpec.signal();
      late BuildContext ctx;
      await tester.pumpWidget(
        Design(
          spec: spec,
          child: MaterialApp(
            theme: spec.themeFor(Brightness.light),
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final plain = DSTextRole.pageTitle.styleOf(ctx);
      final heavy = DSTextRole.pageTitle.styleOf(ctx, emphasis: true);
      expect(heavy.fontSize, plain.fontSize);
      expect(heavy.color, plain.color);
      expect(heavy.fontWeight, spec.type.emphasisWeight);
      expect(heavy.fontWeight, isNot(plain.fontWeight));
    });
  });

  group('a count that is the shape, and a count beside a label', () {
    testWidgets('the annotating counts are one style, not three that agree', (
      tester,
    ) async {
      // Three components independently drew `labelSmall` in the secondary
      // grey with tabular figures, and the role that claimed them by name —
      // `count` — described something else. They are captions: a second,
      // quieter fact about the label they sit beside.
      final ctx = await ctxOf(tester);
      final caption = DSTextRole.caption.styleOf(ctx);
      expect(DSTabBarStyle.resolve(ctx).countStyle, caption);
      expect(DSSegmentedButtonStyle.resolve(ctx).countStyle, caption);
      expect(DSSearchBarStyle.resolve(ctx).countStyle, caption);
    });

    testWidgets('the chip draws the same one', (tester) async {
      // The chip's count is a widget rather than a style field, so it is the
      // one of the four that has to be rendered to be checked.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Center(child: DSChipCount(count: 12))),
        ),
      );
      final ctx = tester.element(find.byType(DSChipCount));
      expect(
        tester.widget<Text>(find.text('12')).style,
        DSTextRole.caption.styleOf(ctx),
      );
    });

    testWidgets('and `count` stays the number that is the whole shape', (
      tester,
    ) async {
      final ctx = await ctxOf(tester);
      final count = DSTextRole.count.styleOf(ctx);
      final caption = DSTextRole.caption.styleOf(ctx);
      // The two differ on exactly the axis the doc argues about. Same step,
      // both tabular; `count` is emphasised and adds no colour of its own so
      // that it inherits the dot's foreground, `caption` is at rest weight in
      // the secondary grey so that it stays under the label beside it.
      expect(count.fontSize, caption.fontSize);
      expect(count.fontFeatures, caption.fontFeatures);
      expect(count.fontWeight, ctx.design.type.emphasisWeight);
      expect(count.fontWeight, isNot(caption.fontWeight));
      expect(count.color, isNot(caption.color));
      // The notification dot is the shape the role describes, and still the
      // only component using it.
      expect(DSDotStyle.resolve(ctx).labelStyle, count);
    });

    testWidgets('the search bar count gained tabular figures, which is the '
        'one pixel this moved', (tester) async {
      // The other three were already tabular by hand. This one was not, so a
      // result count redrawn on every keystroke changed width between "9
      // results" and "10 results" and shifted the line as the reader typed.
      final ctx = await ctxOf(tester);
      expect(DSSearchBarStyle.resolve(ctx).countStyle?.fontFeatures, const [
        FontFeature.tabularFigures(),
      ]);
    });

    testWidgets('and the two reads the count hid are roles as well', (
      tester,
    ) async {
      // Both surfaced only once the count conversion emptied the locals
      // around them: they are written `Theme.of(context).textTheme.bodySmall`
      // inline rather than through a `text` local, which is the form the
      // earlier measurements of this migration did not match.
      final ctx = await ctxOf(tester);
      final text = Theme.of(ctx).textTheme;
      final palette = ctx.palette;
      expect(
        DSTextRole.bodyDetail.styleOf(ctx),
        text.bodySmall?.copyWith(color: palette.mutedForeground),
      );
      expect(
        DSTextRole.body.styleOf(ctx),
        text.bodyMedium?.copyWith(color: palette.foreground),
      );
    });
  });
}
