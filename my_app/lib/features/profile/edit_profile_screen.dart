import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/localization/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../auth/application/auth_controller.dart';
import '../auth/data/auth_requests.dart';
import '../auth/presentation/auth_form_widgets.dart';

/// Edit the authenticated user's name. Seeds from the real session user,
/// persists via `PATCH /me`, and refreshes the session on success.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    final input = ProfileUpdateInput(
      firstName: _firstName.text.trim() == user?.firstName
          ? null
          : _firstName.text.trim(),
      lastName: _lastName.text.trim() == (user?.lastName ?? '')
          ? null
          : _lastName.text.trim(),
    );
    if (input.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(input);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profileUpdated)));
      Navigator.of(context).pop();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l.profileEditTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.teal,
                    child: Icon(
                      Icons.person_rounded,
                      size: 50,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.authFieldName,
                  controller: _firstName,
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['first_name']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.authFieldLastName,
                  controller: _lastName,
                  prefixIcon: Icons.person_outline_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['last_name']),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: l.profileSaveChanges,
                  onPressed: _submitting ? null : _save,
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
