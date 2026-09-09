import 'package:flutter/foundation.dart';

/// The authenticated user, parsed from `UserResource` (`/auth/me`, `/me`,
/// login/register `data.user`).
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.preferredLanguage,
    this.timezone,
    this.status,
  });

  final String id;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;

  /// `ar` | `he` | `en`
  final String? preferredLanguage;
  final String? timezone;

  /// `active` | `suspended` | ...
  final String? status;

  String get displayName => [
    firstName,
    lastName,
  ].where((p) => (p ?? '').trim().isNotEmpty).join(' ').trim();

  /// A stable contact label for screens that showed a hardcoded email.
  String get contact => email ?? phone ?? '';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: '${json['id']}',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    preferredLanguage: json['preferred_language'] as String?,
    timezone: json['timezone'] as String?,
    status: json['status'] as String?,
  );

  AuthUser copyWith({
    String? firstName,
    String? lastName,
    String? preferredLanguage,
    String? timezone,
  }) => AuthUser(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email,
    phone: phone,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    timezone: timezone ?? this.timezone,
    status: status,
  );
}
