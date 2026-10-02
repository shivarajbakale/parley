import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_form_page.dart';
import 'package:parley_android/design_system/ds_pinned_action_bar.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Email + password registration — the **Form** archetype
/// (`docs/principles/screen-archetypes.md`), the same shape as [LoginPage].
/// Pushed from [LoginPage] within the auth navigator; on success the gate
/// swaps to the home screen automatically.
///
/// One column, primary bottom and full width. Two forms in one app that put
/// their submit button in two different places is the kind of difference
/// nobody decides and everybody notices.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authProvider.notifier)
        .signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
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
    // The bar this screen pins reports its own height here, so a snack bar
    // does not land on it and the button does not sit on its primary control.
    // Without the host each of the three floats independently and none of them
    // knows the others exist; `DSFab.hideOnScroll` reads a DSScrollRetreat
    // that nothing publishes.

    return DSFormPage(
      eyebrow: 'GET STARTED',
      title: 'Create account',
      leading: const BackButton(),
      footer: DSPinnedActionBar(
        children: [
          DSButton(
            variant: DSButtonVariant.primary,
            label: 'Create account',
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
                  controller: _name,
                  label: 'Name (optional)',
                  leadingIcon: Icons.person_outline,
                  input: const DSFieldInput(
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                context.design.space.verticalMd,
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
                  validation: DSFieldValidation(
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter your email';
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                context.design.space.verticalMd,
                DSTextField(
                  controller: _password,
                  label: 'Password',
                  helperText: 'At least 8 characters',
                  leadingIcon: Icons.lock_outline,
                  input: const DSFieldInput.password(
                    textInputAction: TextInputAction.done,
                  ),
                  validation: DSFieldValidation(
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
