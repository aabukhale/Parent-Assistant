import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../kid/data/kid_models.dart';

/// iOS Live Activity for a routine that is genuinely under way (time-bound:
/// it starts with the first checked step and ends when the routine is done
/// or after a few hours at most — iOS caps Live Activities at 8 h active).
///
/// Shows only the routine title and step progress — no names, no points.
/// On Android, on iOS < 16.1, or when the user disabled Live Activities the
/// native side reports unsupported and every call is a no-op.
class RoutineLiveActivity {
  const RoutineLiveActivity._();

  static const _channel = MethodChannel('mamily/live_activity');

  static bool get _supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> update(Routine routine) async {
    if (!_supportedPlatform) return;
    final run = routine.todayRun;
    if (run == null || run.isFinished) return;
    await _invoke('startOrUpdate', {
      'routineId': routine.id,
      'title': routine.title,
      'done': routine.doneCount,
      'total': routine.steps.length,
      'startedAt': run.startedAt?.toUtc().millisecondsSinceEpoch,
    });
  }

  static Future<void> end(Routine routine) async {
    if (!_supportedPlatform) return;
    await _invoke('end', {
      'routineId': routine.id,
      'done': routine.doneCount,
      'total': routine.steps.length,
    });
  }

  /// Ends every Mamily Live Activity (logout / session revoked).
  static Future<void> endAll() async {
    if (!_supportedPlatform) return;
    await _invoke('endAll', const {});
  }

  static Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Not available on this build/OS — nothing to show.
    } on PlatformException catch (e) {
      debugPrint('Live Activity $method failed: ${e.code}');
    }
  }
}
