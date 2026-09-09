import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_locales.dart';
import 'core/localization/l10n.dart';
import 'core/localization/locale_controller.dart';
import 'core/providers.dart';
import 'core/storage/secure_token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply the persisted UI locale before the first frame so there is no flash
  // of the wrong language / direction.
  final storage = SecureTokenStorage();
  final storedLocale = AppLocales.resolve(await storage.readLocale());

  runApp(
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        initialLocaleProvider.overrideWithValue(storedLocale),
      ],
      child: const MamilyApp(),
    ),
  );
}

class MamilyApp extends ConsumerWidget {
  const MamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
