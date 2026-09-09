import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/devices_repository.dart';
import '../data/models/device.dart';

@immutable
class DevicesState {
  const DevicesState({
    required this.devices,
    required this.meta,
    this.loadingMore = false,
  });

  final List<Device> devices;
  final PageMeta meta;
  final bool loadingMore;

  bool get isEmpty => devices.isEmpty;
  bool get hasMore => meta.hasMore;

  DevicesState copyWith({
    List<Device>? devices,
    PageMeta? meta,
    bool? loadingMore,
  }) => DevicesState(
    devices: devices ?? this.devices,
    meta: meta ?? this.meta,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Registered devices for the active family. Family-scoped: a family switch
/// tears the list down and reloads.
class DevicesController extends AsyncNotifier<DevicesState> {
  static const _perPage = 15;

  String? get _familyId => ref.read(activeFamilyIdProvider);

  @override
  Future<DevicesState> build() async {
    final familyId = ref.watch(activeFamilyIdProvider);
    if (familyId == null) {
      return DevicesState(devices: const [], meta: PageMeta.single(0));
    }
    final page = await ref
        .read(devicesRepositoryProvider)
        .list(familyId, perPage: _perPage);
    return DevicesState(devices: page.items, meta: page.meta);
  }

  Future<void> refresh() async {
    final familyId = _familyId;
    if (familyId == null) return;
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(devicesRepositoryProvider)
          .list(familyId, perPage: _perPage);
      return DevicesState(devices: page.items, meta: page.meta);
    });
  }

  Future<void> loadMore() async {
    final familyId = _familyId;
    final current = state.valueOrNull;
    if (familyId == null ||
        current == null ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(devicesRepositoryProvider)
          .list(familyId, page: current.meta.nextPage, perPage: _perPage);
      state = AsyncData(
        current.copyWith(
          devices: [...current.devices, ...page.items],
          meta: page.meta,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Register **this install** as a device. The identifier is the stable
  /// per-install id persisted in secure storage, so a repeated registration
  /// from this install updates the existing device row rather than creating a
  /// duplicate — the backend de-duplicates on `(family, device_identifier_hash)`
  /// by exact string match, so the value must be byte-stable across app runs.
  Future<Device> registerThisInstall({
    required String name,
    required DevicePlatform platform,
    required DeviceMode deviceMode,
    String? childId,
  }) async {
    final familyId = _familyId;
    if (familyId == null) throw StateError('No active family');
    final installId = await ref
        .read(secureStorageProvider)
        .readOrCreateInstallId();
    final device = await ref
        .read(devicesRepositoryProvider)
        .register(
          familyId,
          DeviceRegisterInput(
            name: name,
            platform: platform,
            deviceMode: deviceMode,
            deviceIdentifierHash: installId,
            childId: childId,
          ),
        );
    await refresh();
    return device;
  }

  Future<void> updateDevice(String deviceId, DeviceUpdateInput input) async {
    final familyId = _familyId;
    if (familyId == null) return;
    await ref.read(devicesRepositoryProvider).update(familyId, deviceId, input);
    await refresh();
  }

  Future<void> remove(String deviceId) async {
    final familyId = _familyId;
    if (familyId == null) return;
    await ref.read(devicesRepositoryProvider).remove(familyId, deviceId);
    await refresh();
  }
}

final devicesControllerProvider =
    AsyncNotifierProvider<DevicesController, DevicesState>(
      DevicesController.new,
    );
