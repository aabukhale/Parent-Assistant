import 'package:flutter/foundation.dart';

/// Backend `App\Enums\ActivitySource`. Unknown wire values fall back to
/// [global] rather than throwing.
enum ActivitySource {
  global,
  ai,
  family;

  static ActivitySource fromWire(String? v) => switch (v) {
    'ai' => ActivitySource.ai,
    'family' => ActivitySource.family,
    _ => ActivitySource.global,
  };

  String get wire => name;
}

/// A catalog activity (`ActivityResource`). `title` / `description` are already
/// localized by the API for the request locale — never re-translate them.
@immutable
class Activity {
  const Activity({
    required this.id,
    required this.familyId,
    required this.source,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.minAge,
    required this.maxAge,
    required this.materials,
    required this.steps,
    required this.isActive,
    this.createdAt,
  });

  final String id;

  /// `null` for a global / AI template; a UUID for a family-created activity.
  final String? familyId;
  final ActivitySource source;
  final String title;
  final String? description;
  final int? durationMinutes;
  final int? minAge;
  final int? maxAge;

  /// Always a list (the API defaults a null column to `[]`).
  final List<String> materials;
  final List<String> steps;
  final bool isActive;
  final DateTime? createdAt;

  bool get isFamily => source == ActivitySource.family || familyId != null;

  static List<String> _stringList(Object? raw) => raw is List
      ? raw.map((e) => '$e').toList(growable: false)
      : const <String>[];

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
    id: '${json['id']}',
    familyId: json['family_id'] as String?,
    source: ActivitySource.fromWire(json['source'] as String?),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    durationMinutes: (json['duration_minutes'] as num?)?.round(),
    minAge: (json['min_age'] as num?)?.round(),
    maxAge: (json['max_age'] as num?)?.round(),
    materials: _stringList(json['materials']),
    steps: _stringList(json['steps']),
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse('${json['created_at']}'),
  );
}
