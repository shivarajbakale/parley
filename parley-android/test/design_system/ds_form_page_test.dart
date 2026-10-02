import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/theme/app_theme.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// flutter-068 — the form page as a component.
///
/// `DSFormPage` was named by five places before it was written, and four
/// screens built its shape by hand: `login_page`, `signup_page`,
/// `new_booking_page` and `repeat_rule_page`. They disagreed about every
/// number the shape needs — whether the body extends under the pinned bar,
/// how much clearance the last field gets, whether the scroll is on the
/// reading edge, and whether a rule separates the header from the fields.
///
/// These tests are the part of that agreement a machine can hold: the header
/// is outside the scroll, the clearance is the height the bar reports rather
/// than a number a screen picked, and the reading edge resolves through the
/// same chain the rest of the page rhythm does.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    DSPageStyle? extension,
  }) async {
    await tester.pumpWidget(
      Design(
        spec: AppTheme.spec,
        child: MaterialApp(
          theme: extension == null
              ? AppTheme.lightTheme
              : AppTheme.lightTheme.copyWith(extensions: [extension]),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget form({
    String title = 'Invite a member',
    String? eyebrow,
    String? subtitle,
    Widget? leading,
    Widget? actions,
    Widget? below,
    Widget? footer,
    DSPageStyle? style,
    bool fullBleed = false,
    List<Widget> children = const [SizedBox(height: 40, key: Key('field'))],
  }) {
    if (fullBleed) {
      return DSFormPage.fullBleed(
        title: title,
        eyebrow: eyebrow,
        subtitle: subtitle,
        leading: leading,
        actions: actions,
        below: below,
        footer: footer,
        style: style,
        children: children,
      );
    }
    return DSFormPage(
      title: title,
      eyebrow: eyebrow,
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      below: below,
      footer: footer,
      style: style,
      children: children,
    );
  }

  /// The inset the scrolling half of the page pays.
  ///
  /// Read off the `SingleChildScrollView` rather than a `ListView`: the body
  /// gives its column a minimum height so a form shorter than the page can be
  /// centred in what it was given. The number this returns, and every claim
  /// below about it, is unchanged — only the widget carrying it moved.
  EdgeInsets scrollPadding(WidgetTester tester) =>
      tester
              .widget<SingleChildScrollView>(
                find.byType(SingleChildScrollView).first,
              )
              .padding!
          as EdgeInsets;

  group('the header does not scroll', () {
    testWidgets('it is outside the scrollable, not a sliver in it', (
      tester,
    ) async {
      // The one decision that separates this page from DSPage. A reader
      // halfway down a form with the title scrolled away is filling in
      // fields for an unnamed thing.
      await pump(tester, form());
      expect(find.byType(DSPageHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.byType(DSPageHeader),
        ),
        findsNothing,
      );
    });

    testWidgets('and a rule marks the edge the content passes under', (
      tester,
    ) async {
      // DSDivider's own guidance is "whitespace first", and it holds between
      // two blocks of content. This is not that: it is the boundary of a
      // scroll, and without it the first field slides up to touch the title.
      await pump(tester, form());
      expect(find.byType(DSDivider), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.byType(DSDivider),
        ),
        findsNothing,
      );
    });

    testWidgets('a hero draws its own edge, so no rule is added', (
      tester,
    ) async {
      // The golden caught this: a straight hairline immediately under the
      // hero's rounded corners is a second boundary, not a missing one.
      await pump(
        tester,
        const DSFormPage.hero(
          header: DSHero(eyebrow: 'Welcome back', title: 'Sign in'),
          children: [SizedBox(height: 40, key: Key('field'))],
        ),
      );
      expect(find.byType(DSHero), findsOneWidget);
      expect(find.byType(DSDivider), findsNothing);
    });

    testWidgets('chrome in `below` stays with it', (tester) async {
      // A step indicator that scrolls away from the step it is counting is
      // an indicator of nothing. form_page put its DSSegmentedProgress in
      // the fixed column by hand for this reason.
      await pump(
        tester,
        form(below: const DSSegmentedProgress(currentStep: 2, totalSteps: 4)),
      );
      expect(
        find.descendant(
          of: find.byType(Scrollable),
          matching: find.byType(DSSegmentedProgress),
        ),
        findsNothing,
      );
    });

    testWidgets('the header carries what the page was given', (tester) async {
      await pump(
        tester,
        form(
          eyebrow: 'WORKSPACE',
          subtitle: 'Who is joining?',
          leading: const BackButton(),
        ),
      );
      final header = tester.widget<DSPageHeader>(find.byType(DSPageHeader));
      expect(header.title, 'Invite a member');
      expect(header.eyebrow, 'WORKSPACE');
      expect(header.subtitle, 'Who is joining?');
      expect(header.leading, isA<BackButton>());
    });
  });

  group('the bottom adds up', () {
    testWidgets('the page installs the bottom-inset host', (tester) async {
      await pump(tester, form());
      expect(find.byType(DSBottomInsetsHost), findsOneWidget);
    });

    testWidgets('the body extends under the pinned bar', (tester) async {
      // signup_page set this and the other three did not, so the Scaffold cut
      // their bodies off at the bar's top edge. A list that stops dead
      // against an opaque band gives the reader no sign anything is behind
      // it, and a translucent bar has nothing to blur.
      await pump(
        tester,
        form(
          footer: DSPinnedActionBar(
            children: [DSButton(label: 'Send invite', onPressed: () {})],
          ),
        ),
      );
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    });

    testWidgets('the clearance is the height the bar reports', (tester) async {
      // Not a number a screen picked. signup_page added `space.xl` plus
      // MediaQuery.paddingOf(context).bottom — a second count of a home
      // indicator DSPinnedActionBar already contains — while repeat_rule_page
      // used a flat `space.xl` and new_booking_page a flat `space.sm`,
      // neither of which knows how tall the bar is.
      await pump(
        tester,
        form(
          footer: DSPinnedActionBar(
            children: [DSButton(label: 'Send invite', onPressed: () {})],
          ),
        ),
      );
      final barHeight = tester.getSize(find.byType(DSPinnedActionBar)).height;
      expect(barHeight, greaterThan(0));
      expect(scrollPadding(tester).bottom, greaterThanOrEqualTo(barHeight));
    });

    testWidgets('and a page with no bar reserves none of it', (tester) async {
      // The other direction. A clearance that is a constant is a hole on
      // every screen that does not pin anything.
      await pump(tester, form());
      final withoutBar = scrollPadding(tester).bottom;
      await pump(
        tester,
        form(
          footer: DSPinnedActionBar(
            children: [DSButton(label: 'Send invite', onPressed: () {})],
          ),
        ),
      );
      expect(withoutBar, lessThan(scrollPadding(tester).bottom));
    });
  });

  group('the reading edge', () {
    testWidgets('the page puts its children on the gutter', (tester) async {
      await pump(tester, form());
      expect(
        tester.getTopLeft(find.byKey(const Key('field'))).dx,
        AppTheme.spec.space.pageGutter,
      );
    });

    testWidgets('fullBleed hands it to the children instead', (tester) async {
      // A DSListTile insets its own content so its divider can run to the
      // edge. Inside a gutter-padded scroll it is indented twice and stands
      // out of the column it belongs to.
      await pump(tester, form(fullBleed: true));
      expect(tester.getTopLeft(find.byKey(const Key('field'))).dx, 0);
    });

    testWidgets('and a theme extension moves the scroll with the page', (
      tester,
    ) async {
      // The reason the gutter is resolved rather than read from the spec: a
      // wider page moves the form too. Four screens spelled the number into
      // a scroll view's own padding, where no override could reach it.
      await pump(tester, form(), extension: const DSPageStyle(gutter: 48));
      expect(tester.getTopLeft(find.byKey(const Key('field'))).dx, 48);
    });

    testWidgets('the instance wins over the extension', (tester) async {
      await pump(
        tester,
        form(style: const DSPageStyle(gutter: 64)),
        extension: const DSPageStyle(gutter: 48),
      );
      expect(tester.getTopLeft(find.byKey(const Key('field'))).dx, 64);
    });
  });

  group('the gap under a fixed header', () {
    testWidgets('comes from the spec, not from the screen', (tester) async {
      // headerGap is the one number DSPage never needs — its header is a
      // sliver, so firstSectionGap is the gap under it and the break has
      // already been provided by the header sliding away. The four screens
      // that built a fixed header chose sm, md and lg.
      await pump(tester, form());
      expect(scrollPadding(tester).top, AppTheme.spec.space.md);
    });

    testWidgets('and moves through the chain like the rest of it', (
      tester,
    ) async {
      await pump(tester, form(), extension: const DSPageStyle(headerGap: 30));
      expect(scrollPadding(tester).top, 30);
    });
  });
}
