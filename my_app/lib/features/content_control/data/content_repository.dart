import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'content_requests.dart';
import 'models/content_item.dart';

/// HTTP for the content catalog + per-child content policy
/// (`ContentCatalogController`, `ContentPolicyController`).
///
/// Catalog reads = any authenticated user. Policy reads = any active member.
/// `manage_content_policy` for the age-filter setting and rule create/delete.
/// Rule create is **idempotent** server-side (updateOrCreate by target key).
class ContentRepository {
  ContentRepository(this._client);

  final ApiClient _client;

  String _child(String familyId, String childId) =>
      '/families/$familyId/children/$childId';

  // --- Catalog ---

  Future<Paginated<ContentItem>> listCatalog({
    int? age,
    String? categoryKey,
    int page = 1,
    int perPage = 20,
  }) async {
    final envelope = await _client.get(
      '/content',
      query: {
        'page': page,
        'per_page': perPage,
        'age': ?age,
        'category': ?categoryKey,
      },
    );
    return Paginated.from<ContentItem>(envelope, ContentItem.fromJson);
  }

  Future<ContentItem> showItem(String itemId) async {
    final envelope = await _client.get('/content/$itemId');
    return ContentItem.fromJson(envelope.dataMap);
  }

  // --- Policy ---

  Future<EffectiveContentPolicy> policy(String familyId, String childId) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/content-policy',
    );
    return EffectiveContentPolicy.fromJson(envelope.dataMap);
  }

  /// `PUT …/content-policy` — the only mutable *setting*. Returns the recomputed
  /// effective policy.
  Future<EffectiveContentPolicy> setAgeFilter(
    String familyId,
    String childId, {
    required bool enabled,
  }) async {
    final envelope = await _client.put(
      '${_child(familyId, childId)}/content-policy',
      body: {'age_filter_enabled': enabled},
    );
    return EffectiveContentPolicy.fromJson(envelope.dataMap);
  }

  Future<Paginated<ContentRule>> listRules(
    String familyId,
    String childId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final envelope = await _client.get(
      '${_child(familyId, childId)}/content-rules',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<ContentRule>(envelope, ContentRule.fromJson);
  }

  Future<ContentRule> saveRule(
    String familyId,
    String childId,
    ContentRuleInput input,
  ) async {
    final envelope = await _client.post(
      '${_child(familyId, childId)}/content-rules',
      body: input.toJson(),
    );
    return ContentRule.fromJson(envelope.dataMap);
  }

  Future<void> deleteRule(
    String familyId,
    String childId,
    String ruleId,
  ) async {
    await _client.delete('${_child(familyId, childId)}/content-rules/$ruleId');
  }
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(apiClientProvider)),
);
