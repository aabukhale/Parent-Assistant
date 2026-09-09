import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/sleep_log.dart';
import 'models/sleep_summary.dart';
import 'sleep_requests.dart';

/// HTTP for `/families/{family}/children/{child}/sleep-logs`.
///
/// Read = any active member; create / update / delete require the `manage_sleep`
/// permission (owner/parent implicitly; caregiver → 403). Overlapping periods
/// come back as **409**.
class SleepRepository {
  SleepRepository(this._client);

  final ApiClient _client;

  String _base(String familyId, String childId) =>
      '/families/$familyId/children/$childId/sleep-logs';

  Future<Paginated<SleepLog>> list({
    required String familyId,
    required String childId,
    int page = 1,
    int perPage = 20,
  }) async {
    final envelope = await _client.get(
      _base(familyId, childId),
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<SleepLog>(envelope, SleepLog.fromJson);
  }

  Future<SleepLog> show(String familyId, String childId, String logId) async {
    final envelope = await _client.get('${_base(familyId, childId)}/$logId');
    return SleepLog.fromJson(envelope.dataMap);
  }

  Future<SleepLog> create(
    String familyId,
    String childId,
    SleepLogInput input,
  ) async {
    final envelope = await _client.post(
      _base(familyId, childId),
      body: input.toJson(),
    );
    return SleepLog.fromJson(envelope.dataMap);
  }

  Future<SleepLog> update(
    String familyId,
    String childId,
    String logId,
    SleepLogInput input,
  ) async {
    final envelope = await _client.patch(
      '${_base(familyId, childId)}/$logId',
      body: input.toJson(),
    );
    return SleepLog.fromJson(envelope.dataMap);
  }

  Future<void> delete(String familyId, String childId, String logId) async {
    await _client.delete('${_base(familyId, childId)}/$logId');
  }

  Future<SleepSummary> summary({
    required String familyId,
    required String childId,
    required String period,
  }) async {
    final envelope = await _client.get(
      '${_base(familyId, childId)}/summary',
      query: {'period': period},
    );
    return SleepSummary.fromJson(envelope.dataMap);
  }
}

final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) => SleepRepository(ref.watch(apiClientProvider)),
);
