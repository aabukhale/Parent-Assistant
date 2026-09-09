import 'package:flutter/foundation.dart';

import 'content_enums.dart';

@immutable
class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.key,
    required this.name,
  });

  final String id;
  final String key;
  final String name;

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(
        id: '${json['id']}',
        key: '${json['key']}',
        name: json['name'] as String? ?? '',
      );
}

@immutable
class ContentProvider {
  const ContentProvider({required this.key, required this.name});

  final String key;
  final String name;

  factory ContentProvider.fromJson(Map<String, dynamic> json) =>
      ContentProvider(
        key: '${json['key']}',
        name: json['name'] as String? ?? '',
      );
}

/// A catalog content item (`ContentItemResource`). `title` / `description` are
/// API-localized. Nothing about media URLs, thumbnails, or duration is invented
/// — the backend does not expose them.
@immutable
class ContentItem {
  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.provider,
    required this.externalRef,
    required this.minAge,
    required this.maxAge,
    required this.publishedAt,
    required this.categories,
  });

  final String id;
  final ContentType type;
  final String title;
  final String? description;
  final ContentProvider? provider;
  final String? externalRef;
  final int? minAge;
  final int? maxAge;
  final DateTime? publishedAt;
  final List<ContentCategory> categories;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final rawProvider = json['provider'];
    final rawCategories = (json['categories'] as List?) ?? const [];
    return ContentItem(
      id: '${json['id']}',
      type: ContentType.fromWire(json['type'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      provider: rawProvider is Map<String, dynamic>
          ? ContentProvider.fromJson(rawProvider)
          : null,
      externalRef: json['external_ref'] as String?,
      minAge: (json['min_age'] as num?)?.round(),
      maxAge: (json['max_age'] as num?)?.round(),
      publishedAt: DateTime.tryParse('${json['published_at']}'),
      categories: rawCategories
          .whereType<Map>()
          .map((m) => ContentCategory.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

/// One stored parental content rule (`ContentRuleResource`). This is **policy
/// configuration only** — it does not, by itself, block anything on a device.
@immutable
class ContentRule {
  const ContentRule({
    required this.id,
    required this.childId,
    required this.ruleType,
    required this.decision,
    required this.contentCategoryId,
    required this.contentItemId,
    required this.providerKey,
    required this.externalRef,
    required this.label,
    this.createdAt,
  });

  final String id;
  final String childId;
  final ContentRuleType ruleType;
  final ContentDecision decision;
  final String? contentCategoryId;
  final String? contentItemId;
  final String? providerKey;
  final String? externalRef;
  final String? label;
  final DateTime? createdAt;

  factory ContentRule.fromJson(Map<String, dynamic> json) => ContentRule(
    id: '${json['id']}',
    childId: '${json['child_id']}',
    ruleType: ContentRuleType.fromWire(json['rule_type'] as String?),
    decision: ContentDecision.fromWire(json['decision'] as String?),
    contentCategoryId: json['content_category_id'] as String?,
    contentItemId: json['content_item_id'] as String?,
    providerKey: json['provider_key'] as String?,
    externalRef: json['external_ref'] as String?,
    label: json['label'] as String?,
    createdAt: DateTime.tryParse('${json['created_at']}'),
  );
}

@immutable
class ExternalChannelDecision {
  const ExternalChannelDecision({
    required this.providerKey,
    required this.externalRef,
    required this.label,
    required this.decision,
  });

  final String? providerKey;
  final String? externalRef;
  final String? label;
  final ContentDecision decision;

  factory ExternalChannelDecision.fromJson(Map<String, dynamic> json) =>
      ExternalChannelDecision(
        providerKey: json['provider_key'] as String?,
        externalRef: json['external_ref'] as String?,
        label: json['label'] as String?,
        decision: ContentDecision.fromWire(json['decision'] as String?),
      );
}

/// The child's **effective** content policy (`ContentPolicyService::effectivePolicy`).
/// Server-computed and authoritative. `category_decisions` / `item_decisions`
/// are maps of id → decision.
@immutable
class EffectiveContentPolicy {
  const EffectiveContentPolicy({
    required this.childId,
    required this.childAge,
    required this.contentAge,
    required this.ageFilterEnabled,
    required this.categoryDecisions,
    required this.itemDecisions,
    required this.externalChannels,
  });

  final String childId;
  final int? childAge;
  final int? contentAge;
  final bool ageFilterEnabled;
  final Map<String, ContentDecision> categoryDecisions;
  final Map<String, ContentDecision> itemDecisions;
  final List<ExternalChannelDecision> externalChannels;

  static Map<String, ContentDecision> _decisions(Object? raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry('$k', ContentDecision.fromWire('$v')));
  }

  factory EffectiveContentPolicy.fromJson(Map<String, dynamic> json) {
    final rawChannels = (json['external_channels'] as List?) ?? const [];
    return EffectiveContentPolicy(
      childId: '${json['child_id']}',
      childAge: (json['child_age'] as num?)?.round(),
      contentAge: (json['content_age'] as num?)?.round(),
      ageFilterEnabled: json['age_filter_enabled'] as bool? ?? true,
      categoryDecisions: _decisions(json['category_decisions']),
      itemDecisions: _decisions(json['item_decisions']),
      externalChannels: rawChannels
          .whereType<Map>()
          .map(
            (m) => ExternalChannelDecision.fromJson(m.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}
