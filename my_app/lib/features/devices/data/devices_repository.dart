import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import 'models/device.dart';

/// `POST …/devices` body. `device_identifier_hash` is **required** by the
/// backend so a repeated registration from the same install de-duplicates
/// instead of creating a new row. We derive it from the per-install id in
/// secure storage (see `SecureTokenStorage.readOrCreateInstallId`).
class DeviceRegisterInput {
  const DeviceRegisterInput({
    required this.name,
    required this.platform,
    required this.deviceMode,
    required this.deviceIdentifierHash,
    this.childId,
    this.appVersion,
    this.osVersion,
  });

  final String name;
  final DevicePlatform platform;
  final DeviceMode deviceMode;
  final String deviceIdentifierHash;
  final String? childId;
  final String? appVersion;
  final String? osVersion;

  Map<String, dynamic> toJson() => {
    'name': name,
    'platform': platform.wire,
    'device_mode': deviceMode.wire,
    'device_identifier_hash': deviceIdentifierHash,
    if (childId != null) 'child_id': childId,
    if (appVersion != null) 'app_version': appVersion,
    if (osVersion != null) 'os_version': osVersion,
  };
}

class DeviceUpdateInput {
  const DeviceUpdateInput({
    this.name,
    this.deviceMode,
    this.childId,
    this.clearChild = false,
    this.isActive,
  });

  final String? name;
  final DeviceMode? deviceMode;
  final String? childId;
  final bool clearChild;
  final bool? isActive;

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (deviceMode != null) 'device_mode': deviceMode!.wire,
    if (clearChild)
      'child_id': null
    else if (childId != null)
      'child_id': childId,
    if (isActive != null) 'is_active': isActive,
  };
}

/// HTTP for `/families/{family}/devices` (`DeviceController`). Reads = any
/// active member; register = any active member; update / delete are policy-gated
/// server-side (the registering user or an owner). A revoked device stays
/// listed with `is_active: false`.
class DevicesRepository {
  DevicesRepository(this._client);

  final ApiClient _client;

  Future<Paginated<Device>> list(
    String familyId, {
    int page = 1,
    int perPage = 15,
  }) async {
    final envelope = await _client.get(
      '/families/$familyId/devices',
      query: {'page': page, 'per_page': perPage},
    );
    return Paginated.from<Device>(envelope, Device.fromJson);
  }

  Future<Device> register(String familyId, DeviceRegisterInput input) async {
    final envelope = await _client.post(
      '/families/$familyId/devices',
      body: input.toJson(),
    );
    return Device.fromJson(envelope.dataMap);
  }

  Future<Device> update(
    String familyId,
    String deviceId,
    DeviceUpdateInput input,
  ) async {
    final envelope = await _client.patch(
      '/families/$familyId/devices/$deviceId',
      body: input.toJson(),
    );
    return Device.fromJson(envelope.dataMap);
  }

  Future<void> remove(String familyId, String deviceId) async {
    await _client.delete('/families/$familyId/devices/$deviceId');
  }
}

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(ref.watch(apiClientProvider)),
);
