import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';

/// Root navigator, so notification taps and links can navigate without a
/// BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Selected tab of the child shell / parent shell (deep links switch tabs).
final kidTabProvider = StateProvider<int>((_) => 0);
final parentTabProvider = StateProvider<int>((_) => 0);

/// A link that arrived before the right session was ready (e.g. a
/// notification tapped while the app was terminated). Consumed by the shell.
final pendingDeepLinkProvider = StateProvider<String?>((_) => null);

/// `ref.read` of either a widget ref or a provider ref.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

typedef RouteOpener =
    Future<void> Function(NavigatorState nav, Reader read, Uri uri);

/// Authorizes and opens in-app routes such as `/child/tasks/{id}` or
/// `/parent/inbox`.
///
/// A route is only a *hint*: the target screen re-fetches its data with the
/// current session, so an id that belongs to someone else simply 404s. The
/// router additionally refuses any route for the other role, so a crafted
/// notification or link can never open a parent screen in a child session.
class DeepLinks {
  const DeepLinks._();

  static RouteOpener? kidOpener;
  static RouteOpener? parentOpener;

  static bool isAllowed(String route, {required bool isChild}) {
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
    final first = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return isChild ? first == 'child' : first == 'parent';
  }

  /// Open [route] now if the matching session is active, else remember it.
  static Future<void> open(WidgetRef ref, String route) =>
      openWith(ref.read, route);

  static Future<void> openWith(Reader read, String route) async {
    final auth = read(authControllerProvider);
    final isChild = auth.isChild;
    final ready =
        auth.isChild || (auth.isAuthenticated && auth.activeMembership != null);
    if (!ready) {
      read(pendingDeepLinkProvider.notifier).state = route;
      return;
    }
    if (!isAllowed(route, isChild: isChild)) return;
    final nav = rootNavigatorKey.currentState;
    final opener = isChild ? kidOpener : parentOpener;
    if (nav == null || opener == null) {
      read(pendingDeepLinkProvider.notifier).state = route;
      return;
    }
    await opener(nav, read, Uri.parse(route));
  }

  /// Called by a shell once it is on screen.
  static Future<void> consumePending(WidgetRef ref) async {
    final pending = ref.read(pendingDeepLinkProvider);
    if (pending == null) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    await openWith(ref.read, pending);
  }
}
