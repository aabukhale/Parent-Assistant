import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/design_system.dart';
import '../../../core/localization/l10n.dart';

/// Shows a friendly message for a failed child action. Never raw server text.
void showKidError(BuildContext context, Object error) {
  final l = context.l10n;
  final message = switch (error) {
    ApiException(kind: ApiErrorKind.rateLimited) => l.pairTooMany,
    ApiException e => e.localizedMessage(l),
    _ => l.errorUnknown,
  };
  showResultSnack(context, message);
}
