/// Backend `App\Enums\ContentType`. Unknown wire values are preserved as
/// [unknown] so a new backend type never crashes the app.
enum ContentType {
  video,
  audio,
  story,
  educationalCard,
  movementChallenge,
  channel,
  unknown;

  static ContentType fromWire(String? v) => switch (v) {
    'video' => ContentType.video,
    'audio' => ContentType.audio,
    'story' => ContentType.story,
    'educational_card' => ContentType.educationalCard,
    'movement_challenge' => ContentType.movementChallenge,
    'channel' => ContentType.channel,
    _ => ContentType.unknown,
  };
}

/// Backend `App\Enums\ContentRuleType`.
enum ContentRuleType {
  category('category'),
  contentItem('content_item'),
  externalChannel('external_channel'),
  unknown('unknown');

  const ContentRuleType(this.wire);
  final String wire;

  static ContentRuleType fromWire(String? v) => switch (v) {
    'category' => ContentRuleType.category,
    'content_item' => ContentRuleType.contentItem,
    'external_channel' => ContentRuleType.externalChannel,
    _ => ContentRuleType.unknown,
  };
}

/// Backend `App\Enums\ContentDecision`.
enum ContentDecision {
  allow('allow'),
  block('block'),
  unknown('unknown');

  const ContentDecision(this.wire);
  final String wire;

  static ContentDecision fromWire(String? v) => switch (v) {
    'allow' => ContentDecision.allow,
    'block' => ContentDecision.block,
    _ => ContentDecision.unknown,
  };
}
