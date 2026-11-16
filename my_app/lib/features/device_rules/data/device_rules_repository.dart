import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import 'device_rules_models.dart';

/// Parent-side device rules for one child. The server re-checks
/// manage_screen_time on every change; children have no route here.
class DeviceRulesRepository {
  DeviceRulesRepository(this._client, this.familyId);

  final ApiClient _client;
  final String familyId;

  String _base(String childId) =>
      '/families/$familyId/children/$childId/device-rules';

  Future<DeviceRulesState> load(String childId) async =>
      DeviceRulesState.fromJson((await _client.get(_base(childId))).dataMap);

  /// [expectedVersion] protects against two parents overwriting each other
  /// (the server answers 409 when the rules changed meanwhile).
  Future<DeviceRulesState> save(
    String childId,
    DeviceRules rules, {
    required int expectedVersion,
    String? summary,
  }) async => DeviceRulesState.fromJson(
    (await _client.put(
      _base(childId),
      body: {
        ...rules.toJson(),
        'expected_version': expectedVersion,
        'summary': ?summary,
      },
    )).dataMap,
  );

  Future<RulePreview> preview(String childId, DeviceRules rules) async =>
      RulePreview.fromJson(
        (await _client.post(
          '${_base(childId)}/preview',
          body: rules.toJson(),
        )).dataMap,
      );

  Future<DeviceRulesState> applyPreset(
    String childId,
    String preset, {
    List<int>? days,
    String? start,
    String? end,
    String? name,
    int? minutes,
  }) async => DeviceRulesState.fromJson(
    (await _client.post(
      '${_base(childId)}/presets',
      body: {
        'preset': preset,
        'days': ?days,
        'start': ?start,
        'end': ?end,
        'name': ?name,
        'minutes': ?minutes,
      },
    )).dataMap,
  );

  /// [minutes] null = until released.
  Future<DeviceRulesState> restrictNow(String childId, {int? minutes}) async =>
      DeviceRulesState.fromJson(
        (await _client.post(
          '${_base(childId)}/restrict-now',
          body: {'minutes': minutes},
        )).dataMap,
      );

  Future<DeviceRulesState> release(String childId) async =>
      DeviceRulesState.fromJson(
        (await _client.post('${_base(childId)}/release')).dataMap,
      );

  Future<DeviceRulesState> undoTo(String childId, int version) async =>
      DeviceRulesState.fromJson(
        (await _client.post(
          '${_base(childId)}/undo',
          body: {'version': version},
        )).dataMap,
      );

  /// Apps reported by the child's Android phones (for the picker).
  Future<({List<AppRef> apps, DateTime? reportedAt})> apps(
    String childId,
  ) async {
    final d = (await _client.get('${_base(childId)}/apps')).dataMap;
    return (
      apps: ((d['apps'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AppRef.fromJson(m.cast<String, dynamic>()))
          .toList(),
      reportedAt: DateTime.tryParse(
        (d['reported_at'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  Future<List<RuleVersion>> history(String childId) async {
    final items = (await _client.get(
      '${_base(childId)}/history',
    )).dataMap['items'];
    return (items as List)
        .whereType<Map>()
        .map((m) => RuleVersion.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

final deviceRulesRepositoryProvider = Provider<DeviceRulesRepository>(
  (ref) => DeviceRulesRepository(
    ref.watch(apiClientProvider),
    ref.watch(activeFamilyIdProvider) ?? '',
  ),
);

final deviceRulesProvider = FutureProvider.autoDispose
    .family<DeviceRulesState, String>(
      (ref, childId) => ref.watch(deviceRulesRepositoryProvider).load(childId),
    );

final ruleHistoryProvider = FutureProvider.autoDispose
    .family<List<RuleVersion>, String>(
      (ref, childId) =>
          ref.watch(deviceRulesRepositoryProvider).history(childId),
    );
