import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../errors/api_exception.dart';

export '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  /// Localized strings for the active locale. Non-null (see `nullable-getter: false`).
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension ApiExceptionL10n on ApiException {
  /// A user-safe, localized message. Raw server/exception text is never shown.
  ///
  /// For [ApiErrorKind.validation] the backend's own field messages
  /// (already localized via `Accept-Language`) are preferred by the forms;
  /// this returns the generic fallback.
  String localizedMessage(AppLocalizations l) => switch (kind) {
    ApiErrorKind.network => l.errorNetwork,
    ApiErrorKind.timeout => l.errorTimeout,
    ApiErrorKind.unauthorized => l.errorUnauthorized,
    ApiErrorKind.forbidden => l.errorForbidden,
    ApiErrorKind.notFound => l.errorNotFound,
    ApiErrorKind.conflict => l.errorConflict,
    ApiErrorKind.validation => l.errorValidation,
    ApiErrorKind.rateLimited => l.errorRateLimited,
    ApiErrorKind.unavailable => l.errorUnavailable,
    ApiErrorKind.server => l.errorServer,
    ApiErrorKind.unknown => l.errorUnknown,
  };
}
