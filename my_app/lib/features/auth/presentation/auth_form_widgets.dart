import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A form-level error strip (invalid credentials, network failure, …).
class AuthFormErrorBanner extends StatelessWidget {
  const AuthFormErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.coral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.coral,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single backend field-validation message rendered under its input.
class AuthFieldError extends StatelessWidget {
  const AuthFieldError({super.key, required this.messages});
  final List<String>? messages;

  @override
  Widget build(BuildContext context) {
    if (messages == null || messages!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          messages!.first,
          style: const TextStyle(color: AppColors.coral, fontSize: 12),
        ),
      ),
    );
  }
}
