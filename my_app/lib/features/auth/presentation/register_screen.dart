import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/device_label.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../application/auth_controller.dart';
import '../data/auth_requests.dart';
import 'auth_form_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _familyName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void dispose() {
    _firstName.dispose();
    _familyName.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
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
          .register(
            RegisterInput(
              firstName: _firstName.text.trim(),
              familyName: _familyName.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              passwordConfirmation: _passwordConfirm.text,
              deviceName: currentDeviceLabel(),
              preferredLanguage: ref
                  .read(localeControllerProvider)
                  .languageCode,
            ),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          if (_fieldErrors.isEmpty) {
            _formError = e.localizedMessage(context.l10n);
          }
        } else {
          _formError = e.localizedMessage(context.l10n);
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
      appBar: AppBar(title: Text(l.authRegisterAction)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(
                  l.authRegisterTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 28),
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.authFieldName,
                  hint: l.authFieldNameHint,
                  controller: _firstName,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: _required,
                ),
                AuthFieldError(messages: _fieldErrors['first_name']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.authFieldFamilyName,
                  hint: l.authFieldFamilyNameHint,
                  controller: _familyName,
                  prefixIcon: Icons.family_restroom_rounded,
                  validator: _required,
                ),
                AuthFieldError(messages: _fieldErrors['family_name']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.authFieldEmail,
                  hint: l.authFieldEmailHint,
                  controller: _email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.validationRequired;
                    }
                    final ok = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v.trim());
                    return ok ? null : l.validationEmail;
                  },
                ),
                AuthFieldError(messages: _fieldErrors['email']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.authFieldPassword,
                  hint: l.authFieldPasswordHint,
                  controller: _password,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.validationRequired;
                    return v.length < 8 ? l.validationPasswordShort : null;
                  },
                ),
                AuthFieldError(messages: _fieldErrors['password']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.authFieldPasswordConfirm,
                  controller: _passwordConfirm,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) =>
                      v == _password.text ? null : l.validationPasswordMismatch,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  text: l.authRegisterAction,
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? context.l10n.validationRequired : null;
}
