import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'child_requests.dart';
import 'models/child.dart';

/// HTTP for the Sprint 1 child CRUD, scoped to a family.
///
/// Routes: `/families/{family}/children[/{child}]`.
/// Read = any active member; create/update/delete = owner/parent only
/// (caregiver → 403).
class ChildrenRepository {
  ChildrenRepository(this._client);

  final ApiClient _client;

  Future<Paginated<Child>> list({
    required String familyId,
    int page = 1,
    int perPage = 20,
    String status = 'active',
  }) async {
    final envelope = await _client.get(
      '/families/$familyId/children',
      query: {'page': page, 'per_page': perPage, 'status': status},
    );
    return Paginated.from<Child>(envelope, Child.fromJson);
  }

  Future<Child> show(String familyId, String childId) async {
    final envelope = await _client.get('/families/$familyId/children/$childId');
    return Child.fromJson(envelope.dataMap);
  }

  Future<Child> create(String familyId, ChildInput input) async {
    final envelope = await _client.post(
      '/families/$familyId/children',
      body: input.toJson(),
    );
    return Child.fromJson(envelope.dataMap);
  }

  Future<Child> update(
    String familyId,
    String childId,
    ChildInput input,
  ) async {
    final envelope = await _client.patch(
      '/families/$familyId/children/$childId',
      body: input.toJson(),
    );
    return Child.fromJson(envelope.dataMap);
  }

  Future<void> delete(String familyId, String childId) async {
    await _client.delete('/families/$familyId/children/$childId');
  }
}

final childrenRepositoryProvider = Provider<ChildrenRepository>(
  (ref) => ChildrenRepository(ref.watch(apiClientProvider)),
);
