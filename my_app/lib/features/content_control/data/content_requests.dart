import 'models/content_enums.dart';

/// `POST …/content-rules` body. The backend does an `updateOrCreate` keyed by a
/// derived `target_key`, so posting the same target twice **updates** the rule
/// (200) instead of creating a duplicate (201) — it is idempotent by design.
class ContentRuleInput {
  const ContentRuleInput.category({
    required this.decision,
    required String categoryId,
    this.label,
  }) : ruleType = ContentRuleType.category,
       contentCategoryId = categoryId,
       contentItemId = null,
       providerKey = null,
       externalRef = null;

  const ContentRuleInput.item({
    required this.decision,
    required String itemId,
    this.label,
  }) : ruleType = ContentRuleType.contentItem,
       contentItemId = itemId,
       contentCategoryId = null,
       providerKey = null,
       externalRef = null;

  const ContentRuleInput.externalChannel({
    required this.decision,
    required this.providerKey,
    required this.externalRef,
    this.label,
  }) : ruleType = ContentRuleType.externalChannel,
       contentCategoryId = null,
       contentItemId = null;

  final ContentRuleType ruleType;
  final ContentDecision decision;
  final String? contentCategoryId;
  final String? contentItemId;
  final String? providerKey;
  final String? externalRef;
  final String? label;

  Map<String, dynamic> toJson() => {
    'rule_type': ruleType.wire,
    'decision': decision.wire,
    if (contentCategoryId != null) 'content_category_id': contentCategoryId,
    if (contentItemId != null) 'content_item_id': contentItemId,
    if (providerKey != null) 'provider_key': providerKey,
    if (externalRef != null) 'external_ref': externalRef,
    if ((label ?? '').trim().isNotEmpty) 'label': label!.trim(),
  };
}
