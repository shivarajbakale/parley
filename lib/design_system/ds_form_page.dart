// ds-tier: 4 — template

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parley_android/design_system/ds_ground.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_divider.dart';
import 'package:parley_android/design_system/ds_hero.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_page_header.dart';

/// A page whose title stays put and whose primary action is pinned.
///
/// The other half of [DSPage], and the second component the kit named before
/// it wrote it: `ui_lint`'s `screen-gutter` rule, `ui_probe`'s `gutter` rule,
/// `ds_page.dart`, `ds_media_row.dart` and the `add-component` skill all say
/// "only `DSPage`, `DSFormPage` or `DSGutter` may apply `space.pageGutter`",
/// and every one of them writes this name as a string rather than a doc link,
/// because a link to a class that is not there does not compile.
///
/// **The difference from [DSPage] is one decision: whether the header
/// scrolls.** On a page of content it should — the title has said its piece
/// and the content is the subject. On a form it must not: the header names
/// what is being filled in, the pinned bar names what the button will do with
/// it, and a reader halfway down a form with both scrolled away is filling in
/// fields for an unnamed thing. So [DSPage] puts the header in the scroll as a
/// sliver and this one puts the scroll under a fixed header.
///
/// Four screens built that shape by hand and disagreed about all four of the
/// numbers it needs:
///
///   * **Under the bar or against it.** `signup_page` set `extendBody: true`
///     and let its fields scroll behind the action bar; the other three left
///     it unset, so the `Scaffold` cut the body off at the bar's top edge. A
///     list that stops dead against an opaque band gives the reader no sign
///     anything is behind it, and a translucent bar has nothing to blur — so
///     this page extends, the same call [DSPage] makes.
///   * **The clearance.** `signup_page` added `space.xl` *plus*
///     `MediaQuery.paddingOf(context).bottom`, which counts the home
///     indicator a second time — [DSPinnedActionBar] already contains it, and
///     that double count is what parked the snack bar a finger's width up the
///     screen before `DSBottomInsets` existed. `repeat_rule_page` used a flat
///     `space.xl` and `new_booking_page` a flat `space.sm`, neither of which
///     knows how tall the bar actually is. Here the number comes from
///     [DSBottomInsets.scrollClearance], which the bar reports itself.
///   * **The reading edge.** Two padded the scroll horizontally, one did not,
///     and none of them could be moved by a [DSPageStyle] override. This
///     resolves the same `gutter` [DSPage] resolves, so a wider page moves the
///     form with it; [DSFormPage.fullBleed] is the opt-out for a form whose
///     rows inset their own content.
///   * **The boundary.** Two drew a [DSDivider] under the header and two drew
///     nothing. It is drawn here, and the condition is not a knob:
///     [DSDivider]'s own guidance is "whitespace first", and it holds —
///     between two blocks of content. This is not that. It is the edge that
///     content passes *under*, and without a line the first field slides up
///     to touch the title with nothing between them. [DSFormPage.hero] is
///     the exception, because a plate draws its own bottom edge: the golden
///     showed a straight hairline immediately under the hero's rounded
///     corners, which is one boundary too many rather than one too few.
///
/// **Which header is still a decision, and the kit already made it.**
/// [DSHero]'s guidance is "the screen is the entry point to a flow and has to
/// say what app this is — sign-in, sign-up, a paywall, a first-run welcome",
/// and [DSPageHeader] for "every screen after the first". A form can be
/// either, so [DSFormPage.hero] takes the plate and the other two
/// constructors take the page header. What the page owns is everything under
/// the header; it does not re-litigate which header, the same call [DSPage]
/// makes by having three constructors.
///
/// The fifth thing they disagreed about was invisible: three of the four read
/// the insets from outside [DSBottomInsetsHost] or not at all, so a read that
/// looked correct returned the fallback. The scroll here is built by a
/// [Builder] under the host for that reason.
///
/// **Use when** a screen's job is to be filled in or chosen from and its
/// primary action is a pinned bar — sign-in, sign-up, create, edit, a step of
/// a flow. This is the `Form` archetype in
/// `docs/principles/screen-archetypes.md`, which asks for exactly this shape:
/// one column, one primary action, full width, above the safe area.
/// **Instead:** [DSPage] when the content is the subject and the header may
/// scroll away — which is nearly every other screen; [DSPage.surface] when
/// there is a fixed header but the body manages its own space rather than
/// scrolling.
class DSFormPage extends StatelessWidget {
  /// The form page: the page owns the reading edge, and its children take the
  /// full width inside it.
  const DSFormPage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.below,
    this.footer,
    this.style,
  }) : _gutter = true,
       _hero = null;

  /// The form page whose children own the reading edge.
  ///
  /// For a form built from rows rather than fields: [DSListTile] insets its
  /// own content so its divider can run to the edge, and a row inside a
  /// gutter-padded scroll is indented twice — it stands out of the column it
  /// belongs to. `new_booking_page`'s repeat row is the case.
  const DSFormPage.fullBleed({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.below,
    this.footer,
    this.style,
  }) : _gutter = false,
       _hero = null;

  /// The entry-point form, whose header is a [DSHero] plate.
  ///
  /// `login_page` is the case, and the reason this is a constructor rather
  /// than a widget slot: the plate carries its own title, eyebrow, mark and
  /// leading, so the scalars the other two constructors take would be dead
  /// parameters beside it.
  const DSFormPage.hero({
    super.key,
    required DSHero header,
    required this.children,
    this.footer,
    this.style,
  }) : _hero = header,
       _gutter = true,
       title = '',
       eyebrow = null,
       subtitle = null,
       leading = null,
       actions = null,
       below = null;

  /// The screen's name. Empty on [DSFormPage.hero], which carries its own.
  final String title;

  /// The small tracked line above the title — an editorial device, not a
  /// breadcrumb. See [DSPageHeader].
  final String? eyebrow;

  /// One supporting line under the title. On a form this is the question the
  /// fields answer, and it is worth leaving null when the pinned bar already
  /// says it: `new_booking_page` lost the bottom of its last row to a subtitle
  /// that repeated the bar's helper text.
  final String? subtitle;

  /// Replaces the automatic back button. A form reached as a modal takes a
  /// close button; one reached as a route takes the default.
  final Widget? leading;

  /// The header's trailing controls.
  final Widget? actions;

  /// Chrome that belongs to the fixed header rather than to the fields — a
  /// step indicator, a tab bar. It stays above the divider, so it does not
  /// scroll away from the fields it is counting.
  final Widget? below;

  /// The form's content, as boxes.
  ///
  /// Boxes rather than slivers, which is the other half of the [DSPage]
  /// difference: a form is a short column of controls that are all built
  /// anyway, and the laziness a sliver buys costs the fixed header the page
  /// exists for.
  final List<Widget> children;

  /// Pinned below the scroll — a [DSPinnedActionBar] holding the primary
  /// action. It reports its own height, so the content above clears it
  /// without this page or the screen being told the number.
  final Widget? footer;

  final DSPageStyle? style;

  final bool _gutter;

  /// Set by [DSFormPage.hero]; mutually exclusive with the header scalars.
  final DSHero? _hero;

  @override
  Widget build(BuildContext context) {
    final resolved = DSPageStyle.resolve(context, style);
    final gutter = _gutter ? (resolved.gutter ?? 0) : 0.0;

    return DSGround(
      child: DSBottomInsetsHost(
        child: Scaffold(
          backgroundColor: resolved.background,
          extendBody: true,
          body: Column(
            children: <Widget>[
              _hero ??
                  DSPageHeader(
                    title: title,
                    eyebrow: eyebrow,
                    subtitle: subtitle,
                    leading: leading,
                    actions: actions,
                    below: below,
                  ),
              // Only under a header that draws no edge of its own. See the
              // boundary paragraph above.
              if (_hero == null) const DSDivider(),
              Expanded(
                // Under the host, so the clearance below reads the heights the
                // bars report. A read taken above it gets the fallback insets
                // and is wrong by exactly the bar it was asking about.
                child: Builder(
                  builder: (context) {
                    final EdgeInsets inset = EdgeInsets.fromLTRB(
                      gutter,
                      resolved.headerGap ?? 0,
                      gutter,
                      (resolved.trailingGap ?? 0) +
                          DSBottomInsets.of(context).scrollClearance,
                    );
                    // A form that does not fill the page is centred in what it
                    // was given rather than stacked at the top.
                    //
                    // Top-alignment is the right default for a page you scroll;
                    // it is the wrong one for a short form under a pinned bar,
                    // because everything the form does not use collects in one
                    // place — between the last field and the button. The probe
                    // calls that a `dead-band` and puts the floor at 140pt, a
                    // sixth of a median phone. Login measured 179 once body copy
                    // came down to 12.8pt: the fields did not move, they simply
                    // stopped reaching.
                    //
                    // A minimum height rather than `SliverFillRemaining`, which
                    // is the sliver written for exactly this and cannot be used
                    // here. With `hasScrollBody: false` it lays the child out at
                    // a *tight* extent taken from `getMaxIntrinsicHeight`, and
                    // the maximum intrinsic height of wrapping text is its
                    // height on one line. At a 2.0 text scale the booking form
                    // wraps, the sliver asked for 33 points less than the column
                    // needed, and the column overflowed by exactly that. A
                    // minimum constraint asks for no intrinsic at all: short
                    // content is stretched to the viewport and centres in it,
                    // tall content is left alone and scrolls.
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: inset,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - inset.top - inset.bottom,
                            ),
                          ),
                          // The gutter above is this page's, and saying so is
                          // what stops a row inside it applying a second one:
                          // `DSSwitchTile` on the master-password form drew its
                          // label at 40pt inside a form already inset to 20.
                          child: DSGutter.markApplied(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              // The `ListView` stretched its children to the
                              // full width; a `Column` centres them. Stretch
                              // keeps the fields the width they have always
                              // been.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: footer,
        ),
      ),
    );
  }
}
