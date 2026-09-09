import 'package:flutter/foundation.dart';

/// Backend `App\Enums\DevicePlatform`.
enum DevicePlatform {
  ios('ios'),
  android('android'),
  web('web'),
  unknown('unknown');

  const DevicePlatform(this.wire);
  final String wire;

  static DevicePlatform fromWire(String? v) => switch (v) {
    'ios' => DevicePlatform.ios,
    'android' => DevicePlatform.android,
    'web' => DevicePlatform.web,
    _ => DevicePlatform.unknown,
  };
}

/// Backend `App\Enums\DeviceMode`. Records *expected* locking behaviour — the
/// API never locks a device itself.
enum DeviceMode {
  childDedicated('child_dedicated'),
  familyShared('family_shared'),
  unknown('unknown');

  const DeviceMode(this.wire);
  final String wire;

  static DeviceMode fromWire(String? v) => switch (v) {
    'child_dedicated' => DeviceMode.childDedicated,
    'family_shared' => DeviceMode.familyShared,
    _ => DeviceMode.unknown,
  };
}

/// A registered device (`DeviceResource`). `push_token` is never exposed — only
/// [hasPushToken]. Device registration records metadata for a future native
/// Child Mode; it does **not** grant this app any device-control capability.
@immutable
class Device {
  const Device({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.childId,
    required this.name,
    required this.platform,
    required this.deviceMode,
    required this.hasPushToken,
    required this.appVersion,
    required this.osVersion,
    required this.lastSeenAt,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String familyId;
  final String? userId;
  final String? childId;
  final String name;
  final DevicePlatform platform;
  final DeviceMode deviceMode;
  final bool hasPushToken;
  final String? appVersion;
  final String? osVersion;
  final DateTime? lastSeenAt;
  final bool isActive;
  final DateTime? createdAt;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: '${json['id']}',
    familyId: '${json['family_id']}',
    userId: json['user_id'] as String?,
    childId: json['child_id'] as String?,
    name: json['name'] as String? ?? '',
    platform: DevicePlatform.fromWire(json['platform'] as String?),
    deviceMode: DeviceMode.fromWire(json['device_mode'] as String?),
    hasPushToken: json['has_push_token'] as bool? ?? false,
    appVersion: json['app_version'] as String?,
    osVersion: json['os_version'] as String?,
    lastSeenAt: DateTime.tryParse('${json['last_seen_at']}'),
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse('${json['created_at']}'),
  );
}
