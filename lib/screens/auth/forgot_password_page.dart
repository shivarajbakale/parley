import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parley_android/design_system/ds_button.dart';
import 'package:parley_android/design_system/ds_page.dart';
import 'package:parley_android/design_system/ds_page_header.dart';
import 'package:parley_android/design_system/ds_scope.dart';
import 'package:parley_android/design_system/ds_snack_bar.dart';
import 'package:parley_android/design_system/ds_text_field.dart';
import 'package:parley_android/providers/auth_provider.dart';
import 'package:parley_android/theme/spec/design_spec.dart';
import 'package:parley_android/design_system/ds_text.dart';

/// Requests a password-reset email. Always reports success (never reveals
/// whether the account exists) and pops back to sign-in.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_email.text.trim());
    if (!mounted) return;
    if (ok) {
      showDSSnackBar(
        context,
        message: 'If that email exists, a reset link is on its way.',
        tone: DSTone.success,
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(authProvider.select((s) => s.submitting));

    ref.listen(authProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showDSSnackBar(context, message: error, tone: DSTone.error);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const DSPageHeader(
            eyebrow: 'RECOVER',
            title: 'Reset password',
            leading: BackButton(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                DSGutter.of(context),
                context.design.space.md,
                DSGutter.of(context),
                context.design.space.xxxl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DSText(
                      'Enter your email and we’ll send a link to reset your '
                      'password.',
                      role: DSTextRole.bodySupport,
                    ),
                    context.design.space.verticalLg,
                    DSTextField(
                      controller: _email,
                      label: 'Email',
                      hintText: 'you@example.com',
                      leadingIcon: Icons.alternate_email,
                      input: const DSFieldInput.email(
                        textInputAction: TextInputAction.done,
                      ),
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
                    context.design.space.verticalLg,
                    DSButton(
                      variant: DSButtonVariant.primary,
                      label: 'Send reset link',
                      fullWidth: true,
                      loading: submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
