import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/ds_bottom_insets.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_pressable.dart';
import 'package:parley_android/design_system/ds_progress_indicator.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/providers/observability_provider.dart';
import 'package:parley_android/providers/purchases_provider.dart';
import 'package:parley_android/services/purchases/purchase_models.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Subscription paywall — the **Offer** archetype
/// (`docs/principles/screen-archetypes.md`). Push it with
/// `context.push(AppRoutes.paywall)` from any `pro`-gated action (or
/// deep-link to `/paywall`). Pops on success.
///
/// Push it from the gated action rather than from launch: a paywall that
/// answers a question the user was in the middle of asking outperforms one
/// that greets them.
///
/// The vertical order is the archetype and is not a preference — outcome,
/// then the plans, then the proof, then the primary with the billing
/// disclosure in the same bar. Three of those were missing before this screen
/// named its shape: the action said "Continue", which names no purchase; the
/// renewal amount appeared nowhere, so the user met it at the charge; and
/// terms and privacy, which App Review asks for, were not on the screen at
/// all.
///
/// Benefits copy is placeholder — edit [_benefits] per app.
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  String? _selectedPackageId;

  static const _benefits = [
    'Unlimited everything — no caps',
    'Priority sync across devices',
    'Advanced features & themes',
    'Support an indie developer',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider).screen('paywall');
      ref.read(purchasesProvider.notifier).loadOfferings();
    });
  }

  Future<void> _buy() async {
    final state = ref.read(purchasesProvider);
    final packages = state.offerings.expand((o) => o.packages).toList();
    if (packages.isEmpty) return;
    final selected = packages.firstWhere(
      (p) => p.id == _selectedPackageId,
      orElse: () => packages.first,
    );
    final entitled = await ref
        .read(purchasesProvider.notifier)
        .purchase(selected);
    if (!mounted) return;
    if (entitled) {
      showDSSnackBar(
        context,
        message: 'You’re Pro — thanks!',
        tone: DSTone.success,
      );
      Navigator.of(context).maybePop();
    }
  }

  /// The button names the purchase. "Continue" names nothing, and an action
  /// that could equally be a next step is one people tap by accident.
  String _ctaLabel(PurchasePackage p) => p.period == 'lifetime'
      ? 'Buy Pro — ${p.priceString}'
      : 'Subscribe — ${p.priceString}/${p.period}';

  /// The renewal, the amount and the way out, in plain language, in the same
  /// bar as the button. A disclosure the user meets at the charge instead of
  /// at the tap is most of what the Offer archetype is about.
  String _billingLine(PurchasePackage p) => p.period == 'lifetime'
      ? 'One payment of ${p.priceString}. Nothing renews.'
      : 'Renews at ${p.priceString} every ${p.period} until you cancel. '
            'Cancel any time in your store account.';

  /// Terms and privacy are part of the archetype and part of App Review. This
  /// template has no legal pages to point at, so it says so out loud rather
  /// than shipping a link that goes nowhere — the same honesty the sign-in
  /// screen's demo hint uses.
  void _openLegal(String which) => showDSSnackBar(
    context,
    message: 'Point “$which” at your own URL in lib/screens/paywall_page.dart.',
    tone: DSTone.info,
  );

  Future<void> _restore() async {
    final entitled = await ref.read(purchasesProvider.notifier).restore();
    if (!mounted) return;
    if (entitled) {
      showDSSnackBar(
        context,
        message: 'Purchases restored.',
        tone: DSTone.success,
      );
      Navigator.of(context).maybePop();
    } else {
      showDSSnackBar(
        context,
        message: 'Nothing to restore.',
        tone: DSTone.info,
      );
    }
  }

  /// Shown when offerings can't be loaded (network/store error). The provider
  /// also sets `state.error`, surfaced via the snackbar listener in [build].
  Widget _buildUnavailable(ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DSGutter.of(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: context.design.component.glyphHero,
              color: context.palette.mutedForeground,
            ),
            context.design.space.verticalMd,
            Text(
              'Plans aren’t available right now.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.palette.mutedForeground,
              ),
            ),
            context.design.space.verticalLg,
            DSButton(
              variant: DSButtonVariant.secondary,
              label: 'Try again',
              onPressed: () =>
                  ref.read(purchasesProvider.notifier).loadOfferings(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(purchasesProvider);
    final packages = state.offerings.expand((o) => o.packages).toList();
    final selectedId =
        _selectedPackageId ??
        (packages.where((p) => p.highlighted).firstOrNull?.id ??
            packages.firstOrNull?.id);
    // The bar is drawn from the selected plan, so its label and its renewal
    // line can never describe a different plan from the one that is ticked.
    final selected = state.loadingOfferings
        ? null
        : packages.where((p) => p.id == selectedId).firstOrNull;

    ref.listen(purchasesProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showDSSnackBar(context, message: error, tone: DSTone.error);
      }
    });
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.

    return DSBottomInsetsHost(
      child: Scaffold(
        body: SafeArea(
          // The bar below owns the bottom inset. Both halves being careful is
          // how a bar ends up with a gap under it.
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: state.loadingOfferings
                    ? const Center(child: DSProgressIndicator.circular())
                    : packages.isEmpty
                    ? _buildUnavailable(theme)
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          DSGutter.of(context),
                          0,
                          DSGutter.of(context),
                          context.design.space.lg,
                        ),
                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,
                            size: context.design.component.glyphHero,
                            color: context.palette.primary,
                          ),
                          context.design.space.verticalMd,
                          Text(
                            'Go Pro',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: context.design.type.emphasisWeight,
                            ),
                          ),
                          context.design.space.verticalSm,
                          // The outcome, in the user's terms. Not the name of
                          // the tier, which they have no way to price.
                          Text(
                            'Everything this app does, on every device you '
                            'use, with no caps.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: context.palette.mutedForeground,
                            ),
                          ),
                          context.design.space.verticalLg,
                          // Plans before proof. The user came to find out what
                          // it costs; a benefit list they have to scroll past
                          // first reads as a delay.
                          ...packages.map(
                            (p) => _PlanCard(
                              package: p,
                              selected: p.id == selectedId,
                              onTap: () =>
                                  setState(() => _selectedPackageId = p.id),
                            ),
                          ),
                          context.design.space.verticalMd,
                          ..._benefits.map(
                            (b) => Padding(
                              padding: EdgeInsets.only(
                                bottom: context.design.space.sm,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size:
                                        context.design.component.iconSizeInline,
                                    color: context.palette.primary,
                                  ),
                                  context.design.space.horizontalSm,
                                  Expanded(child: Text(b)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        // `DSPinnedActionBar`, not a Padding around a Column: the bar owns the
        // safe area, the chrome material and the hairline, and it is the only
        // place `ui_lint`'s `glass-off-chrome` allows that material. It also
        // carries the disclosure, which is how the renewal line and the button
        // stay in one block at every text scale.
        bottomNavigationBar: selected == null
            ? null
            : DSPinnedActionBar(
                layout: DSActionBarLayout.stack,
                helperText: _billingLine(selected),
                children: [
                  DSButton(
                    variant: DSButtonVariant.primary,
                    label: _ctaLabel(selected),
                    fullWidth: true,
                    loading: state.purchasing,
                    onPressed: _buy,
                  ),
                  // Wrap, not Row: three links at a 2.0x text scale are wider
                  // than a phone, and the one that would be clipped is the one
                  // App Review looks for.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DSButton(
                        variant: DSButtonVariant.ghost,
                        label: 'Restore purchases',
                        size: DSButtonSize.sm,
                        onPressed: state.purchasing ? null : _restore,
                      ),
                      DSButton(
                        variant: DSButtonVariant.ghost,
                        label: 'Terms',
                        size: DSButtonSize.sm,
                        onPressed: () => _openLegal('Terms'),
                      ),
                      DSButton(
                        variant: DSButtonVariant.ghost,
                        label: 'Privacy',
                        size: DSButtonSize.sm,
                        onPressed: () => _openLegal('Privacy'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PurchasePackage package;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schemePalette = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(context.radiusOf(AppShape.control)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: context.design.space.sm),
      child: DSPressable(
        focusShape: shape,
        child: DSInkSurface(
          shape: shape,
          tint: selected
              ? schemePalette.secondary.withValues(alpha: 0.4)
              : schemePalette.muted,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(context.design.space.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                context.radiusOf(AppShape.control),
              ),
              border: Border.all(
                color: selected
                    ? schemePalette.primary
                    : schemePalette.borderSoft,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? schemePalette.primary
                      : schemePalette.mutedForeground,
                ),
                context.design.space.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            package.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: context.design.type.emphasisWeight,
                            ),
                          ),
                          if (package.highlighted) ...[
                            context.design.space.horizontalSm,
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.design.space.sm,
                                vertical: context.design.space.hairline,
                              ),
                              decoration: BoxDecoration(
                                color: schemePalette.primary,
                                borderRadius: BorderRadius.circular(
                                  context.radiusOf(AppShape.control),
                                ),
                              ),
                              child: Text(
                                'BEST VALUE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: schemePalette.primaryForeground,
                                  fontWeight:
                                      context.design.type.emphasisWeight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        package.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: schemePalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                context.design.space.horizontalSm,
                Text(
                  package.priceString,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: context.design.type.emphasisWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
