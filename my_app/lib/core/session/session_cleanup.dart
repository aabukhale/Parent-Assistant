import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything that must be wiped when a session ends (logout, revoke, 401,
/// account switch): offline caches, home-screen widget data, the floating
/// overlay, scheduled local notifications, …
///
/// Features register a task at startup; [run] executes them all and never
/// lets one failure stop the others.
class SessionCleanup {
  final List<Future<void> Function()> _tasks = [];

  void register(Future<void> Function() task) => _tasks.add(task);

  Future<void> run() async {
    for (final task in List.of(_tasks)) {
      try {
        await task();
      } catch (e) {
        debugPrint('Session cleanup step failed: ${e.runtimeType}');
      }
    }
  }
}

final sessionCleanupProvider = Provider<SessionCleanup>(
  (_) => SessionCleanup(),
);
