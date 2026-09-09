import 'package:flutter/foundation.dart';

import 'models/sleep_log.dart';

/// Create / update payload for `…/sleep-logs`.
///
/// The pickers produce **local** `DateTime`s; they are converted to UTC ISO-8601
/// on the wire (the backend stores/returns UTC). `started_at` and `ended_at` are
/// always sent together — the backend's `required_with` rules pair them, and a
/// period may span midnight so both full timestamps matter.
@immutable
class SleepLogInput {
  const SleepLogInput({
    required this.startedAt,
    required this.endedAt,
    this.source,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// Only sent when set. Create defaults to `manual`; edit omits it to preserve
  /// the existing source.
  final SleepSource? source;

  Map<String, dynamic> toJson() => {
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    if (source != null) 'source': source!.wire,
  };

  Duration get localSpan => endedAt.difference(startedAt);
}
