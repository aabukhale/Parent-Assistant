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

  /// A paired child's language, chosen by a parent for that child. Shown
  /// while the child session is active but never stored as this device's
  /// own language, so it can't leak into a parent's session on a shared
  /// phone. (It is restored on restart from the cached child session.)
  void applyChildLanguage(String? code) {
    if (code == null) return;
    final locale = AppLocales.resolve(code);
    if (state != locale) state = locale;
  }

  /// Back to this device's own language (the last one a person picked here
  /// or a parent account's language), e.g. after a child session ends.
  Future<void> restoreDeviceLocale() async {
    final stored = await ref.read(secureStorageProvider).readLocale();
    state = AppLocales.resolve(stored);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
