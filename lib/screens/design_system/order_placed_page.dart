import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/design_system.dart';
import 'package:parley_android/screens/design_system/order_data.dart';
import 'package:parley_android/theme/app_haptics.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';

/// The end moment — the **Confirmation** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// What happened, its identifier, what was ordered, and what happens next.
/// In that order, because the order *is* the archetype: the screen's first
/// job is confirming *this* transaction rather than celebrating a transaction
/// in general, and the identifier is what makes it this one.
///
/// What to imitate when you replace it:
///
///   * the **outcome** is in the past tense and in the reader's words — "Your
///     order is placed", not "Success". A word that could head any screen in
///     any app is a word that confirms nothing;
///   * the **identifier is selectable**. An order number a reader cannot copy
///     is one they photograph, and a photograph is not in their order history;
///   * the **summary is on the screen**, not only in the email. It is the most
///     requested thing on a confirmation and the easiest to leave off;
///   * **what happens next carries a date.** "Arrives Thursday 12 March", not
///     "soon". A next step with no date is the question the reader comes back
///     to the app to ask;
///   * the **undo window is named here** and nowhere else. A cancellation
///     policy the reader meets in an email is one they meet too late;
///   * **it says what it emailed**, which is what stops the screenshot;
///   * there is **one way onward**. A confirmation is the last screen of a
///     flow, not the last screen of the app — and it is never a dialog: the
///     end of four screens of work does not get dismissed by a tap outside
///     it.
///
/// Delete this file and `order_data.dart` with the rest of the design-system
/// demo surface when the app ships a real checkout.
class OrderPlacedPage extends StatelessWidget {
  const OrderPlacedPage({super.key, this.order = demoOrder});

  final DemoOrder order;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final theme = Theme.of(context);
    final palette = context.palette;

    // The bar carries the screen's name and nothing else, so the page's
    // default header is the right one: `header-earns-its-height` fails a large
    // header with no payload, and the payload of this screen is the outcome
    // below it.
    return DSPage(
      title: 'Order placed',
      slivers: [
        DSGutter.sliver(
          // A confirmation centres in the page rather than stacking at the
          // top of it.
          //
          // There is exactly one of this screen's content and nothing to
          // scroll to, so top-alignment collects everything the page does not
          // use into one band between the last card and the pinned button.
          // The probe grades that as `dead-band` above 140pt, a sixth of a
          // median phone; this measured 150 once body copy came down to
          // 12.8pt. The cards did not move — they stopped reaching.
          //
          // `SliverLayoutBuilder` and a minimum height rather than
          // `SliverFillRemaining`, which is the sliver written for this and
          // cannot be used: with `hasScrollBody: false` it lays its child out
          // at a tight extent taken from `getMaxIntrinsicHeight`, and the
          // maximum intrinsic height of wrapping text is its height on one
          // line. A minimum constraint asks for no intrinsic at all — short
          // content is stretched to the viewport and centres in it, and
          // content that outgrows the page is left alone and scrolls.
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) => SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    constraints.viewportMainAxisExtent -
                        constraints.precedingScrollExtent -
                        DSBottomInsets.of(context).scrollClearance,
                  ),
                ),
                child: Align(
                  // A 50/50 centre split put half the slack above the
                  // banner: fine on the device this was tuned against, but on
                  // a taller phone the same math hands the top an even bigger
                  // share of an even bigger slack, and the page reads as
                  // mostly empty before anything starts. `dead-band` only
                  // grades the space *below* the content, so the split can
                  // move most of the slack there without tripping it —
                  // pinned to `-0.4` rather than the floor (`-1`, all slack
                  // below) so a device with unusually little content left
                  // over still keeps a bottom band under the 140pt rule.
                  alignment: const Alignment(0, -0.4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DSMessage(
                        tone: DSMessageTone.success,
                        title: 'Your order is placed',
                        message:
                            'We sent a copy to ${order.emailedTo}. '
                            '${order.cancelUntil}.',
                        icon: Icons.check_circle_outline,
                      ),
                      SizedBox(height: space.md),
                      _Reference(reference: order.reference),
                      SizedBox(height: space.lg),
                      DSSection(
                        label: 'What you ordered',
                        child: DSCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final line in order.lines)
                                DSListTile(
                                  title: line.title,
                                  subtitle: line.detail,
                                  trailing: Text(
                                    line.price,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  divider: true,
                                ),
                              DSListTile(
                                title: 'Total',
                                subtitle: order.paidWith,
                                trailing: Text(
                                  order.total,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: space.lg),
                      DSSection(
                        label: 'What happens next',
                        child: DSCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                color: palette.mutedForeground,
                              ),
                              SizedBox(width: space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DSText(
                                      order.arrives,
                                      role: DSTextRole.body,
                                    ),
                                    SizedBox(height: space.hairline),
                                    const DSText(
                                      'We will email you the tracking number the '
                                      'morning it ships.',
                                      role: DSTextRole.bodyDetail,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      // One way onward, pinned: this is the last screen of a flow, and the
      // thing the reader does next is leave it.
      footer: DSPinnedActionBar(
        children: [
          DSButton(
            label: 'Track order',
            icon: Icons.local_shipping_outlined,
            fullWidth: true,
            onPressed: () {
              AppHaptics.selection();
              context.push(AppRoutes.blog);
            },
          ),
          DSButton(
            label: 'Back to shop',
            variant: DSButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}

/// The identifier, in a well the reader can select from.
///
/// `SelectableText` rather than `Text` is the whole point of the widget: the
/// archetype's rule is that the number can be copied, and a number that can
/// only be read is one the reader photographs.
class _Reference extends StatelessWidget {
  const _Reference({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final space = context.design.space;
    final theme = Theme.of(context);
    final palette = context.palette;

    return DSCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order number',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
                SizedBox(height: space.hairline),
                SelectableText(reference, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
