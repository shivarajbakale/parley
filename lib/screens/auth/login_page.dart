import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_form_page.dart';
import 'package:parley_android/design_system/ds_hero.dart';
import 'package:parley_android/design_system/ds_message.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/design_system/ds_text.dart';

/// Email + password sign-in — the **Form** archetype
/// (`docs/principles/screen-archetypes.md`). First screen of the
/// unauthenticated flow.
///
/// It opens on a [DSHero] rather than a [DSPageHeader], and that is the one
/// place this app spends a screen's worth of surface on saying what it is: a
/// sign-in screen is the only screen a user meets before they have any reason
/// to trust the thing, and a title over a column of grey rectangles gives them
/// nothing to go on.
///
/// One column, and the primary action **bottom, full width, above the safe
/// area** rather than at the end of the scroll. That is the single clearest
/// difference from the desktop form it would otherwise be: the bottom edge is
/// the reachable zone on a phone, and a submit button that scrolls away is one
/// the user has to go looking for. Pinned, it also rides above the keyboard —
/// the Scaffold lifts its bottom bar by the inset, so the button is visible
/// while the last field is being typed into.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
    _finishAutofill();
  }

  /// Tells the platform the credential set is complete, which is what prompts
  /// "Save this password?". Only on success: offering to save the pair that
  /// was just rejected is how a wrong password gets into a keychain.
  void _finishAutofill() {
    if (ref.read(authProvider).error != null) return;
    TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(authProvider.select((s) => s.submitting));

    ref.listen(authProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showDSSnackBar(context, message: error, tone: DSTone.error);
      }
    });

    return DSFormPage.hero(
      // No subtitle. The eyebrow already says the returning half, and every
      // line the plate spends is a line the form loses: with one here,
      // `make ui-probe` put the demo banner behind the pinned bar at a 1.3x
      // text scale.
      header: const DSHero(eyebrow: 'Welcome back', title: 'Sign in'),
      footer: DSPinnedActionBar(
        children: [
          DSButton(
            variant: DSButtonVariant.primary,
            label: 'Sign in',
            fullWidth: true,
            loading: submitting,
            onPressed: _submit,
          ),
        ],
      ),
      children: [
        // AutofillGroup, not the hints alone: the hints say what a field
        // holds, and the group is what tells the platform the set was
        // submitted together. Without it iOS and Android offer to fill but
        // never offer to save, which is the half of password-manager support
        // a user notices.
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSTextField(
                  controller: _email,
                  label: 'Email',
                  hintText: 'you@example.com',
                  leadingIcon: Icons.alternate_email,
                  input: const DSFieldInput.email(
                    textInputAction: TextInputAction.next,
                  ),
                  onChanged: (_) =>
                      ref.read(authProvider.notifier).clearError(),
                  validation: DSFieldValidation(validator: _validateEmail),
                ),
                context.design.space.verticalMd,
                DSTextField(
                  controller: _password,
                  label: 'Password',
                  leadingIcon: Icons.lock_outline,
                  input: const DSFieldInput.password(
                    textInputAction: TextInputAction.done,
                  ),
                  validation: DSFieldValidation(
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                ),
                context.design.space.verticalSm,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: DSButton(
                    variant: DSButtonVariant.ghost,
                    label: 'Forgot password?',
                    size: DSButtonSize.sm,
                    onPressed: () => context.push(AppRoutes.forgot),
                  ),
                ),
                context.design.space.verticalMd,
                // Wrap, not Row: at the largest accessibility text size
                // the sentence and the link together are wider than a
                // phone, and a Row clips whichever one is on the outside.
                // Wrapping to a second line is what a reader at that size
                // expects; losing the link is not.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const DSText(
                      "Don't have an account?",
                      role: DSTextRole.bodySupport,
                    ),
                    DSButton(
                      variant: DSButtonVariant.ghost,
                      label: 'Sign up',
                      size: DSButtonSize.sm,
                      onPressed: () => context.push(AppRoutes.signup),
                    ),
                  ],
                ),
                context.design.space.verticalLg,
                const _DemoHint(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
    return null;
  }
}

/// Surfaces the mock account credentials. Delete this widget once a real
/// [AuthService] is wired.
///
/// A [DSMessage], not the hand-rolled slab it used to be. That slab was a
/// filled container at card weight, which made the loudest block on the
/// sign-in screen the one telling the user the backend is fake.
class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) => const DSMessage(
    tone: DSMessageTone.info,
    message:
        'Mock backend — sign in with demo@rocketship.dev / password, '
        'or create any account.',
  );
}
