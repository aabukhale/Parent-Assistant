import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';

import '../../../core/config/device_label.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import '../data/auth_requests.dart';
import 'auth_form_widgets.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            LoginInput(
              login: _login.text.trim(),
              password: _password.text,
              deviceName: currentDeviceLabel(),
            ),
          );
      // On success the AuthGate swaps to the app shell; nothing to navigate.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          // Backend sometimes reports invalid credentials as a 'login' field error.
          if (_fieldErrors.isEmpty) {
            _formError = e.localizedMessage(context.l10n);
          }
        } else {
          _formError =
              e.rawMessage?.isNotEmpty == true && e.kind == ApiErrorKind.unknown
              ? e.rawMessage
              : e.localizedMessage(context.l10n);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthPage(
      title: l.authLoginTitle,
      subtitle: l.parentEntrySubtitle,
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.authFieldEmail,
                  hint: l.authFieldEmailHint,
                  controller: _login,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(
                  messages: _fieldErrors['login'] ?? _fieldErrors['email'],
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  label: l.authFieldPassword,
                  hint: l.authFieldPasswordHint,
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitting ? null : _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? l.validationRequired : null,
                ),
                AuthFieldError(messages: _fieldErrors['password']),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _login.text.trim(),
                        ),
                      ),
                    ),
                    child: Text(l.authForgotPassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.authLoginAction),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
