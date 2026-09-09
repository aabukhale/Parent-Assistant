import 'package:flutter/foundation.dart';

/// Payloads for the auth endpoints. Field names match the backend Form Requests
/// exactly (`RegisterRequest`, `LoginRequest`, `UpdateProfileRequest`).
@immutable
class RegisterInput {
  const RegisterInput({
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.familyName,
    required this.deviceName,
    this.preferredLanguage,
    this.timezone,
  });

  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String password;
  final String passwordConfirmation;
  final String familyName;
  final String deviceName;
  final String? preferredLanguage;
  final String? timezone;

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    if (_notBlank(lastName)) 'last_name': lastName,
    if (_notBlank(email)) 'email': email,
    if (_notBlank(phone)) 'phone': phone,
    'password': password,
    'password_confirmation': passwordConfirmation,
    'family_name': familyName,
    'device_name': deviceName,
    if (_notBlank(preferredLanguage)) 'preferred_language': preferredLanguage,
    if (_notBlank(timezone)) 'timezone': timezone,
  };

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;
}

@immutable
class LoginInput {
  const LoginInput({
    required this.login,
    required this.password,
    required this.deviceName,
  });

  /// Email or phone.
  final String login;
  final String password;
  final String deviceName;

  Map<String, dynamic> toJson() => {
    'login': login,
    'password': password,
    'device_name': deviceName,
  };
}

@immutable
class ProfileUpdateInput {
  const ProfileUpdateInput({
    this.firstName,
    this.lastName,
    this.preferredLanguage,
    this.timezone,
  });

  final String? firstName;
  final String? lastName;
  final String? preferredLanguage;
  final String? timezone;

  /// Only sends the fields the caller actually changed (`sometimes` on the API).
  Map<String, dynamic> toJson() => {
    if (firstName != null) 'first_name': firstName,
    if (lastName != null) 'last_name': lastName,
    if (preferredLanguage != null) 'preferred_language': preferredLanguage,
    if (timezone != null) 'timezone': timezone,
  };

  bool get isEmpty => toJson().isEmpty;
}
