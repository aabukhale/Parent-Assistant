import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../widgets/app_text_field.dart';
import '../data/auth_repository.dart';
import 'auth_form_widgets.dart';

/// Two steps: request a 6-digit code by email, then set a new password.
/// The first step never reveals whether an account exists.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: _email.text,
            code: _code.text,
            password: _password.text,
          );
      if (!mounted) return;
      showResultSnack(context, l.resetDone);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation && e.fieldError('password') != null) {
          _error = e.fieldError('password');
        } else if (e.isValidation) {
          _error = l.resetInvalidCode;
        } else {
          _error = e.localizedMessage(l);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthPage(
      title: l.resetTitle,
      subtitle: _codeSent ? l.resetCodeSent : l.resetIntro,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) AuthFormErrorBanner(message: _error!),
              AppTextField(
                label: l.authFieldEmail,
                hint: l.authFieldEmailHint,
                controller: _email,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => (v == null || !v.contains('@'))
                    ? l.validationRequired
                    : null,
              ),
              if (_codeSent) ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.resetCodeLabel,
                  controller: _code,
                  prefixIcon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  validator: (v) =>
                      (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim()))
                      ? l.resetInvalidCode
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  label: l.resetNewPassword,
                  controller: _password,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) =>
                      (v == null || v.length < 8) ? l.validationRequired : null,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _reset : _send),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(_codeSent ? l.resetSave : l.resetSendCode),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _busy ? null : _send,
                  child: Text(l.resetSendCode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
