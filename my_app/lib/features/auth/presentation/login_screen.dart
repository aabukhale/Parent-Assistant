import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/device_label.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../application/auth_controller.dart';
import '../data/auth_requests.dart';
import 'auth_form_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(l.authLoginAction)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  l.authLoginTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 32),
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.authFieldEmail,
                  hint: l.authFieldEmailHint,
                  controller: _login,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(
                  messages: _fieldErrors['login'] ?? _fieldErrors['email'],
                ),
                const SizedBox(height: 18),
                AppTextField(
                  label: l.authFieldPassword,
                  hint: l.authFieldPasswordHint,
                  controller: _password,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? l.validationRequired : null,
                ),
                AuthFieldError(messages: _fieldErrors['password']),
                const SizedBox(height: 28),
                PrimaryButton(
                  text: l.authLoginAction,
                  onPressed: _submitting ? null : _submit,
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
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
