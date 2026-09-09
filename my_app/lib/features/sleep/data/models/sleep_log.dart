import 'package:flutter/foundation.dart';

/// Backend `App\Enums\SleepSource`. The app only ever creates `manual` logs;
/// `device` is reserved for native sleep sensors (not built — no device
/// monitoring in this phase).
enum SleepSource {
  manual,
  device;

  static SleepSource fromString(String? v) =>
      v == 'device' ? SleepSource.device : SleepSource.manual;

  String get wire => name;
}

/// A single sleep period (`SleepLogResource`).
///
/// * `started_at` / `ended_at` are **UTC ISO-8601** on the wire; parsed as UTC
///   and exposed as `startedAtLocal` / `endedAtLocal` for display.
/// * `durationMinutes` is **derived by the backend** (`round(|end - start|)`) —
///   never recomputed or stored here. A period may legitimately span midnight,
///   so `started_at` and `ended_at` are not assumed to share a date.
@immutable
class SleepLog {
  const SleepLog({
    required this.id,
    required this.childId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.source,
    this.recordedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String childId;

  /// UTC.
  final DateTime startedAt;

  /// UTC.
  final DateTime endedAt;

  final int durationMinutes;
  final SleepSource source;
  final String? recordedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DateTime get startedAtLocal => startedAt.toLocal();
  DateTime get endedAtLocal => endedAt.toLocal();

  /// True when the local start and end fall on different calendar days.
  bool get crossesMidnightLocal {
    final s = startedAtLocal;
    final e = endedAtLocal;
    return s.year != e.year || s.month != e.month || s.day != e.day;
  }

  factory SleepLog.fromJson(Map<String, dynamic> json) => SleepLog(
    id: '${json['id']}',
    childId: '${json['child_id']}',
    startedAt: DateTime.parse('${json['started_at']}'),
    endedAt: DateTime.parse('${json['ended_at']}'),
    durationMinutes: (json['duration_minutes'] as num?)?.round() ?? 0,
    source: SleepSource.fromString(json['source'] as String?),
    recordedBy: json['recorded_by'] as String?,
    createdAt: DateTime.tryParse('${json['created_at']}'),
    updatedAt: DateTime.tryParse('${json['updated_at']}'),
  );
}
