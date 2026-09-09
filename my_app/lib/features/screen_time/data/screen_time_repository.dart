import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/screen_time_models.dart';

/// The editable fields of one screen-time rule (default or a weekday override).
class ScreenTimeRuleInput {
  const ScreenTimeRuleInput({
    required this.dailyLimitMinutes,
    this.sessionLimitMinutes,
    this.allowedStartTime,
    this.allowedEndTime,
    this.isEnabled = true,
  });

  final int dailyLimitMinutes;
  final int? sessionLimitMinutes;
  final String? allowedStartTime;
  final String? allowedEndTime;
  final bool isEnabled;

  Map<String, dynamic> toJson() => {
    'daily_limit_minutes': dailyLimitMinutes,
    if (sessionLimitMinutes != null)
      'session_limit_minutes': sessionLimitMinutes,
    if (allowedStartTime != null) 'allowed_start_time': allowedStartTime,
    if (allowedEndTime != null) 'allowed_end_time': allowedEndTime,
    'is_enabled': isEnabled,
  };
}

/// `PUT …/screen-time-rules` body: exactly one `default` and 0–7 `overrides`,
/// each keyed by ISO `day_of_week` (1–7). The backend **replaces** the whole
/// rule set with what is sent.
class ScreenTimeRulesInput {
  const ScreenTimeRulesInput({
    required this.defaultRule,
    this.overrides = const {},
  });

  final ScreenTimeRuleInput defaultRule;

  /// ISO day-of-week (1–7) → rule.
  final Map<int, ScreenTimeRuleInput> overrides;

  Map<String, dynamic> toJson() => {
    'default': defaultRule.toJson(),
    'overrides': [
      for (final entry in overrides.entries)
        {'day_of_week': entry.key, ...entry.value.toJson()},
    ],
  };
}

class GrantExtraTimeInput {
  const GrantExtraTimeInput({
    required this.additionalMinutes,
    this.expiresAt,
    this.reason,
  });

  final int additionalMinutes;
  final DateTime? expiresAt;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'additional_minutes': additionalMinutes,
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

/// One usage event for `POST …/usage/ingest`. `clientEventId` is the **per-child
/// idempotency key** — a retry of the same logical event MUST reuse it.
class UsageEvent {
  const UsageEvent({
    required this.startedAt,
    required this.endedAt,
    required this.usedSeconds,
    required this.clientEventId,
    this.appIdentifier,
    this.appName,
    this.category,
    this.source,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int usedSeconds;
  final String clientEventId;
  final String? appIdentifier;
  final String? appName;
  final String? category;
  final String? source;

  Map<String, dynamic> toJson() => {
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'used_seconds': usedSeconds,
    'client_event_id': clientEventId,
    if (appIdentifier != null) 'app_identifier': appIdentifier,
    if (appName != null) 'app_name': appName,
    if (category != null) 'category': category,
    if (source != null) 'source': source,
  };
}

/// `POST …/usage/ingest` body. `batchId` is the **batch idempotency key** — a
/// retry of the same batch reuses it, and the backend returns `replayed: true`
/// with the original result instead of double-counting.
class UsageIngestBatch {
  const UsageIngestBatch({
    required this.batchId,
    required this.events,
    this.deviceId,
  });

  final String batchId;
  final List<UsageEvent> events;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    if (deviceId != null) 'device_id': deviceId,
    'events': [for (final e in events) e.toJson()],
  };
}

@immutable
class UsageIngestResult {
  const UsageIngestResult({
    required this.batchId,
    required this.inserted,
    required this.skipped,
    required this.replayed,
  });

  final String batchId;
  final int inserted;
  final int skipped;
  final bool replayed;

  factory UsageIngestResult.fromJson(Map<String, dynamic> json) =>
      UsageIngestResult(
        batchId: '${json['batch_id']}',
        inserted: (json['inserted'] as num?)?.round() ?? 0,
        skipped: (json['skipped'] as num?)?.round() ?? 0,
        replayed: json['replayed'] as bool? ?? false,
      );
}

/// HTTP for `/families/{family}/children/{child}` screen-time endpoints
/// (`ScreenTimeController`, `ScreenTimeOverrideController`).
///
/// Reads (rules / summary / policy / overrides) = any active member.
/// `manage_screen_time` for rule updates; `grant_extra_time` for override
/// grant/revoke. Usage ingest = any active member, but there is **no native
/// usage collector in this app** — [ingestUsage] exists for a future native
/// bridge and is never called with fabricated data.
class ScreenTimeRepository {
  ScreenTimeRepository(this._client);

  final ApiClient _client;

  String _child(String familyId, String childId) =>
      '/families/$familyId/children/$childId';

  Future<List<ScreenTimeRule>> rules(String familyId, String childId) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/screen-time-rules',
    );
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(ScreenTimeRule.fromJson)
        .toList(growable: false);
  }

  Future<List<ScreenTimeRule>> updateRules(
    String familyId,
    String childId,
    ScreenTimeRulesInput input,
  ) async {
    final envelope = await _client.put(
      '${_child(familyId, childId)}/screen-time-rules',
      body: input.toJson(),
    );
    return envelope.dataList
        .whereType<Map<String, dynamic>>()
        .map(ScreenTimeRule.fromJson)
        .toList(growable: false);
  }

  Future<ScreenTimeSummary> summary(
    String familyId,
    String childId, {
    DateTime? date,
  }) async {
    final dateParam = date == null
        ? null
        : DateFormat('yyyy-MM-dd').format(date);
    final envelope = await _client.get(
      '${_child(familyId, childId)}/screen-time/summary',
      query: {'date': ?dateParam},
    );
    return ScreenTimeSummary.fromJson(envelope.dataMap);
  }

  Future<ScreenTimePolicy> policy(
    String familyId,
    String childId, {
    String? deviceId,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/screen-time/policy',
      query: {'device_id': ?deviceId},
    );
    return ScreenTimePolicy.fromJson(envelope.dataMap);
  }

  Future<Paginated<ScreenTimeOverride>> overrides(
    String familyId,
    String childId, {
    bool activeOnly = false,
    int page = 1,
    int perPage = 25,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/screen-time-overrides',
      query: {'page': page, 'per_page': perPage, 'active_only': activeOnly},
    );
    return Paginated.from<ScreenTimeOverride>(
      envelope,
      ScreenTimeOverride.fromJson,
    );
  }

  Future<ScreenTimeOverride> grantExtraTime(
    String familyId,
    String childId,
    GrantExtraTimeInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/screen-time-overrides',
      body: input.toJson(),
    );
    return ScreenTimeOverride.fromJson(envelope.dataMap);
  }

  Future<ScreenTimeOverride> revokeOverride(
    String familyId,
    String childId,
    String overrideId,
  ) async {
    final envelope = await _client.delete(
      '${_child(familyId, childId)}/screen-time-overrides/$overrideId',
    );
    return ScreenTimeOverride.fromJson(envelope.dataMap);
  }

  /// For a future native usage bridge only. `batch.batchId` and each
  /// `event.clientEventId` must be stable across retries.
  Future<UsageIngestResult> ingestUsage(
    String familyId,
    String childId,
    UsageIngestBatch batch,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/usage/ingest',
      body: batch.toJson(),
    );
    return UsageIngestResult.fromJson(envelope.dataMap);
  }
}

final screenTimeRepositoryProvider = Provider<ScreenTimeRepository>(
  (ref) => ScreenTimeRepository(ref.watch(apiClientProvider)),
);
