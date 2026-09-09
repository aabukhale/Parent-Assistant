import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_locales.dart';

/// Holds the active UI [Locale].
///
/// - Seeded from secure storage at startup (see `initialLocaleProvider`, which
///   `main()` overrides with the persisted value).
/// - [setLocale] persists the choice and updates the app immediately.
/// - The Dio locale interceptor reads [localeControllerProvider] on every
///   request, so changing the locale here also changes `Accept-Language`.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => ref.read(initialLocaleProvider);

  Future<void> setLocale(Locale locale) async {
    if (!AppLocales.supported.contains(locale)) return;
    state = locale;
    await ref.read(secureStorageProvider).writeLocale(locale.languageCode);
  }

  Future<void> setLanguageCode(String code) =>
      setLocale(AppLocales.resolve(code));
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
