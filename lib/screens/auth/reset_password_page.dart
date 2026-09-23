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
import 'package:parley_android/utils/app_routes.dart';
import 'package:parley_android/theme/spec/design_spec.dart';

/// Landing for the password-reset deep link `/reset?token=…`. Demonstrates a
/// token-carrying deep link: the token comes from the URL, the user sets a new
/// password, and on success we route to sign-in.
class ResetPasswordPage extends ConsumerStatefulWidget {
  final String? token;
  const ResetPasswordPage({super.key, this.token});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authProvider.notifier)
        .completePasswordReset(
          token: widget.token ?? '',
          newPassword: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      showDSSnackBar(
        context,
        message: 'Password updated — sign in.',
        tone: DSTone.success,
      );
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = ref.watch(authProvider.select((s) => s.submitting));
    final hasToken = (widget.token ?? '').isNotEmpty;

    ref.listen(authProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        showDSSnackBar(context, message: error, tone: DSTone.error);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const DSPageHeader(eyebrow: 'RECOVER', title: 'New password'),
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
                    if (!hasToken)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: context.design.space.md,
                        ),
                        child: Text(
                          'This reset link is missing or expired. Request a '
                          'new one from the sign-in screen.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.palette.destructive,
                          ),
                        ),
                      ),
                    DSTextField(
                      controller: _password,
                      label: 'New password',
                      helperText: 'At least 8 characters',
                      leadingIcon: Icons.lock_outline,
                      enabled: hasToken,
                      input: const DSFieldInput.password(
                        textInputAction: TextInputAction.done,
                      ),
                      validation: DSFieldValidation(
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                    ),
                    context.design.space.verticalLg,
                    DSButton(
                      variant: DSButtonVariant.primary,
                      label: 'Update password',
                      fullWidth: true,
                      loading: submitting,
                      onPressed: hasToken ? _submit : null,
                    ),
                    if (!hasToken) ...[
                      context.design.space.verticalSm,
                      DSButton(
                        variant: DSButtonVariant.ghost,
                        label: 'Back to sign in',
                        fullWidth: true,
                        onPressed: () => context.go(AppRoutes.login),
                      ),
                    ],
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
