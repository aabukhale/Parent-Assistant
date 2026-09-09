import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/family_member.dart';

/// `GET /families/{family}/members` — roles + backend-computed
/// `effective_permissions` for every member. Any active member may read.
class FamilyMembersRepository {
  FamilyMembersRepository(this._client);

  final ApiClient _client;

  /// One page.
  Future<Paginated<FamilyMember>> list({
    required String familyId,
    int page = 1,
    int perPage = 50,
  }) async {
    final envelope = await _client.get(
      '/families/$familyId/members',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<FamilyMember>(envelope, FamilyMember.fromJson);
  }

  /// Every member of the family (families are small; pages through if needed).
  /// Capped at 20 pages so a misbehaving `meta` can never loop forever.
  Future<List<FamilyMember>> listAll(String familyId) async {
    var page = 1;
    final first = await list(familyId: familyId, page: page);
    final members = [...first.items];
    var meta = first.meta;
    while (meta.hasMore && page < 20) {
      page++;
      final next = await list(familyId: familyId, page: page);
      members.addAll(next.items);
      meta = next.meta;
    }
    return members;
  }
}

final familyMembersRepositoryProvider = Provider<FamilyMembersRepository>(
  (ref) => FamilyMembersRepository(ref.watch(apiClientProvider)),
);
