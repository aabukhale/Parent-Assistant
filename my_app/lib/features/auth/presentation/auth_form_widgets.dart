import 'package:flutter/material.dart';

import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';

/// Form-level error (e.g. wrong credentials). Announced to screen readers.
class AuthFormErrorBanner extends StatelessWidget {
  const AuthFormErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: NoticeBanner(tone: AppTone.danger, message: message),
  );
}

/// A single backend field-validation message rendered under its input.
class AuthFieldError extends StatelessWidget {
  const AuthFieldError({super.key, required this.messages});
  final List<String>? messages;

  @override
  Widget build(BuildContext context) {
    if (messages == null || messages!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        right: AppSpacing.xs,
        left: AppSpacing.xs,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          messages!.first,
          style: context.type.bodySmall?.copyWith(
            color: context.mamily.danger.foreground,
          ),
        ),
      ),
    );
  }
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: context.type.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(Icons.lock_outline_rounded, color: c.ink2),
            suffixIcon: IconButton(
              tooltip: _obscure ? l.authPasswordShow : l.authPasswordHide,
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared layout for auth pages: brand mark, title, subtitle, form.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppContentFrame(
        top: false,
        child: AppContentFrame(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MamilyBrandMark(size: 56),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(title, style: context.type.headlineMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    style: context.type.bodyLarge?.copyWith(
                      color: context.mamily.ink2,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
