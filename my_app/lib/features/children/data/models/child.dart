import 'package:flutter/foundation.dart';

import 'interest.dart';

enum ChildGender {
  male,
  female,
  unspecified;

  static ChildGender? fromString(String? v) => switch (v) {
    'male' => ChildGender.male,
    'female' => ChildGender.female,
    'unspecified' => ChildGender.unspecified,
    _ => null,
  };

  String get wire => name;
}

enum ChildStatus {
  active,
  archived;

  static ChildStatus fromString(String? v) =>
      v == 'archived' ? ChildStatus.archived : ChildStatus.active;
}

/// A child profile (`ChildResource`).
///
/// Contract notes (backend is authoritative):
///  * write `birth_date` (`YYYY-MM-DD`); read the computed [age]
///  * `interests` carries full [Interest] rows on read; writes send interest UUIDs
///  * there is no `school_grade`, no `allergies`, no `learning_goals` on the child
///  * `avatar_color` is the only avatar field (no upload endpoint yet)
@immutable
class Child {
  const Child({
    required this.id,
    required this.familyId,
    required this.name,
    required this.birthDate,
    required this.age,
    required this.status,
    this.gender,
    this.avatarColor,
    this.preferredLanguage,
    this.contentAgeOverride,
    this.interests = const [],
  });

  final String id;
  final String familyId;
  final String name;
  final DateTime birthDate;
  final int age;
  final ChildStatus status;
  final ChildGender? gender;
  final String? avatarColor;
  final String? preferredLanguage;
  final int? contentAgeOverride;
  final List<Interest> interests;

  List<String> get interestIds =>
      interests.map((i) => i.id).toList(growable: false);

  factory Child.fromJson(Map<String, dynamic> json) {
    final rawInterests = (json['interests'] as List?) ?? const [];
    return Child(
      id: '${json['id']}',
      familyId: '${json['family_id']}',
      name: json['name'] as String? ?? '',
      birthDate: DateTime.tryParse('${json['birth_date']}') ?? DateTime(1970),
      age: (json['age'] as num?)?.toInt() ?? 0,
      status: ChildStatus.fromString(json['status'] as String?),
      gender: ChildGender.fromString(json['gender'] as String?),
      avatarColor: json['avatar_color'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      contentAgeOverride: (json['content_age_override'] as num?)?.toInt(),
      interests: rawInterests
          .whereType<Map>()
          .map((m) => Interest.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
