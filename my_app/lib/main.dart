import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/deep_links.dart';
import 'core/cache/offline_cache.dart';
import 'core/design_system.dart';
import 'core/localization/app_locales.dart';
import 'core/localization/l10n.dart';
import 'core/localization/locale_controller.dart';
import 'core/providers.dart';
import 'core/session/session_cleanup.dart';
import 'core/storage/secure_token_storage.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_state.dart';
import 'features/auth/data/child_auth_repository.dart';
import 'features/auth/data/models/child_session.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/pairing_screen.dart';
import 'features/notifications/push/push_service.dart';
import 'features/remote/presentation/kid_remote_layer.dart';
import 'features/surfaces/live_activity.dart';
import 'features/surfaces/surface_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply the persisted UI locale before the first frame so there is no flash
  // of the wrong language / direction.
  final storage = SecureTokenStorage();
  final storedLocale = await _initialLocale(storage);
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

/// A paired child's phone opens in the language a parent chose for that
/// child (from the cached session, so also offline); otherwise the device's
/// own language.
Future<Locale> _initialLocale(SecureTokenStorage storage) async {
  if (await storage.readSessionKind() == ChildAuthRepository.sessionKind) {
    try {
      final cached = await storage.readChildSessionCache();
      if (cached != null) {
        final session = ChildSession.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        if (session.language != null) {
          return AppLocales.resolve(session.language);
        }
      }
    } catch (_) {
      // Corrupt cache: fall back to the device language.
    }
  }
  return AppLocales.resolve(await storage.readLocale());
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

  /// A pairing code from a `mamily://pair` link that arrived before the
  /// session was known (cold start: the child scanned the parent's QR with
  /// the camera app, which launched Mamily). Kept until auth settles instead
  /// of being dropped — dropping it is what made children scan twice.
  String? _pendingPairCode;
  final _handledPairCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _listenForLinks();
  }

  Future<void> _listenForLinks() async {
    try {
      final appLinks = AppLinks();
      _links = appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
      // Also ask for the launch link explicitly; duplicates are ignored.
      final initial = await appLinks.getInitialLink();
      if (initial != null && mounted) _handleLink(initial);
    } catch (_) {
      // Link handling unavailable on this platform (e.g. tests).
    }
  }

  /// `mamily://pair?code=…` pairs this phone (only when signed out — never
  /// replaces a live session). `mamily://open/<route>` opens an in-app route
  /// through the role-checked router.
  void _handleLink(Uri uri) {
    if (uri.scheme != 'mamily') return;
    if (uri.host == 'pair') {
      final code = pairingCodeFromLink(uri.toString());
      if (code == null || !_handledPairCodes.add(code)) return;
      _pendingPairCode = code;
      _openPendingPairing();
      return;
    }
    if (uri.host == 'open') {
      DeepLinks.open(ref, uri.path);
    }
  }

  void _openPendingPairing() {
    final code = _pendingPairCode;
    if (code == null) return;
    final auth = ref.read(authControllerProvider);
    switch (auth.phase) {
      case AuthPhase.restoring || AuthPhase.restoreFailed:
        return; // Wait: the auth listener calls back when it settles.
      case AuthPhase.unauthenticated:
        _pendingPairCode = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = rootNavigatorKey.currentState;
          if (nav == null) return;
          nav.popUntil((r) => r.isFirst);
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PairingScreen(initialCode: code, autoSubmit: true),
            ),
          );
        });
      case AuthPhase.authenticated:
        _pendingPairCode = null;
        // Never swap a live session for a scanned code. A child phone says
        // why nothing happened; a parent phone ignores it.
        if (auth.isChild) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) showResultSnack(ctx, ctx.l10n.pairAlreadySignedIn);
        }
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
      if (_pendingPairCode != null && next.phase != AuthPhase.restoring) {
        _openPendingPairing();
      }
    });

    // Child screens pushed on the root navigator (routine run, task details)
    // sit outside the kid shell, so the app-wide theme follows the session.
    final isChild = ref.watch(authControllerProvider.select((s) => s.isChild));

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: isChild ? AppTheme.kid : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Text grows up to 200% (WCAG 1.4.4). Beyond that the largest iOS
      // accessibility sizes broke words letter by letter on phone widths.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        // A child's remote-help banner (with Stop) sits above the navigator,
        // so it stays visible on every screen, not only the tab shell.
        child: isChild ? KidRemoteLayer(child: child!) : child!,
      ),
      home: const AuthGate(),
    );
  }
}
