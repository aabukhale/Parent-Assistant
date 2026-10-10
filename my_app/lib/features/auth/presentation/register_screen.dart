import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';

import '../../../core/config/device_label.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../widgets/app_text_field.dart';
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
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l.validationRequired : null;
    return AuthPage(
      title: l.authRegisterTitle,
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
                  label: l.authFieldName,
                  hint: l.authFieldNameHint,
                  controller: _firstName,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  validator: required,
                ),
                AuthFieldError(messages: _fieldErrors['first_name']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.authFieldFamilyName,
                  hint: l.authFieldFamilyNameHint,
                  controller: _familyName,
                  prefixIcon: Icons.family_restroom_rounded,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                AuthFieldError(messages: _fieldErrors['family_name']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: l.authFieldEmail,
                  hint: l.authFieldEmailHint,
                  controller: _email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return l.validationRequired;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value))
                      return l.validationEmail;
                    return null;
                  },
                ),
                AuthFieldError(messages: _fieldErrors['email']),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  label: l.authFieldPassword,
                  hint: l.authFieldPasswordHint,
                  controller: _password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.validationRequired;
                    if (v.length < 8) return l.validationPasswordShort;
                    return null;
                  },
                ),
                AuthFieldError(messages: _fieldErrors['password']),
                const SizedBox(height: AppSpacing.lg),
                PasswordField(
                  label: l.authFieldPasswordConfirm,
                  controller: _passwordConfirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submitting ? null : _submit(),
                  validator: (v) =>
                      v != _password.text ? l.validationPasswordMismatch : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
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
                      : Text(l.authRegisterAction),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
