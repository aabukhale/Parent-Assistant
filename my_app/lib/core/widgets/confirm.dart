import 'package:flutter/material.dart';

import '../localization/l10n.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../theme/mamily_colors.dart';

/// A bottom-sheet confirmation with one clear primary action. Returns true
/// only when the user explicitly confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  Widget? extra,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final c = sheetContext.mamily;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: sheetContext.type.titleLarge),
              if (body != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: sheetContext.type.bodyLarge?.copyWith(color: c.ink2),
                ),
              ],
              if (extra != null) ...[
                const SizedBox(height: AppSpacing.lg),
                extra,
              ],
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: c.danger.foreground,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(cancelLabel ?? sheetContext.l10n.commonCancel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Short confirmation message, optionally with an Undo action.
void showResultSnack(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: onUndo == null ? 3 : 5),
        // Snackbars with an action persist by default, which left "Undo"
        // covering later screens. Keep it only for screen-reader users, who
        // need time to reach the action.
        persist: MediaQuery.accessibleNavigationOf(context),
        action: onUndo == null
            ? null
            : SnackBarAction(label: context.l10n.commonUndo, onPressed: onUndo),
      ),
    );
}
