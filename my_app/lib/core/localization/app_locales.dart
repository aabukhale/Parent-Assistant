import 'package:flutter/widgets.dart';

/// The three locales the backend and app support. Arabic is the default.
class AppLocales {
  const AppLocales._();

  static const arabic = Locale('ar');
  static const hebrew = Locale('he');
  static const english = Locale('en');

  static const fallback = arabic;

  static const supported = <Locale>[arabic, hebrew, english];

  static const rtl = <String>{'ar', 'he'};

  static bool isRtl(Locale locale) => rtl.contains(locale.languageCode);

  /// Normalise an arbitrary language tag to a supported [Locale].
  static Locale resolve(String? languageCode) {
    switch (languageCode) {
      case 'ar':
        return arabic;
      case 'he':
        return hebrew;
      case 'en':
        return english;
      default:
        return fallback;
    }
  }
}
