import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/interceptors.dart';
import 'config/app_config.dart';
import 'localization/app_locales.dart';
import 'localization/locale_controller.dart';
import 'storage/secure_token_storage.dart';

/// Persisted UI locale, read once at startup. `main()` overrides this with the
/// value from [SecureTokenStorage]; the default keeps Arabic if nothing stored.
final initialLocaleProvider = Provider<Locale>((_) => AppLocales.fallback);

final appConfigProvider = Provider<AppConfig>(
  (_) => AppConfig.fromEnvironment(),
);

final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => SecureTokenStorage(),
);

/// Bumped by the Dio [AuthInterceptor] whenever the backend answers 401.
/// The auth controller listens to this and forces the app back to sign-in.
final unauthorizedSignalProvider = StateProvider<int>((_) => 0);

/// Bumped after any mutation whose result feeds a dashboard / report aggregate
/// (points, task completions, sleep logs, learning goals, children, reward
/// redemptions). The Phase 7 dashboard providers `ref.watch` this and re-fetch;
/// nothing else observes it, so a bump is a cheap no-op when no dashboard is
/// mounted. Lives in `core` so feature controllers can signal it without a
/// cross-feature import.
final dashboardRefreshSignalProvider = StateProvider<int>((_) => 0);

/// Signal that dashboard aggregates may have changed. Safe to call from a
/// mutation controller after `await`.
void bumpDashboardRefresh(Ref ref) =>
    ref.read(dashboardRefreshSignalProvider.notifier).state++;

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {'Accept': 'application/json'},
      // Let the client map non-2xx itself.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      tokenReader: storage.readToken,
      onUnauthorized: () async {
        await storage.clearSession();
        // StateController mutation is safe from here; the auth controller reacts.
        ref.read(unauthorizedSignalProvider.notifier).state++;
      },
    ),
    LocaleInterceptor(
      languageCodeReader: () => ref.read(localeControllerProvider).languageCode,
    ),
    if (config.enableRequestLogging) SafeLoggingInterceptor(),
  ]);

  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
