import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_control_tile.dart';
import 'package:parley_android/design_system/ds_dialog.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_settings.dart';
import 'package:parley_android/design_system/ds_theme_mode_picker.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/providers/purchases_provider.dart';
import 'package:parley_android/providers/settings_provider.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// The Settings tab — the **Settings** archetype
/// (`docs/principles/screen-archetypes.md`).
///
/// Grouped inset lists, in the order the user thinks about them rather than
/// the order the services are wired in: who you are, how it looks, how it
/// behaves, what it is. Every toggle applies immediately — a switch that needs
/// a Save button was never a switch — and the one destructive action sits in
/// its own group at the bottom, behind a confirm that names what it will do.
class SettingsPage extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;

  const SettingsPage({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);
    final isPro = ref.watch(isProProvider);

    return CustomScrollView(
      slivers: [
        DSPageHeader.compactSliver(
          title: 'Settings',
          leading: onOpenDrawer != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onOpenDrawer,
                  tooltip: 'Open navigation menu',
                )
              : null,
        ),
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Account',
            children: [
              if (user != null)
                // The address goes under the label rather than beside it. An
                // email is long and unbreakable, and a row that puts one on
                // its trailing edge either cuts the address or cuts the label
                // it answers — the probe found both, at 320 points.
                DSSettingsRow(label: 'Signed in as', description: user.email),
              isPro
                  ? const DSSettingsRow(label: 'Subscription', value: 'Pro')
                  : DSSettingsRow(
                      label: 'Upgrade to Pro',
                      onTap: () => context.push(AppRoutes.paywall),
                    ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.design.space.xl)),
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Appearance',
            children: [
              DSSettingsRow(
                label: 'Theme',
                trailing: DSThemeModePicker(
                  value: settings.themeMode,
                  showLabels: false,
                  onChanged: (mode) {
                    ref.read(settingsProvider.notifier).setThemeMode(mode);
                  },
                ),
              ),
              DSSettingsRow(
                label: 'Display Settings',
                onTap: () => context.push(AppRoutes.appearance),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.design.space.xl)),
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Preferences',
            footer:
                'Confirmations help prevent accidental deletes. Haptics fire on tab switches and key actions.',
            children: [
              DSSwitchTile(
                label: 'Haptic Feedback',
                value: settings.hapticFeedback,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).setHapticFeedback(v),
              ),
              DSSwitchTile(
                label: 'Confirm Before Delete',
                value: settings.confirmBeforeDelete,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setConfirmBeforeDelete(v),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.design.space.xl)),
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'About',
            children: [
              const DSSettingsRow(label: 'Version', value: '0.1.0'),
              // The tour is three screens a user meets once and can never
              // find again, which is the usual fate of onboarding. `?demo=1`
              // is the router's existing opt-in for a screen someone asked
              // for rather than arrived at.
              DSSettingsRow(
                label: 'Replay the tour',
                onTap: () => context.push('${AppRoutes.onboarding}?demo=1'),
              ),
              DSSettingsRow(
                label: 'About',
                onTap: () => context.push(AppRoutes.about),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.design.space.xl)),
        // Its own group, at the bottom, in the destructive colour. Sitting
        // third in the Account list it was one mis-tap away from every other
        // row; here it is somewhere the thumb has to travel to on purpose.
        SliverToBoxAdapter(
          child: DSSettingsSection(
            eyebrow: 'Session',
            footer: 'Signing out clears the stored token on this device.',
            children: [
              DSSettingsRow(
                label: 'Sign out',
                tone: DSTone.error,
                icon: Icons.logout,
                onTap: () => _confirmSignOut(context, ref, user?.email),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          // Clears the floating nav bar: see `dashboard_page`.
          child: SizedBox(
            height:
                context.design.space.xl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  /// Names the object. "Are you sure?" asks the user to remember which
  /// account they are signed in to; the email is the thing they are actually
  /// deciding about, so it goes in the sentence.
  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    String? email,
  ) async {
    final confirmed = await showDSConfirm(
      context: context,
      icon: Icons.logout,
      title: 'Sign out?',
      message: email == null
          ? 'You will need to sign in again to get back to your data.'
          : 'You will need to sign in as $email again to get back to your '
                'data.',
      confirmLabel: 'Sign out',
      // Not a tone: `destructive` moves the default focus onto Cancel as well
      // as colouring the confirm, which is the rule both platforms state.
      destructive: true,
    );
    if (confirmed ?? false) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
}
