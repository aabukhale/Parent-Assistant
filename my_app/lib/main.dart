import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/deep_links.dart';
import 'core/cache/offline_cache.dart';
import 'core/localization/app_locales.dart';
import 'core/localization/l10n.dart';
import 'core/localization/locale_controller.dart';
import 'core/providers.dart';
import 'core/session/session_cleanup.dart';
import 'core/storage/secure_token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_state.dart';
import 'features/auth/data/child_auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/pairing_screen.dart';
import 'features/notifications/push/push_service.dart';
import 'features/surfaces/live_activity.dart';
import 'features/surfaces/surface_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the persisted UI locale before the first frame so there is no flash
  // of the wrong language / direction.
  final storage = SecureTokenStorage();
  final storedLocale = AppLocales.resolve(await storage.readLocale());
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      initialLocaleProvider.overrideWithValue(storedLocale),
    ],
  );
  _registerSessionCleanup(container);
  await container.read(pushServiceProvider).initialize();

  runApp(
    UncontrolledProviderScope(container: container, child: const MamilyApp()),
  );
}

/// Everything private that must disappear when a session ends.
void _registerSessionCleanup(ProviderContainer container) {
  container.read(sessionCleanupProvider)
    ..register(() => container.read(offlineCacheProvider).clear())
    ..register(RoutineLiveActivity.endAll)
    ..register(() => container.read(surfaceSyncProvider).clearAll())
    ..register(() => container.read(pushServiceProvider).onSessionEnded());
}

class MamilyApp extends ConsumerStatefulWidget {
  const MamilyApp({super.key});

  @override
  ConsumerState<MamilyApp> createState() => _MamilyAppState();
}

class _MamilyAppState extends ConsumerState<MamilyApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    _listenForLinks();
  }

  Future<void> _listenForLinks() async {
    try {
      final appLinks = AppLinks();
      _links = appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
    } catch (_) {
      // Link handling unavailable on this platform (e.g. tests).
    }
  }

  /// `mamily://pair?code=…` opens pairing (only when signed out — never
  /// replaces a live session). `mamily://open/<route>` opens an in-app route
  /// through the role-checked router.
  void _handleLink(Uri uri) {
    if (uri.scheme != 'mamily') return;
    final auth = ref.read(authControllerProvider);
    if (uri.host == 'pair') {
      if (auth.phase != AuthPhase.unauthenticated) return;
      final code = pairingCodeFromLink(uri.toString());
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => PairingScreen(initialCode: code),
        ),
      );
      return;
    }
    if (uri.host == 'open') {
      DeepLinks.open(ref, uri.path);
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  String _surface(AuthState s) => switch (s.phase) {
    AuthPhase.authenticated when s.isChild =>
      'child:${s.childSession!.childId}',
    AuthPhase.authenticated => 'parent:${s.session?.user.id}',
    _ => s.phase.name,
  };

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    // When the session changes (sign in/out, revoke, child ↔ parent), drop any
    // pushed screens so nothing from the previous session stays visible.
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (prev != null &&
          _surface(prev) != _surface(next) &&
          next.phase != AuthPhase.restoring) {
        rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    });

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Text grows up to 200% (WCAG 1.4.4). Beyond that the largest iOS
      // accessibility sizes broke words letter by letter on phone widths.
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 2, child: child!),
      home: const AuthGate(),
    );
  }
}
