import 'package:flutter/foundation.dart';

/// The identity of a paired child device, as reported by `GET /child/me`.
///
/// Everything here comes from the server for the token on this install; the
/// app never chooses which child it is.
@immutable
class ChildSession {
  const ChildSession({
    required this.childId,
    required this.name,
    required this.familyId,
    required this.familyName,
    required this.timezone,
    this.age,
    this.avatarKey,
    this.avatarColor,
    this.preferredLanguage,
    this.deviceId,
    this.deviceMode,
    this.abilities = const [],
  });

  final String childId;
  final String name;
  final int? age;
  final String? avatarKey;
  final String? avatarColor;
  final String? preferredLanguage;
  final String familyId;
  final String familyName;
  final String timezone;
  final String? deviceId;
  final String? deviceMode;
  final List<String> abilities;

  bool can(String ability) => abilities.contains(ability);

  factory ChildSession.fromJson(Map<String, dynamic> json) {
    final child = (json['child'] as Map?)?.cast<String, dynamic>() ?? const {};
    final family =
        (json['family'] as Map?)?.cast<String, dynamic>() ?? const {};
    final device = (json['device'] as Map?)?.cast<String, dynamic>();
    return ChildSession(
      childId: child['id'] as String,
      name: child['name'] as String? ?? '',
      age: (child['age'] as num?)?.toInt(),
      avatarKey: child['avatar_key'] as String?,
      avatarColor: child['avatar_color'] as String?,
      preferredLanguage: child['preferred_language'] as String?,
      familyId: family['id'] as String,
      familyName: family['name'] as String? ?? '',
      timezone: family['timezone'] as String? ?? 'UTC',
      deviceId: device?['id'] as String?,
      deviceMode: device?['device_mode'] as String?,
      abilities: ((json['abilities'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
